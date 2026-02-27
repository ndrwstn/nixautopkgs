#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

nix run nixpkgs#nix-update -- --flake --version=skip agent-browser

package_file="packages/agent-browser/default.nix"
build_log="$(mktemp)"
max_attempts=8

update_hash_field() {
	local field="$1"
	local value="$2"

	python3 - "$package_file" "$field" "$value" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
field = sys.argv[2]
value = sys.argv[3]

pattern = re.compile(rf'(^\s*{re.escape(field)}\s*=\s*")[^"]*(";\s*$)', re.MULTILINE)
text = path.read_text()

updated, count = pattern.subn(rf'\1{value}\2', text, count=1)
if count != 1:
    raise SystemExit(f"Could not update field: {field}")

path.write_text(updated)
PY
}

extract_mismatch() {
	local log_path="$1"
	python3 - "$log_path" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(errors="replace")

matches = list(
    re.finditer(
        r"hash mismatch in fixed-output derivation '([^']+)':\s*specified:\s*([^\s]+)\s*got:\s*([^\s]+)",
        text,
        re.MULTILINE,
    )
)
if not matches:
    sys.exit(1)

drv, got_hash = matches[-1].group(1), matches[-1].group(3)
if "vendor-staging" in drv:
    field = "cargoHash"
elif "npm-deps" in drv:
    field = "npmDepsHash"
else:
    field = "hash"

print(f"{field}|{got_hash}|{drv}")
PY
}

echo "Converging agent-browser hashes"

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
	echo "Build attempt ${attempt}/${max_attempts}"

	if nix build .#agent-browser --no-link 2>&1 | tee "$build_log"; then
		echo "agent-browser hashes are valid"
		echo "Updated agent-browser hashes"
		rm -f "$build_log"
		exit 0
	fi

	if ! mismatch="$(extract_mismatch "$build_log")"; then
		echo "Failed to detect fixed-output mismatch from nix build output" >&2
		echo "Last 200 lines of build log:" >&2
		tail -n 200 "$build_log" >&2
		rm -f "$build_log"
		exit 1
	fi

	IFS='|' read -r field new_hash drv <<<"$mismatch"
	echo "Detected mismatch in ${drv}; updating ${field} -> ${new_hash}"
	update_hash_field "$field" "$new_hash"
done

echo "Exceeded ${max_attempts} attempts while converging agent-browser hashes" >&2
rm -f "$build_log"
exit 1
