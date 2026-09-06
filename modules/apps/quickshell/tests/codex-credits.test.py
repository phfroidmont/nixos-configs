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


class CodexCreditsTest(unittest.TestCase):
    def fetch(self, credits):
        window = {"usedPercent": 100, "windowDurationMins": 10080}
        rpc = Mock(
            side_effect=[
                {},
                {"result": {"account": {"planType": "pro"}}},
                {"result": {"rateLimits": {"secondary": window, "credits": credits}}},
            ]
        )
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
        result = namespace["fetch_codex_rpc"]()
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
