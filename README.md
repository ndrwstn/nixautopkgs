# nixautopkgs

A Nix flake providing up-to-date packages that are often behind in nixpkgs.

<!-- DASHBOARD:START -->
## Packages

| package | release | nixautopkgs | unstable | x86_64<br>linux | aarch64<br>linux | x86_64<br>darwin | aarch64<br>darwin |
|---------|:-------:|:-----------:|:--------:|:---------------:|:-----------------:|:-----------------:|:-----------------:|
| [gcs](./packages/gcs.nix) | [v5.38.1](https://github.com/richardwilkes/gcs/releases/tag/v5.38.1) | [v5.38.1](https://github.com/ndrwstn/nixautopkgs/pull/20) | [v5.28.1](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/gc/gcs/package.nix) | ✓ | — | ✓ | ✓ |
| [opencode](./packages/opencode.nix) | [v0.7.1](https://github.com/sst/opencode/releases/tag/v0.7.1) | [v0.7.0](https://github.com/ndrwstn/nixautopkgs/pull/38) | [v0.3.112](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/op/opencode/package.nix) | ✓ | ✗ | ✓ | ✓ |

*Last updated: 09/10/2025 01:56 PM EDT*
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
