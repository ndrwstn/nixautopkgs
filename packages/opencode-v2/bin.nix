# OpenCode v2 — prebuilt binaries only.
#
# Unlike packages/opencode (which alternates between upstream's source build
# and prebuilt release assets via routing.json), this package intentionally
# has no build route. The upstream CI signs macOS artifacts with an
# RFC3161-timestamped Apple Developer ID certificate and produces desktop
# bundles through electron-builder with notarization and Sentry injection,
# so byte-identical rebuilds of the team's releases are impossible outside
# their pipeline. Rather than ship a nonfunctioning source build that cannot
# match the official releases, this package always consumes the prebuilt
# artifacts published by the official OpenCode distribution service.
#
# CLI and desktop asset hashes in ./assets.json are refreshed from the official
# npm and OpenCode update APIs by .github/scripts/update-opencode-assets.sh.
# Version bumps arrive via the scheduled v2 discovery workflow.
{ pkgs
, system
, opencodeAssets ? builtins.fromJSON (builtins.readFile ./assets.json)
,
}:

let
  lib = pkgs.lib;
  opencodeRuntimePath = lib.makeBinPath ([ pkgs.ripgrep ] ++ lib.optional pkgs.stdenvNoCC.hostPlatform.isDarwin pkgs.sysctl);
  opencodeCliVersion = opencodeAssets.cliVersion
    or (throw "opencode-v2-bin: missing `cliVersion` in packages/opencode-v2/assets.json");
  opencodeDesktopVersion = opencodeAssets.desktopVersion
    or (throw "opencode-v2-bin: missing `desktopVersion` in packages/opencode-v2/assets.json");

  cliAssetBySystem = opencodeAssets.cli
    or (throw "opencode-v2-bin: missing `cli` map in packages/opencode-v2/assets.json");

  desktopAssetBySystem = opencodeAssets.desktop
    or (throw "opencode-v2-bin: missing `desktop` map in packages/opencode-v2/assets.json");

  cliAsset = cliAssetBySystem.${system}
    or (throw "opencode-v2-cli-bin: unsupported system ${system}");

  desktopAsset = desktopAssetBySystem.${system}
    or (throw "opencode-v2-desktop-bin: unsupported system ${system}");

  cliSrc = pkgs.fetchurl {
    url = cliAsset.url;
    hash = cliAsset.hash;
  };

  desktopSrc = pkgs.fetchurl {
    url = desktopAsset.url;
    hash = desktopAsset.hash;
  };
in
{
  # CLI binary. The archive ships the executable as plain `opencode`; it is
  # installed as `opencode2` so it can coexist with the stable v1 `opencode`
  # command from packages/opencode.
  opencode-cli-bin = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode2-cli-bin";
    version = opencodeCliVersion;
    src = cliSrc;

    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/libexec" "$TMPDIR/opencode-cli"

      tar -xzf "$src" -C "$TMPDIR/opencode-cli"

      cli_binary="$(find "$TMPDIR/opencode-cli/package/bin" -type f -perm -u+x ! -name '*.map' -print -quit)"
      if [ -z "$cli_binary" ]; then
        echo "ERROR: could not find executable in the CLI archive" >&2
        exit 1
      fi
      install -Dm755 "$cli_binary" "$out/libexec/opencode2"

      cat > "$out/bin/opencode2" <<EOF
      #!${pkgs.runtimeShell}
      export PATH="${opencodeRuntimePath}:\$PATH"
      exec -a opencode2 "$out/libexec/opencode2" "\$@"
      EOF
      chmod 755 "$out/bin/opencode2"

      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenCode v2 CLI binary package";
      homepage = "https://opencode.ai/";
      license = licenses.mit;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "opencode2";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };

  # Desktop app. Keep the v2 executable and application separate from v1.
  opencode-desktop-bin = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode2-desktop-bin";
    version = opencodeDesktopVersion;
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

         app_path="$(find "$TMPDIR/opencode-desktop" -maxdepth 2 -type d -name 'OpenCode*.app' -print -quit)"
         if [ -z "$app_path" ]; then
           echo "ERROR: could not find OpenCode.app inside the DMG" >&2
           exit 1
         fi
         app_name="$(basename "$app_path")"
         cp -R "$app_path" "$out/Applications/$app_name"
         ln -s "$out/Applications/$app_name/Contents/MacOS/OpenCode" "$out/bin/opencode-desktop-v2"
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
       electron_bin="$(find "$out/opt" -type f -perm -u+x \( -name 'opencode' -o -name 'OpenCode' -o -name 'ai.opencode.desktop*' \) -print -quit)"
       if [ ! -f "$electron_bin" ]; then
         echo "ERROR: expected Electron binary at $electron_bin" >&2
         exit 1
       fi
       electron_rel="''${electron_bin#$out}"

      makeWrapper "$electron_bin" "$out/bin/opencode-desktop-v2" \
        "''${makeWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}" \
        --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$out/share"

      # Patch the desktop file to point to our wrapper
      for desktop_file in "$out/share/applications/"*.desktop; do
        if [ -f "$desktop_file" ]; then
          substituteInPlace "$desktop_file" \
             --replace "$electron_rel" 'opencode-desktop-v2'
        fi
      done
    '';

    meta = with lib; {
      description = "OpenCode v2 Desktop binary package";
      homepage = "https://opencode.ai/";
      license = licenses.mit;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "opencode-desktop-v2";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
}
