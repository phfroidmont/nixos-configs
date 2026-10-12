"""Exercise the collector's RPC parsing without credentials or local usage data."""

import ast
import json
import sys
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
        and node.name in ("fetch_codex_rpc", "limit_window")
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
        "rpc_request": rpc,
        "json": json,
        "number": lambda value: int(value or 0),
        "datetime": datetime,
        "timezone": timezone,
    }
    # Load only the trusted collector functions, avoiding its filesystem setup.
    exec(compile(functions, "collector", "exec"), namespace)  # noqa: S102
    return namespace["fetch_codex_rpc"](), rpc


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
        self.assertEqual(rpc.call_args_list[3].args[3], {"refreshToken": True})
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


unittest.main()
