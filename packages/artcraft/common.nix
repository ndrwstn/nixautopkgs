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
, alsa-lib
, vulkan-loader
, desktop-file-utils
, appstream
, autoAddDriverRunpath ? null
, nix-update-script
}:

{ pname
, displayName
, version
, description
, appId ? "ai.storyteller.${pname}"
, binaries ? [ pname "${pname}-cli" ]
, sourceHash
, outputHashes ? { }
, postPatch ? ""
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
  ];
in
rustPlatform.buildRustPackage rec {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "storytold";
    repo = pname;
    rev = "v${version}";
    hash = sourceHash;
  };

  cargoLock = {
    # Keep the lock file as a repository input rather than interpolating it from
    # the fetcher output. The latter can produce an un-realized .drv path while
    # evaluating foreign-system flake outputs.
    lockFile = ./locks/${pname}.Cargo.lock;
    inherit outputHashes;
  };
  cargoBuildFlags = [
    "--locked"
  ] ++ lib.concatMap (binary: [ "-p" binary ]) binaries;

  installPhase = ''
    runHook preInstall
    for binary in ${lib.concatStringsSep " " binaries}; do
      path="$(find target -type f -path "*/release/$binary" -perm -0100 -print -quit)"
      if [ -z "$path" ]; then
        echo "missing built binary: $binary" >&2
        exit 1
      fi
      install -Dm755 "$path" "$out/bin/$binary"
    done
    runHook postInstall
  '';

  doCheck = false;
  strictDeps = true;
  inherit postPatch;

  # The release profiles enable thin LTO and are memory-heavy. Keep remote
  # builders from killing rustc while compiling the large graphics workspaces.
  env.CARGO_BUILD_JOBS = "1";

  nativeBuildInputs = [ pkg-config ]
    ++ lib.optionals isLinux [
    makeWrapper
    wayland-scanner
    desktop-file-utils
    appstream
  ]
    ++ lib.optionals (isLinux && autoAddDriverRunpath != null) [ autoAddDriverRunpath ];

  buildInputs = lib.optionals isLinux [
    wayland
    libxkbcommon
    libX11
    libxcb
    libXcursor
    libXi
    libXrandr
    alsa-lib
  ];

  postInstall = lib.optionalString isLinux ''
    install -Dm644 packaging/linux/${appId}.desktop \
      $out/share/applications/${appId}.desktop
    install -Dm644 packaging/linux/${appId}.mime.xml \
      $out/share/mime/packages/${appId}.xml
    cp -r assets/app-icon/hicolor $out/share/icons/
    install -d $out/share/metainfo
    substitute packaging/linux/${appId}.metainfo.xml.in \
      $out/share/metainfo/${appId}.metainfo.xml \
      --subst-var-by VERSION ${version} \
      --subst-var-by DATE 1970-01-01

    install -d $out/share/doc/${pname}
    install -Dm644 -t $out/share/doc/${pname} \
      README.md LICENSE-MIT LICENSE-APACHE NOTICE

    desktop-file-validate $out/share/applications/${appId}.desktop
    appstreamcli validate --no-net $out/share/metainfo/${appId}.metainfo.xml
    for bin in ${lib.concatStringsSep " " (map (binary: "$out/bin/${binary}") binaries)}; do
      wrapProgram "$bin" --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"
    done
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    app="$out/Applications/${displayName}.app"
    install -Dm755 "$out/bin/${pname}" "$app/Contents/MacOS/${displayName}"
    if [ -f "assets/app-icon/${pname}.icns" ]; then
      install -Dm644 "assets/app-icon/${pname}.icns" \
        "$app/Contents/Resources/${displayName}.icns"
    fi
    substitute packaging/macos/Info.plist.in "$app/Contents/Info.plist" \
      --subst-var-by VERSION ${version} \
      --subst-var-by SHORT_VERSION ${version} \
      --subst-var-by BUILD_SHA nixautopkgs
    printf 'APPL????' > "$app/Contents/PkgInfo"
  '';

  passthru = {
    inherit runtimeLibs;
    updateScript = nix-update-script { };
  };

  meta = {
    inherit description;
    homepage = "https://getartcraft.com/apps/${pname}";
    changelog = "https://github.com/storytold/${pname}/releases/tag/v${version}";
    license = with lib.licenses; [ mit asl20 ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = pname;
    platforms = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    nixautopkgs.upstream = "storytold/${pname}";
  };
}
