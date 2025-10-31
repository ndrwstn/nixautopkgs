{ pkgs }:

let
  nix-update-script = pkgs.nix-update-script;

  # Desktop entry for Linux
  desktopItem = pkgs.makeDesktopItem {
    name = "gcs";
    desktopName = "GURPS Character Sheet";
    comment = "Interactive character sheet editor for GURPS Fourth Edition";
    exec = "gcs";
    icon = "gcs";
    categories = [ "Game" "RolePlaying" ];
    keywords = [ "GURPS" "character" "sheet" "rpg" ];
    startupNotify = true;
    terminal = false;
    type = "Application";
  };

  # Icon assets from upstream
  iconTheme = "hicolor";

  # macOS app bundle configuration
  appBundleName = "GCS";
  appBundleId = "com.trollworks.gcs";
in

pkgs.buildGoModule.override { go = pkgs.go_1_25; } rec {
  pname = "gcs";
  version = "5.42.0";

  src = pkgs.fetchFromGitHub {
    owner = "richardwilkes";
    repo = "gcs";
    rev = "v${version}";
    hash = "sha256-eCWMaO1iv917aHcdln2B10oCSbmzpXvQIF/luztHwRc=";
  };

  modPostBuild = ''
    chmod +w vendor/github.com/richardwilkes/pdf
    sed -i 's|-lmupdf[^ ]* |-lmupdf |g' vendor/github.com/richardwilkes/pdf/pdf.go
  '';

  vendorHash = "sha256-pbt4zNbFYTXKVe9D70Lg3XVsjadnUIuPwbbV1CJNLc8=";

  nativeBuildInputs = [ pkgs.pkg-config ]
    ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.copyDesktopItems
  ];

  buildInputs = [
    pkgs.mupdf
  ]
  ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.libGL
    pkgs.xorg.libX11
    pkgs.xorg.libXcursor
    pkgs.xorg.libXrandr
    pkgs.xorg.libXinerama
    pkgs.xorg.libXi
    pkgs.xorg.libXxf86vm
    pkgs.fontconfig
    pkgs.freetype
  ];

  flags = [ "-a" ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/richardwilkes/toolbox/v2/xos.AppVersion=${version}"
  ];

  postInstall = ''
        ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          # Install desktop file
          copyDesktopItems
      
          # Install main application icon (using app.png as the main icon)
          install -Dm644 "$src/pkgicons/app.png" "$out/share/icons/${iconTheme}/256x256/apps/gcs.png"
      
          # Also install scalable SVG icon if available
          svg_icon="$src/svg/app_icon.svg"
          if [ -f "$svg_icon" ]; then
            install -Dm644 "$svg_icon" "$out/share/icons/${iconTheme}/scalable/apps/gcs.svg"
          fi
        ''}
        ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          # Create macOS app bundle
          appDir="$out/Applications/${appBundleName}.app"
          mkdir -p "''${appDir}/Contents/MacOS"
          mkdir -p "''${appDir}/Contents/Resources"
      
          # Copy the binary
          cp $out/bin/gcs "''${appDir}/Contents/MacOS/"
      
          # Create Info.plist
          cat > "''${appDir}/Contents/Info.plist" <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleDisplayName</key>
        <string>${appBundleName}</string>
        <key>CFBundleExecutable</key>
        <string>gcs</string>
        <key>CFBundleIconFile</key>
        <string>app</string>
        <key>CFBundleIdentifier</key>
        <string>${appBundleId}</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>${appBundleName}</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>${version}</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>CFBundleVersion</key>
        <string>${version}</string>
        <key>LSApplicationCategoryType</key>
        <string>public.app-category.role-playing-games</string>
        <key>LSMinimumSystemVersion</key>
        <string>10.15</string>
        <key>NSHighResolutionCapable</key>
        <true/>
        <key>NSHumanReadableCopyright</key>
        <string>Copyright © 1998-2025 Richard A. Wilkes</string>
    </dict>
    </plist>
    EOF
      
          # Copy app icon
          if [ -f "$src/pkgicons/app.png" ]; then
            # Convert PNG to ICNS for macOS (using sips if available, otherwise copy as-is)
            if command -v sips >/dev/null 2>&1; then
              sips -s format icns "$src/pkgicons/app.png" --out "''${appDir}/Contents/Resources/app.icns" 2>/dev/null || \
              cp "$src/pkgicons/app.png" "''${appDir}/Contents/Resources/app.png"
            else
              cp "$src/pkgicons/app.png" "''${appDir}/Contents/Resources/app.png"
            fi
          fi
        ''}
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 $GOPATH/bin/gcs -t $out/bin
    runHook postInstall
  '';

  desktopItems = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ desktopItem ];

  passthru = {
    updateScript = nix-update-script { };

    # Desktop file validation for Linux
    desktopFileValidation = pkgs.stdenv.hostPlatform.isLinux;

    # Tests for desktop integration
    tests = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      desktop-file-validation = pkgs.stdenv.mkDerivation {
        name = "gcs-desktop-file-validation";
        buildInputs = [ pkgs.desktop-file-utils ];
        buildPhase = ''
          for desktop_file in ${desktopItem}/share/applications/*.desktop; do
            desktop-file-validate "$desktop_file"
          done
        '';
        installPhase = ''
          touch $out
        '';
      };
    };
  };

  meta = with pkgs.lib; {
    changelog = "https://github.com/richardwilkes/gcs/releases/tag/v${version}";
    description = "Stand-alone, interactive, character sheet editor for the GURPS 4th Edition roleplaying game system";
    homepage = "https://gurpscharactersheet.com/";
    license = licenses.mpl20;
    mainProgram = "gcs";
    maintainers = with maintainers; [ tomasajt ];
    platforms = platforms.linux ++ platforms.darwin;
    broken = pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64;
    nixautopkgs = {
      upstream = "richardwilkes/gcs";
      nixpkgsPath = "pkgs/by-name/gc/gcs/package.nix";
    };
  };
}
