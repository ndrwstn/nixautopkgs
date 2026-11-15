#!/usr/bin/env bash

# Post a commit status on the commit the caller evaluated.
#
# Bot pushes made with GITHUB_TOKEN do not start workflows, so the commit a
# hash updater pushes carries no check runs. Renovate only merges a branch it
# can see a verdict for, so the updater must leave one behind.
#
# Usage: report-status.sh <state> <context> <description>
#
# <state> is success, failure, error, or pending. Post success only for a tree
# that was actually built on every supported platform.

set -euo pipefail

state="${1:?state required}"
context="${2:?context required}"
description="${3:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root" || exit 1

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"

sha="$(git rev-parse HEAD)"

gh api \
	--method POST \
	"repos/${GITHUB_REPOSITORY}/statuses/${sha}" \
	-f state="$state" \
	-f context="$context" \
	-f description="$description" \
	>/dev/null

echo "Reported ${state} for ${context} on ${sha}"
