#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

assets_file="packages/opencode/assets.json"
assets_dir="$(dirname "$assets_file")"
tmp_assets_file="$(mktemp "$assets_dir/assets.json.tmp.XXXXXX")"
trap 'rm -f "$tmp_assets_file"' EXIT

cli_version="$(curl -fsSL --retry 3 --retry-all-errors \
	https://opencode.ai/update/api/latest/cli/npm | jq -r '.version')"
desktop_json="$(curl -fsSL --retry 3 --retry-all-errors \
	https://opencode.ai/update/api/latest/desktop)"
desktop_version="$(jq -r '.artifacts[0].version' <<<"$desktop_json")"

[[ "$cli_version" =~ ^[0-9]+(\.[0-9]+){2}([.-][0-9A-Za-z.-]+)?$ ]] || {
	echo "Failed to resolve the current OpenCode CLI release" >&2
	exit 1
}
[[ "$desktop_version" =~ ^[0-9]+(\.[0-9]+){2}([.-][0-9A-Za-z.-]+)?$ ]] || {
	echo "Failed to resolve the current OpenCode desktop release" >&2
	exit 1
}

npm_asset() {
	local package="$1"
	local metadata
	metadata="$(curl -fsSL "https://registry.npmjs.org/${package}/${cli_version}")"
	jq -e '
		.dist.tarball | type == "string" and length > 0
		and startswith("https://")
	' <<<"$metadata" >/dev/null || {
		echo "Missing npm tarball URL for $package@$cli_version" >&2
		exit 1
	}
	jq -e '
		.dist.integrity | type == "string" and test("^sha512-[A-Za-z0-9+/=]+$")
	' <<<"$metadata" >/dev/null || {
		echo "Missing npm integrity hash for $package@$cli_version" >&2
		exit 1
	}
	jq -cn \
		--arg url "$(jq -r '.dist.tarball' <<<"$metadata")" \
		--arg hash "$(jq -r '.dist.integrity' <<<"$metadata")" \
		--arg name "$(jq -r '.dist.tarball | split("/") | last' <<<"$metadata")" \
		--arg package "$package" \
		'{archiveType:"tar.gz",hash:$hash,name:$name,package:$package,url:$url}'
}

desktop_asset() {
	local name="$1"
	jq -e --arg name "$name" '
		.artifacts[0].metadata.files[$name].url
		| type == "string" and length > 0 and startswith("https://")
	' <<<"$desktop_json" >/dev/null || {
		echo "Missing desktop asset URL for $name" >&2
		exit 1
	}
	jq -e --arg name "$name" '
		.artifacts[0].metadata.files[$name].sha256
		| type == "string" and test("^[A-Fa-f0-9]{64}$")
	' <<<"$desktop_json" >/dev/null || {
		echo "Missing desktop SHA-256 for $name" >&2
		exit 1
	}
	jq -c --arg name "$name" \
		'.artifacts[0].metadata.files[$name] |
     {archiveType:(if ($name|endswith(".dmg")) then "darwin-dmg" else "deb" end),
      hash:.sha256, name:$name, url:.url}' <<<"$desktop_json" |
		python3 -c '
import base64, json, sys
asset = json.load(sys.stdin)
asset["hash"] = "sha256-" + base64.b64encode(bytes.fromhex(asset["hash"])).decode()
print(json.dumps(asset, separators=(",", ":")))
'
}

jq -n \
	--arg cliVersion "$cli_version" \
	--arg desktopVersion "$desktop_version" \
	--argjson darwinArm "$(npm_asset @opencode/cli-darwin-arm64)" \
	--argjson linuxArm "$(npm_asset @opencode/cli-linux-arm64)" \
	--argjson linuxX64 "$(npm_asset @opencode/cli-linux-x64)" \
	--argjson desktopDarwin "$(desktop_asset opencode-desktop-mac-arm64.dmg)" \
	--argjson desktopLinuxArm "$(desktop_asset opencode-desktop-linux-arm64.deb)" \
	--argjson desktopLinuxX64 "$(desktop_asset opencode-desktop-linux-amd64.deb)" \
	'{cli:{"aarch64-darwin":$darwinArm,"aarch64-linux":$linuxArm,"x86_64-linux":$linuxX64},
    cliVersion:$cliVersion,
    desktop:{"aarch64-darwin":$desktopDarwin,"aarch64-linux":$desktopLinuxArm,"x86_64-linux":$desktopLinuxX64},
    desktopVersion:$desktopVersion}' >"$tmp_assets_file"

jq -e '
	(.cliVersion | type == "string" and length > 0)
	and (.desktopVersion | type == "string" and length > 0)
	and all(.cli[];
		((.url | type == "string" and length > 0 and startswith("https://"))
		and (.hash | type == "string" and test("^sha512-[A-Za-z0-9+/=]+$"))))
	and all(.desktop[];
		((.url | type == "string" and length > 0 and startswith("https://"))
		and (.hash | type == "string" and test("^sha256-[A-Za-z0-9+/=]+$"))))
' "$tmp_assets_file" >/dev/null

mv "$tmp_assets_file" "$assets_file"

trap - EXIT

echo "Updated $assets_file for OpenCode CLI v$cli_version, desktop v$desktop_version"
