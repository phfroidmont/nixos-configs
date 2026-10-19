"""Run the Codex collector over pi fixtures: no codex binary, so it never reaches the network."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

collector = Path(sys.argv.pop(1))

TODAY = datetime.now().astimezone()


def pi_message(identifier, provider, api, model, tokens):
    return {
        "type": "message",
        "id": identifier,
        "timestamp": TODAY.isoformat(),
        "message": {
            "role": "assistant",
            "provider": provider,
            "api": api,
            "model": model,
            "usage": {
                "input": tokens,
                "output": tokens,
                "cacheRead": tokens,
                "cacheWrite": tokens,
            },
        },
    }


class CodexUsageTest(unittest.TestCase):
    def collect(self, *session_entries):
        """One collector run against a fresh home, so no cache outlives a case."""
        with tempfile.TemporaryDirectory() as raw:
            home = Path(raw)
            sessions = home / ".pi" / "agent" / "sessions" / "--fixture--"
            sessions.mkdir(parents=True)
            (sessions / "session.jsonl").write_text(
                "".join(json.dumps(entry) + "\n" for entry in session_entries)
            )

            # Only rg: without codex the collector skips the rate-limit probe.
            bin_dir = home / "bin"
            bin_dir.mkdir()
            (bin_dir / "rg").symlink_to(shutil.which("rg"))

            result = subprocess.run(
                [str(collector)],
                capture_output=True,
                check=True,
                text=True,
                env={
                    "HOME": str(home),
                    "PATH": str(bin_dir),
                    "XDG_DATA_HOME": str(home / ".local" / "share"),
                    "XDG_CACHE_HOME": str(home / ".cache"),
                    "CODEX_HOME": str(home / ".codex"),
                    "TZ": os.environ.get("TZ", ""),
                },
            )
            return json.loads(result.stdout)

    def test_chatgpt_login_on_the_openai_provider_is_counted(self):
        # pi 0.99 moved the ChatGPT subscription from openai-codex to a login
        # on the openai provider, whose messages say provider "openai".
        record = self.collect(
            pi_message("chatgpt", "openai", "openai-responses", "gpt-chatgpt", 10),
        )
        self.assertIn("gpt-chatgpt", record["modelUsage"])
        self.assertEqual(record["todayPrompts"], 1)
        self.assertEqual(record["todayTotalTokens"], 40)

    def test_legacy_codex_provider_is_still_counted(self):
        record = self.collect(
            pi_message(
                "legacy", "openai-codex", "openai-codex-responses", "gpt-legacy", 10
            ),
        )
        self.assertIn("gpt-legacy", record["modelUsage"])
        self.assertEqual(record["todayTotalTokens"], 40)

    def test_other_providers_are_left_out(self):
        record = self.collect(
            pi_message("claude", "anthropic", "anthropic-messages", "claude", 10),
            pi_message("router", "openrouter", "openai-completions", "openai/gpt", 10),
        )
        self.assertEqual(record["modelUsage"], {})
        self.assertEqual(record["totalPrompts"], 0)


unittest.main()
