{
  description = "Nix flake for up-to-date packages not yet in nixpkgs";

  inputs = {
    # NOTE: nixpkgs-unstable required for packages to build
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    opencode.url = "github:anomalyco/opencode/v1.2.15";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    let
      opencodeAssets = builtins.fromJSON (builtins.readFile ./packages/opencode-assets.json);
      opencodeRouting = builtins.fromJSON (builtins.readFile ./packages/opencode-routing.json);
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];

      perSystem = { pkgs, system, ... }:
        let
          # Import package definitions
          gcs = import ./packages/gcs.nix { inherit pkgs; };
          opencodeBin = import ./packages/opencode-bin.nix {
            inherit pkgs system;
            inherit opencodeAssets;
          };

          routeForSystem = opencodeRouting.${system}
            or (throw "opencode routing: unsupported system ${system}");

          opencodeCliBuild = inputs.opencode.packages.${system}.default;
          opencodeDesktopBuild = inputs.opencode.packages.${system}.desktop;

          opencodeCliBin = opencodeBin."opencode-cli-bin";
          opencodeDesktopBin = opencodeBin."opencode-desktop-bin";

          resolveOpencodeRoute = target: buildPackage: binPackage:
            let
              route = routeForSystem.${target}
                or (throw "opencode routing: missing `${target}` route for ${system}");
            in
            if route == "build" then buildPackage
            else if route == "bin" then binPackage
            else throw "opencode routing: invalid route `${route}` for ${system}.${target}";

          gcs-linux = gcs.overrideAttrs (oldAttrs: {
            # Ensure Linux desktop integration is enabled
            postInstall = oldAttrs.postInstall or "" + ''
              echo "Linux desktop integration enabled"
            '';
          });
        in
        {
          packages = {
            inherit gcs gcs-linux;
            opencode-cli-build = opencodeCliBuild;
            opencode-desktop-build = opencodeDesktopBuild;
            opencode-cli-bin = opencodeCliBin;
            opencode-desktop-bin = opencodeDesktopBin;

            opencode = resolveOpencodeRoute "cli" opencodeCliBuild opencodeCliBin;
            opencode-desktop = resolveOpencodeRoute "desktop" opencodeDesktopBuild opencodeDesktopBin;
            default = gcs; # Default to gcs for now
          };

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
