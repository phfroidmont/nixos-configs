import base64
import json
import tempfile
import unittest
import stat
from pathlib import Path

import profiles


KEY = base64.b64encode(bytes(range(32))).decode()


class ProfilesTest(unittest.TestCase):
    def metadata(self):
        return {
            "locations": {"ch-zrh": {"country": "Switzerland"}, "se-sto": {"country": "Sweden"}},
            "wireguard": {"ipv4_gateway": "10.64.0.1", "port_ranges": [[4000, 60000]], "relays": [
                {"hostname": "ch-zrh-wg-001", "location": "ch-zrh", "active": True,
                 "public_key": KEY, "ipv4_addr_in": "192.0.2.1"},
                {"hostname": "se-sto-wg-001", "location": "se-sto", "active": True,
                 "public_key": KEY, "ipv4_addr_in": "192.0.2.2"},
                {"hostname": "se-sto-wg-002", "location": "se-sto", "active": False,
                 "public_key": KEY, "ipv4_addr_in": "192.0.2.3"},
            ]},
        }

    def test_generates_active_ipv4_and_preserves_country(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            identity = root / "identity.conf"
            identity.write_text(f"[Interface]\nPrivateKey={KEY}\nAddress=10.1.2.3/32\n")
            metadata = root / "metadata.json"
            metadata.write_text(json.dumps(self.metadata()))
            result = profiles.generate(metadata, identity, root / "profiles", "removed", "se")
            self.assertEqual(result["hostname"], "se-sto-wg-001")
            self.assertEqual(sorted(path.name for path in (root / "profiles").iterdir()),
                             ["ch-zrh-wg-001.conf", "se-sto-wg-001.conf"])
            self.assertIn("Endpoint = 192.0.2.2:51820", (root / "profiles/se-sto-wg-001.conf").read_text())
            self.assertIn("FwMark = 51820", (root / "profiles/se-sto-wg-001.conf").read_text())

    def test_preferred_relay_wins_and_missing_country_falls_back_to_ch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            identity = root / "identity.conf"
            identity.write_text(f"[Interface]\nPrivateKey={KEY}\nAddress=10.1.2.3/32\n")
            metadata = root / "metadata.json"
            metadata.write_text(json.dumps(self.metadata()))
            preferred = profiles.generate(metadata, identity, root / "preferred", "se-sto-wg-001", "ch")
            fallback = profiles.generate(metadata, identity, root / "fallback", "gone", "de")
            self.assertEqual(preferred["hostname"], "se-sto-wg-001")
            self.assertEqual(fallback["hostname"], "ch-zrh-wg-001")

    def test_migration_keeps_only_identity_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "current.conf"
            source.write_text(
                f"[Interface]\nPrivateKey={KEY}\nAddress=10.1.2.3/32,fd00::2/128\nDNS=10.64.0.1\n"
                f"[Peer]\nPublicKey={KEY}\nEndpoint=192.0.2.1:51820\n"
            )
            destination = root / "private/identity.conf"
            profiles.migrate(source, destination)
            contents = destination.read_text()
            self.assertIn("Address = 10.1.2.3/32", contents)
            self.assertNotIn("PublicKey", contents)
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(destination.parent.stat().st_mode), 0o700)

    def test_one_malformed_active_relay_rejects_entire_generation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            identity = root / "identity.conf"
            identity.write_text(f"[Interface]\nPrivateKey={KEY}\nAddress=10.1.2.3/32\n")
            data = self.metadata()
            data["wireguard"]["relays"].append(
                {"hostname": "bad", "location": "missing", "active": True,
                 "public_key": KEY, "ipv4_addr_in": "192.0.2.9"}
            )
            metadata = root / "metadata.json"
            metadata.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "unknown location"):
                profiles.generate(metadata, identity, root / "profiles", "", "")
            self.assertFalse((root / "profiles").exists())

    def test_failure_does_not_create_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            identity = root / "identity.conf"
            identity.write_text(f"[Interface]\nPrivateKey={KEY}\nAddress=10.1.2.3/32\n")
            metadata = root / "metadata.json"
            metadata.write_text('{"locations": {}, "wireguard": {"relays": [], "port_ranges": []}}')
            with self.assertRaises(ValueError):
                profiles.generate(metadata, identity, root / "profiles", "", "")
            self.assertFalse((root / "profiles").exists())


if __name__ == "__main__":
    unittest.main()
