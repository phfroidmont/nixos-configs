"""A read-only usage view covering OpenCode V1 and V2 without double counting.

Keep legacy records authoritative when present: V2 turns some compaction
messages into non-assistant records, while V1 still has their usage details.
A V2 fork starts with copies of its parent's history, under new ids but with
the parent's seq; skip them, since the parent already counts that usage.
Only the connection-local TEMP schema is changed, never OpenCode's database.
"""


def columns(conn, table):
    return {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}


def boundary_field(name):
    # json_extract raises on malformed JSON and SQLite does not promise to
    # evaluate AND terms in order, so the guard wraps each extraction.
    return f"CASE WHEN json_valid(fork.fork_boundary) THEN json_extract(fork.fork_boundary, '$.{name}') END"


# A "through" fork copies the parent up to and including the boundary message;
# a "before" fork stops at the parent's last message ahead of it. seq has gaps
# and a fork's own turns can take seqs between those two, so the cutoff is
# looked up rather than computed. A boundary that no longer resolves, or an
# unknown boundary type, leaves every row counted.
FORK_COPIES = f"""
    AND NOT EXISTS (
        SELECT 1
        FROM session_v2 fork
        JOIN session_message boundary
          ON boundary.session_id = fork.fork_session_id
          AND boundary.id = {boundary_field("messageID")}
        WHERE fork.id = current.session_id
          AND current.seq <= CASE {boundary_field("type")}
            WHEN 'through' THEN boundary.seq
            WHEN 'before' THEN (
              SELECT max(parent.seq) FROM session_message parent
              WHERE parent.session_id = fork.fork_session_id
                AND parent.seq < boundary.seq
            )
          END
    )
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
        if (
            "session_v2" in tables
            and {"fork_session_id", "fork_boundary"} <= columns(conn, "session_v2")
            and "seq" in columns(conn, "session_message")
        ):
            exclude += FORK_COPIES
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
