#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path


module_path = Path(__file__).with_name("opencode_v2_version.py")
spec = importlib.util.spec_from_file_location("opencode_v2_version", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


PACKAGES = ["darwin-arm64", "darwin-x64", "linux-arm64", "linux-x64"]


def metadata(versions):
    return [
        {
            "versions": {version: {} for version in versions},
            "time": {version: timestamp for version, timestamp in versions.items()},
        }
        for _ in PACKAGES
    ]


class VersionSelectionTests(unittest.TestCase):
    def test_timestamp_identifier_does_not_beat_newer_sequential_identifier(self):
        versions = {
            "0.0.0-beta-202608110357": "2026-08-11T03:57:00Z",
            "0.0.0-beta-19425": "2026-09-10T01:58:57Z",
        }
        self.assertEqual(
            module.newest_common_version(metadata(versions)), "0.0.0-beta-19425"
        )

    def test_version_missing_from_platform_is_excluded(self):
        packages = metadata(
            {
                "0.0.0-beta-19425": "2026-09-10T01:58:57Z",
                "0.0.0-beta-19422": "2026-09-10T00:57:00Z",
            }
        )
        packages[-1]["versions"].pop("0.0.0-beta-19425")
        packages[-1]["time"].pop("0.0.0-beta-19425")
        self.assertEqual(module.newest_common_version(packages), "0.0.0-beta-19422")

    def test_missing_publication_time_is_excluded(self):
        packages = metadata(
            {
                "0.0.0-beta-19425": "2026-09-10T01:58:57Z",
                "0.0.0-beta-19422": "2026-09-10T00:57:00Z",
            }
        )
        for package in packages:
            package["time"].pop("0.0.0-beta-19425")
        self.assertEqual(module.newest_common_version(packages), "0.0.0-beta-19422")

    def test_numeric_suffix_breaks_equal_timestamp_tie(self):
        versions = {
            "0.0.0-beta-19425": "2026-09-10T01:58:57Z",
            "0.0.0-beta-19422": "2026-09-10T01:58:57Z",
        }
        self.assertEqual(
            module.newest_common_version(metadata(versions)), "0.0.0-beta-19425"
        )

    def test_no_common_version_fails(self):
        packages = metadata({"0.0.0-beta-19425": "2026-09-10T01:58:57Z"})
        packages[-1]["versions"] = {"0.0.0-beta-19422": {}}
        packages[-1]["time"] = {"0.0.0-beta-19422": "2026-09-10T00:57:00Z"}
        with self.assertRaises(ValueError):
            module.newest_common_version(packages)


if __name__ == "__main__":
    unittest.main()
