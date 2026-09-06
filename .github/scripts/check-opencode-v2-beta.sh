#!/usr/bin/env bash

# Discover the newest beta published to npm and synchronize the pinned v2
# assets file. npm is used for discovery because the beta channel does not
# consistently follow a normal GitHub release cadence.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

assets_file="packages/opencode-v2/assets.json"
packages=(
	"@opencode-ai/cli-darwin-arm64"
	"@opencode-ai/cli-darwin-x64"
	"@opencode-ai/cli-linux-arm64"
	"@opencode-ai/cli-linux-x64"
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
	package_url="$(printf '%s' "$package" | sed 's#/#%2F#')"
	curl --fail --silent --show-error --location \
		"https://registry.npmjs.org/${package_url}" >"$file"
done

version="$(
	python3 - "$tmp_dir" "${packages[@]}" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
packages = sys.argv[2:]
version_sets = []
for package in packages:
    metadata = json.loads((root / (package.split("/")[-1] + ".json")).read_text())
    versions = set(metadata.get("versions", {}))
    versions = {v for v in versions if re.fullmatch(r"0\.0\.0-beta-\d+", v)}
    version_sets.append(versions)

common = set.intersection(*version_sets)
if not common:
    raise SystemExit("No common beta version is published for all CLI platforms")

print(max(common, key=lambda v: int(v.rsplit("-", 1)[1])))
PY
)"

current_version="$(jq -r '.version // empty' "$assets_file")"
if [[ "$version" == "$current_version" ]]; then
	echo "OpenCode v2 is already at $version"
	exit 0
fi

release_json="$tmp_dir/release.json"
release_url="https://api.github.com/repos/anomalyco/opencode-beta/releases/tags/v${version}"
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
	curl_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
	curl_args=()
fi

if ! curl --fail --silent --show-error --location "${curl_args[@]}" "$release_url" >"$release_json"; then
	echo "npm has $version, but the matching GitHub release is not available yet" >&2
	exit 2
fi

missing=()
for asset in "${desktop_assets[@]}"; do
	if ! jq -e --arg name "$asset" '.assets[] | select(.name == $name and (.digest | startswith("sha256:")))' "$release_json" >/dev/null; then
		missing+=("$asset")
	fi
done
if ((${#missing[@]})); then
	echo "GitHub release v${version} is missing assets or digests: ${missing[*]}" >&2
	exit 2
fi

jq --arg version "$version" '.version = $version' "$assets_file" >"$assets_file.tmp"
mv "$assets_file.tmp" "$assets_file"

./.github/scripts/update-opencode-assets.sh \
	--repo anomalyco/opencode-beta \
	--assets-file "$assets_file" \
	--version "$version"

echo "Updated OpenCode v2 from $current_version to $version"
