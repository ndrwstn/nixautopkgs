# Coding Agent Guidelines

## Build/Test Commands

- **Build packages**: `nix build .#gcs` or `nix build .#opencode`
- **Unified build**: `./bin/build-package --platform <platform> --package <package>`
- **Development shell**: `nix develop`
- **Update packages**: Automated via Renovate

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

## Project Structure

- Package definitions: `packages/*.nix`
- Scripts: `bin/`
- Renovate config: `renovate.json`
- Workflows: `.github/workflows/`

## Workflow Pipeline

1. **update-hash.yml** - Updates package hashes from Renovate PRs
2. **test-builds.yml** - Matrix builds on all platforms
3. **auto-merge.yml** - Merges successful builds

## Packages

- **gcs**: GURPS Character Sheet (`richardwilkes/gcs`)
- **opencode**: AI Coding Agent (`sst/opencode`)

## Testing

- Test builds: `nix build .#<package>`
- All platforms: x86_64/aarch64 Linux/Darwin
- Automated via Renovate PRs
