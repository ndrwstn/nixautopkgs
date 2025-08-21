{ pkgs }:

pkgs.buildGoModule.override { go = pkgs.go_1_25; } rec {
  pname = "gcs";
  version = "5.38.1";

  src = pkgs.fetchFromGitHub {
    owner = "richardwilkes";
    repo = "gcs";
    rev = "v${version}";
    hash = "sha256-8uz3TfBcbgo6cQkm9qIFAchFBDCbCeP6DUe/BO8fPI8=";
  };

  modPostBuild = ''
    chmod +w vendor/github.com/richardwilkes/pdf
    sed -i 's|-lmupdf[^ ]* |-lmupdf |g' vendor/github.com/richardwilkes/pdf/pdf.go
  '';

  vendorHash = "sha256-9EvbeypL4bBHA56GdIB6IhtBBGf3yGqPu72UNcb2mwc=";

  nativeBuildInputs = [ pkgs.pkg-config ];

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

  installPhase = ''
    runHook preInstall
    install -Dm755 $GOPATH/bin/gcs -t $out/bin
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    changelog = "https://github.com/richardwilkes/gcs/releases/tag/v${version}";
    description = "Stand-alone, interactive, character sheet editor for the GURPS 4th Edition roleplaying game system";
    homepage = "https://gurpscharactersheet.com/";
    license = licenses.mpl20;
    mainProgram = "gcs";
    maintainers = with maintainers; [ tomasajt ];
    platforms = platforms.linux ++ platforms.darwin;
    broken = pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64;
  };
}
