{ pkgs }:
let
  inherit (pkgs) lib;
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "openspec";
  version = "0.11.0";

  src = pkgs.fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xadEQPtlJUcTxFVYDXXa/j6qiH339VXJ4doHaRuEchA=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.pnpm.configHook
    pkgs.makeWrapper
  ];

  pnpmDeps = pkgs.pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-J+Yc9qwS/+t32qqSywJaZwVuqoffeScOgFW6y6YUhIk=";
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

  meta = {
    description = "OpenSpec is a tool for creating and sharing specifications.";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.unix;
    maintainers = [ {
      name = "Thomas Albrighton";
      github = "thattomperson";
      githubId = 1112472;
    } ]; 
  };
})
