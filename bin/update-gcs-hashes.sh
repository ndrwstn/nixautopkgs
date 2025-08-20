#!/bin/bash

set -euo pipefail

PACKAGE_FILE="packages/gcs.nix"
REPO_OWNER="richardwilkes"
REPO_NAME="gcs"

if [[ ! -f "$PACKAGE_FILE" ]]; then
	echo "Error: $PACKAGE_FILE not found"
	exit 1
fi

echo "Fetching latest version from GitHub releases..."
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name' | sed 's/^v//')

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
	echo "Error: Failed to fetch version from GitHub releases"
	exit 1
fi

echo "Latest version: $VERSION"

# Get current version from package file
CURRENT_VERSION=$(grep '^\s*version = ' "$PACKAGE_FILE" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')

if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
	echo "Already up to date (version $VERSION)"
	exit 0
fi

echo "Updating from $CURRENT_VERSION to $VERSION"

# Fetch new source hash using nix-prefetch-url for proper SRI format
echo "Fetching source hash..."
SOURCE_HASH=$(nix-prefetch-url --unpack "https://github.com/$REPO_OWNER/$REPO_NAME/archive/v$VERSION.tar.gz" 2>/dev/null)

if [[ -z "$SOURCE_HASH" ]]; then
	echo "Error: Failed to fetch source hash"
	exit 1
fi

echo "Source hash: $SOURCE_HASH"

# Update version and hash in package file
if [[ "$OSTYPE" == "darwin"* ]]; then
	# macOS sed
	sed -i.bak 's/version = "[^"]*";/version = "'"$VERSION"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
	sed -i.bak 's/hash = "[^"]*";/hash = "'"$SOURCE_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
else
	# Linux sed
	sed -i 's/version = "[^"]*";/version = "'"$VERSION"'";/' "$PACKAGE_FILE"
	sed -i 's/hash = "[^"]*";/hash = "'"$SOURCE_HASH"'";/' "$PACKAGE_FILE"
fi

echo "Updated $PACKAGE_FILE with version $VERSION"

# Update vendorHash by attempting build and extracting correct hash
echo "Updating vendorHash..."
if ! nix build .#gcs 2>&1 | tee /tmp/gcs_build.log; then
	if grep -q "got:" /tmp/gcs_build.log; then
		NEW_VENDOR_HASH=$(grep "got:" /tmp/gcs_build.log | head -1 | awk '{print $2}')
		echo "Found new vendorHash: $NEW_VENDOR_HASH"

		if [[ "$OSTYPE" == "darwin"* ]]; then
			sed -i.bak 's/vendorHash = "[^"]*";/vendorHash = "'"$NEW_VENDOR_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
		else
			sed -i 's/vendorHash = "[^"]*";/vendorHash = "'"$NEW_VENDOR_HASH"'";/' "$PACKAGE_FILE"
		fi

		echo "Updated vendorHash to $NEW_VENDOR_HASH"
	else
		echo "Warning: Build failed but no vendorHash mismatch found"
		cat /tmp/gcs_build.log
		exit 1
	fi
fi

rm -f /tmp/gcs_build.log
echo "Successfully updated $PACKAGE_FILE"
echo "Run 'nix build .#gcs' to verify the build"
