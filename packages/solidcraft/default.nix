{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, makeWrapper
, wayland
, wayland-scanner
, libxkbcommon
, libglvnd
, vulkan-loader
, dbus
, libx11
, libxcursor
, libxi
, libxrandr
, libxrender
, libxext
, libxcb
, zenity
, desktop-file-utils
, appstream
, nix-update-script
}:

let
  version = "0.41.0";
  shortVersion = lib.head (lib.splitString "-" version);
  isLinux = stdenv.hostPlatform.isLinux;
  runtimeLibs = lib.optionals isLinux [
    wayland
    libxkbcommon
    libglvnd
    vulkan-loader
    dbus
    libx11
    libxcursor
    libxi
    libxrandr
    libxrender
    libxext
    libxcb
  ];
  libraryPath = "${lib.makeLibraryPath runtimeLibs}:/run/opengl-driver/lib";
in
rustPlatform.buildRustPackage {
  pname = "solidcraft";
  inherit version;

  src = fetchFromGitHub {
    owner = "tangency-labs";
    repo = "solidcraft";
    rev = "v${version}";
    hash = "sha256-YmvDHy3qTnA8iRtppJ/iDLjyKynnmjKwIYO+c4VdMes=";
  };

  # Keep the lock file as a repository input rather than interpolating it from
  # the fetcher output. The latter can produce an un-realized .drv path while
  # evaluating foreign-system flake outputs.
  cargoLock.lockFile = ./locks/solidcraft.Cargo.lock;

  cargoBuildFlags = [ "--locked" "-p" "solidcraft" "-p" "solidcraft-cli" ];

  doCheck = false;
  strictDeps = true;

  nativeBuildInputs = [ pkg-config ]
    ++ lib.optionals isLinux [ makeWrapper wayland-scanner desktop-file-utils appstream ];
  buildInputs = runtimeLibs;

  postInstall = lib.optionalString isLinux ''
    install -Dm644 assets/platforms/linux/io.tangencylabs.solidcraft.desktop \
      $out/share/applications/io.tangencylabs.solidcraft.desktop
    install -Dm644 assets/platforms/linux/io.tangencylabs.solidcraft.mime.xml \
      $out/share/mime/packages/io.tangencylabs.solidcraft.xml
    install -d $out/share/metainfo
    substitute assets/platforms/linux/io.tangencylabs.solidcraft.metainfo.xml.in \
      $out/share/metainfo/io.tangencylabs.solidcraft.metainfo.xml \
      --replace-fail "@VERSION@" "${version}" \
      --replace-fail "@DATE@" "1970-01-01"
    for size in 16 24 32 48 64 128 256 512; do
      install -Dm644 "assets/icons/app/linux/exports/hicolor/''${size}x''${size}/apps/io.tangencylabs.solidcraft.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/io.tangencylabs.solidcraft.png"
    done
    install -d $out/share/doc/solidcraft
    docs=(README.md LICENSE-MIT LICENSE-APACHE NOTICE DISCLAIMER.md THIRD-PARTY-LICENSES.txt)
    if [ -f LICENSE-BRAND ]; then docs+=(LICENSE-BRAND); fi
    install -Dm644 -t $out/share/doc/solidcraft "''${docs[@]}"
    desktop-file-validate $out/share/applications/io.tangencylabs.solidcraft.desktop
    appstreamcli validate --no-net $out/share/metainfo/io.tangencylabs.solidcraft.metainfo.xml
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    app="$out/Applications/SolidCraft.app"
    install -Dm755 "$out/bin/solidcraft" "$app/Contents/MacOS/SolidCraft"
    install -Dm755 "$out/bin/solidcraft-cli" "$app/Contents/MacOS/solidcraft-cli"
    install -Dm644 assets/icons/app/macos/exports/icon.icns \
      "$app/Contents/Resources/SolidCraft.icns"
    install -Dm644 assets/icons/app/macos/exports/Assets.car \
      "$app/Contents/Resources/Assets.car"
    install -d "$app/Contents/Resources/Licenses"
    docs=(README.md LICENSE-MIT LICENSE-APACHE NOTICE THIRD-PARTY-LICENSES.txt)
    if [ -f LICENSE-BRAND ]; then docs+=(LICENSE-BRAND); fi
    install -Dm644 -t "$app/Contents/Resources/Licenses" "''${docs[@]}"
    substitute assets/platforms/macos/Info.plist.in "$app/Contents/Info.plist" \
      --replace-fail "@VERSION@" "${version}" \
      --replace-fail "@SHORT_VERSION@" "${shortVersion}"
    printf 'APPL????' > "$app/Contents/PkgInfo"
  '';

  postFixup = lib.optionalString isLinux ''
    wrapProgram $out/bin/solidcraft \
      --prefix LD_LIBRARY_PATH : "${libraryPath}" \
      --suffix PATH : "${lib.makeBinPath [ zenity ]}" \
      --set-default XDG_DATA_DIRS /usr/local/share:/usr/share \
      --prefix XDG_DATA_DIRS : "$out/share:/run/opengl-driver/share"
  '';

  passthru = {
    inherit runtimeLibs;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Open-source parametric 3D CAD application written in Rust";
    homepage = "https://solidcraft.io";
    changelog = "https://github.com/tangency-labs/solidcraft/releases/tag/v${version}";
    license = with lib.licenses; [ mit asl20 ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "solidcraft";
    platforms = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    nixautopkgs.upstream = "tangency-labs/solidcraft";
  };
}
