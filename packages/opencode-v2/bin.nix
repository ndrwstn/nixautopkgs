# OpenCode v2 (beta channel) — prebuilt binaries only.
#
# Unlike packages/opencode (which alternates between upstream's source build
# and prebuilt release assets via routing.json), this package intentionally
# has no build route. The upstream CI signs macOS artifacts with an
# RFC3161-timestamped Apple Developer ID certificate and produces desktop
# bundles through electron-builder with notarization and Sentry injection,
# so byte-identical rebuilds of the team's releases are impossible outside
# their pipeline. Rather than ship a nonfunctioning source build that cannot
# match the official releases, this package always consumes the prebuilt
# artifacts published to github.com/anomalyco/opencode-beta.
#
# Asset hashes in ./assets.json are refreshed by
# .github/scripts/update-opencode-assets.sh (--repo anomalyco/opencode-beta)
# and version bumps arrive via Renovate.
{ pkgs
, system
, opencodeAssets ? builtins.fromJSON (builtins.readFile ./assets.json)
,
}:

let
  lib = pkgs.lib;
  opencodeRuntimePath = lib.makeBinPath ([ pkgs.ripgrep ] ++ lib.optional pkgs.stdenvNoCC.hostPlatform.isDarwin pkgs.sysctl);
  opencodeVersion = opencodeAssets.version
    or (throw "opencode-v2-bin: missing `version` in packages/opencode-v2/assets.json");
  releaseBaseUrl = "https://github.com/anomalyco/opencode-beta/releases/download/v${opencodeVersion}";

  cliAssetBySystem = opencodeAssets.cli
    or (throw "opencode-v2-bin: missing `cli` map in packages/opencode-v2/assets.json");

  desktopAssetBySystem = opencodeAssets.desktop
    or (throw "opencode-v2-bin: missing `desktop` map in packages/opencode-v2/assets.json");

  cliAsset = cliAssetBySystem.${system}
    or (throw "opencode-v2-cli-bin: unsupported system ${system}");

  desktopAsset = desktopAssetBySystem.${system}
    or (throw "opencode-v2-desktop-bin: unsupported system ${system}");

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
  # CLI binary. The archive ships the executable as plain `opencode`; it is
  # installed as `opencode2` so it can coexist with the stable v1 `opencode`
  # command from packages/opencode.
  opencode-cli-bin = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode2-cli-bin";
    version = opencodeVersion;
    src = cliSrc;

    nativeBuildInputs = [ pkgs.unzip ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/libexec" "$TMPDIR/opencode-cli"

      if [ "${cliAsset.archiveType}" = "zip" ]; then
        unzip -q "$src" -d "$TMPDIR/opencode-cli"
      else
        tar -xzf "$src" -C "$TMPDIR/opencode-cli"
      fi

      install -Dm755 "$TMPDIR/opencode-cli/opencode" "$out/libexec/opencode2"

      cat > "$out/bin/opencode2" <<EOF
      #!${pkgs.runtimeShell}
      export PATH="${opencodeRuntimePath}:\$PATH"
      exec -a opencode2 "$out/libexec/opencode2" "\$@"
      EOF
      chmod 755 "$out/bin/opencode2"

      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenCode v2 (beta) CLI binary package";
      homepage = "https://opencode.ai/";
      license = licenses.mit;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "opencode2";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };

  # Desktop app. The beta dmg ships "OpenCode Beta.app" and the Linux deb is
  # electron-builder packaging under "opt/OpenCode Beta" with the binary
  # "ai.opencode.desktop.beta", so both coexist cleanly beside the stable
  # OpenCode.app / opencode-desktop from packages/opencode.
  opencode-desktop-bin = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode2-desktop-bin";
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
      pkgs.nspr
      pkgs.nss
      pkgs.alsa-lib
    ];

    dontWrapGApps = pkgs.stdenv.isLinux;

    dontUnpack = true;
    dontStrip = true;
    autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

    preFixup = lib.optionalString pkgs.stdenv.isLinux ''
      makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
    '';

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

        cp -R "$TMPDIR/opencode-desktop/OpenCode Beta.app" "$out/Applications/OpenCode Beta.app"
        ln -s "$out/Applications/OpenCode Beta.app/Contents/MacOS/OpenCode Beta" "$out/bin/opencode-desktop-v2"
      else
        mkdir -p "$TMPDIR/opencode-desktop"
        data_tar="$(ar t "$src" | grep -m1 '^data\.tar\.')"
        if [[ -z "$data_tar" ]]; then
          echo "ERROR: could not find data.tar.* inside $src" >&2
          exit 1
        fi
        if [[ "$data_tar" == *.xz ]]; then
          ar p "$src" "$data_tar" | tar -xJf - -C "$TMPDIR/opencode-desktop"
        elif [[ "$data_tar" == *.gz ]]; then
          ar p "$src" "$data_tar" | tar -xzf - -C "$TMPDIR/opencode-desktop"
        else
          ar p "$src" "$data_tar" | tar -xf - -C "$TMPDIR/opencode-desktop"
        fi
        cp -R "$TMPDIR/opencode-desktop/usr/." "$out/" 2>/dev/null || true
        if [ -d "$TMPDIR/opencode-desktop/opt" ]; then
          mkdir -p "$out/opt"
          cp -R "$TMPDIR/opencode-desktop/opt/." "$out/opt/"
        fi
      fi

      runHook postInstall
    '';

    postFixup = lib.optionalString pkgs.stdenv.isLinux ''
      electron_bin="$out/opt/OpenCode Beta/ai.opencode.desktop.beta"
      if [ ! -f "$electron_bin" ]; then
        echo "ERROR: expected Electron binary at $electron_bin" >&2
        exit 1
      fi

      makeWrapper "$electron_bin" "$out/bin/opencode-desktop-v2" \
        "''${makeWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}" \
        --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$out/share"

      # Patch the beta .desktop file to point to our wrapper
      for desktop_file in "$out/share/applications/"*.desktop; do
        if [ -f "$desktop_file" ]; then
          substituteInPlace "$desktop_file" \
            --replace '/opt/OpenCode Beta/ai.opencode.desktop.beta' 'opencode-desktop-v2' \
            --replace '/opt/OpenCode Beta/' "$out/opt/OpenCode Beta/"
        fi
      done
    '';

    meta = with lib; {
      description = "OpenCode v2 (beta) Desktop binary package";
      homepage = "https://opencode.ai/";
      license = licenses.mit;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "opencode-desktop-v2";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
}
