#!/bin/bash

set -euo pipefail

# This script updates package hashes for all packages
# It does NOT build - that's handled separately

echo "=== Updating Package Hashes ==="

UPDATED_PACKAGES=()

# Update GCS hashes
echo "Updating GCS hashes..."
if ./bin/update-gcs-hashes.sh; then
	UPDATED_PACKAGES+=("gcs")
	echo "✅ GCS hashes updated"
else
	echo "ℹ️  GCS hashes unchanged or failed"
fi

# Update OpenCode hashes
echo "Updating OpenCode hashes..."
if ./bin/update-opencode-hashes.sh; then
	UPDATED_PACKAGES+=("opencode")
	echo "✅ OpenCode hashes updated"
else
	echo "ℹ️  OpenCode hashes unchanged or failed"
fi

if [[ ${#UPDATED_PACKAGES[@]} -gt 0 ]]; then
	echo "=== Hash Update Summary ==="
	echo "Updated packages: ${UPDATED_PACKAGES[*]}"
	echo "updated=true"
	exit 0
else
	echo "=== Hash Update Summary ==="
	echo "No packages were updated"
	echo "updated=false"
	exit 1
fi
