# AGENTS.md - Coding Agent Guidelines

## Build/Test Commands

- **Build packages**: `nix build .#gcs` or `nix build .#opencode`
- **Test all builds**: `nix build .#gcs && nix build .#opencode`
- **Development shell**: `nix develop`
- **Update packages**: Handled automatically by Renovate (see `renovate.json`)

## Code Style Guidelines

- **Language**: Nix expressions with Bash scripts for automation
- **Formatting**: 2-space indentation, no trailing whitespace
- **Imports**: Use `{ pkgs }` or `{ pkgs, system }` parameter patterns
- **Naming**: Use kebab-case for package names, camelCase for Nix variables
- **Versions**: Always use semantic versioning (e.g., "5.38.1")
- **Hashes**: Use SHA256 hashes with `sha256-` prefix for fetchFromGitHub/fetchurl
- **Error handling**: Use `set -euo pipefail` in shell scripts
- **Comments**: Minimal comments, prefer self-documenting code

## Package Structure

- Package definitions in `packages/*.nix`
- Renovate configuration in `renovate.json`
- GitHub workflows in `.github/workflows/auto-merge.yml`
- Follow existing patterns for new packages (see gcs.nix/opencode.nix)

## Dependency Management

- Renovate automatically monitors upstream releases
- Updates are created as PRs with comprehensive changelogs
- Add new packages by updating `renovate.json` regex managers
- Manual update scripts in `bin/` are kept for emergency use

## Testing

- Always test builds after changes: `nix build .#<package>`
- Renovate PRs include automated build testing
- Check Renovate configuration: validate `renovate.json` syntax
