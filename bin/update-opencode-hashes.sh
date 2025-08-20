#!/bin/bash

set -euo pipefail

PACKAGE_FILE="packages/opencode.nix"
REPO_OWNER="sst"
REPO_NAME="opencode"

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

echo "Updating from $CURRENT_VERSION to $VERSION"

# Fetch new source hash for main repo using nix-prefetch-url for proper SRI format
echo "Fetching main source hash..."
MAIN_SOURCE_HASH=$(nix-prefetch-url --unpack "https://github.com/$REPO_OWNER/$REPO_NAME/archive/v$VERSION.tar.gz" 2>/dev/null)

if [[ -z "$MAIN_SOURCE_HASH" ]]; then
	echo "Error: Failed to fetch main source hash"
	exit 1
fi

echo "Main source hash: $MAIN_SOURCE_HASH"

# Update version and main source hash
if [[ "$OSTYPE" == "darwin"* ]]; then
	# macOS sed
	sed -i.bak 's/version = "[^"]*";/version = "'"$VERSION"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
	sed -i.bak 's/hash = "[^"]*";/hash = "'"$MAIN_SOURCE_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
else
	# Linux sed
	sed -i 's/version = "[^"]*";/version = "'"$VERSION"'";/' "$PACKAGE_FILE"
	sed -i 's/hash = "[^"]*";/hash = "'"$MAIN_SOURCE_HASH"'";/' "$PACKAGE_FILE"
fi

echo "Updated main source hash"

# Update TUI vendorHash by attempting build and extracting correct hash
echo "Updating TUI vendorHash..."
if ! nix build .#opencode 2>&1 | tee /tmp/opencode_build.log; then
	if grep -q "got:" /tmp/opencode_build.log; then
		NEW_VENDOR_HASH=$(grep "got:" /tmp/opencode_build.log | head -1 | awk '{print $2}')
		echo "Found new TUI vendorHash: $NEW_VENDOR_HASH"

		if [[ "$OSTYPE" == "darwin"* ]]; then
			sed -i.bak 's/vendorHash = "sha256-[^"]*";/vendorHash = "'"$NEW_VENDOR_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
		else
			sed -i 's/vendorHash = "sha256-[^"]*";/vendorHash = "'"$NEW_VENDOR_HASH"'";/' "$PACKAGE_FILE"
		fi

		echo "Updated TUI vendorHash to $NEW_VENDOR_HASH"

		# Try building again to get node_modules hash
		echo "Updating node_modules hash..."
		if ! nix build .#opencode 2>&1 | tee /tmp/opencode_build2.log; then
			if grep -q "got:" /tmp/opencode_build2.log; then
				NEW_NODE_HASH=$(grep "got:" /tmp/opencode_build2.log | head -1 | awk '{print $2}')
				echo "Found new node_modules hash: $NEW_NODE_HASH"

				# Update all platform hashes to the same value (they should be identical)
				if [[ "$OSTYPE" == "darwin"* ]]; then
					sed -i.bak 's/"aarch64-darwin" = "sha256-[^"]*";/"aarch64-darwin" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
					sed -i.bak 's/"aarch64-linux" = "sha256-[^"]*";/"aarch64-linux" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
					sed -i.bak 's/"x86_64-darwin" = "sha256-[^"]*";/"x86_64-darwin" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
					sed -i.bak 's/"x86_64-linux" = "sha256-[^"]*";/"x86_64-linux" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE" && rm -f "$PACKAGE_FILE.bak"
				else
					sed -i 's/"aarch64-darwin" = "sha256-[^"]*";/"aarch64-darwin" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE"
					sed -i 's/"aarch64-linux" = "sha256-[^"]*";/"aarch64-linux" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE"
					sed -i 's/"x86_64-darwin" = "sha256-[^"]*";/"x86_64-darwin" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE"
					sed -i 's/"x86_64-linux" = "sha256-[^"]*";/"x86_64-linux" = "'"$NEW_NODE_HASH"'";/' "$PACKAGE_FILE"
				fi

				echo "Updated node_modules hash to $NEW_NODE_HASH"
			else
				echo "Warning: Build failed but no node_modules hash mismatch found"
				cat /tmp/opencode_build2.log
				exit 1
			fi
		fi
		rm -f /tmp/opencode_build2.log
	else
		echo "Warning: Build failed but no vendorHash mismatch found"
		cat /tmp/opencode_build.log
		exit 1
	fi
fi

rm -f /tmp/opencode_build.log
echo "Successfully updated $PACKAGE_FILE"
echo "Run 'nix build .#opencode' to verify the build"
