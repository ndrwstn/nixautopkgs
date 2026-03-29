{ pkgs
, system
, opencodeAssets ? builtins.fromJSON (builtins.readFile ./assets.json)
,
}:

let
  lib = pkgs.lib;
  opencodeVersion = opencodeAssets.version
    or (throw "opencode-bin: missing `version` in packages/opencode/assets.json");
  releaseBaseUrl = "https://github.com/anomalyco/opencode/releases/download/v${opencodeVersion}";

  cliAssetBySystem = opencodeAssets.cli
    or (throw "opencode-bin: missing `cli` map in packages/opencode/assets.json");

  desktopAssetBySystem = opencodeAssets.desktop
    or (throw "opencode-bin: missing `desktop` map in packages/opencode/assets.json");

  cliAsset = cliAssetBySystem.${system}
    or (throw "opencode-cli-bin: unsupported system ${system}");

  desktopAsset = desktopAssetBySystem.${system}
    or (throw "opencode-desktop-bin: unsupported system ${system}");

  cliSrc = pkgs.fetchurl {
    url = "${releaseBaseUrl}/${cliAsset.name}";
    hash = cliAsset.hash;
  };

  desktopSrc = pkgs.fetchurl {
    url = "${releaseBaseUrl}/${desktopAsset.name}";
    hash = desktopAsset.hash;
  };
in
{
  opencode-cli-bin = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-cli-bin";
    version = opencodeVersion;
    src = cliSrc;

    nativeBuildInputs = [ pkgs.unzip ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$TMPDIR/opencode-cli"

      if [ "${cliAsset.archiveType}" = "zip" ]; then
        unzip -q "$src" -d "$TMPDIR/opencode-cli"
      else
        tar -xzf "$src" -C "$TMPDIR/opencode-cli"
      fi

      install -Dm755 "$TMPDIR/opencode-cli/opencode" "$out/bin/opencode"

      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenCode CLI binary package";
      homepage = "https://opencode.ai/";
      license = licenses.mit;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "opencode";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };

  opencode-desktop-bin = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-desktop-bin";
    version = opencodeVersion;
    src = desktopSrc;

    nativeBuildInputs = [ pkgs.binutils pkgs.makeWrapper ]
      ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.undmg ]
      ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook pkgs.wrapGAppsHook3 ];

    buildInputs = lib.optionals pkgs.stdenv.isLinux [
      pkgs.webkitgtk_4_1
      pkgs.gtk3
      pkgs.glib
      pkgs.dbus
      pkgs.librsvg
      pkgs.libappindicator
      pkgs.glib-networking
      pkgs.openssl
      pkgs.libsoup_3
      pkgs.gst_all_1.gstreamer
      pkgs.gst_all_1.gst-plugins-base
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.stdenv.cc.cc.lib # libstdc++ for native modules
    ];

    dontUnpack = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"

      if [ "${desktopAsset.archiveType}" = "darwin-dmg" ]; then
        mkdir -p "$out/Applications" "$out/bin"

        mkdir -p "$TMPDIR/opencode-desktop"
        cp "$src" "$TMPDIR/opencode-desktop/opencode-desktop.dmg"
        (
          cd "$TMPDIR/opencode-desktop"
          undmg opencode-desktop.dmg
        )

        cp -R "$TMPDIR/opencode-desktop/OpenCode.app" "$out/Applications/OpenCode.app"
        ln -s "$out/Applications/OpenCode.app/Contents/MacOS/OpenCode" "$out/bin/opencode-desktop"
      else
        mkdir -p "$TMPDIR/opencode-desktop"
        ar p "$src" data.tar.gz | tar -xzf - -C "$TMPDIR/opencode-desktop"
        cp -R "$TMPDIR/opencode-desktop/usr/." "$out/"

        if [ -f "$out/share/applications/OpenCode.desktop" ]; then
          substituteInPlace "$out/share/applications/OpenCode.desktop" \
            --replace-fail "Exec=OpenCode" "Exec=opencode-desktop"
        fi

      fi

      runHook postInstall
    '';

    postFixup = lib.optionalString pkgs.stdenv.isLinux ''
      # Manually wrap OpenCode with GTK environment
      # wrapGAppsHook doesn't work because the opencode-desktop symlink 
      # doesn't exist yet during fixupPhase
      mv "$out/bin/OpenCode" "$out/bin/.OpenCode-unwrapped"

      makeWrapper "$out/bin/.OpenCode-unwrapped" "$out/bin/OpenCode" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}" \
        --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$out/share"

      # Create the opencode-desktop symlink pointing to the wrapped binary
      ln -s "$out/bin/OpenCode" "$out/bin/opencode-desktop"
    '';

    meta = with lib; {
      description = "OpenCode Desktop binary package";
      homepage = "https://opencode.ai/";
      license = licenses.mit;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "opencode-desktop";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
}
