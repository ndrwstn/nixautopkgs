{ lib
, chromium
, fetchFromGitHub
, geist-font
, makeBinaryWrapper
, nodejs_22
, pnpm_10
, rustPlatform
, stdenv
}:

let
  pname = "agent-browser";
  version = "0.26.0";
  hash = "sha256-q3UcFTB8OMOrfx5xcNPtBBAwOxoscwrjGg+y8tdETm0=";
  cargoHash = "sha256-ENIGFhZ+pXIZvEFUA0No3HpeHtxgJohMgx6F0wNpmO0=";
  pnpmDepsHash = "sha256-p9xpkR15JRq3zzx0GtICpETqRWLyHT7RTgkQ0Y9qWsY=";

  pnpm = pnpm_10.override {
    nodejs = nodejs_22;
  };

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${version}";
    inherit hash;
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src cargoHash;
  sourceRoot = "source/cli";
  pnpmRoot = "..";

  pnpmDeps = pnpm.fetchDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 2;
    hash = pnpmDepsHash;
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs_22
    pnpm
    pnpm.configHook
  ];
  buildInputs = lib.optional stdenv.isLinux chromium;

  pnpmInstallFlags = [ "--ignore-scripts" ];

  env = {
    NEXT_TELEMETRY_DISABLED = 1;
  };

  postUnpack = ''
    chmod -R u+w source

    # Replace Google Fonts fetch with a local font from nixpkgs since
    # the Nix sandbox has no network access.
    substituteInPlace source/packages/dashboard/src/app/layout.tsx \
      --replace-fail '{ Geist } from "next/font/google"' \
      'localFont from "next/font/local"'

    substituteInPlace source/packages/dashboard/src/app/layout.tsx \
      --replace-fail 'const geist = Geist({ subsets: ["latin"], variable: "--font-sans" });' \
      'const geist = localFont({ src: "./Geist-Regular.otf", variable: "--font-sans" });'

    cp "${geist-font}/share/fonts/opentype/Geist-Regular.otf" \
      source/packages/dashboard/src/app/Geist-Regular.otf
  '';

  preBuild = ''
    pnpm --dir .. --filter dashboard build
  '';

  # Tests require runtime environment (XDG_RUNTIME_DIR, writable HOME, etc.)
  # that isn't available in the Nix sandbox. Skip tests during build.
  doCheck = false;

  postInstall = ''
    repo_root="$(realpath ..)"

    mkdir -p $out/share/agent-browser
    cp -r "$repo_root/bin" "$repo_root/scripts" $out/share/agent-browser/

    if [ -d "$repo_root/skill-data" ]; then
      cp -r "$repo_root/skill-data" $out/share/agent-browser/
    fi

    mkdir -p $out/share/agent-browser/node_modules

    mkdir -p $out/etc/agent-browser
    cp -r "$repo_root/skills" $out/etc/agent-browser/

    mv $out/bin/agent-browser $out/bin/.agent-browser-unwrapped
    makeWrapper $out/bin/.agent-browser-unwrapped $out/bin/agent-browser \
      --prefix PATH : ${lib.makeBinPath [ nodejs_22 ]} \
      ${lib.optionalString stdenv.isLinux "--set AGENT_BROWSER_EXECUTABLE_PATH ${chromium}/bin/chromium"}
  '';

  passthru.category = "Utilities";

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "agent-browser";
  };
}
