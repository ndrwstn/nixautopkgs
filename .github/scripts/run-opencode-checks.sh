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

# Timeout duration in seconds (30 minutes)
TIMEOUT_SECONDS=1800

# Run a build with timeout using Python for cross-platform compatibility
# Returns: "success", "failure", or "timeout"
run_build_with_timeout() {
	local attr_name="$1"
	local log_file="$tmp_dir/${attr_name}.log"
	local start_time end_time elapsed

	start_time=$(date +%s)
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ${attr_name} for ${system}..." >&2

	# Use Python for portable timeout since GNU timeout isn't available on macOS
	python3 -c "
import sys
import subprocess
import os

cmd = ['nix', 'build', '--no-link', '.#packages.${system}.${attr_name}']
log_path = '${log_file}'
timeout = ${TIMEOUT_SECONDS}

try:
    with open(log_path, 'w') as log_f:
        proc = subprocess.Popen(
            cmd,
            stdout=log_f,
            stderr=subprocess.STDOUT
        )
        try:
            proc.wait(timeout=timeout)
            sys.exit(proc.returncode)
        except subprocess.TimeoutExpired:
            # Kill the process and its children
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            # Also try to kill any leftover nix/bun processes
            try:
                subprocess.run(['pkill', '-f', 'bun install'], capture_output=True)
            except:
                pass
            sys.exit(124)  # Standard timeout exit code
except Exception as e:
    with open(log_path, 'a') as log_f:
        log_f.write(f'Runner error: {e}\\n')
    sys.exit(1)
"

	local exit_code=$?
	end_time=$(date +%s)
	elapsed=$((end_time - start_time))

	if [[ $exit_code -eq 0 ]]; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Succeeded ${attr_name} for ${system} in ${elapsed}s" >&2
		echo "success"
		return 0
	elif [[ $exit_code -eq 124 ]]; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] TIMED OUT ${attr_name} for ${system} after ${TIMEOUT_SECONDS}s" >&2
		echo "--- ${system} ${attr_name} timed out (last 120 lines) ---" >&2
		sed -n '1,120p' "$log_file" >&2
		echo "--- end log excerpt ---" >&2
		echo "timeout"
		return 0
	else
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed ${attr_name} for ${system} after ${elapsed}s (exit ${exit_code})" >&2
		echo "--- ${system} ${attr_name} failed (last 120 lines) ---" >&2
		sed -n '1,120p' "$log_file" >&2
		echo "--- end log excerpt ---" >&2
		echo "failure"
		return 0
	fi
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running OpenCode build/bin checks for ${system}" >&2

routing_file="${repo_root}/packages/opencode/routing.json"
desktop_route="$(jq -r --arg system "$system" '.[$system].desktop' "$routing_file")"

cli_build="$(run_build_with_timeout "opencode-cli-build")"
cli_bin="$(run_build_with_timeout "opencode-cli-bin")"

if [[ "$desktop_route" == "null" ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping desktop checks for ${system} (route is null)" >&2
	desktop_build="skipped"
	desktop_bin="skipped"
else
	desktop_build="$(run_build_with_timeout "opencode-desktop-build")"
	desktop_bin="$(run_build_with_timeout "opencode-desktop-bin")"
fi

if [[ "$desktop_bin" == "success" && "$system" == *"-darwin" ]]; then
	desktop_out="$(nix path-info ".#packages.${system}.opencode-desktop-bin" 2>/dev/null)"
	desktop_app="${desktop_out}/Applications/OpenCode.app"

	if ! spctl --assess --type execute --verbose=4 "$desktop_app" >/dev/null 2>&1; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Darwin desktop-bin Gatekeeper assessment failed for ${system}" >&2
		desktop_bin="failure"
	else
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Darwin desktop-bin Gatekeeper assessment passed for ${system}" >&2
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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wrote OpenCode check result: $output_json" >&2
