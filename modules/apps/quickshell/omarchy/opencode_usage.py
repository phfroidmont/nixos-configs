"""A read-only usage view covering OpenCode V1 and V2 without double counting.

Keep legacy records authoritative when present: V2 turns some compaction
messages into non-assistant records, while V1 still has their usage details.
Only the connection-local TEMP schema is changed, never OpenCode's database.
"""


def prepare(conn):
    tables = {
        row[0]
        for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    }
    queries = []
    if "message" in tables:
        queries.append("SELECT id, session_id, data FROM message")
    if "session_message" in tables:
        exclude = (
            "AND NOT EXISTS (SELECT 1 FROM message old WHERE old.id = current.id)"
            if "message" in tables
            else ""
        )
        queries.append(f"""
            SELECT id, session_id,
              CASE WHEN json_valid(data) THEN json_object('role', 'assistant',
                'providerID', json_extract(data, '$.model.providerID'),
                'modelID', json_extract(data, '$.model.id'),
                'tokens', json_extract(data, '$.tokens'),
                'time', json_object('created', time_created)) END AS data
            FROM session_message current
            WHERE type = 'assistant' {exclude} AND json_valid(data)
        """)
    query = (
        " UNION ALL ".join(queries)
        or "SELECT NULL AS id, NULL AS session_id, NULL AS data WHERE 0"
    )
    conn.execute("CREATE TEMP VIEW opencode_usage AS " + query)
