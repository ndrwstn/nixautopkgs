# nixautopkgs

A Nix flake providing up-to-date packages that are identified and auto-built based upon GitHub releases
and Renovate. Use at your own risk, packages are not verified except by building for supported architecture.

<!-- DASHBOARD:START -->
## Packages

| package | release | nixautopkgs | unstable | x86_64<br>linux | aarch64<br>linux | x86_64<br>darwin | aarch64<br>darwin |
|---------|:-------:|:-----------:|:--------:|:---------------:|:-----------------:|:-----------------:|:-----------------:|
| [gcs](./packages/gcs.nix) | [v5.40.2](https://github.com/richardwilkes/gcs/releases/tag/v5.40.2) | [v5.40.2](https://github.com/ndrwstn/nixautopkgs/pull/73) | [v5.39.0](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/gc/gcs/package.nix) | ✓ | — | ✓ | ✓ |
| [opencode](./packages/opencode.nix) | [v0.14.1](https://github.com/sst/opencode/releases/tag/v0.14.1) | [v0.14.1](https://github.com/ndrwstn/nixautopkgs/pull/74) | [v0.13.5](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/op/opencode/package.nix) | ✓ | — | ✓ | ✓ |

*Last updated: 10/04/2025 06:18 AM EDT*
<!-- DASHBOARD:END -->## Usage

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
