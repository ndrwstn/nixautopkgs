# nixautopkgs

This flake provides packages that are not yet in nixpkgs and tracks newer upstream releases.

## CleverSwitch

`cleverswitch` synchronizes host switching between Logitech keyboards and mice. It is packaged
from source for Apple Silicon Darwin (`aarch64-darwin`) and Linux (`aarch64-linux` and
`x86_64-linux`). Linux users can install the packaged udev rule from
`$out/share/cleverswitch/udev/42-cleverswitch.rules` to grant non-root HID access.

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
`x86_64-darwin` is intentionally unsupported. Renovate tracks the seven upstream GitHub
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

## ConstructCraft

`constructcraft` packages ConstructCraft, an open-source BIM authoring application written in
Rust by Francis Rebouças. It is unrelated to the ArtCraft project:

- `constructcraft`: desktop BIM authoring application
- `ccad`: command-line and MCP server, with Lua scripting and visual graphs

The package is built from source for `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.
It is GPL-3.0-or-later. Icons, fonts, and translations are compiled into the binary; the package
also installs the Linux desktop entry, MIME type, and icons, and a macOS `.app` bundle.

Renovate tracks `francisreboucas/constructcraft`. A dedicated workflow refreshes the pinned
`Cargo.lock` and source hash before an update can merge.

## SolidCraft

`solidcraft` packages SolidCraft (formerly SolveCraft), an open-source parametric 3D CAD
application and clean-room Fusion 360 counterpart written in Rust:

- `solidcraft`: desktop application
- `solidcraft-cli`: headless CLI and MCP server
- `solvecraft-cli`: deprecated compatibility alias for `solidcraft-cli`

The package is built from source for `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.
The code is MIT OR Apache-2.0; upstream branding and interface assets have their own terms.
Linux gets the desktop entry, MIME type, icons and AppStream metadata; macOS gets a
`SolidCraft.app` bundle with the CLI inside.

This package tracks the newest stable **or release-candidate** release. Upstream is
stabilizing a new geometry kernel and writes a newer design format in the 0.40 series, so
designs saved by it do not open in 0.30.1. Nightly builds are ignored. The source tree is
large (about 640 MB), so the checks workflow builds it on all three systems before an update
can merge.

## OpenCode V2 compatibility

OpenCode V2 uses the same `opencode` command as V1. Existing supported project configuration,
agents, commands, skills, MCP definitions, and `AGENTS.md` files are intended to continue working.
Plugins and integrations using the server API require migration to the V2 APIs. Terminal settings
move from layered `tui.json` files to the global `cli.json` file.
