#!/usr/bin/env python3
"""Fetch the one Mullvad relay document over sockets exempted from the tunnel."""

import http.client
import os
import socket
import ssl
import struct
import sys

HOST = "api.mullvad.net"
PATH = "/app/v1/relays"
RESOLVER = "1.1.1.1"
MARK = 51820
TIMEOUT = 8
MAX_BODY = 8 * 1024 * 1024
DNS_ATTEMPTS = 3


def marked_socket(kind: int) -> socket.socket:
    sock = socket.socket(socket.AF_INET, kind)
    sock.settimeout(TIMEOUT)
    sock.setsockopt(socket.SOL_SOCKET, getattr(socket, "SO_MARK", 36), MARK)
    return sock


def dns_question(identifier: int) -> bytes:
    labels = b"".join(bytes((len(label),)) + label.encode("ascii") for label in HOST.split("."))
    return struct.pack("!HHHHHH", identifier, 0x0100, 1, 0, 0, 0) + labels + b"\0" + struct.pack("!HH", 1, 1)


def skip_name(packet: bytes, offset: int) -> int:
    while True:
        if offset >= len(packet):
            raise ValueError("truncated DNS name")
        length = packet[offset]
        if length & 0xC0 == 0xC0:
            if offset + 2 > len(packet):
                raise ValueError("truncated DNS pointer")
            return offset + 2
        offset += 1
        if length == 0:
            return offset
        if length & 0xC0 or offset + length > len(packet):
            raise ValueError("invalid DNS name")
        offset += length


def parse_dns(packet: bytes, identifier: int) -> tuple[list[str], bool]:
    if len(packet) < 12:
        raise ValueError("short DNS reply")
    reply_id, flags, questions, answers, _, _ = struct.unpack("!HHHHHH", packet[:12])
    if reply_id != identifier or not flags & 0x8000 or flags & 0xF or questions != 1:
        raise ValueError("invalid DNS reply")
    offset = 12
    offset = skip_name(packet, offset) + 4
    if offset > len(packet) or packet[12:offset] != dns_question(identifier)[12:]:
        raise ValueError("DNS reply did not echo the question")
    addresses = []
    for _ in range(answers):
        offset = skip_name(packet, offset)
        if offset + 10 > len(packet):
            raise ValueError("truncated DNS record")
        record_type, record_class, _, length = struct.unpack("!HHIH", packet[offset : offset + 10])
        offset += 10
        if offset + length > len(packet):
            raise ValueError("truncated DNS value")
        if record_type == 1 and record_class == 1 and length == 4:
            addresses.append(socket.inet_ntoa(packet[offset : offset + 4]))
        offset += length
    return addresses, bool(flags & 0x0200)


def query_tcp(question: bytes, identifier: int) -> list[str]:
    with marked_socket(socket.SOCK_STREAM) as sock:
        sock.connect((RESOLVER, 53))
        sock.sendall(struct.pack("!H", len(question)) + question)
        length_prefix = bytearray()
        while len(length_prefix) < 2:
            chunk = sock.recv(2 - len(length_prefix))
            if not chunk:
                raise RuntimeError("short DNS TCP length")
            length_prefix.extend(chunk)
        length = struct.unpack("!H", length_prefix)[0]
        chunks = bytearray()
        while len(chunks) < length:
            chunk = sock.recv(length - len(chunks))
            if not chunk:
                raise RuntimeError("short DNS TCP reply")
            chunks.extend(chunk)
    addresses, _ = parse_dns(bytes(chunks), identifier)
    return addresses


def resolve() -> list[str]:
    last_error = None
    for _ in range(DNS_ATTEMPTS):
        identifier = int.from_bytes(os.urandom(2), "big")
        question = dns_question(identifier)
        try:
            with marked_socket(socket.SOCK_DGRAM) as sock:
                sock.connect((RESOLVER, 53))
                sock.sendall(question)
                reply = sock.recv(65535)
            addresses, truncated = parse_dns(reply, identifier)
            if truncated:
                addresses = query_tcp(question, identifier)
            if addresses:
                return addresses
            last_error = RuntimeError(f"no IPv4 address returned for {HOST}")
        except (OSError, RuntimeError, ValueError, struct.error) as error:
            last_error = error
    raise RuntimeError(f"DNS lookup failed after {DNS_ATTEMPTS} attempts: {last_error}")


def fetch(addresses: list[str], ca_file: str) -> bytes:
    last_error = None
    for address in addresses:
        raw = None
        tls = None
        response = None
        try:
            raw = marked_socket(socket.SOCK_STREAM)
            raw.connect((address, 443))
            tls = ssl.create_default_context(cafile=ca_file).wrap_socket(raw, server_hostname=HOST)
            raw = None  # The TLS socket now owns the underlying descriptor.
            tls.sendall(
                f"GET {PATH} HTTP/1.1\r\nHost: {HOST}\r\nUser-Agent: aegis-mullvad-refresh/1\r\n"
                "Accept: application/json\r\nConnection: close\r\n\r\n".encode("ascii")
            )
            response = http.client.HTTPResponse(tls)
            response.begin()
            if response.status != 200:
                raise RuntimeError(f"unexpected HTTP status {response.status}")
            body = response.read(MAX_BODY + 1)
            if len(body) > MAX_BODY:
                raise RuntimeError("relay document is too large")
            return body
        except (OSError, ssl.SSLError, http.client.HTTPException, RuntimeError) as error:
            last_error = error
        finally:
            if response is not None:
                response.close()
            if tls is not None:
                tls.close()
            if raw is not None:
                raw.close()
    raise RuntimeError(f"metadata fetch failed: {last_error}")


def main() -> None:
    ca_file = os.environ.get("MULLVAD_CA_FILE")
    if not ca_file:
        raise RuntimeError("MULLVAD_CA_FILE is required")
    sys.stdout.buffer.write(fetch(resolve(), ca_file))


if __name__ == "__main__":
    main()
