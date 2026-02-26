{ pkgs, system, opencodeVersion ? "1.2.15" }:

let
  lib = pkgs.lib;
  releaseBaseUrl = "https://github.com/anomalyco/opencode/releases/download/v${opencodeVersion}";

  cliAssetBySystem = {
    aarch64-darwin = {
      name = "opencode-darwin-arm64.zip";
      hash = "sha256-QUTNt65NGDlk17I73TcGHtUnYbveflV2Pg69EpmMHl4=";
      archiveType = "zip";
    };
    x86_64-darwin = {
      name = "opencode-darwin-x64.zip";
      hash = "sha256-ukTTi3x6FWdSRtlfJfH8T2tvv1IpwI1HgTq5jzUDp+M=";
      archiveType = "zip";
    };
    aarch64-linux = {
      name = "opencode-linux-arm64.tar.gz";
      hash = "sha256-3UyldkoJP5LYUVgz1cWOq8ZX5yzcPvK6OsEeDbdJuA0=";
      archiveType = "tar.gz";
    };
    x86_64-linux = {
      name = "opencode-linux-x64.tar.gz";
      hash = "sha256-eLAZRkZOk1ybeSYe2kpI9AZiGweHo1j+YHtscTBfMg4=";
      archiveType = "tar.gz";
    };
  };

  desktopAssetBySystem = {
    aarch64-darwin = {
      name = "opencode-desktop-darwin-aarch64.dmg";
      hash = "sha256-veTQ8jD64TpYyGYDauwZdjWRUGKhoo8ZwTn+A8Af/u4=";
      archiveType = "darwin-dmg";
    };
    x86_64-darwin = {
      name = "opencode-desktop-darwin-x64.dmg";
      hash = "sha256-B6KCXgyfnVoU88EOCIM6WwBHnFIrhlMJBBp/swrpELw=";
      archiveType = "darwin-dmg";
    };
    aarch64-linux = {
      name = "opencode-desktop-linux-arm64.deb";
      hash = "sha256-wlEfUjNASbo0xkC4gfwTwmWghkv1rEahKvOLhWJUL2c=";
      archiveType = "deb";
    };
    x86_64-linux = {
      name = "opencode-desktop-linux-amd64.deb";
      hash = "sha256-TJmFT+ZUtnb3O7LG2xrJJKJBt+VNkTs4jk45j8mnHPE=";
      archiveType = "deb";
    };
  };

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
