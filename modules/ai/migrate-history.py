"""Back up V1 history and fill metadata required by the V2 importer.

Older V1 messages used `mode` instead of `agent`; user messages did not always
record their model. Recover those values from their recorded assistant reply,
without changing text, tools, timestamps, token counts, or costs.
"""

import json
import os
import sqlite3
from datetime import UTC, datetime
from pathlib import Path


def repair_metadata(conn):
    rows = conn.execute("""SELECT id, session_id, data FROM message
        WHERE json_valid(data) AND (
          json_extract(data, '$.agent') IS NULL OR
          (json_extract(data, '$.role') = 'user' AND json_extract(data, '$.model') IS NULL)
        )""").fetchall()
    updates = []
    for message_id, session_id, raw in rows:
        message = json.loads(raw)
        role = message.get("role")
        if role == "assistant":
            if not message.get("agent"):
                if not isinstance(message.get("mode"), str):
                    raise ValueError(f"Cannot recover agent for {message_id}")
                message["agent"] = message["mode"]
        elif role == "user":
            reply = conn.execute(
                """SELECT data FROM message
                WHERE session_id = ? AND json_valid(data)
                  AND json_extract(data, '$.role') = 'assistant'
                  AND json_extract(data, '$.parentID') = ?
                ORDER BY time_created LIMIT 1""",
                (session_id, message_id),
            ).fetchone()
            if reply is None:
                # An abandoned prompt has no recorded model to recover. Keep
                # that uncertainty explicit rather than inventing usage/model
                # history. Select a current model before resuming this session.
                assistant = {
                    "mode": "build",
                    "providerID": "legacy",
                    "modelID": "unknown",
                }
                print(
                    f"Preserving unanswered legacy prompt {message_id} with model legacy/unknown"
                )
            else:
                assistant = json.loads(reply[0])
            if not message.get("agent"):
                message["agent"] = assistant.get("agent") or assistant["mode"]
            if not message.get("model"):
                message["model"] = {
                    "providerID": assistant["providerID"],
                    "modelID": assistant["modelID"],
                }
        else:
            raise ValueError(f"Unknown legacy message role in {message_id}")
        updates.append((json.dumps(message, separators=(",", ":")), message_id))
    conn.executemany("UPDATE message SET data = ? WHERE id = ?", updates)
    return len(updates)


def main():
    data = (
        Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "opencode"
    )
    database = (
        Path(os.environ.get("OPENCODE_DB", data / "opencode.db")).expanduser().resolve()
    )
    if not database.is_file():
        print("No existing history database; V2 will create one.")
        return
    conn = sqlite3.connect(database.as_uri() + "?mode=rw", uri=True, timeout=30)
    tables = {
        row[0]
        for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    }
    if "message" not in tables:
        print("No V1 messages to prepare.")
        return
    if (
        "kv" in tables
        and conn.execute("SELECT 1 FROM kv WHERE key='migration.v1-v2'").fetchone()
    ):
        raise RuntimeError(
            "V2 history migration has already started; do not rewrite its legacy source."
        )
    backup = database.with_name(
        "opencode-before-v2-" + datetime.now(UTC).strftime("%Y%m%d-%H%M%S") + ".db"
    )
    print(f"Backing up history to {backup}", flush=True)
    with backup.open("xb"):
        pass
    backup.chmod(0o600)
    target = sqlite3.connect(backup)
    try:
        conn.backup(target, pages=4096)
    finally:
        target.close()
    with conn:
        count = repair_metadata(conn)
    conn.close()
    print(f"Prepared {count} legacy messages. Backup retained at {backup}.")
    print("Start oc to let V2 migrate the prepared history.")


if __name__ == "__main__":
    main()
