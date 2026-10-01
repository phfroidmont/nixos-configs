"""Session-scoped profile selection for OpenCode's shared V2 service."""

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import urlopen

HELP = """Usage: oc [launcher options] [--] [opencode arguments...]

  --profile balanced|openai|anthropic|premium
  --agents custom|stock
  --review-model fable|opus
  --no-auto                 Do not automatically approve permission requests
  --help                    Native help: oc -- --help

Selections are stored on the session, not on the shared daemon. Resuming without
selectors preserves the session's profile and model. New sessions default to the
balanced model profile with stock agents. Use --agents custom for the custom
suite. --power has been removed.
"""


def fail(message):
    raise ValueError(message)


def model_ref(value):
    model, _, variant = value.partition("#")
    provider, model = model.split("/", 1)
    return {
        "providerID": provider,
        "id": model,
        **({"variant": variant} if variant else {}),
    }


def wait_for_metals(directory):
    if os.environ.get("HERDR_ENV") != "1":
        return
    for filename in ("opencode.json", "opencode.jsonc"):
        try:
            config = json.loads((Path(directory) / filename).read_text())
        except (OSError, ValueError):
            continue
        mcp = config.get("mcp", {})
        server = mcp.get("servers", mcp).get("metals-lsp", {})
        url = server.get("url", "")
        if (
            server.get("disabled")
            or server.get("enabled") is False
            or not url.startswith(("http://localhost:", "http://127.0.0.1:"))
        ):
            continue
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            try:
                with urlopen(url, timeout=1):
                    return
            except HTTPError as error:
                if error.code < 500:
                    return
            except (URLError, TimeoutError, OSError):
                pass
            time.sleep(0.25)
        print(
            f"oc: timed out waiting for Metals MCP at {url}; starting anyway",
            file=sys.stderr,
        )


def main(native, presets_path, args):
    selectors = {}
    auto = True
    while args:
        option, equals, value = args[0].partition("=")
        if option in ("--profile", "--agents", "--review-model"):
            args.pop(0)
            if not equals:
                if not args:
                    fail(f"{option} requires a value")
                value = args.pop(0)
            choices = {
                "--profile": ("balanced", "openai", "anthropic", "premium"),
                "--agents": ("custom", "stock"),
                "--review-model": ("fable", "opus"),
            }
            if value not in choices[option]:
                fail(f"invalid value for {option}: {value}")
            if option in selectors and selectors[option] != value:
                fail(f"conflicting {option} values")
            selectors[option] = value
        elif option in ("--auto", "--no-auto"):
            auto = option == "--auto"
            args.pop(0)
        elif option == "--power":
            fail(
                "--power was removed: the unused Superpowers plugin is not loaded in V2"
            )
        elif option == "--help":
            print(HELP)
            return
        else:
            if option == "--":
                args.pop(0)
            break

    # Maintenance commands must not create sessions or get permission flags.
    command = args[0] if args else ""
    maintenance = {
        "api",
        "auth",
        "mcp",
        "models",
        "stats",
        "session",
        "service",
        "debug",
        "plugin",
        "reload",
        "pair",
        "serve",
        "upgrade",
        "update",
        "uninstall",
        "acp",
    }
    if command in maintenance or any(
        arg in ("--help", "-h", "--version", "-v", "--completions") for arg in args
    ):
        if selectors:
            fail("profile selectors apply to interactive sessions, mini, and run")
        return os.execv(native, [native, *args])
    if os.environ.get("OPENCODE_CONFIG_CONTENT", "{}").strip() not in ("", "{}"):
        fail(
            "OPENCODE_CONFIG_CONTENT is daemon-wide in V2; move settings to project configuration"
        )
    # Do not let the first client seed shared server configuration accidentally.
    os.environ.pop("OPENCODE_CONFIG_CONTENT", None)

    endpoint_args = []
    forwarded = []
    session_id = None
    continuing = False
    fork = False
    directory = os.getcwd()
    explicit_agent = None
    explicit_model = None
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--":
            forwarded.extend(args[index:])
            break
        key, equals, value = arg.partition("=")
        if key in ("--session", "-s", "--server", "--model", "-m", "--agent", "--dir"):
            if not equals:
                index += 1
                if index == len(args):
                    fail(f"{key} requires a value")
                value = args[index]
            if key in ("--session", "-s"):
                session_id = value
            elif key == "--server":
                endpoint_args = ["--server", value]
                forwarded.extend(endpoint_args)
            elif key in ("--model", "-m"):
                explicit_model = value
            elif key == "--agent":
                explicit_agent = value
            else:
                directory = str(Path(value).resolve())
                forwarded.extend(["--dir", directory])
        elif (
            key in ("--prompt", "--file", "-f", "--format", "--title", "--log-level")
            and not equals
        ):
            if index + 1 == len(args):
                fail(f"{key} requires a value")
            forwarded.extend(args[index : index + 2])
            index += 1
        elif arg in ("--continue", "-c"):
            continuing = True
        elif arg == "--fork":
            fork = True
        elif arg == "--standalone":
            fail(
                "oc profiles use the shared service; use opencode --standalone for a private server"
            )
        elif arg == "--port" or arg.startswith("--port="):
            fail(
                "V2 clients use the shared service; configure its port with opencode service set port"
            )
        else:
            forwarded.append(arg)
        index += 1
    if command not in ("run", "mini", "") and not command.startswith("-"):
        directory = str(Path(command).resolve())
    wait_for_metals(directory)

    def api(method, path, body=None):
        argv = [native, "api", *endpoint_args, method, path]
        if body is not None:
            argv.extend(["--data", json.dumps(body)])
        result = subprocess.run(argv, check=True, text=True, stdout=subprocess.PIPE)
        if not result.stdout.strip():
            return None
        value = json.loads(result.stdout)
        return value.get("data", value) if isinstance(value, dict) else value

    announced_migration = False
    while True:
        migration = api("GET", "/api/experimental/migration/v1")
        if migration["status"] == "completed":
            break
        if migration["status"] == "error":
            fail(
                f"history migration failed: {migration.get('error', 'see server log')}"
            )
        if not announced_migration:
            print("oc: waiting for V2 history migration...", file=sys.stderr)
            announced_migration = True
        time.sleep(2)

    if continuing and not session_id:
        sessions = api(
            "GET",
            "/api/session?parentID=null&limit=1&order=desc&directory="
            + quote(directory, safe=""),
        )
        roots = [
            s
            for s in sessions
            if not s.get("parentID")
            and s.get("location", {}).get("directory") == directory
        ]
        if roots:
            session_id = max(roots, key=lambda s: s["time"]["updated"])["id"]
    session = (
        api("GET", "/api/session/" + quote(session_id, safe="")) if session_id else None
    )
    if fork and session:
        session = api("POST", f"/api/session/{session_id}/fork", {})
        session_id = session["id"]
    metadata = (session or {}).get("metadata") or {}
    had_profile = "ocProfile" in metadata
    previous = metadata.get("ocSelection", {})
    mode = selectors.get("--agents", previous.get("mode", "stock"))
    if mode == "stock" and "--review-model" in selectors:
        fail("--review-model requires --agents custom")
    profile = selectors.get("--profile", previous.get("profile", "balanced"))
    reviewer = (
        selectors.get("--review-model", previous.get("reviewer", "default"))
        if mode == "custom"
        else "default"
    )
    group = f"oc-{mode}-{profile}-{reviewer}-"
    agent = explicit_agent or (session or {}).get("agent") or "build"
    if agent.startswith("oc-"):
        # All group components are single words; agent IDs may contain hyphens.
        agent = agent.split("-", 4)[4]
    presets = json.loads(Path(presets_path).read_text())
    supported = (
        presets["custom"]
        if mode == "custom"
        else {"build": {}, "plan": {}, "general": {}, "explore": {}}
    )
    selected_agent = group + agent if mode == "custom" and agent in supported else agent
    selected_model = (
        explicit_model
        or presets["profiles"][profile].get(
            agent, presets["profiles"][profile]["build"]
        )["model"]
    )
    metadata = {
        **metadata,
        "ocProfile": group,
        "ocSelection": {"mode": mode, "profile": profile, "reviewer": reviewer},
    }
    if session:
        if (
            selectors
            or explicit_agent
            or explicit_model
            or not had_profile
            or (mode == "custom" and not session.get("agent", "").startswith("oc-"))
        ):
            api("PATCH", f"/api/session/{session_id}", {"metadata": metadata})
            api("POST", f"/api/session/{session_id}/agent", {"agent": selected_agent})
            if "--profile" in selectors or explicit_model:
                api(
                    "POST",
                    f"/api/session/{session_id}/model",
                    {"model": model_ref(selected_model)},
                )
    else:
        session = api(
            "POST",
            "/api/session",
            {
                "location": {"directory": directory},
                "agent": selected_agent,
                "model": model_ref(selected_model),
                "metadata": metadata,
            },
        )
        session_id = session["id"]
    insertion = 1 if forwarded and forwarded[0] in ("run", "mini") else 0
    forwarded[insertion:insertion] = [
        "--session",
        session_id,
        *(["--auto"] if auto and "--auto" not in forwarded else []),
    ]
    os.execv(native, [native, *forwarded])


if __name__ == "__main__":
    try:
        main(sys.argv[1], sys.argv[2], sys.argv[3:])
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"oc: {error}", file=sys.stderr)
        sys.exit(2)
