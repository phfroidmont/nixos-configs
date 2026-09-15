#!/usr/bin/env python3
"""Migrate a Mullvad identity and generate validated IPv4 relay profiles."""

import argparse
import base64
import configparser
import ipaddress
import json
import os
import re
import sys
from pathlib import Path

HOSTNAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")


def read_config(path: Path) -> configparser.ConfigParser:
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str.lower
    try:
        with path.open(encoding="utf-8") as source:
            config.read_file(source)
    except (configparser.Error, UnicodeError):
        # Parser errors may include source lines containing the private key.
        raise ValueError("invalid WireGuard configuration syntax") from None
    return config


def private_key(value: str) -> str:
    try:
        decoded = base64.b64decode(value, validate=True)
    except ValueError as error:
        raise ValueError("invalid WireGuard private key") from error
    if len(decoded) != 32:
        raise ValueError("invalid WireGuard private key length")
    return value


def ipv4_address(value: str) -> str:
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        try:
            interface = ipaddress.ip_interface(item)
        except ValueError:
            continue
        if interface.version == 4:
            return str(interface)
    raise ValueError("config has no IPv4 interface address")


def migrate(source: Path, destination: Path) -> None:
    config = read_config(source)
    key = private_key(config["Interface"]["privatekey"].strip())
    address = ipv4_address(config["Interface"]["address"])
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".tmp")
    temporary.write_text(f"[Interface]\nPrivateKey = {key}\nAddress = {address}\n", encoding="utf-8")
    os.chmod(temporary, 0o600)
    temporary.replace(destination)


def validate_key(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("relay public key is not a string")
    try:
        decoded = base64.b64decode(value, validate=True)
    except ValueError as error:
        raise ValueError("invalid relay public key") from error
    if len(decoded) != 32:
        raise ValueError("invalid relay public key length")
    return value


def choose_port(ranges: object) -> int:
    if not isinstance(ranges, list) or not ranges:
        raise ValueError("wireguard.port_ranges is empty")
    parsed = []
    for item in ranges:
        if not isinstance(item, list) or len(item) != 2:
            raise ValueError("invalid WireGuard port range")
        low, high = item
        if not isinstance(low, int) or not isinstance(high, int) or not (1 <= low <= high <= 65535):
            raise ValueError("invalid WireGuard port range")
        parsed.append((low, high))
    if any(low <= 51820 <= high for low, high in parsed):
        return 51820
    return parsed[0][0]


def generate(metadata_path: Path, identity_path: Path, output: Path, preferred: str, country: str) -> dict:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    locations = metadata.get("locations")
    wireguard = metadata.get("wireguard")
    if not isinstance(locations, dict) or not isinstance(wireguard, dict):
        raise ValueError("metadata lacks locations or wireguard")
    relays = wireguard.get("relays")
    if not isinstance(relays, list):
        raise ValueError("metadata lacks wireguard.relays")
    port = choose_port(wireguard.get("port_ranges"))
    gateway = str(ipaddress.IPv4Address(wireguard.get("ipv4_gateway")))

    identity = read_config(identity_path)
    key = private_key(identity["Interface"]["privatekey"].strip())
    address = ipv4_address(identity["Interface"]["address"])
    valid = []
    for relay in relays:
        if not isinstance(relay, dict) or relay.get("active") is not True:
            continue
        hostname = relay.get("hostname")
        location = relay.get("location")
        if not isinstance(hostname, str) or not HOSTNAME.fullmatch(hostname):
            raise ValueError("invalid active relay hostname")
        if not isinstance(location, str) or location not in locations:
            raise ValueError(f"relay {hostname} has unknown location")
        location_data = locations[location]
        if not isinstance(location_data, dict) or not isinstance(location_data.get("country"), str):
            raise ValueError(f"relay {hostname} has invalid location")
        country_code = location.split("-", 1)[0].lower()
        if not re.fullmatch(r"[a-z]{2}", country_code):
            raise ValueError(f"relay {hostname} has invalid country code")
        endpoint = str(ipaddress.IPv4Address(relay.get("ipv4_addr_in")))
        public_key = validate_key(relay.get("public_key"))
        valid.append((hostname, country_code, endpoint, public_key))
    if not valid:
        raise ValueError("metadata contains no active IPv4 WireGuard relays")
    if len({item[0] for item in valid}) != len(valid):
        raise ValueError("duplicate active relay hostname")

    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    os.chmod(output, 0o700)
    for hostname, _, endpoint, public_key in sorted(valid):
        profile = output / f"{hostname}.conf"
        profile.write_text(
            "[Interface]\n"
            f"PrivateKey = {key}\nAddress = {address}\nDNS = {gateway}\nFwMark = 51820\n\n"
            "[Peer]\n"
            f"PublicKey = {public_key}\nAllowedIPs = 0.0.0.0/0\nEndpoint = {endpoint}:{port}\n",
            encoding="utf-8",
        )
        os.chmod(profile, 0o600)

    by_name = {item[0]: item for item in valid}
    selected = by_name.get(preferred)
    if selected is None and country:
        selected = next((item for item in sorted(valid) if item[1] == country), None)
    if selected is None:
        selected = next((item for item in sorted(valid) if item[1] == "ch"), None)
    if selected is None:
        raise ValueError("selected relay is gone and no relay exists in its country or Switzerland")
    return {"hostname": selected[0], "country": selected[1], "count": len(valid)}


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    migrate_parser = subparsers.add_parser("migrate")
    migrate_parser.add_argument("source", type=Path)
    migrate_parser.add_argument("destination", type=Path)
    generate_parser = subparsers.add_parser("generate")
    generate_parser.add_argument("metadata", type=Path)
    generate_parser.add_argument("identity", type=Path)
    generate_parser.add_argument("output", type=Path)
    generate_parser.add_argument("--preferred", default="")
    generate_parser.add_argument("--country", default="")
    arguments = parser.parse_args()
    if arguments.command == "migrate":
        migrate(arguments.source, arguments.destination)
    else:
        print(json.dumps(generate(arguments.metadata, arguments.identity, arguments.output,
                                  arguments.preferred, arguments.country)))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, configparser.Error, json.JSONDecodeError) as error:
        print(f"mullvad profile error: {error}", file=sys.stderr)
        raise SystemExit(1)
