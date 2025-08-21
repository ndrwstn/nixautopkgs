# nixautopkgs

A Nix flake providing up-to-date packages that are often behind in nixpkgs.

## Usage

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

Package versions are automatically updated via Renovate when new upstream releases are detected.
