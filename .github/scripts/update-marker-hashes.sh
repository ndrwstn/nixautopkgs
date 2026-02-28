#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

package_file="packages/marker/default.nix"
build_log="$(mktemp)"
max_attempts=8

update_field() {
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
updated, count = pattern.subn(lambda m: f'{m.group(1)}{value}{m.group(2)}', text, count=1)

if count != 1:
    raise SystemExit(f"Could not update field: {field}")

path.write_text(updated)
PY
}

extract_field() {
	local field="$1"
	python3 - "$package_file" "$field" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
field = sys.argv[2]
match = re.search(rf'^\s*{re.escape(field)}\s*=\s*"([^"]+)";', text, re.MULTILINE)
if not match:
    raise SystemExit(f"Could not extract field: {field}")
print(match.group(1))
PY
}

sync_pdftext_version() {
	local version="$1"
	local pyproject
	pyproject="$(curl -fsSL "https://raw.githubusercontent.com/datalab-to/marker/v${version}/pyproject.toml")"

	local parsed
	parsed="$(python3 -c 'import re,sys
text=sys.stdin.read()
m=re.search(r"^pdftext\s*=\s*\"[~^]?([0-9][0-9A-Za-z.+-]*)\"", text, re.MULTILINE)
print(m.group(1) if m else "")' <<<"$pyproject")"

	if [[ -z "$parsed" ]]; then
		echo "Could not parse pdftext version from marker pyproject" >&2
		exit 1
	fi

	echo "Setting pdftextVersion=${parsed}"
	update_field "pdftextVersion" "$parsed"
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
field = "pdftextHash" if "pdftext" in drv else "hash"
print(f"{field}|{got_hash}|{drv}")
PY
}

version="$(extract_field version)"
sync_pdftext_version "$version"

nix run nixpkgs#nix-update -- --flake --version=skip marker

echo "Converging marker hashes"
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
	echo "Build attempt ${attempt}/${max_attempts}"
	if nix build .#marker --no-link 2>&1 | tee "$build_log"; then
		echo "marker hashes are valid"
		rm -f "$build_log"
		exit 0
	fi

	if ! mismatch="$(extract_mismatch "$build_log")"; then
		echo "Failed to detect fixed-output mismatch from nix build output" >&2
		tail -n 200 "$build_log" >&2
		rm -f "$build_log"
		exit 1
	fi

	IFS='|' read -r field new_hash drv <<<"$mismatch"
	echo "Detected mismatch in ${drv}; updating ${field} -> ${new_hash}"
	update_field "$field" "$new_hash"
done

echo "Exceeded ${max_attempts} attempts while converging marker hashes" >&2
rm -f "$build_log"
exit 1
