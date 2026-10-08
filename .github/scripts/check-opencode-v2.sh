#!/usr/bin/env bash

# Discover the current stable v2 CLI and desktop release from OpenCode's
# official update API.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

assets_file="packages/opencode-v2/assets.json"
cli_version="$(curl --fail --silent --show-error --retry 3 --retry-all-errors https://opencode.ai/update/api/latest/cli/npm | jq -r '.version')"
desktop_version="$(curl --fail --silent --show-error --retry 3 --retry-all-errors https://opencode.ai/update/api/latest/desktop | jq -r '.artifacts[0].version')"

current_cli_version="$(jq -r '.cliVersion // empty' "$assets_file")"
current_desktop_version="$(jq -r '.desktopVersion // empty' "$assets_file")"
if [[ "$cli_version" == "$current_cli_version" && "$desktop_version" == "$current_desktop_version" ]]; then
	echo "OpenCode v2 is already at CLI $cli_version and desktop $desktop_version"
	exit 0
fi

./.github/scripts/update-opencode-assets.sh \
	--assets-file "$assets_file" \
	--version "$cli_version" \
	--desktop-version "$desktop_version"

echo "Updated OpenCode v2 CLI from $current_cli_version to $cli_version; desktop from $current_desktop_version to $desktop_version"
