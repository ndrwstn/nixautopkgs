{ pkgs }:
let
  inherit (pkgs) lib;
  nix-update-script = pkgs.nix-update-script;
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "openspec";
  version = "1.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DIMMOEVQ2FQj48WAF4S1IhxX5ChrFZll51CZ3bZNGHE=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.pnpm
    (if pkgs ? pnpmConfigHook then pkgs.pnpmConfigHook else pkgs.pnpm.configHook)
    pkgs.makeWrapper
  ];

  pnpmDeps = (if pkgs ? fetchPnpmDeps then pkgs.fetchPnpmDeps else pkgs.pnpm.fetchDeps) {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-Tj2vGOTm1Uk1iQUu1NRbMf2S02TUm/bs7Gj1l/TIGXY=";
  };

  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/openspec"
    cp -r --parents \
      node_modules/ \
      package.json \
      dist \
      bin \
      "$out/lib/openspec"

    makeWrapper "${lib.getExe pkgs.nodejs}" "$out/bin/openspec" \
      --add-flags "$out/lib/openspec/bin/openspec.js"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "OpenSpec is a tool for creating and sharing specifications.";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "openspec";
    nixautopkgs = {
      upstream = "Fission-AI/OpenSpec";
      nixpkgsPath = "pkgs/by-name/op/openspec/package.nix";
    };
  };
})
