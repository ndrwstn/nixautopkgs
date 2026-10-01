#!/usr/bin/env bash

# Discover the newest active CLI development build from npm and the newest
# complete desktop build from the beta GitHub releases. These channels are
# independent and therefore use separate versions in assets.json.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

assets_file="packages/opencode-v2/assets.json"
packages=(
	"opencode-darwin-arm64"
	"opencode-darwin-x64"
	"opencode-linux-arm64"
	"opencode-linux-x64"
)
desktop_assets=(
	"opencode-desktop-mac-arm64.dmg"
	"opencode-desktop-mac-x64.dmg"
	"opencode-desktop-linux-arm64.deb"
	"opencode-desktop-linux-amd64.deb"
)

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for package in "${packages[@]}"; do
	file="$tmp_dir/${package##*/}.json"
	curl --fail --silent --show-error --location \
		"https://registry.npmjs.org/${package}" >"$file"
done

current_cli_version="$(jq -r '.cliVersion // .version // empty' "$assets_file")"
if [[ "$current_cli_version" != 0.0.0-dev-* ]]; then
	current_cli_version=""
fi
cli_version="$(python3 .github/scripts/opencode_v2_version.py \
	"$tmp_dir" "${packages[@]}" --channel dev --current "$current_cli_version")"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
	curl_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
	curl_args=()
fi

releases_json="$tmp_dir/releases.json"
curl --fail --silent --show-error --location "${curl_args[@]}" \
	"https://api.github.com/repos/anomalyco/opencode-beta/releases?per_page=100" >"$releases_json"

required_json="$(printf '%s\n' "${desktop_assets[@]}" | jq -R . | jq -s .)"
desktop_version="$(jq -r --argjson required "$required_json" '
	[ .[]
	  | select(.draft == false and .prerelease == false)
	  | select(.tag_name | test("^v0\\.0\\.0-(?:beta|dev)-[0-9]+$"))
	  | . as $release
	  | select(all($required[]; . as $name | any($release.assets[]; .name == $name)))
	] | sort_by(.published_at) | last.tag_name // empty | sub("^v"; "")
' "$releases_json")"

if [[ -z "$desktop_version" ]]; then
	echo "No complete OpenCode beta desktop release is available" >&2
	exit 2
fi

current_desktop_version="$(jq -r '.desktopVersion // .version // empty' "$assets_file")"
if [[ "$cli_version" == "$current_cli_version" && "$desktop_version" == "$current_desktop_version" ]]; then
	echo "OpenCode v2 is already at CLI $cli_version and desktop $desktop_version"
	exit 0
fi

./.github/scripts/update-opencode-assets.sh \
	--repo anomalyco/opencode-beta \
	--assets-file "$assets_file" \
	--version "$cli_version" \
	--desktop-version "$desktop_version"

echo "Updated OpenCode v2 CLI from $current_cli_version to $cli_version; desktop from $current_desktop_version to $desktop_version"
