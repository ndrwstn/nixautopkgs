{
  description = "Nix flake for up-to-date packages not yet in nixpkgs";

  inputs = {
    # NOTE: nixpkgs-unstable required for packages to build
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

          devShells = {
            default = pkgs.mkShell {
              name = "nixautopkgs-dev";

              buildInputs = with pkgs; [
                # Language toolchains
                go
                bun

                # Version control
                git

                # Nix tools
                nix-prefetch-git
                nix-prefetch-github

                # Utilities
                jq
                curl
                gnused
                diffutils
                coreutils

                # Optional: Additional development tools
                ripgrep # Better grep for searching
                fd # Better find for file discovery
              ];

              shellHook = ''
                echo "╔══════════════════════════════════════════════════════════╗"
                echo "║          nixautopkgs development shell loaded           ║"
                echo "╚══════════════════════════════════════════════════════════╝"
                echo ""
                echo "📦 Package Commands:"
                echo "  ./bin/update-gcs       - Update GCS package hashes"
                echo "  ./bin/update-opencode  - Update OpenCode package hashes"
                echo "  nix build .#gcs        - Build GCS package"
                echo "  nix build .#opencode   - Build OpenCode package"
                echo ""
                echo "🛠️  Available Tools:"
                echo "  • go $(go version | cut -d' ' -f3) - Go programming language"
                echo "  • bun - JavaScript runtime & package manager"
                echo "  • git - Version control"
                echo "  • jq - JSON processor"
                echo "  • nix-prefetch-* - Nix fetching tools"
                echo ""
                echo "💡 Tips:"
                echo "  • Run update scripts after Renovate updates versions"
                echo "  • Use 'nix flake check' to validate the flake"
                echo "  • Use 'nix flake show' to see all outputs"
              '';
            };
          };
        };
    };
}
