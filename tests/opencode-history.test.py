import importlib.util
import json
import sqlite3
import sys

spec = importlib.util.spec_from_file_location("migration", sys.argv[1])
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)
conn = sqlite3.connect(":memory:")
conn.execute(
    "CREATE TABLE message(id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT)"
)
assistant = {
    "role": "assistant",
    "parentID": "user",
    "mode": "build",
    "providerID": "vllm",
    "modelID": "old-model",
    "cost": 1.5,
    "tokens": {"input": 123, "output": 45},
}
conn.executemany(
    "INSERT INTO message VALUES (?, 'session', 1, ?)",
    [
        ("user", json.dumps({"role": "user", "time": {"created": 1}})),
        ("assistant", json.dumps(assistant)),
        ("unanswered", json.dumps({"role": "user", "time": {"created": 2}})),
    ],
)
with conn:
    assert migration.repair_metadata(conn) == 3
messages = {
    key: json.loads(raw) for key, raw in conn.execute("SELECT id, data FROM message")
}
assert messages["assistant"] == {**assistant, "agent": "build"}
assert messages["user"]["model"] == {"providerID": "vllm", "modelID": "old-model"}
assert messages["unanswered"]["model"] == {"providerID": "legacy", "modelID": "unknown"}
assert migration.repair_metadata(conn) == 0, "repair must be idempotent"
assert messages["user"]["time"] == {"created": 1}
print("Legacy history metadata repair regression passed")
