#!/usr/bin/env bash

# Discover the current stable CLI and desktop release from OpenCode's
# official update API.
#
# Emits cli_changed and desktop_changed to $GITHUB_OUTPUT when it is set, so
# the workflow can skip the desktop build when only the CLI moved.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root" || exit 1

assets_file="packages/opencode/assets.json"
cli_version="$(curl --fail --silent --show-error --retry 3 --retry-all-errors https://opencode.ai/update/api/latest/cli/npm | jq -r '.version')"
desktop_version="$(curl --fail --silent --show-error --retry 3 --retry-all-errors https://opencode.ai/update/api/latest/desktop | jq -r '.artifacts[0].version')"

current_cli_version="$(jq -r '.cliVersion // empty' "$assets_file")"
current_desktop_version="$(jq -r '.desktopVersion // empty' "$assets_file")"

cli_changed=false
desktop_changed=false
if [[ "$cli_version" != "$current_cli_version" ]]; then
	cli_changed=true
fi
if [[ "$desktop_version" != "$current_desktop_version" ]]; then
	desktop_changed=true
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
	{
		echo "cli_changed=$cli_changed"
		echo "desktop_changed=$desktop_changed"
	} >>"$GITHUB_OUTPUT"
fi

if [[ "$cli_changed" == false && "$desktop_changed" == false ]]; then
	echo "OpenCode is already at CLI $cli_version and desktop $desktop_version"
	exit 0
fi

./.github/scripts/update-opencode-assets.sh \
	--assets-file "$assets_file" \
	--version "$cli_version" \
	--desktop-version "$desktop_version"

echo "Updated OpenCode CLI from $current_cli_version to $cli_version; desktop from $current_desktop_version to $desktop_version"
