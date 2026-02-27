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

    nativeBuildInputs = [ pkgs.binutils ] ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.undmg ];

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

        if [ -f "$out/bin/OpenCode" ]; then
          ln -s "$out/bin/OpenCode" "$out/bin/opencode-desktop"
        fi
      fi

      runHook postInstall
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
