{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchNpmDeps
, chromium
, makeBinaryWrapper
, nodejs-slim
, rustPlatform
, stdenv
}:

let
  version = "0.25.1";
  hash = "sha256-/f2u/GywKEPo/rH7Yow3f6Cn6154Qf9MbIzZhWa7x0E=";
  cargoHash = "sha256-FotzoypumLksSqcdslvl+xJ5oojI4x77S9wcsiZXBCs=";
  npmDepsHash = "sha256-uCI6dz7wkAcGkbU0nSYcn8q3f1E3ocEj1ACAOi3g5q4=";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${version}";
    inherit hash;
  };

  agent-browser-native-binary = rustPlatform.buildRustPackage {
    pname = "agent-browser-native-binary";
    inherit version src cargoHash;
    sourceRoot = "source/cli";

    # Tests require runtime environment (XDG_RUNTIME_DIR, writable HOME, etc.)
    # that isn't available in the Nix sandbox. Skip tests during build.
    doCheck = false;

    meta = {
      description = "Native Rust CLI for agent-browser";
      license = lib.licenses.asl20;
      platforms = lib.platforms.unix;
    };
  };
in
buildNpmPackage {
  pname = "agent-browser";
  inherit version src;

  # v0.23.0+ doesn't have a build script - package is just a wrapper
  dontNpmBuild = true;

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = npmDepsHash;
    forceEmptyCache = true; # Handle versions with no npm dependencies
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';
  };
  makeCacheWritable = true;

  nativeBuildInputs = [ makeBinaryWrapper ];
  buildInputs = [ agent-browser-native-binary ] ++ lib.optional stdenv.isLinux chromium;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/agent-browser
    cp -r bin scripts $out/share/agent-browser/
    # node_modules may not exist if there are no npm dependencies
    if [ -d node_modules ]; then
      cp -r node_modules $out/share/agent-browser/
    else
      mkdir -p $out/share/agent-browser/node_modules
    fi

    mkdir -p $out/etc/agent-browser
    cp -r skills $out/etc/agent-browser/

    mkdir -p $out/bin
    cp ${agent-browser-native-binary}/bin/agent-browser $out/bin/.agent-browser-unwrapped

    # Only create symlink if node_modules exists (may be empty for versions with no deps)
    if [ -d $out/share/agent-browser/node_modules ]; then
      ln -s $out/share/agent-browser/node_modules $out/node_modules
    fi

    makeWrapper $out/bin/.agent-browser-unwrapped $out/bin/agent-browser \
      --prefix PATH : ${lib.makeBinPath [ nodejs-slim ]} \
      ${lib.optionalString stdenv.isLinux "--set AGENT_BROWSER_EXECUTABLE_PATH ${chromium}/bin/chromium"}

    runHook postInstall
  '';

  doInstallCheck = false;

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
