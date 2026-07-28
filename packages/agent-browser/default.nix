{ lib
, chromium
, fetchFromGitHub
, fetchPnpmDeps
, geist-font
, makeBinaryWrapper
, nodejs_22
, pnpmConfigHook
, pnpm_11
, rustPlatform
, stdenv
}:

let
  pname = "agent-browser";
  version = "0.33.1";
  hash = "sha256-praWvAgWoDmWqXzh/kxdfQAPGkVS4qkb0pPYtMWO/N8=";
  cargoHash = "sha256-j2tkoO334dtl22ykqBz5A0RTLrefyREAiXFKqTXEsgM=";
  pnpmDepsHash = "sha256-uY+Zm/LtNn3+qf4B/p3/nzn5Emj6C7+S8X4q8wr+Ow0=";

  pnpm = pnpm_11.override {
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

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = pnpmDepsHash;
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs_22
    pnpm
    pnpmConfigHook
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
