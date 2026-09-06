"""Run the Claude collector over fixtures: no sign-in, so it never reaches the network."""

import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

collector = Path(sys.argv.pop(1))

TODAY = datetime.now().astimezone()
LAST_WEEK = TODAY - timedelta(days=8)

# Each transcript message is worth four times its token figure: the collector
# adds input, output, and both cache counters.
TOKEN_FIELDS = 4


def transcript_message(identifier, model, when, tokens, entrypoint):
    entry = {
        "type": "assistant",
        "timestamp": when.isoformat(),
        "sessionId": "session-" + identifier,
        "message": {
            "role": "assistant",
            "id": identifier,
            "model": model,
            "usage": {
                "input_tokens": tokens,
                "output_tokens": tokens,
                "cache_read_input_tokens": tokens,
                "cache_creation_input_tokens": tokens,
            },
        },
    }
    if entrypoint is not None:
        entry["entrypoint"] = entrypoint
    return entry


class ClaudeUsageTest(unittest.TestCase):
    def collect(self, *transcript_entries):
        """One collector run against a fresh home, so no cache outlives a case."""
        with tempfile.TemporaryDirectory() as raw:
            home = Path(raw)

            transcripts = home / ".claude" / "projects" / "-fixture"
            transcripts.mkdir(parents=True)
            (transcripts / "session.jsonl").write_text(
                "".join(json.dumps(entry) + "\n" for entry in transcript_entries)
            )

            database = home / ".local" / "share" / "opencode" / "opencode.db"
            database.parent.mkdir(parents=True)
            connection = sqlite3.connect(database)
            connection.execute("CREATE TABLE message (session_id TEXT, data TEXT)")
            connection.execute(
                "INSERT INTO message (session_id, data) VALUES (?, ?)",
                (
                    "opencode-session",
                    json.dumps(
                        {
                            "role": "assistant",
                            "providerID": "anthropic",
                            "modelID": "claude-opencode",
                            "time": {"created": int(TODAY.timestamp() * 1000)},
                            "tokens": {
                                "input": 7,
                                "output": 7,
                                "reasoning": 0,
                                "cache": {"read": 7, "write": 7},
                            },
                        }
                    ),
                ),
            )
            connection.commit()
            connection.close()

            result = subprocess.run(
                [str(collector)],
                capture_output=True,
                check=True,
                text=True,
                env={
                    "HOME": str(home),
                    "XDG_CONFIG_HOME": str(home / ".config"),
                    "XDG_DATA_HOME": str(home / ".local" / "share"),
                    "XDG_CACHE_HOME": str(home / ".cache"),
                },
            )
            return json.loads(result.stdout)

    def test_agent_sdk_sessions_are_left_to_opencode(self):
        # opencode drives Claude Code through the SDK and keeps its own durable
        # row per message, so the transcript must not be counted a second time.
        for entrypoint in ("sdk-ts", "sdk-py"):
            with self.subTest(entrypoint=entrypoint):
                record = self.collect(
                    transcript_message("sdk", "claude-sdk", TODAY, 100, entrypoint),
                )
                self.assertNotIn("claude-sdk", record["modelUsage"])
                self.assertIn("claude-opencode", record["modelUsage"])
                self.assertEqual(record["totalPrompts"], 1)
                self.assertEqual(record["todayTotalTokens"], 7 * TOKEN_FIELDS)

    def test_interactive_sessions_are_counted(self):
        # An interactive run reaches Anthropic on its own, and no other source
        # knows about it. A transcript naming no entrypoint predates the field.
        for entrypoint in ("cli", "vscode", None):
            with self.subTest(entrypoint=entrypoint):
                record = self.collect(
                    transcript_message("live", "claude-live", TODAY, 100, entrypoint),
                )
                self.assertIn("claude-live", record["modelUsage"])
                self.assertIn("claude-opencode", record["modelUsage"])
                self.assertEqual(record["totalPrompts"], 2)
                self.assertEqual(record["todayTotalTokens"], 107 * TOKEN_FIELDS)

    def test_model_usage_covers_only_the_recent_window(self):
        record = self.collect(
            transcript_message("recent", "claude-recent", TODAY, 100, "cli"),
            transcript_message("stale", "claude-stale", LAST_WEEK, 200, "cli"),
        )
        self.assertIn("claude-recent", record["modelUsage"])
        self.assertNotIn("claude-stale", record["modelUsage"])
        # All-time counters still see both: only the model breakdown is windowed.
        self.assertEqual(record["totalPrompts"], 3)
        self.assertEqual(record["activeDays"], 2)

    def test_a_mixed_day_counts_each_message_once(self):
        record = self.collect(
            transcript_message("live", "claude-live", TODAY, 100, "cli"),
            transcript_message("sdk", "claude-sdk", TODAY, 500, "sdk-ts"),
        )
        self.assertEqual(
            sorted(record["modelUsage"]), ["claude-live", "claude-opencode"]
        )
        self.assertEqual(record["todayTotalTokens"], 107 * TOKEN_FIELDS)
        self.assertEqual(record["recentDays"][-1]["messageCount"], 107 * TOKEN_FIELDS)


unittest.main()
