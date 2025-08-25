# Coding Agent Guidelines

## Build/Test Commands

- **Build packages**: `nix build .#gcs` or `nix build .#opencode`
- **Unified build**: `./bin/build-package --platform <platform> --package <package>`
- **Development shell**: `nix develop` (includes go, bun, git, jq, nix-prefetch tools)
- **Update packages**: Automated via Renovate
- **Manual hash updates**: `./bin/update-gcs` or `./bin/update-opencode` (run in `nix develop`)

## Code Style

- **Language**: Nix expressions with Bash scripts
- **Formatting**: 2-space indentation, no trailing whitespace
- **Imports**: Use `{ pkgs }` or `{ pkgs, system }` patterns
- **Naming**: kebab-case for packages, camelCase for Nix variables
- **Versions**: Semantic versioning (e.g., "5.38.1")
- **Hashes**: SHA256 with `sha256-` prefix
- **Error handling**: `set -euo pipefail` in shell scripts

## Scripts

- **Update GCS**: `./bin/update-gcs`
- **Update OpenCode**: `./bin/update-opencode`
- **Build**: `./bin/build-package --platform <platform> --package <package>`

### Script Versioning

**CRITICAL**: When modifying any update script (`bin/update-*`), you MUST update the version string at the top of the script:

```bash
echo ">>> SCRIPT_NAME UPDATE HASH SCRIPT - LAST MODIFIED YYYY-MM-DD HH:MM <<<"
```

This helps track which version of the script is running in GitHub Actions logs and debug issues. The timestamp should be the actual modification time, not dynamic.

## Project Structure

- Package definitions: `packages/*.nix`
- Scripts: `bin/`
- Renovate config: `renovate.json`
- Workflows: `.github/workflows/`

## Workflow Pipeline

1. **update-build.yml** - Unified workflow that updates hashes and builds packages from Renovate PRs
2. **auto-merge.yml** - Merges successful builds

## Packages

- **gcs**: GURPS Character Sheet (`richardwilkes/gcs`)
- **opencode**: AI Coding Agent (`sst/opencode`)

## Testing

- Test builds: `nix build .#<package>`
- All platforms: x86_64/aarch64 Linux/Darwin
- Automated via Renovate PRs
