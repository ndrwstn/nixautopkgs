#!/bin/bash

set -euo pipefail

PACKAGE_FILE="packages/opencode.nix"

if [[ ! -f "$PACKAGE_FILE" ]]; then
	echo "Error: $PACKAGE_FILE not found"
	exit 1
fi

echo "Fetching latest version from npm registry..."
VERSION=$(curl -s https://registry.npmjs.org/opencode-ai/latest | jq -r '.version')

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
	echo "Error: Failed to fetch version from npm registry"
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

# Fetch hashes for all packages
echo "Fetching hashes for version $VERSION..."

echo -n "Fetching opencode-ai hash... "
OPENCODE_AI_HASH=$(nix-prefetch-url --type sha256 "https://registry.npmjs.org/opencode-ai/-/opencode-ai-${VERSION}.tgz" 2>/dev/null)
echo "$OPENCODE_AI_HASH"

echo -n "Fetching opencode-darwin-arm64 hash... "
DARWIN_ARM64_HASH=$(nix-prefetch-url --type sha256 "https://registry.npmjs.org/opencode-darwin-arm64/-/opencode-darwin-arm64-${VERSION}.tgz" 2>/dev/null)
echo "$DARWIN_ARM64_HASH"

echo -n "Fetching opencode-darwin-x64 hash... "
DARWIN_X64_HASH=$(nix-prefetch-url --type sha256 "https://registry.npmjs.org/opencode-darwin-x64/-/opencode-darwin-x64-${VERSION}.tgz" 2>/dev/null)
echo "$DARWIN_X64_HASH"

echo -n "Fetching opencode-linux-arm64 hash... "
LINUX_ARM64_HASH=$(nix-prefetch-url --type sha256 "https://registry.npmjs.org/opencode-linux-arm64/-/opencode-linux-arm64-${VERSION}.tgz" 2>/dev/null)
echo "$LINUX_ARM64_HASH"

echo -n "Fetching opencode-linux-x64 hash... "
LINUX_X64_HASH=$(nix-prefetch-url --type sha256 "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-${VERSION}.tgz" 2>/dev/null)
echo "$LINUX_X64_HASH"

# Verify all hashes were fetched successfully
if [[ -z "$OPENCODE_AI_HASH" || -z "$DARWIN_ARM64_HASH" || -z "$DARWIN_X64_HASH" || -z "$LINUX_ARM64_HASH" || -z "$LINUX_X64_HASH" ]]; then
	echo "Error: Failed to fetch one or more hashes"
	exit 1
fi

echo "Updating $PACKAGE_FILE..."

# Update version and checksums
if [[ "$OSTYPE" == "darwin"* ]]; then
	# macOS sed
	sed -i '' "s/version = \"[^\"]*\";/version = \"$VERSION\";/" "$PACKAGE_FILE"
	sed -i '' "s/\"opencode-ai\" = \"[^\"]*\";/\"opencode-ai\" = \"$OPENCODE_AI_HASH\";/" "$PACKAGE_FILE"
	sed -i '' "s/\"opencode-darwin-arm64\" = \"[^\"]*\";/\"opencode-darwin-arm64\" = \"$DARWIN_ARM64_HASH\";/" "$PACKAGE_FILE"
	sed -i '' "s/\"opencode-darwin-x64\" = \"[^\"]*\";/\"opencode-darwin-x64\" = \"$DARWIN_X64_HASH\";/" "$PACKAGE_FILE"
	sed -i '' "s/\"opencode-linux-arm64\" = \"[^\"]*\";/\"opencode-linux-arm64\" = \"$LINUX_ARM64_HASH\";/" "$PACKAGE_FILE"
	sed -i '' "s/\"opencode-linux-x64\" = \"[^\"]*\";/\"opencode-linux-x64\" = \"$LINUX_X64_HASH\";/" "$PACKAGE_FILE"
else
	# Linux sed
	sed -i "s/version = \"[^\"]*\";/version = \"$VERSION\";/" "$PACKAGE_FILE"
	sed -i "s/\"opencode-ai\" = \"[^\"]*\";/\"opencode-ai\" = \"$OPENCODE_AI_HASH\";/" "$PACKAGE_FILE"
	sed -i "s/\"opencode-darwin-arm64\" = \"[^\"]*\";/\"opencode-darwin-arm64\" = \"$DARWIN_ARM64_HASH\";/" "$PACKAGE_FILE"
	sed -i "s/\"opencode-darwin-x64\" = \"[^\"]*\";/\"opencode-darwin-x64\" = \"$DARWIN_X64_HASH\";/" "$PACKAGE_FILE"
	sed -i "s/\"opencode-linux-arm64\" = \"[^\"]*\";/\"opencode-linux-arm64\" = \"$LINUX_ARM64_HASH\";/" "$PACKAGE_FILE"
	sed -i "s/\"opencode-linux-x64\" = \"[^\"]*\";/\"opencode-linux-x64\" = \"$LINUX_X64_HASH\";/" "$PACKAGE_FILE"
fi

echo "Successfully updated $PACKAGE_FILE with new hashes for version $VERSION"
echo "Run 'nix build .#opencode' to test the build"
