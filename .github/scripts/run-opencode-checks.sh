#!/usr/bin/env bash

set -uo pipefail

if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <system> <output-json>" >&2
	exit 1
fi

system="$1"
output_json="$2"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

run_build() {
	local attr_name="$1"
	local log_file="$tmp_dir/${attr_name}.log"
	local max_attempts=3
	local timeout_minutes=15

	for attempt in $(seq 1 $max_attempts); do
		>"$log_file" # Clear log

		echo "Building ${attr_name} (attempt $attempt/$max_attempts)..." >&2

		if timeout ${timeout_minutes}m \
			nix build --no-link ".#packages.${system}.${attr_name}" >"$log_file" 2>&1; then
			echo "success"
			return 0
		fi

		local exit_code=$?

		if [[ $exit_code -eq 124 ]]; then
			echo "TIMEOUT: ${attr_name} hung after ${timeout_minutes}m (attempt $attempt)" >&2
			# Kill any leftover nix/bun processes to prevent resource leaks
			pkill -f "bun install" 2>/dev/null || true
		else
			echo "FAILED: ${attr_name} exited with code $exit_code (attempt $attempt)" >&2
		fi

		if [[ $attempt -lt $max_attempts ]]; then
			local backoff=$((attempt * 30))
			echo "Retrying in ${backoff}s..." >&2
			sleep $backoff
		fi
	done

	echo "--- ${system} ${attr_name} failed after $max_attempts attempts ---" >&2
	sed -n '1,120p' "$log_file" >&2
	echo "--- end log excerpt ---" >&2
	echo "failure"
}

cli_build="$(run_build "opencode-cli-build")"
cli_bin="$(run_build "opencode-cli-bin")"
desktop_build="$(run_build "opencode-desktop-build")"
desktop_bin="$(run_build "opencode-desktop-bin")"

if [[ "$desktop_bin" == "success" && "$system" == *"-darwin" ]]; then
	desktop_out="$(nix path-info ".#packages.${system}.opencode-desktop-bin" 2>/dev/null)"
	desktop_app="${desktop_out}/Applications/OpenCode.app"

	if ! spctl --assess --type execute --verbose=4 "$desktop_app" >/dev/null 2>&1; then
		echo "Darwin desktop-bin Gatekeeper assessment failed for ${system}" >&2
		desktop_bin="failure"
	fi
fi

jq -n \
	--arg system "$system" \
	--arg cliBuild "$cli_build" \
	--arg cliBin "$cli_bin" \
	--arg desktopBuild "$desktop_build" \
	--arg desktopBin "$desktop_bin" \
	'{
    system: $system,
    cli: {
      build: $cliBuild,
      bin: $cliBin
    },
    desktop: {
      build: $desktopBuild,
      bin: $desktopBin
    }
  }' >"$output_json"

echo "Wrote OpenCode check result: $output_json"
