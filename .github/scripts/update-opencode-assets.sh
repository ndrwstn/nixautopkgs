#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

repo="anomalyco/opencode"
assets_file="packages/opencode/assets.json"
update_lock=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--update-lock)
		update_lock=1
		shift
		;;
	--repo)
		repo="${2:?--repo requires a value}"
		shift 2
		;;
	--assets-file)
		assets_file="${2:?--assets-file requires a value}"
		shift 2
		;;
	*)
		echo "Unknown argument: $1" >&2
		echo "Usage: $0 [--update-lock] [--repo owner/name] [--assets-file path]" >&2
		exit 1
		;;
	esac
done

default_assets_file="packages/opencode/assets.json"
v2_assets_file="packages/opencode-v2/assets.json"
v2_mode=0

if [[ "$assets_file" == "$default_assets_file" ]]; then
	# v1 flow: the version comes from the flake input URL in flake.nix
	if [[ "$update_lock" -eq 1 ]]; then
		nix flake update opencode
	fi

	version="$(sed -nE 's/.*opencode\.url = "github:anomalyco\/opencode\/v([^"]+)";.*/\1/p' flake.nix)"
	if [[ -z "$version" ]]; then
		echo "Failed to parse opencode version from flake.nix" >&2
		exit 1
	fi
else
	# Alternate flow (opencode-v2 beta tracking): the version lives in the
	# assets file itself; Renovate bumps it and this script syncs npm CLI
	# integrity metadata plus GitHub desktop hashes.
	if [[ "$update_lock" -eq 1 ]]; then
		echo "--update-lock is only supported for $default_assets_file" >&2
		exit 1
	fi

	version="$(jq -r '.version // empty' "$assets_file")"
	if [[ -z "$version" ]]; then
		echo "Failed to parse version from $assets_file" >&2
		exit 1
	fi
	if [[ "$assets_file" == "$v2_assets_file" ]]; then
		v2_mode=1
	fi
fi

release_json="$(mktemp)"
npm_metadata_dir="$(mktemp -d)"
trap 'rm -f "$release_json"; rm -rf "$npm_metadata_dir"' EXIT

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
	curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/${repo}/releases/tags/v${version}" >"$release_json"
else
	curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/v${version}" >"$release_json"
fi

digest_for_asset() {
	local asset_name="$1"
	local optional="${2:-0}"
	local digest
	digest="$(jq -r --arg name "$asset_name" 'first(.assets[] | select(.name == $name) | .digest) // empty' "$release_json")"
	if [[ -z "$digest" || "$digest" == "null" ]]; then
		if [[ "$optional" -eq 1 ]]; then
			return 0
		fi
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

desktop_darwin_arm64_name="opencode-desktop-mac-arm64.dmg"
desktop_darwin_x64_name="opencode-desktop-mac-x64.dmg"
desktop_linux_arm64_name="opencode-desktop-linux-arm64.deb"
desktop_linux_x64_name="opencode-desktop-linux-amd64.deb"

cli_darwin_arm64_package=""
cli_darwin_x64_package=""
cli_linux_arm64_package=""
cli_linux_x64_package=""
cli_darwin_arm64_url=""
cli_darwin_x64_url=""
cli_linux_arm64_url=""
cli_linux_x64_url=""
cli_darwin_arm64_archive_type="zip"
cli_darwin_x64_archive_type="zip"
cli_linux_arm64_archive_type="tar.gz"
cli_linux_x64_archive_type="tar.gz"

if [[ "$v2_mode" -eq 1 ]]; then
	npm_asset_metadata() {
		local package="$1"
		local metadata_file="$npm_metadata_dir/${package##*/}.json"
		local url integrity

		if ! curl -fsSL "https://registry.npmjs.org/${package}/${version}" >"$metadata_file"; then
			echo "Failed to fetch npm metadata for ${package}@${version}" >&2
			exit 1
		fi

		url="$(jq -r '.dist.tarball // empty' "$metadata_file")"
		integrity="$(jq -r '.dist.integrity // empty' "$metadata_file")"
		if [[ -z "$url" || -z "$integrity" || "$integrity" != sha512-* ]]; then
			echo "Missing npm tarball URL or sha512 integrity for ${package}@${version}" >&2
			exit 1
		fi

		printf '%s\t%s\n' "$url" "$integrity"
	}

	cli_darwin_arm64_package="@opencode-ai/cli-darwin-arm64"
	cli_darwin_x64_package="@opencode-ai/cli-darwin-x64"
	cli_linux_arm64_package="@opencode-ai/cli-linux-arm64"
	cli_linux_x64_package="@opencode-ai/cli-linux-x64"

	IFS=$'\t' read -r cli_darwin_arm64_url cli_darwin_arm64_hash < <(npm_asset_metadata "$cli_darwin_arm64_package")
	IFS=$'\t' read -r cli_darwin_x64_url cli_darwin_x64_hash < <(npm_asset_metadata "$cli_darwin_x64_package")
	IFS=$'\t' read -r cli_linux_arm64_url cli_linux_arm64_hash < <(npm_asset_metadata "$cli_linux_arm64_package")
	IFS=$'\t' read -r cli_linux_x64_url cli_linux_x64_hash < <(npm_asset_metadata "$cli_linux_x64_package")

	cli_darwin_arm64_name="${cli_darwin_arm64_url##*/}"
	cli_darwin_x64_name="${cli_darwin_x64_url##*/}"
	cli_linux_arm64_name="${cli_linux_arm64_url##*/}"
	cli_linux_x64_name="${cli_linux_x64_url##*/}"
else
	cli_darwin_arm64_hash="$(digest_for_asset "$cli_darwin_arm64_name")"
	cli_darwin_x64_hash="$(digest_for_asset "$cli_darwin_x64_name")"
	cli_linux_arm64_hash="$(digest_for_asset "$cli_linux_arm64_name")"
	cli_linux_x64_hash="$(digest_for_asset "$cli_linux_x64_name")"
fi

desktop_darwin_arm64_hash="$(digest_for_asset "$desktop_darwin_arm64_name")"
desktop_darwin_x64_hash="$(digest_for_asset "$desktop_darwin_x64_name")"
desktop_linux_arm64_hash="$(digest_for_asset "$desktop_linux_arm64_name" 1)"
desktop_linux_x64_hash="$(digest_for_asset "$desktop_linux_x64_name")"

if [[ -z "$desktop_linux_arm64_hash" ]]; then
	echo "Note: optional desktop asset '$desktop_linux_arm64_name' is missing from release v${version}. Omitting aarch64-linux desktop entry." >&2
fi

jq_args=(
	-S -n
	--arg version "$version"
	--arg cliDarwinArm64Name "$cli_darwin_arm64_name"
	--arg cliDarwinArm64Hash "$cli_darwin_arm64_hash"
	--arg cliDarwinX64Name "$cli_darwin_x64_name"
	--arg cliDarwinX64Hash "$cli_darwin_x64_hash"
	--arg cliLinuxArm64Name "$cli_linux_arm64_name"
	--arg cliLinuxArm64Hash "$cli_linux_arm64_hash"
	--arg cliLinuxX64Name "$cli_linux_x64_name"
	--arg cliLinuxX64Hash "$cli_linux_x64_hash"
	--arg cliDarwinArm64Package "$cli_darwin_arm64_package"
	--arg cliDarwinX64Package "$cli_darwin_x64_package"
	--arg cliLinuxArm64Package "$cli_linux_arm64_package"
	--arg cliLinuxX64Package "$cli_linux_x64_package"
	--arg cliDarwinArm64Url "$cli_darwin_arm64_url"
	--arg cliDarwinX64Url "$cli_darwin_x64_url"
	--arg cliLinuxArm64Url "$cli_linux_arm64_url"
	--arg cliLinuxX64Url "$cli_linux_x64_url"
	--argjson v2Mode "$v2_mode"
	--arg desktopDarwinArm64Name "$desktop_darwin_arm64_name"
	--arg desktopDarwinArm64Hash "$desktop_darwin_arm64_hash"
	--arg desktopDarwinX64Name "$desktop_darwin_x64_name"
	--arg desktopDarwinX64Hash "$desktop_darwin_x64_hash"
	--arg desktopLinuxX64Name "$desktop_linux_x64_name"
	--arg desktopLinuxX64Hash "$desktop_linux_x64_hash"
)

desktop_filter='{
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
  "x86_64-linux": {
    name: $desktopLinuxX64Name,
    hash: $desktopLinuxX64Hash,
    archiveType: "deb"
  }
}'

if [[ -n "$desktop_linux_arm64_hash" ]]; then
	jq_args+=(
		--arg desktopLinuxArm64Name "$desktop_linux_arm64_name"
		--arg desktopLinuxArm64Hash "$desktop_linux_arm64_hash"
	)
	desktop_filter='{
  "aarch64-darwin": {
    name: $desktopDarwinArm64Name,
    hash: $desktopDarwinArm64Hash,
    archiveType: "darwin-dmg"
  },
  "aarch64-linux": {
    name: $desktopLinuxArm64Name,
    hash: $desktopLinuxArm64Hash,
    archiveType: "deb"
  },
  "x86_64-darwin": {
    name: $desktopDarwinX64Name,
    hash: $desktopDarwinX64Hash,
    archiveType: "darwin-dmg"
  },
  "x86_64-linux": {
    name: $desktopLinuxX64Name,
    hash: $desktopLinuxX64Hash,
    archiveType: "deb"
  }
}'
fi

mkdir -p "$(dirname "$assets_file")"

jq "${jq_args[@]}" \
	"{
    version: \$version,
    cli: {
      \"aarch64-darwin\": ({
        name: \$cliDarwinArm64Name,
        hash: \$cliDarwinArm64Hash,
        archiveType: (if \$v2Mode == 1 then \"tar.gz\" else \"zip\" end)
      } + (if \$v2Mode == 1 then { package: \$cliDarwinArm64Package, url: \$cliDarwinArm64Url } else {} end)),
      \"x86_64-darwin\": ({
        name: \$cliDarwinX64Name,
        hash: \$cliDarwinX64Hash,
        archiveType: (if \$v2Mode == 1 then \"tar.gz\" else \"zip\" end)
      } + (if \$v2Mode == 1 then { package: \$cliDarwinX64Package, url: \$cliDarwinX64Url } else {} end)),
      \"aarch64-linux\": ({
        name: \$cliLinuxArm64Name,
        hash: \$cliLinuxArm64Hash,
        archiveType: \"tar.gz\"
      } + (if \$v2Mode == 1 then { package: \$cliLinuxArm64Package, url: \$cliLinuxArm64Url } else {} end)),
      \"x86_64-linux\": ({
        name: \$cliLinuxX64Name,
        hash: \$cliLinuxX64Hash,
        archiveType: \"tar.gz\"
      } + (if \$v2Mode == 1 then { package: \$cliLinuxX64Package, url: \$cliLinuxX64Url } else {} end))
    },
    desktop: ${desktop_filter}
  }" >"$assets_file"

echo "Updated $assets_file for OpenCode v${version}"
