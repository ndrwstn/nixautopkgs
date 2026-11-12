{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, makeWrapper
, wayland
, wayland-scanner
, libxkbcommon
, libX11
, libxcb
, libXcursor
, libXi
, libXrandr
, vulkan-loader
, libGL
, desktop-file-utils
, libicns
, nix-update-script
}:

let
  isLinux = stdenv.hostPlatform.isLinux;
  runtimeLibs = lib.optionals isLinux [
    libxkbcommon
    wayland
    libX11
    libxcb
    libXcursor
    libXi
    libXrandr
    vulkan-loader
    libGL
  ];
in
rustPlatform.buildRustPackage rec {
  pname = "constructcraft";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "francisreboucas";
    repo = "constructcraft";
    rev = "v${version}";
    hash = "sha256-JIPioQmV3vQquBBrPzfnHtTIZe/X3nXixDF8cryVIIw=";
  };

  # Keep the lock file as a repository input rather than interpolating it from
  # the fetcher output. The latter can produce an un-realized .drv path while
  # evaluating foreign-system flake outputs.
  cargoLock.lockFile = ./locks/constructcraft.Cargo.lock;

  cargoBuildFlags = [ "--locked" "-p" "cc_app" "-p" "cc_cli" ];

  doCheck = false;
  strictDeps = true;

  nativeBuildInputs = [ pkg-config ]
    ++ lib.optionals isLinux [
    makeWrapper
    wayland-scanner
    desktop-file-utils
  ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ libicns ];

  buildInputs = lib.optionals isLinux [
    wayland
    libxkbcommon
    libX11
    libxcb
    libXcursor
    libXi
    libXrandr
  ];

  installPhase = ''
    runHook preInstall
    for binary in constructcraft ccad; do
      path="$(find target -type f -path "*/release/$binary" -perm -0100 -print -quit)"
      if [ -z "$path" ]; then
        echo "missing built binary: $binary" >&2
        exit 1
      fi
      install -Dm755 "$path" "$out/bin/$binary"
    done
    runHook postInstall
  '';

  postInstall = lib.optionalString isLinux ''
    install -Dm644 packaging/linux/constructcraft.desktop \
      $out/share/applications/constructcraft.desktop
    install -Dm644 packaging/linux/constructcraft.xml \
      $out/share/mime/packages/constructcraft.xml
    install -Dm644 assets/icons/app-icon-256.png \
      $out/share/icons/hicolor/256x256/apps/constructcraft.png
    install -Dm644 assets/icons/app-icon.png \
      $out/share/icons/hicolor/512x512/apps/constructcraft.png
    install -d $out/share/doc/constructcraft/examples
    install -Dm644 -t $out/share/doc/constructcraft \
      README.md README.pt-BR.md CHANGELOG.md LICENSE
    install -Dm644 examples/casa_simples.ccad \
      $out/share/doc/constructcraft/examples/casa_simples.ccad

    desktop-file-validate $out/share/applications/constructcraft.desktop

    for binary in constructcraft ccad; do
      wrapProgram "$out/bin/$binary" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"
    done
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    app="$out/Applications/ConstructCraft.app"
    install -Dm755 "$out/bin/constructcraft" "$app/Contents/MacOS/constructcraft"
    substitute packaging/macos/Info.plist.in "$app/Contents/Info.plist" \
      --replace-fail "@VERSION@" "${version}"
    printf 'APPL????' > "$app/Contents/PkgInfo"
    install -d "$app/Contents/Resources"
    ${libicns}/bin/png2icns "$app/Contents/Resources/ConstructCraft.icns" \
      assets/icons/app-icon.png
  '';

  passthru = {
    inherit runtimeLibs;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Open-source BIM authoring application written in Rust";
    homepage = "https://francisreboucas.github.io/constructcraft";
    changelog = "https://github.com/francisreboucas/constructcraft/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "constructcraft";
    platforms = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    nixautopkgs.upstream = "francisreboucas/constructcraft";
  };
}
