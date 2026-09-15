import unittest

import health


class HealthTest(unittest.TestCase):
    def test_recent_handshake_with_traffic_is_healthy(self):
        self.assertTrue(health.is_healthy(900, 1, 1, 1000))

    def test_stale_or_future_handshake_is_unhealthy(self):
        self.assertFalse(health.is_healthy(819, 1, 1, 1000))
        self.assertFalse(health.is_healthy(1001, 1, 1, 1000))

    def test_both_transfer_counters_are_required(self):
        self.assertFalse(health.is_healthy(1000, 0, 1, 1000))
        self.assertFalse(health.is_healthy(1000, 1, 0, 1000))


if __name__ == "__main__":
    unittest.main()
