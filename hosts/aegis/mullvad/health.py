#!/usr/bin/env python3
"""Evaluate the bounded Mullvad tunnel health predicate."""

import sys

MAX_HANDSHAKE_AGE = 180


def is_healthy(handshake: int, received: int, sent: int, now: int) -> bool:
    age = now - handshake
    return 0 <= age <= MAX_HANDSHAKE_AGE and received > 0 and sent > 0


if __name__ == "__main__":
    try:
        values = [int(value) for value in sys.argv[1:]]
        if len(values) != 4:
            raise ValueError
    except ValueError:
        print("usage: health.py HANDSHAKE RECEIVED SENT NOW", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(0 if is_healthy(*values) else 1)
