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


def boundary(kind, message_id):
    return json.dumps({"type": kind, "messageID": message_id})


conn = sqlite3.connect(":memory:")
conn.execute(
    "CREATE TABLE session_v2(id TEXT PRIMARY KEY, fork_session_id TEXT, fork_boundary TEXT)"
)
conn.execute(
    "CREATE TABLE session_message(id TEXT PRIMARY KEY, session_id TEXT, type TEXT, seq INTEGER, time_created INTEGER, data TEXT)"
)
conn.executemany(
    "INSERT INTO session_v2 VALUES (?, ?, ?)",
    [
        ("parent", None, None),
        ("through", "parent", boundary("through", "parent-6")),
        ("before", "parent", boundary("before", "parent-8")),
        ("nested", "through", boundary("through", "through-7")),
        ("orphan", "deleted", boundary("through", "deleted-6")),
        ("broken", "parent", "{broken"),
        ("unknown", "parent", boundary("sideways", "parent-6")),
    ],
)
# seq has gaps, as in real OpenCode data, and a fork keeps its parent's seq on
# every copied row.
history = [(1, "user"), (3, "assistant"), (6, "idle")]
messages = [("parent", seq, kind) for seq, kind in history]
messages += [("parent", 8, "user"), ("parent", 9, "assistant")]
for fork in ("through", "before", "orphan", "broken", "unknown"):
    messages += [(fork, seq, kind) for seq, kind in history]
messages += [
    ("through", 7, "assistant"),
    # A "before" fork's own turns can land between the parent's last copied
    # row and the boundary, and can reuse the boundary's seq.
    ("before", 7, "assistant"),
    ("before", 8, "assistant"),
]
messages += [("nested", seq, kind) for seq, kind in history]
messages += [("nested", 7, "assistant"), ("nested", 8, "assistant")]
assistant = json.dumps(
    {"model": {"providerID": "anthropic", "id": "claude-test"}, "tokens": {"input": 1}}
)
conn.executemany(
    "INSERT INTO session_message VALUES (?, ?, ?, ?, ?, ?)",
    [
        (f"{session}-{seq}", session, kind, seq, 1000, assistant)
        for session, seq, kind in messages
    ],
)
usage.prepare(conn)
counted = {row[0] for row in conn.execute("SELECT id FROM opencode_usage")}
assert counted == {
    "parent-3",
    "parent-9",
    "through-7",
    "before-7",
    "before-8",
    "nested-8",
    "orphan-3",
    "broken-3",
    "unknown-3",
}, f"fork copies skipped, own turns and unresolved forks kept: {sorted(counted)}"
conn.close()
print("OpenCode usage V1/V2 migration, deduplication, and fork tests passed")
