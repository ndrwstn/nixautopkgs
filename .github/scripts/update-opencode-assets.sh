#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

assets_file="packages/opencode/assets.json"
cli_version="$(curl -fsSL --retry 3 --retry-all-errors \
	https://opencode.ai/update/api/latest/cli/npm | jq -r '.version')"
desktop_json="$(curl -fsSL --retry 3 --retry-all-errors \
	https://opencode.ai/update/api/latest/desktop)"
desktop_version="$(jq -r '.artifacts[0].version' <<<"$desktop_json")"

[[ -n "$cli_version" && "$cli_version" != null ]] || {
	echo "Failed to resolve the current OpenCode CLI release" >&2
	exit 1
}
[[ -n "$desktop_version" && "$desktop_version" != null ]] || {
	echo "Failed to resolve the current OpenCode desktop release" >&2
	exit 1
}

npm_asset() {
	local package="$1"
	local metadata
	metadata="$(curl -fsSL "https://registry.npmjs.org/${package}/${cli_version}")"
	jq -cn \
		--arg url "$(jq -r '.dist.tarball' <<<"$metadata")" \
		--arg hash "$(jq -r '.dist.integrity' <<<"$metadata")" \
		--arg name "$(jq -r '.dist.tarball | split("/") | last' <<<"$metadata")" \
		--arg package "$package" \
		'{archiveType:"tar.gz",hash:$hash,name:$name,package:$package,url:$url}'
}

desktop_asset() {
	local name="$1"
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
    desktopVersion:$desktopVersion}' >"$assets_file"

echo "Updated $assets_file for OpenCode CLI v$cli_version, desktop v$desktop_version"
