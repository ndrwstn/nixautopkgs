{ pkgs }:
let
  inherit (pkgs) lib;
  nix-update-script = pkgs.nix-update-script;
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "openspec";
  version = "0.23.0";

  src = pkgs.fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BhbKhcJgM1WlePx9P6/9owZLosFmjL36cgKkZiBIqQM=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.pnpm.configHook
    pkgs.makeWrapper
  ];

  pnpmDeps = pkgs.pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-k6SkpPk16csxJmj1Zct4wl6QnOYs5K47ecKXgW+PPAY=";
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
