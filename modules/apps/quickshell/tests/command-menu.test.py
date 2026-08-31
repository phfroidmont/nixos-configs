#!/usr/bin/env python3

import argparse
import json
import shlex
from pathlib import Path


ROOT_IDS = ["apps", "controls", "capture", "network", "nixos", "hardware", "tools", "system"]
ROOT_LABELS = ["Apps", "Controls", "Capture", "Network", "NixOS", "Hardware", "Tools", "System"]
CONFIRM_ONLY = {"nixos update"}
DISRUPTIVE = CONFIRM_ONLY | {
    "vpn up",
    "vpn down",
    "tailscale up",
    "tailscale down",
    "system logout",
    "system suspend",
    "system hibernate",
    "system reboot",
    "system shutdown",
}
ALLOWED_ARGUMENTS = {
    "capture record start region": {"--audio"},
    "capture record start screen": {"--audio"},
    **{command: {"--yes"} for command in DISRUPTIVE - CONFIRM_ONLY},
}
REQUIRED_IDS = {
    "controls.audio", "controls.network", "controls.bluetooth", "controls.display",
    "controls.power", "controls.notifications", "controls.reminders", "controls.clipboard",
    "controls.agents", "controls.clock", "controls.keybindings",
    "capture.screenshot.region", "capture.screenshot.window", "capture.screenshot.screen",
    "capture.ocr", "capture.record.region", "capture.record.region-audio",
    "capture.record.screen", "capture.record.screen-audio", "capture.record.status",
    "capture.record.stop", "network.panel", "network.vpn.status", "network.vpn.up",
    "network.vpn.down", "network.tailscale.status", "network.tailscale.up",
    "network.tailscale.down", "nixos.build", "nixos.test", "nixos.switch",
    "nixos.update", "nixos.generations", "nixos.rollback", "hardware.summary",
    "hardware.cpu", "hardware.memory", "hardware.gpu", "hardware.storage",
    "hardware.sensors", "hardware.battery", "hardware.network", "hardware.pci",
    "hardware.usb", "hardware.firmware", "tools.launch.browser",
    "tools.launch.terminal", "tools.launch.editor", "tools.launch.files",
    "tools.fos.status", "tools.fos.doctor", "tools.fos.stats", "tools.fos.monitor",
    "system.lock", "system.logout", "system.suspend", "system.hibernate",
    "system.reboot", "system.shutdown",
}


def fail(message):
    raise SystemExit(f"command menu: {message}")


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot load {path}: {error}")


def registry_paths(registry):
    if isinstance(registry, dict):
        registry = registry.get("commands", [])
    if not isinstance(registry, list):
        fail("registry must be an array or contain a commands array")
    paths = []
    for entry in registry:
        command = entry.get("command") if isinstance(entry, dict) else entry
        if isinstance(command, str) and command.strip():
            paths.append(tuple(command.split()))
    if not paths:
        fail("registry contains no command paths")
    return paths


def action_words(action):
    try:
        words = shlex.split(action)
    except ValueError as error:
        fail(f"invalid action {action!r}: {error}")
    if not words or words[0] not in {"fos", "fos-internal-menu-terminal"}:
        fail(f"action has a forbidden prefix: {action!r}")
    words = words[1:]
    if not words:
        fail(f"action has no FOS command: {action!r}")
    return words


def registered_path(words, paths):
    matches = [path for path in paths if tuple(words[:len(path)]) == path]
    return max(matches, key=len) if matches else None


def validate(catalog, paths):
    if not isinstance(catalog, dict):
        fail("catalog root must be an object")
    roots = [item_id for item_id in catalog if "." not in item_id]
    if roots != ROOT_IDS:
        fail(f"root order must be {ROOT_IDS}, got {roots}")
    labels = [catalog[item_id].get("label") for item_id in roots]
    if labels != ROOT_LABELS:
        fail(f"root labels must be {ROOT_LABELS}, got {labels}")
    if catalog["apps"].get("provider") != "apps":
        fail("Apps must use the apps provider")
    if "docker" in json.dumps(catalog).lower():
        fail("Docker entries are forbidden")

    missing = REQUIRED_IDS - catalog.keys()
    if missing:
        fail(f"missing curated IDs: {', '.join(sorted(missing))}")
    if catalog["controls.reminders"].get("action") != "fos menu reminders":
        fail("Controls > Reminders must use the public reminders menu route")

    for item_id, item in catalog.items():
        if not isinstance(item, dict):
            fail(f"{item_id} must be an object")
        if not item.get("icon") or not item.get("label") or not item.get("description"):
            fail(f"{item_id} needs an icon, label, and description")
        if "." in item_id and item_id.rsplit(".", 1)[0] not in catalog:
            fail(f"{item_id} has no declared parent")

        action = item.get("action")
        if not action:
            continue
        lowered = action.lower()
        if "docker" in lowered or "omarchy-" in lowered:
            fail(f"{item_id} invokes a forbidden executable")
        words = action_words(action)
        forbidden_mutations = {"theme", "package", "packages", "font", "fonts", "default", "defaults"}
        if forbidden_mutations.intersection(words):
            fail(f"{item_id} attempts a Nix-managed mutation")

        path = registered_path(words, paths)
        if path is None:
            fail(f"{item_id} does not map to a registered command: {action!r}")
        command = " ".join(path)
        arguments = words[len(path):]
        allowed_arguments = ALLOWED_ARGUMENTS.get(command, set())
        if any(argument not in allowed_arguments for argument in arguments):
            fail(f"{item_id} passes unsupported arguments: {action!r}")
        disruptive = command in DISRUPTIVE
        confirm = item.get("confirm")
        confirm_label = item.get("confirmLabel")
        confirmed = (
            isinstance(confirm, str) and bool(confirm.strip())
            and isinstance(confirm_label, str) and bool(confirm_label.strip())
        )
        has_yes = "--yes" in arguments
        if disruptive and (not confirmed or (command not in CONFIRM_ONLY and not has_yes)):
            fail(f"{item_id} must confirm before running")
        if not disruptive and ("confirm" in item or "confirmLabel" in item or has_yes):
            fail(f"{item_id} has confirmation fields reserved for disruptive actions")


def main():
    parser = argparse.ArgumentParser(description="Validate the declarative FOS command menu")
    parser.add_argument("catalog", type=Path)
    parser.add_argument("registry", type=Path)
    parser.add_argument("shell", type=Path)
    args = parser.parse_args()
    validate(load_json(args.catalog), registry_paths(load_json(args.registry)))
    model = (args.shell / "plugins/menu/MenuModel.js").read_text(encoding="utf-8")
    menu = (args.shell / "plugins/menu/Menu.qml").read_text(encoding="utf-8")
    for field in ("confirm: value.confirm ||", "confirmLabel: value.confirmLabel ||"):
        if field not in model:
            fail(f"menu model does not preserve {field.split(':', 1)[0]}")
    for behavior in ("actionConfirmOpen", "requestAction", "actionConfirm.selectedIndex = 0"):
        if behavior not in menu:
            fail(f"menu confirmation flow is missing {behavior}")
    print("command menu catalog tests passed")


if __name__ == "__main__":
    main()
