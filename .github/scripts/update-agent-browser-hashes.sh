#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

nix run nixpkgs#nix-update -- --flake --version=skip agent-browser

echo "Updated agent-browser hashes"
