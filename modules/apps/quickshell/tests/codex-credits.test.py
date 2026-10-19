"""Exercise the collector's RPC parsing without credentials or local usage data."""

import ast
import json
import queue
import subprocess
import sys
import threading
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock

source = ast.parse(Path(sys.argv.pop(1)).read_text())
functions = ast.Module(
    body=[
        node
        for node in source.body
        if isinstance(node, ast.FunctionDef)
        and node.name
        in ("fetch_codex_rpc", "limit_window", "read_lines", "rpc_request")
    ],
    type_ignores=[],
)


def run_fetch(responses):
    rpc = Mock(side_effect=responses)
    namespace = {
        "AUTH_HELP": "Log in",
        "ENV": {},
        "find_command": lambda name: name,
        "subprocess": Mock(),
        "json": json,
        "number": lambda value: int(value or 0),
        "datetime": datetime,
        "timezone": timezone,
    }
    # Load only the trusted collector functions, avoiding its filesystem setup.
    exec(compile(functions, "collector", "exec"), namespace)  # noqa: S102
    # Replace the pipe plumbing loaded above with the scripted responses.
    namespace["read_lines"] = Mock()
    namespace["rpc_request"] = rpc
    return namespace["fetch_codex_rpc"](), rpc


def load_rpc_request():
    namespace = {
        "json": json,
        "queue": queue,
        "threading": threading,
        "time": time,
    }
    exec(compile(functions, "collector", "exec"), namespace)  # noqa: S102
    return namespace["read_lines"], namespace["rpc_request"]


WINDOW = {"usedPercent": 100, "windowDurationMins": 10080}
ACCOUNT = {"result": {"account": {"planType": "pro"}}}
EXPIRED = {"error": {"code": -32603, "message": "token_expired"}}


class CodexTokenRefreshTest(unittest.TestCase):
    def test_refreshes_token_and_retries(self):
        result, rpc = run_fetch(
            [
                {},
                ACCOUNT,
                EXPIRED,
                ACCOUNT,
                {"result": {"rateLimits": {"primary": WINDOW}}},
            ]
        )
        self.assertEqual(rpc.call_count, 5)
        self.assertEqual(rpc.call_args_list[3].args[4], {"refreshToken": True})
        self.assertEqual(result["limits"][0]["percent"], 1.0)
        self.assertEqual(result["usageStatusText"], "")

    def test_reports_persistent_error(self):
        result, rpc = run_fetch([{}, ACCOUNT, EXPIRED, ACCOUNT, EXPIRED])
        self.assertEqual(rpc.call_count, 5)
        self.assertEqual(result["limits"], [])
        self.assertEqual(result["usageStatusText"], "Codex limits unavailable")
        self.assertEqual(result["authHelpText"], "token_expired")


class CodexCreditsTest(unittest.TestCase):
    def fetch(self, credits):
        result, rpc = run_fetch(
            [
                {},
                ACCOUNT,
                {"result": {"rateLimits": {"secondary": WINDOW, "credits": credits}}},
            ]
        )
        self.assertEqual(result["tierLabel"], "pro")
        self.assertEqual(result["limits"][0]["percent"], 1.0)
        self.assertEqual(result["usageStatusText"], "")
        self.assertEqual(rpc.call_count, 3)
        return result.get("creditsText", "")

    def test_balance(self):
        for balance, expected in (
            ("1250.50", "1250"),
            ("2051.4769850000", "2051"),
            ("2051.99", "2051"),
            ("1250", "1250"),
            ("0.75", "0"),
        ):
            with self.subTest(balance=balance):
                self.assertEqual(
                    self.fetch({"hasCredits": True, "balance": balance}), expected
                )

    def test_zero(self):
        self.assertEqual(self.fetch({"hasCredits": False, "balance": "0"}), "0")

    def test_unlimited(self):
        for balance in (None, "0", "1250.50"):
            with self.subTest(balance=balance):
                self.assertEqual(
                    self.fetch({"unlimited": True, "balance": balance}), "Unlimited"
                )

    def test_unavailable(self):
        for credits in (
            None,
            {},
            {"hasCredits": False, "balance": None},
            {"balance": ""},
            {"balance": "  "},
            {"balance": 42},
            [],
        ):
            with self.subTest(credits=credits):
                self.assertEqual(self.fetch(credits), "")


# The app-server writes a notification and the reply in a single chunk.
SAME_CHUNK_SERVER = r"""
import sys
sys.stdin.readline()
sys.stdout.write('{"method":"account/updated","params":{}}\n{"id":2,"result":{"ok":true}}\n')
sys.stdout.flush()
sys.stdin.readline()
"""


class CodexRpcReadTest(unittest.TestCase):
    def test_reply_sharing_a_chunk_with_a_notification(self):
        read_lines, rpc_request = load_rpc_request()
        proc = subprocess.Popen(
            [sys.executable, "-I", "-c", SAME_CHUNK_SERVER],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
        )
        try:
            message = rpc_request(
                proc, read_lines(proc.stdout), 2, "account/read", timeout=2
            )
        finally:
            proc.kill()
            proc.wait()
        self.assertEqual(message["result"], {"ok": True})


unittest.main()
