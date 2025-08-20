#!/bin/bash

set -euo pipefail

PLATFORM="x86_64-linux"
PACKAGES=("gcs" "opencode")

echo "=== Building packages for $PLATFORM ==="

BUILD_SUCCESS=true

for package in "${PACKAGES[@]}"; do
	echo "Building $package for $PLATFORM..."

	if nix build .#$package --system $PLATFORM --no-link; then
		echo "✅ $package build successful on $PLATFORM"
	else
		echo "❌ $package build failed on $PLATFORM"
		BUILD_SUCCESS=false
	fi
done

if [[ "$BUILD_SUCCESS" == "true" ]]; then
	echo "🎉 All builds successful on $PLATFORM!"
	exit 0
else
	echo "💥 One or more builds failed on $PLATFORM"
	exit 1
fi
