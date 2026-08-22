{ lib
, stdenv
, fetchurl
, replaceVars
, makeDesktopItem
, copyDesktopItems
, icoutils
, openjdk21
,
}:

let
  version = "0.51.0";

  # The upstream MekHQ release tarball bundles the entire MegaMek suite: the
  # three application jars plus shared dependencies under lib/, game data for
  # every program, sample campaigns, runtime configuration (mmconf/) and
  # native icons under data/images/misc/. This package installs that
  # distribution once and exposes one launcher per application (megamek,
  # mekhq, megameklab).
  #
  # NOTE: all three programs must stay on the same suite version to remain
  # interoperable; packaging them from a single upstream artifact guarantees
  # that by construction.
  apps = [
    {
      id = "megamek";
      display = "MegaMek";
      mainClass = "megamek.MegaMek";
      description = "Networked Java version of BattleTech: tactical combat with BattleMechs, vehicles and infantry";
    }
    {
      id = "mekhq";
      display = "MekHQ";
      mainClass = "mekhq.MekHQ";
      description = "BattleTech mercenary campaign manager integrating MegaMek battles and MegaMekLab unit customization";
    }
    {
      id = "megameklab";
      display = "MegaMekLab";
      mainClass = "megameklab.MegaMekLab";
      description = "BattleTech unit designer for creating and modifying units and printing record sheets";
    }
  ];

  desktopItems = map
    (
      app:
      makeDesktopItem {
        name = app.id;
        desktopName = app.display;
        comment = app.description;
        exec = app.id;
        icon = app.id;
        categories = [
          "Game"
          "StrategyGame"
        ];
        keywords = [
          "BattleTech"
          "MechWarrior"
          "wargame"
        ];
        startupNotify = true;
        terminal = false;
        type = "Application";
      }
    )
    apps;

  # Launcher scripts are generated from a shell template: they prepare a
  # writable state directory (see wrapper.sh.in for why) before exec'ing the
  # JVM with options taken from upstream's Launch4j config (*.l4j.ini) and
  # Gradle start scripts.
  mkWrapper =
    app:
    replaceVars ./wrapper.sh.in {
      inherit (stdenv) shell;
      java = "${openjdk21}/bin/java";
      appName = app.display;
      inherit (app) mainClass;
    };

  mkAppBundle =
    app:
    ''
      bundle="$out/Applications/${app.display}.app"
      mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"

      ln -s "$out/bin/${app.id}" "$bundle/Contents/MacOS/${app.display}"
      cp "$dest/data/images/misc/${app.id}.icns" "$bundle/Contents/Resources/${app.id}.icns"

      plist="$bundle/Contents/Info.plist"
      {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        echo '<plist version="1.0">'
        echo '<dict>'
        echo '    <key>CFBundleDevelopmentRegion</key>'
        echo '    <string>en</string>'
        echo '    <key>CFBundleDisplayName</key>'
        echo "    <string>${app.display}</string>"
        echo '    <key>CFBundleExecutable</key>'
        echo "    <string>${app.display}</string>"
        echo '    <key>CFBundleIconFile</key>'
        echo "    <string>${app.id}</string>"
        echo '    <key>CFBundleIdentifier</key>'
        echo "    <string>org.megamek.${app.id}</string>"
        echo '    <key>CFBundleInfoDictionaryVersion</key>'
        echo '    <string>6.0</string>'
        echo '    <key>CFBundleName</key>'
        echo "    <string>${app.display}</string>"
        echo '    <key>CFBundlePackageType</key>'
        echo '    <string>APPL</string>'
        echo '    <key>CFBundleShortVersionString</key>'
        echo "    <string>${version}</string>"
        echo '    <key>CFBundleSignature</key>'
        echo '    <string>????</string>'
        echo '    <key>CFBundleVersion</key>'
        echo "    <string>${version}</string>"
        echo '    <key>LSApplicationCategoryType</key>'
        echo '    <string>public.app-category.games</string>'
        echo '    <key>NSHighResolutionCapable</key>'
        echo '    <true/>'
        echo '</dict>'
        echo '</plist>'
      } > "$plist"
    '';

  mkLinuxIcons =
    app:
    ''
      tmp="$(mktemp -d)"
      (
        cd "$tmp"
        icotool -x "$dest/data/images/misc/${app.id}.ico"
      )
      for f in "$tmp"/${app.id}_*.png; do
        w="$(basename "$f")"
        w="''${w#${app.id}_}"
        w="''${w%%x*}"
        if [ "$w" -gt 0 ] 2>/dev/null; then
          install -Dm644 "$f" "$iconRoot/''${w}x''${w}/apps/${app.id}.png"
        fi
      done
      rm -rf "$tmp"
    '';
in

stdenv.mkDerivation {
  pname = "mekhq";
  inherit version;

  src = fetchurl {
    url = "https://github.com/MegaMek/mekhq/releases/download/v${version}/MekHQ-${version}.tar.gz";
    hash = "sha256-/sct9rWSRSNW6xjCwAhenv8VbM+0Ync3V7IElKkeRz8=";
  };

  # NOTE: the tarball's top-level directory is `MekHQ-0.51.00`, deliberately
  # not derivable from the version string; stdenv auto-detects the single
  # source root, so this stays robust across upstream naming changes.

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    copyDesktopItems
    icoutils # icotool: extracts PNG frames from the bundled .ico icons
  ];

  strictDeps = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase =
    ''
      runHook preInstall

      dest="$out/share/mekhq"
      mkdir -p "$dest"

      # Install everything the launchers and apps need at runtime. Windows
      # launchers (.exe/.bat), Gradle start scripts (bin/), stale bundled
      # logs/ and root-level duplicate jars are intentionally left behind.
      mv lib data docs campaigns mmconf LICENSE LICENSE.assets LICENSE.code "$dest"/
      [ -f sentry.properties ] && cp -p sentry.properties "$dest"/ || true

      mkdir -p "$out/bin"
    ''
    + lib.concatMapStrings
      (
        app: ''
          install -Dm755 ${mkWrapper app} "$out/bin/${app.id}"
          # Bake the final store path into the launcher (see wrapper.sh.in).
          sed -i "s|__NIX_STORE_PATH__|$out|g" "$out/bin/${app.id}"
        ''
      )
      apps
    + lib.optionalString stdenv.hostPlatform.isLinux (
      ''
        iconRoot="$out/share/icons/hicolor"
        mkdir -p "$iconRoot"
      ''
      + lib.concatMapStrings mkLinuxIcons apps
    )
    + lib.optionalString stdenv.hostPlatform.isDarwin (
      lib.concatMapStrings mkAppBundle apps
    )
    + ''

      runHook postInstall
    '';

  inherit desktopItems;

  passthru = {
    nixautopkgs.upstream = {
      type = "github";
      owner = "MegaMek";
      repo = "mekhq";
    };
  };

  meta = with lib; {
    changelog = "https://github.com/MegaMek/mekhq/releases/tag/v${version}";
    description = "BattleTech suite: MegaMek tactical simulator, MegaMekLab unit designer and MekHQ campaign manager";
    longDescription = ''
      The MegaMek suite implements the published Classic BattleTech rules as
      free software. This package installs the official combined distribution
      and provides launchers for all three applications:

      - megamek: networked tabletop combat simulator for BattleMechs, vehicles
        and infantry (playable against humans or bots)
      - mekhq: mercenary company campaign management integrating personnel,
        finances, logistics and MegaMek battles
      - megameklab: unit construction tool covering everything from Support
        Vehicles up to WarShips, with record sheet printing

      All three programs share one upstream release and must stay on the same
      suite version. Launchers keep mutable state (logs, campaign saves) in
      ''${XDG_DATA_HOME:-''$HOME/.local/share}/megamek-suite; override with
      MEKHQ_STATE_DIR or tune heap size via MEKHQ_XMX (default 4096m).
    '';
    homepage = "https://megamek.org";
    license = licenses.gpl3Plus;
    mainProgram = "mekhq";
    platforms = platforms.unix;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
  };
}
