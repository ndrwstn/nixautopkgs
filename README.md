# nixautopkgs

This flake provides packages that are not yet in nixpkgs, and tracks newer upstream releases.

## OpenCode Packaging Strategy

OpenCode is exposed as both source-build and binary-package variants:

- `opencode-cli-build`: from the upstream OpenCode flake (`anomalyco/opencode`)
- `opencode-cli-bin`: first-party binary packaging in this repo
- `opencode-desktop-build`: from the upstream OpenCode flake (`anomalyco/opencode`)
- `opencode-desktop-bin`: first-party binary packaging in this repo

Default aliases are manually controlled in `flake.nix`:

- `opencode`
- `opencode-desktop`

These currently default to `*-bin` variants because upstream build variants are known to be unstable.

## Manual Switching (No Auto-Fallback)

Switching defaults is a manual edit in `flake.nix`:

- `preferOpencodeCliBin = true/false`
- `preferOpencodeDesktopBin = true/false`

If upstream flake builds recover, set the relevant value(s) to `false` to use build variants by default.

## Version and Hash Maintenance

OpenCode binary packaging is pinned and deterministic:

- release version is set by `opencodeVersion` in `flake.nix`
- asset hashes are pinned in `packages/opencode-bin.nix`
- no runtime self-update behavior is used

When bumping versions:

1. Update `inputs.opencode.url` in `flake.nix`.
2. Update `opencodeVersion` in `flake.nix`.
3. Refresh asset hashes in `packages/opencode-bin.nix` from the GitHub release digests.

## Platform Notes

Published binary assets are wired for:

- `aarch64-darwin`
- `x86_64-darwin`
- `aarch64-linux`
- `x86_64-linux`

Maintainer-tested targets are currently:

- `aarch64-darwin`
- `x86_64-darwin`
- `x86_64-linux`

`aarch64-linux` is best-effort unless explicitly validated by maintainers.
