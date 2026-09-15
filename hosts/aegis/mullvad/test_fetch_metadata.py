import struct
import unittest
from unittest import mock

import fetch_metadata


class FetchTest(unittest.TestCase):
    @staticmethod
    def dns_reply(identifier, address=b"\xc0\x00\x02\x01"):
        question = fetch_metadata.dns_question(identifier)[12:]
        answer = b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 60, 4) + address
        return struct.pack("!HHHHHH", identifier, 0x8180, 1, 1, 0, 0) + question + answer

    def test_dns_parser_reads_a_record(self):
        identifier = 123
        packet = self.dns_reply(identifier)
        self.assertEqual(fetch_metadata.parse_dns(packet, identifier), (["192.0.2.1"], False))

    def test_dns_parser_rejects_wrong_echoed_question(self):
        packet = bytearray(self.dns_reply(123))
        packet[13] = ord("x")
        with self.assertRaisesRegex(ValueError, "echo"):
            fetch_metadata.parse_dns(bytes(packet), 123)

    def test_dns_retries_after_lost_packet(self):
        first = mock.MagicMock()
        first.__enter__.return_value.recv.side_effect = socket_timeout = TimeoutError("lost")
        second = mock.MagicMock()
        second.__enter__.return_value.recv.return_value = self.dns_reply(2)
        with mock.patch.object(fetch_metadata, "marked_socket", side_effect=[first, second]), \
             mock.patch.object(fetch_metadata.os, "urandom", side_effect=[b"\0\1", b"\0\2"]):
            self.assertEqual(fetch_metadata.resolve(), ["192.0.2.1"])
        self.assertIsInstance(socket_timeout, TimeoutError)

    def test_dns_exhausts_retries(self):
        sockets = [mock.MagicMock() for _ in range(fetch_metadata.DNS_ATTEMPTS)]
        for fake in sockets:
            fake.__enter__.return_value.recv.side_effect = TimeoutError("lost")
        with mock.patch.object(fetch_metadata, "marked_socket", side_effect=sockets):
            with self.assertRaisesRegex(RuntimeError, "after 3 attempts"):
                fetch_metadata.resolve()

    def test_socket_is_marked_before_use(self):
        fake = mock.Mock()
        with mock.patch.object(fetch_metadata.socket, "socket", return_value=fake):
            self.assertIs(fetch_metadata.marked_socket(fetch_metadata.socket.SOCK_STREAM), fake)
        fake.setsockopt.assert_called_once_with(fetch_metadata.socket.SOL_SOCKET,
                                                getattr(fetch_metadata.socket, "SO_MARK", 36),
                                                fetch_metadata.MARK)
        fake.settimeout.assert_called_once_with(fetch_metadata.TIMEOUT)

    def test_fetch_uses_explicit_ca_sni_and_closes_response(self):
        raw = mock.Mock()
        tls = mock.Mock()
        context = mock.Mock()
        context.wrap_socket.return_value = tls
        response = mock.Mock(status=200)
        response.read.return_value = b"{}"
        with mock.patch.object(fetch_metadata, "marked_socket", return_value=raw), \
             mock.patch.object(fetch_metadata.ssl, "create_default_context", return_value=context) as create_context, \
             mock.patch.object(fetch_metadata.http.client, "HTTPResponse", return_value=response):
            self.assertEqual(fetch_metadata.fetch(["192.0.2.1"], "/ca.pem"), b"{}")
        create_context.assert_called_once_with(cafile="/ca.pem")
        context.wrap_socket.assert_called_once_with(raw, server_hostname=fetch_metadata.HOST)
        raw.connect.assert_called_once_with(("192.0.2.1", 443))
        request = tls.sendall.call_args.args[0]
        self.assertIn(b"GET /app/v1/relays HTTP/1.1", request)
        response.close.assert_called_once()
        tls.close.assert_called_once()

    def test_fetch_rejects_redirect_without_following_it(self):
        raw = mock.Mock()
        tls = mock.Mock()
        context = mock.Mock()
        context.wrap_socket.return_value = tls
        response = mock.Mock(status=302)
        with mock.patch.object(fetch_metadata, "marked_socket", return_value=raw), \
             mock.patch.object(fetch_metadata.ssl, "create_default_context", return_value=context), \
             mock.patch.object(fetch_metadata.http.client, "HTTPResponse", return_value=response):
            with self.assertRaisesRegex(RuntimeError, "status 302"):
                fetch_metadata.fetch(["192.0.2.1"], "/ca.pem")
        response.close.assert_called_once()
        tls.close.assert_called_once()

    def test_fetch_rejects_oversize_body(self):
        raw = mock.Mock()
        tls = mock.Mock()
        context = mock.Mock()
        context.wrap_socket.return_value = tls
        response = mock.Mock(status=200)
        response.read.return_value = b"12345"
        with mock.patch.object(fetch_metadata, "MAX_BODY", 4), \
             mock.patch.object(fetch_metadata, "marked_socket", return_value=raw), \
             mock.patch.object(fetch_metadata.ssl, "create_default_context", return_value=context), \
             mock.patch.object(fetch_metadata.http.client, "HTTPResponse", return_value=response):
            with self.assertRaisesRegex(RuntimeError, "too large"):
                fetch_metadata.fetch(["192.0.2.1"], "/ca.pem")
        tls.close.assert_called_once()

    def test_fetch_closes_raw_socket_when_tls_setup_fails(self):
        raw = mock.Mock()
        context = mock.Mock()
        context.wrap_socket.side_effect = OSError("TLS failed")
        with mock.patch.object(fetch_metadata, "marked_socket", return_value=raw), \
             mock.patch.object(fetch_metadata.ssl, "create_default_context", return_value=context):
            with self.assertRaisesRegex(RuntimeError, "TLS failed"):
                fetch_metadata.fetch(["192.0.2.1"], "/ca.pem")
        raw.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
