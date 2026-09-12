#!/usr/bin/env python3

"""Select the newest common OpenCode v2 beta version.

Beta version identifiers have used more than one numbering scheme.  Their
numeric suffixes therefore cannot be used to determine release order.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


BETA_VERSION = re.compile(r"0\.0\.0-beta-\d+$")


def _published_at(version: str, metadata: list[dict[str, Any]]) -> datetime:
    times = []
    for package in metadata:
        value = package.get("time", {}).get(version)
        if not value:
            raise ValueError(f"version {version} has no npm publication time")
        try:
            times.append(datetime.fromisoformat(value.replace("Z", "+00:00")))
        except ValueError as error:
            raise ValueError(
                f"version {version} has invalid npm publication time {value!r}"
            ) from error
    return min(times)


def version_key(version: str, metadata: list[dict[str, Any]]) -> tuple[datetime, int]:
    """Return a release-order key, using the suffix only for ties."""

    suffix = int(version.rsplit("-", 1)[1])
    return (_published_at(version, metadata), suffix)


def newest_common_version(metadata: list[dict[str, Any]]) -> str:
    if not metadata:
        raise ValueError("No npm package metadata supplied")

    version_sets = []
    for package in metadata:
        versions = {
            version
            for version in package.get("versions", {})
            if BETA_VERSION.fullmatch(version)
        }
        version_sets.append(versions)

    common = set.intersection(*version_sets)
    candidates = [
        version
        for version in common
        if all(version in package.get("time", {}) for package in metadata)
    ]
    if not candidates:
        raise ValueError(
            "No common beta version with publication metadata is available for all CLI platforms"
        )

    return max(candidates, key=lambda version: version_key(version, metadata))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata_dir", type=Path)
    parser.add_argument("packages", nargs="+")
    parser.add_argument("--current")
    args = parser.parse_args()

    metadata = []
    for package in args.packages:
        path = args.metadata_dir / f"{package.split('/')[-1]}.json"
        metadata.append(json.loads(path.read_text()))

    selected = newest_common_version(metadata)
    if args.current:
        common = set.intersection(
            *[
                {
                    version
                    for version in package.get("versions", {})
                    if BETA_VERSION.fullmatch(version)
                }
                for package in metadata
            ]
        )
        if args.current not in common or any(
            args.current not in package.get("time", {}) for package in metadata
        ):
            raise ValueError(
                f"current version {args.current} is not present with publication metadata for all CLI platforms"
            )
        if version_key(selected, metadata) < version_key(args.current, metadata):
            raise ValueError(
                f"refusing to select older beta {selected} over current {args.current}"
            )

    print(selected)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"OpenCode beta version discovery failed: {error}", file=sys.stderr)
        raise SystemExit(1)
