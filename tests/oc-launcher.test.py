import importlib.util
import json
import sys
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("oc", sys.argv[1])
oc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oc)
presets = sys.argv[2]


def launch(args, session=None):
    calls = []

    def run(argv, **kwargs):
        if "/api/experimental/migration/v1" in argv:
            return type("Result", (), {"stdout": '{"status":"completed"}'})()
        body = json.loads(argv[argv.index("--data") + 1]) if "--data" in argv else None
        calls.append((argv, body))
        if argv[2] == "GET":
            response = session
        else:
            response = {"id": "ses_new", **(body or {})}
        return type("Result", (), {"stdout": json.dumps({"data": response})})()

    with (
        patch.object(oc.subprocess, "run", run),
        patch.object(oc.os, "execv") as execute,
        patch.dict(oc.os.environ, {}, clear=True),
    ):
        oc.main("/native/opencode", presets, args)
        return calls, execute.call_args.args[1]


calls, argv = launch(["--profile", "premium", "--review-model=fable"])
assert calls[0][1]["agent"] == "oc-custom-premium-fable-build"
assert calls[0][1]["model"]["variant"] == "xhigh"
assert argv == ["/native/opencode", "--session", "ses_new", "--auto"]
calls, argv = launch(
    ["--agents", "stock", "--profile", "anthropic", "--no-auto", "--", "run", "Explain"]
)
assert calls[0][1]["agent"] == "build"
assert argv == ["/native/opencode", "run", "--session", "ses_new", "Explain"]
session = {
    "id": "ses_old",
    "agent": "oc-custom-premium-fable-build",
    "metadata": {
        "ocProfile": "oc-custom-premium-fable-",
        "ocSelection": {"mode": "custom", "profile": "premium", "reviewer": "fable"},
    },
}
calls, argv = launch(["--session", "ses_old"], session)
assert len(calls) == 1, "resuming must not reset the selected model or profile"
assert argv[2] == "ses_old"
calls, argv = launch(["--", "service", "status"])
assert not calls and argv == ["/native/opencode", "service", "status"]
for args in (
    ["--power"],
    ["--profile"],
    ["--profile=x"],
    ["--agents=stock", "--review-model=opus"],
    ["--profile=balanced", "--profile=premium"],
):
    try:
        launch(args)
        raise AssertionError(f"accepted invalid arguments: {args}")
    except ValueError:
        pass
print("V2 launcher selection and resume tests passed")
