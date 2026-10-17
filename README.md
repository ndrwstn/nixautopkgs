# nixautopkgs

This flake provides packages that are not yet in nixpkgs and tracks newer upstream releases.

## OpenCode

OpenCode is packaged from the official prebuilt release artifacts:

- `opencode`: OpenCode CLI
- `opencode-desktop`: OpenCode desktop application

There are no separate V1 packages or source-build routes. Official artifacts are used because
the upstream macOS signatures and desktop notarization cannot be reproduced byte-for-byte in a
local Nix build.

Supported systems:

- `aarch64-darwin`
- `aarch64-linux`
- `x86_64-linux`

## ArtCraft

The ArtCraft cluster packages the open-source Rust applications from the ArtCraft project:

- `photocraft`: raster photo editor
- `vectorcraft`: vector graphics editor
- `filmcraft`: nonlinear video editor
- `lightcraft`: nondestructive photo and RAW editor
- `effectcraft`: motion graphics and compositing tool
- `designcraft`: page layout and publishing editor
- `pdfcraft`: PDF reader and editor
- `deckcraft`: presentation and slide editor
- `gridcraft`: spreadsheet editor
- `cadcraft`: CAD and drafting application
- `soundcraft`: digital audio workstation
- `wordcraft`: word processor
- `figcraft`: interface design and prototyping tool

These packages are built from source for `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.
`x86_64-darwin` is intentionally unsupported. Renovate tracks all 13 upstream GitHub
repositories as one update cluster; the ArtCraft hash-update workflow refreshes Cargo/source hashes
and builds the affected packages before an update can merge.

The applications' code is MIT/Apache-2.0 licensed. Upstream ArtCraft branding is separately
trademarked and is retained only as part of the corresponding unmodified application.

`craft-fonts` is also available as a standalone font package. `craft-libs` is not exposed as a
user-facing package because it is an upstream Rust build dependency rather than an application or
runtime library.

The package is deterministic: `packages/opencode/assets.json` pins the CLI and desktop versions,
URLs, and hashes. A failed fetch or hash mismatch fails loudly.

### Maintenance

`.github/workflows/opencode-update.yml` polls OpenCode's official update API every 30 minutes,
opens an update PR, validates all supported systems, and enables automerge.

Manual update:

```sh
./.github/scripts/check-opencode.sh
```

Checks can be run for an individual system with:

```sh
./.github/scripts/run-opencode-checks.sh aarch64-darwin result.json
```

## OpenCode V2 compatibility

OpenCode V2 uses the same `opencode` command as V1. Existing supported project configuration,
agents, commands, skills, MCP definitions, and `AGENTS.md` files are intended to continue working.
Plugins and integrations using the server API require migration to the V2 APIs. Terminal settings
move from layered `tui.json` files to the global `cli.json` file.
