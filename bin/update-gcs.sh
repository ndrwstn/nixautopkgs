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
CURRENT_VERSION=$(grep 'version = ' "$PACKAGE_FILE" | sed 's/.*version = "\([^"]*\)".*/\1/')

if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
	echo "Already up to date (version $VERSION)"
	exit 0
fi

echo "Updating from $CURRENT_VERSION to $VERSION"

# Fetch new source hash
echo "Fetching source hash..."
SOURCE_HASH=$(nix-prefetch-git --url "https://github.com/$REPO_OWNER/$REPO_NAME.git" --rev "v$VERSION" --quiet | jq -r '.sha256')

if [[ -z "$SOURCE_HASH" ]]; then
	echo "Error: Failed to fetch source hash"
	exit 1
fi

echo "Source hash: $SOURCE_HASH"

# Update version and hash in package file
if [[ "$OSTYPE" == "darwin"* ]]; then
	# macOS sed
	sed -i '' "s/version = \"[^\"]*\";/version = \"$VERSION\";/" "$PACKAGE_FILE"
	sed -i '' "s/hash = \"[^\"]*\";/hash = \"sha256-$SOURCE_HASH\";/" "$PACKAGE_FILE"
else
	# Linux sed
	sed -i "s/version = \"[^\"]*\";/version = \"$VERSION\";/" "$PACKAGE_FILE"
	sed -i "s/hash = \"[^\"]*\";/hash = \"sha256-$SOURCE_HASH\";/" "$PACKAGE_FILE"
fi

echo "Updated $PACKAGE_FILE with version $VERSION"

# Note: vendorHash will need to be updated manually or through build process
echo "Note: vendorHash may need to be updated if Go dependencies changed"
echo "Run 'nix build .#gcs' to test the build"
