{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "craft-fonts";
  version = "2026-10-10";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "craft-fonts";
    rev = "8dcdacd5153e64560d109541a47d806f26f048c0";
    hash = "sha256-4E9OrthE5z39xFXpvpwn4Fn6RH3wX2sF56rZZejZT+I=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -d $out/share/fonts/truetype/craft-fonts $out/share/doc/craft-fonts
    find fonts -type f \( -name '*.ttf' -o -name '*.otf' \) \
      -exec install -Dm644 {} $out/share/fonts/truetype/craft-fonts/ \;
    install -Dm644 ATTRIBUTION.md LICENSE-APACHE LICENSE-MIT \
      -t $out/share/doc/craft-fonts
    find fonts -name OFL.txt -exec install -Dm644 {} \
      $out/share/doc/craft-fonts/ \;
    runHook postInstall
  '';

  meta = {
    description = "Fonts used by the ArtCraft Crafting Apps";
    homepage = "https://github.com/storytold/craft-fonts";
    license = with lib.licenses; [ ofl mit asl20 ];
    platforms = lib.platforms.all;
    nixautopkgs.upstream = "storytold/craft-fonts";
  };
}
