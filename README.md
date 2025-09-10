# nixautopkgs

A Nix flake providing up-to-date packages that are often behind in nixpkgs.

<!-- DASHBOARD:START -->
## 📦 Package Status
*Last updated: 2025-09-10 16:03 UTC • [↻ Update](https://github.com/ndrwstn/nixautopkgs/actions/workflows/update-dashboard.yml)*

| Package | Latest Release | Our Version | Nixpkgs Unstable |
|---------|---------------|-------------|------------------|
| [gcs](./packages/gcs.nix) | [v5.38.1](https://github.com/richardwilkes/gcs/releases/tag/v5.38.1) | [v5.38.1](https://github.com/ndrwstn/nixautopkgs/pull/20) | [v5.28.1](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/gc/gcs/package.nix) |
| [opencode](./packages/opencode.nix) | [v0.7.1](https://github.com/sst/opencode/releases/tag/v0.7.1) | [v0.7.0](https://github.com/ndrwstn/nixautopkgs/pull/38) | [v0.3.112](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/op/opencode/package.nix) |

### Platform Support

| Package | x86_64-linux | aarch64-linux | x86_64-darwin | aarch64-darwin |
|---------|-------------|---------------|---------------|----------------|
| gcs | ✓ | — | ✓ | ✓ |
| opencode | ✓ | ✗ | ✓ | ✓ |

*Legend: ✓ Built successfully • ✗ Build failed • — Not supported • ? Unknown*
<!-- DASHBOARD:END -->
## Usage

Add this flake to your system configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixautopkgs.url = "github:ndrwstn/nixautopkgs";
  };

  outputs = { self, nixpkgs, nixautopkgs, ... }: {
    environment.systemPackages = [
      nixautopkgs.gcs
      nixautopkgs.opencode
    ];
  };
}
```

## Automatic Updates

Work in progress, packages are planned to be automatically updated via Renovate and GitHub Actions when a new upstream release is detected.
