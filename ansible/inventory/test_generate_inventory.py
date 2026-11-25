#!/usr/bin/env python3
"""
test_generate_inventory.py
Unit tests for generate_inventory.py covering:
- Valid outputs handling & correct INI formatting
- Missing required outputs detection (ValueError)
- Empty values detection (ValueError)
- Atomic file generation without partial file leftovers
"""

import os
import tempfile
import unittest
from generate_inventory import generate_hosts_ini, validate_outputs, REQUIRED_OUTPUT_KEYS

class TestGenerateInventory(unittest.TestCase):
    def setUp(self):
        self.valid_outputs = {
            "harbor_public_ip": {"value": "54.1.2.3"},
            "harbor_private_ip": {"value": "10.0.2.10"},
            "harbor_data_volume_id": {"value": "vol-0123456789abcdef0"},
            "k3s_server_public_ip": {"value": "54.1.2.4"},
            "k3s_server_private_ip": {"value": "10.0.1.10"},
            "k3s_worker_public_ip": {"value": "54.1.2.5"},
            "k3s_worker_private_ip": {"value": "10.0.1.20"},
            "rds_endpoint": {"value": "mydb.xyz.us-east-1.rds.amazonaws.com:5432"}
        }

    def test_valid_generation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            out_file = os.path.join(tmpdir, "hosts.ini")
            generate_hosts_ini(self.valid_outputs, out_file)
            self.assertTrue(os.path.exists(out_file))
            with open(out_file, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("harbor_server ansible_host=54.1.2.3", content)
            self.assertIn("harbor_volume_id=vol-0123456789abcdef0", content)
            self.assertIn("k3s_version=v1.35.10+k3s1", content)
            self.assertIn("StrictHostKeyChecking=accept-new", content)

    def test_missing_required_key_raises_error(self):
        for key in REQUIRED_OUTPUT_KEYS:
            invalid_outputs = dict(self.valid_outputs)
            del invalid_outputs[key]
            with tempfile.TemporaryDirectory() as tmpdir:
                out_file = os.path.join(tmpdir, "hosts.ini")
                with self.assertRaises(ValueError):
                    generate_hosts_ini(invalid_outputs, out_file)
                self.assertFalse(os.path.exists(out_file), f"File should not be created if key {key} is missing")

    def test_empty_required_value_raises_error(self):
        invalid_outputs = dict(self.valid_outputs)
        invalid_outputs["harbor_data_volume_id"] = {"value": ""}
        with tempfile.TemporaryDirectory() as tmpdir:
            out_file = os.path.join(tmpdir, "hosts.ini")
            with self.assertRaises(ValueError):
                generate_hosts_ini(invalid_outputs, out_file)
            self.assertFalse(os.path.exists(out_file))

if __name__ == "__main__":
    unittest.main()
