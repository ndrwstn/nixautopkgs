{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, callPackage
, installShellFiles
, writableTmpDirAsHomeHook
, nix-update-script
, testers
, targetPackages
, extraPackages ? null
}:

assert
(extraPackages == null)
  || lib.warn "Overriding television with the 'extraPackages' attribute is deprecated. Please use `television.withPackages (p: [ p.fd ...])` instead.";

let
  television = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "television";
    version = "0.15.9";

    __structuredAttrs = true;

    src = fetchFromGitHub {
      owner = "alexpasmantier";
      repo = "television";
      rev = finalAttrs.version;
      hash = "sha256-JrQUFlhAAaB+VGP184I44hSsIyfCaTMNXxyPp0E5GM0=";
    };

    cargoHash = "sha256-eD+NQYY9QnCBZ+SiOCQbcLZ2p3uX0u/nEnft2f6NfU0=";

    nativeBuildInputs = [
      installShellFiles
      writableTmpDirAsHomeHook
    ];

    # TODO: Investigate selectively disabling or fixing upstream tests.
    # Matches the current nixpkgs package: tests need runtime HOME/TUI state.
    doCheck = false;

    postInstall = ''
      installManPage target/${stdenv.hostPlatform.rust.cargoShortTarget}/assets/tv.1
    ''
    + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      mkdir -p $out/share/television
      for shell in bash zsh fish; do
        "$out/bin/tv" init $shell > completion.$shell

        # Split shell completion and shell integration.
        awk -v C=completion_pure.$shell -v D=$out/share/television/completion.$shell '
          NR==FNR { key=$0; nextfile }
          {
            if (!found && index($0, key)) found=1
            print > (found ? D : C)
          }
        ' television/utils/shell/completion.$shell completion.$shell

        installShellCompletion --cmd tv completion_pure.$shell
      done

      # Nushell does not contain regular completion for now.
      "$out/bin/tv" init nu > $out/share/television/completion.nu
    '';

    passthru = {
      updateScript = nix-update-script { };

      withPackages = f:
        callPackage ./wrapper.nix {
          television = finalAttrs.finalPackage;
          extraPackages = f targetPackages;
        };

      tests = {
        version = testers.testVersion {
          package = finalAttrs.finalPackage;
          command = "XDG_DATA_HOME=$TMPDIR tv --version";
        };
        wrapper = testers.testVersion {
          package = finalAttrs.finalPackage.withPackages (pkgs: [
            pkgs.fd
            pkgs.git
          ]);
          command = "XDG_DATA_HOME=$TMPDIR tv --version";
        };
      };
    };

    meta = {
      description = "Blazingly fast general purpose fuzzy finder TUI";
      longDescription = ''
        Television is a fast and versatile fuzzy finder TUI.
        It lets you quickly search through any kind of data source (files, git
        repositories, environment variables, docker images, you name it) using a
        fuzzy matching algorithm and is designed to be easily extensible.
      '';
      homepage = "https://github.com/alexpasmantier/television";
      changelog = "https://github.com/alexpasmantier/television/releases/tag/${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "tv";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
      nixautopkgs = {
        upstream = "alexpasmantier/television";
        nixpkgsPath = "pkgs/by-name/te/television/package.nix";
      };
    };
  });
in
if extraPackages == null then television else television.withPackages (lib.const extraPackages)
