"""Audit effective model limits, including aliases and subscription overrides."""

import argparse
import json
import subprocess
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def audit(models, catalog, meridian):
    contexts = {model["id"]: model["context_window"] for model in meridian["data"]}
    checked = {"openai": 0, "anthropic": 0}
    failures = []
    for model in models:
        provider = model["providerID"]
        if provider not in checked or not model.get("enabled", True):
            continue
        checked[provider] += 1
        name = f"{provider}/{model['id']}"
        source = catalog[provider]["models"].get(model["modelID"])
        if source is None:
            failures.append(
                f"{name}: no catalog limits for {model['modelID']}; needs review"
            )
            continue
        expected = dict(source["limit"])
        if provider == "anthropic" and model["modelID"] in contexts:
            expected["context"] = contexts[model["modelID"]]
        # An omitted input limit uses context minus maximum output. Treat an
        # explicit equivalent value the same, but catch stale smaller budgets.
        actual = dict(model["limit"])
        for limits in (actual, expected):
            limits.setdefault("input", limits["context"] - limits["output"])
        if actual != expected:
            failures.append(f"{name}: effective {actual}, expected {expected}")
    if not all(checked.values()):
        failures.append(f"Incomplete inventory: {checked}")
    return checked, failures


def get_json(url):
    request = Request(url, headers={"User-Agent": "oc-check-model-limits/1.0"})
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("native")
    parser.add_argument("--server", help="Optional isolated OpenCode server URL")
    parser.add_argument("--directory", default=".")
    parser.add_argument("--meridian", default="http://127.0.0.1:3456")
    args = parser.parse_args()
    query = urlencode({"directory": str(Path(args.directory).resolve())})
    command = [args.native, "api"]
    if args.server:
        command.extend(["--server", args.server])
    command.extend(["get", "/api/model?" + query])
    models = json.loads(subprocess.check_output(command, text=True))["data"]
    checked, failures = audit(
        models,
        get_json("https://models.dev/api.json"),
        get_json(args.meridian.rstrip("/") + "/v1/models"),
    )
    print(
        f"Checked {checked['openai']} OpenAI and {checked['anthropic']} Anthropic models (including aliases)."
    )
    for failure in failures:
        print(failure)
    if failures:
        raise SystemExit(1)
    print(
        "All context, input, and output limits match the catalog and Meridian subscription inventory."
    )


if __name__ == "__main__":
    main()
