#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

update_lock=0
if [[ "${1:-}" == "--update-lock" ]]; then
	update_lock=1
fi

if [[ "$update_lock" -eq 1 ]]; then
	nix flake update opencode
fi

version="$(sed -nE 's/.*opencode\.url = "github:anomalyco\/opencode\/v([^"]+)";.*/\1/p' flake.nix)"
if [[ -z "$version" ]]; then
	echo "Failed to parse opencode version from flake.nix" >&2
	exit 1
fi

release_json="$(mktemp)"
trap 'rm -f "$release_json"' EXIT

curl -fsSL "https://api.github.com/repos/anomalyco/opencode/releases/tags/v${version}" >"$release_json"

digest_for_asset() {
	local asset_name="$1"
	local digest
	digest="$(jq -r --arg name "$asset_name" 'first(.assets[] | select(.name == $name) | .digest) // empty' "$release_json")"
	if [[ -z "$digest" || "$digest" == "null" ]]; then
		echo "Missing digest for release asset: $asset_name" >&2
		exit 1
	fi

	if [[ "$digest" != sha256:* ]]; then
		echo "Unsupported digest format for $asset_name: $digest" >&2
		exit 1
	fi

	local hex_digest="${digest#sha256:}"
	local sri_hash
	sri_hash="$(
		python3 - "$hex_digest" <<'PY'
import base64
import binascii
import sys

hex_digest = sys.argv[1].strip()
print("sha256-" + base64.b64encode(binascii.unhexlify(hex_digest)).decode("ascii"))
PY
	)"

	printf '%s\n' "$sri_hash"
}

cli_darwin_arm64_name="opencode-darwin-arm64.zip"
cli_darwin_x64_name="opencode-darwin-x64.zip"
cli_linux_arm64_name="opencode-linux-arm64.tar.gz"
cli_linux_x64_name="opencode-linux-x64.tar.gz"

desktop_darwin_arm64_name="opencode-desktop-darwin-aarch64.dmg"
desktop_darwin_x64_name="opencode-desktop-darwin-x64.dmg"
desktop_linux_arm64_name="opencode-desktop-linux-arm64.deb"
desktop_linux_x64_name="opencode-desktop-linux-amd64.deb"

cli_darwin_arm64_hash="$(digest_for_asset "$cli_darwin_arm64_name")"
cli_darwin_x64_hash="$(digest_for_asset "$cli_darwin_x64_name")"
cli_linux_arm64_hash="$(digest_for_asset "$cli_linux_arm64_name")"
cli_linux_x64_hash="$(digest_for_asset "$cli_linux_x64_name")"

desktop_darwin_arm64_hash="$(digest_for_asset "$desktop_darwin_arm64_name")"
desktop_darwin_x64_hash="$(digest_for_asset "$desktop_darwin_x64_name")"
desktop_linux_arm64_hash="$(digest_for_asset "$desktop_linux_arm64_name")"
desktop_linux_x64_hash="$(digest_for_asset "$desktop_linux_x64_name")"

jq -S -n \
	--arg version "$version" \
	--arg cliDarwinArm64Name "$cli_darwin_arm64_name" \
	--arg cliDarwinArm64Hash "$cli_darwin_arm64_hash" \
	--arg cliDarwinX64Name "$cli_darwin_x64_name" \
	--arg cliDarwinX64Hash "$cli_darwin_x64_hash" \
	--arg cliLinuxArm64Name "$cli_linux_arm64_name" \
	--arg cliLinuxArm64Hash "$cli_linux_arm64_hash" \
	--arg cliLinuxX64Name "$cli_linux_x64_name" \
	--arg cliLinuxX64Hash "$cli_linux_x64_hash" \
	--arg desktopDarwinArm64Name "$desktop_darwin_arm64_name" \
	--arg desktopDarwinArm64Hash "$desktop_darwin_arm64_hash" \
	--arg desktopDarwinX64Name "$desktop_darwin_x64_name" \
	--arg desktopDarwinX64Hash "$desktop_darwin_x64_hash" \
	--arg desktopLinuxArm64Name "$desktop_linux_arm64_name" \
	--arg desktopLinuxArm64Hash "$desktop_linux_arm64_hash" \
	--arg desktopLinuxX64Name "$desktop_linux_x64_name" \
	--arg desktopLinuxX64Hash "$desktop_linux_x64_hash" \
	'{
    version: $version,
    cli: {
      "aarch64-darwin": {
        name: $cliDarwinArm64Name,
        hash: $cliDarwinArm64Hash,
        archiveType: "zip"
      },
      "x86_64-darwin": {
        name: $cliDarwinX64Name,
        hash: $cliDarwinX64Hash,
        archiveType: "zip"
      },
      "aarch64-linux": {
        name: $cliLinuxArm64Name,
        hash: $cliLinuxArm64Hash,
        archiveType: "tar.gz"
      },
      "x86_64-linux": {
        name: $cliLinuxX64Name,
        hash: $cliLinuxX64Hash,
        archiveType: "tar.gz"
      }
    },
    desktop: {
      "aarch64-darwin": {
        name: $desktopDarwinArm64Name,
        hash: $desktopDarwinArm64Hash,
        archiveType: "darwin-dmg"
      },
      "x86_64-darwin": {
        name: $desktopDarwinX64Name,
        hash: $desktopDarwinX64Hash,
        archiveType: "darwin-dmg"
      },
      "aarch64-linux": {
        name: $desktopLinuxArm64Name,
        hash: $desktopLinuxArm64Hash,
        archiveType: "deb"
      },
      "x86_64-linux": {
        name: $desktopLinuxX64Name,
        hash: $desktopLinuxX64Hash,
        archiveType: "deb"
      }
    }
  }' >packages/opencode-assets.json

echo "Updated packages/opencode-assets.json for OpenCode v${version}"
