# nixoverlays

A Nix flake providing up-to-date packages that are often behind in nixpkgs, with automatic version updates via GitHub Actions.

## Available Packages

- **gcs** - GURPS Character Sheet editor (builds from source)
- **opencode** - AI coding agent for the terminal (pre-built binaries)

## Usage

### In your flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixoverlays.url = "github:yourusername/nixoverlays";
  };

  outputs = { self, nixpkgs, nixoverlays, ... }: {
    # Use packages directly
    packages.x86_64-linux.default = nixoverlays.packages.x86_64-linux.gcs;

    # Or add to system packages
    nixosConfigurations.yoursystem = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            nixoverlays.packages.x86_64-linux.gcs
            nixoverlays.packages.x86_64-linux.opencode
          ];
        }
      ];
    };
  };
}
```

### Direct installation

```bash
# Install temporarily
nix shell github:yourusername/nixoverlays#gcs

# Install to profile
nix profile install github:yourusername/nixoverlays#gcs

# Build locally
nix build github:yourusername/nixoverlays#gcs
```

## Automatic Updates

This repository uses [Renovate](https://renovatebot.com/) to automatically monitor upstream releases and create pull requests with updated versions:

- **GCS**: Monitors GitHub releases at `richardwilkes/gcs`
- **OpenCode**: Monitors npm releases for `opencode-ai`

### How it works

1. Renovate continuously monitors upstream repositories for new releases
2. When a new version is detected, a PR is created immediately with updated versions and hashes
3. The PR includes comprehensive release notes and changelogs
4. Renovate can auto-merge PRs that pass all checks (configurable)
5. Failed builds remain open for manual intervention

Configuration is managed through `renovate.json` in the repository root.

## Adding New Packages

To add a new package:

1. Create `packages/yourpackage.nix` following the existing patterns
2. Add the package to `flake.nix` in the `packages` attribute
3. Add regex managers to `renovate.json` for automatic version detection
4. Renovate will automatically detect and update new packages based on the patterns

### Package Template

For GitHub releases:

```nix
{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "yourpackage";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # ... rest of package definition
}
```

For npm packages:

```nix
{ pkgs, system }:

let
  version = "1.0.0";
  # ... architecture and checksum mappings
in

pkgs.stdenv.mkDerivation {
  pname = "yourpackage";
  inherit version;

  # ... rest of package definition
}
```

## Development

```bash
# Test builds locally
nix build .#gcs
nix build .#opencode

# Enter development shell
nix develop
```
