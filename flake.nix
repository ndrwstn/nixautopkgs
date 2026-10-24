{
  description = "Nix flake for up-to-date packages not yet in nixpkgs";

  inputs = {
    # NOTE: nixpkgs-unstable required for packages to build
    # Pinned to October 13, 2026 (e6da1f9db6d0c209655096bf772569219022cbf8) - provides Go 1.27.2 and pnpm_11
    # renovate: datasource=git-refs depName=NixOS/nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/901c54c08bdc20e00c2b3c73716b97497b1b3c74";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];

      perSystem = { pkgs, system, ... }:
        let
          # Import package definitions
          gcs = import ./packages/gcs/default.nix { inherit pkgs; };
          agent-browser = pkgs.callPackage ./packages/agent-browser/default.nix { };
          clamav = pkgs.callPackage ./packages/clamav/default.nix { };
          mlx = pkgs.python313Packages.callPackage ./packages/mlx/default.nix { };
          mlx-lm = pkgs.python313Packages.callPackage ./packages/mlx-lm/default.nix {
            inherit mlx;
          };
          ocrit = pkgs.callPackage ./packages/ocrit/default.nix { };
          television = pkgs.callPackage ./packages/television/default.nix { };
          mekhq = pkgs.callPackage ./packages/mekhq/default.nix { };
          # OpenCode stable - official binaries only
          opencodePackages = import ./packages/opencode/default.nix {
            inherit pkgs system;
          };
          artcraftPackages = import ./packages/artcraft/default.nix { inherit pkgs; };
          craft-fonts = pkgs.callPackage ./packages/artcraft/fonts.nix { };

          gcs-linux = gcs.overrideAttrs (oldAttrs: {
            # Ensure Linux desktop integration is enabled
            postInstall = oldAttrs.postInstall or "" + ''
              echo "Linux desktop integration enabled"
            '';
          });
        in
        {
          packages = {
            inherit agent-browser clamav television mekhq;
          }
          // pkgs.lib.optionalAttrs (system != "aarch64-linux") {
            inherit gcs gcs-linux;
          }
          // pkgs.lib.optionalAttrs (system == "aarch64-darwin") {
            inherit mlx mlx-lm ocrit;
          }
          // artcraftPackages
          // { inherit craft-fonts; }
          // opencodePackages;

          devShells = {
            default = pkgs.mkShell {
              name = "nixautopkgs-dev";

              packages = with pkgs; [
                # Language toolchains
                go
                bun

                # Version control
                git

                # Nix tools
                nix-prefetch-git
                nix-prefetch-github
                nix-update

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
                 echo "  nix-update gcs         - Update GCS package hashes"
                 echo "  nix build .#gcs        - Build GCS package"
                echo ""
                echo "🛠️  Available Tools:"
                echo "  • go $(go version | cut -d' ' -f3) - Go programming language"
                echo "  • bun - JavaScript runtime & package manager"
                echo "  • git - Version control"
                echo "  • jq - JSON processor"
                echo "  • nix-prefetch-* - Nix fetching tools"
                echo ""
                echo "💡 Tips:"
                echo "  • Hash updates are automatic via nix-update when Renovate updates versions"
                echo "  • Use 'nix flake check' to validate the flake"
                echo "  • Use 'nix flake show' to see all outputs"
              '';
            };
          };
        };
    };
}
