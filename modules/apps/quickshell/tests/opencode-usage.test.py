import importlib.util
import json
import sqlite3
import sys
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("usage", sys.argv[1])
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)

with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "opencode.db"
    conn = sqlite3.connect(path)
    conn.execute(
        "CREATE TABLE message(id TEXT PRIMARY KEY, session_id TEXT, data TEXT)"
    )
    conn.execute(
        "CREATE TABLE session_message(id TEXT PRIMARY KEY, session_id TEXT, type TEXT, time_created INTEGER, data TEXT)"
    )
    legacy = {
        "role": "assistant",
        "providerID": "openai",
        "modelID": "gpt-test",
        "tokens": {"input": 10},
        "time": {"created": 1000},
    }
    modern = {
        "model": {"providerID": "openai", "id": "gpt-test"},
        "tokens": {"input": 20},
    }
    conn.execute(
        "INSERT INTO message VALUES (?, ?, ?)", ("old", "session", json.dumps(legacy))
    )
    conn.execute(
        "INSERT INTO message VALUES (?, ?, ?)",
        ("compact", "session", json.dumps(legacy)),
    )
    conn.executemany(
        "INSERT INTO session_message VALUES (?, ?, ?, ?, ?)",
        [
            ("old", "session", "assistant", 1000, json.dumps(modern)),
            ("new", "session", "assistant", 2000, json.dumps(modern)),
            ("compact", "session", "compaction", 1000, "{}"),
            ("user", "session", "user", 2000, "{}"),
            ("invalid", "session", "assistant", 2000, "{broken"),
        ],
    )
    conn.commit()
    conn.close()
    conn = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
    usage.prepare(conn)
    conn.execute("PRAGMA query_only = ON")
    rows = dict(conn.execute("SELECT id, data FROM opencode_usage"))
    assert len(rows) == 3, "migrated records counted once; compaction usage retained"
    assert sum(json.loads(row)["tokens"]["input"] for row in rows.values()) == 40
    assert json.loads(rows["new"])["providerID"] == "openai"
    assert json.loads(rows["new"])["modelID"] == "gpt-test"
    assert json.loads(rows["new"])["time"]["created"] == 2000
    assert conn.execute("SELECT count(*) FROM message").fetchone()[0] == 2
    conn.close()
    for schema in (
        "CREATE TABLE message(id TEXT, session_id TEXT, data TEXT)",
        "CREATE TABLE session_message(id TEXT, session_id TEXT, type TEXT, time_created INTEGER, data TEXT)",
    ):
        conn = sqlite3.connect(":memory:")
        conn.execute(schema)
        usage.prepare(conn)
        assert list(conn.execute("SELECT * FROM opencode_usage")) == []
        conn.close()
print("OpenCode usage V1/V2 migration and deduplication tests passed")
