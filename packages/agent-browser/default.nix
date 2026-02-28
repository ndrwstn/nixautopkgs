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
  version = "0.15.1";
  hash = "sha256-oDgnxQ09e1IUd1kfgr75TNiYOf5VpMXG9DjfGG4OGwA=";
  cargoHash = "sha256-94w9V+NZiWeQ3WbQnsKxVxlvsCaOJR0Wm6XVc85Lo88=";
  npmDepsHash = "sha256-knZbN+XILd6mB2Hjh1Z0twwwHiqoMNoKHeY4T4Y6qDA=";

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

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = npmDepsHash;
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

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/agent-browser
    cp -r dist node_modules scripts $out/share/agent-browser/

    mkdir -p $out/etc/agent-browser
    cp -r skills $out/etc/agent-browser/

    mkdir -p $out/bin
    cp ${agent-browser-native-binary}/bin/agent-browser $out/bin/.agent-browser-unwrapped

    ln -s $out/share/agent-browser/dist $out/dist
    ln -s $out/share/agent-browser/node_modules $out/node_modules

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
