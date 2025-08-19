{
  description = "Nix flake for up-to-date packages not yet in nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];

      perSystem = { pkgs, system, ... }:
        let
          # Import package definitions
          gcs = import ./packages/gcs.nix { inherit pkgs; };
          opencode = import ./packages/opencode.nix { inherit pkgs system; };
        in
        {
          packages = {
            inherit gcs opencode;
            default = gcs; # Default to gcs for now
          };

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nix-prefetch-git
              curl
              jq
            ];
          };
        };
    };
}
