# nixoverlays

A Nix flake providing up-to-date packages that are often behind in nixpkgs.

## Usage

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixoverlays.url = "github:ndrwstn/nixoverlays";
  };

  outputs = { self, nixpkgs, nixoverlays, ... }: {
    environment.systemPackages = [
      nixoverlays.packages.x86_64-linux.gcs
      nixoverlays.packages.x86_64-linux.opencode
    ];
  };
}
```

## Automatic Updates

Package versions are automatically updated via Renovate when new upstream releases are detected.
