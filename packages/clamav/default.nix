{ lib
, stdenv
, fetchurl
, pkg-config
, cmake
, zlib
, bzip2
, libiconv
, libxml2
, openssl
, ncurses
, curl
, libmilter
, pcre2
, libmspack
, systemd
, json_c
, check
, rustc
, rust-bindgen
, rustfmt
, cargo
, python3
, python3Packages
, nix-update-script
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "clamav";
  version = "1.5.2";

  src = fetchurl {
    url = "https://www.clamav.net/downloads/production/clamav-${finalAttrs.version}.tar.gz";
    hash = "sha256-80AYzyLwW92dGhV0ygcZPj4DDKUgUMPlwiDiOjIxSWU=";
  };

  patches = [
    ./sample-configuration-file-install-location.patch
    ./use-non-existent-file-with-proper-permissions.patch
  ];

  enableParallelBuilding = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    rustc
    rust-bindgen
    rustfmt
    cargo
    python3
  ];

  buildInputs = [
    zlib
    bzip2
    libxml2
    openssl
    ncurses
    curl
    libiconv
    libmilter
    pcre2
    libmspack
    json_c
    check
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux systemd;

  cmakeFlags = [
    "-DSYSTEMD_UNIT_DIR=${placeholder "out"}/lib/systemd"
    "-DAPP_CONFIG_DIRECTORY=/etc/clamav"
    "-DCVD_CERTS_DIRECTORY=${placeholder "out"}/etc/clamav/certs"
  ];

  # Seems to only fail on x86_64-darwin with sandboxing
  doCheck = !(stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64);
  __darwinAllowLocalNetworking = true;

  checkInputs = [
    python3Packages.pytest
  ];

  passthru = {
    updateScript = nix-update-script { };
    nixautopkgs = {
      upstream = {
        type = "github";
        owner = "Cisco-Talos";
        repo = "clamav";
      };
      nixpkgsPath = "pkgs/by-name/cl/clamav";
    };
  };

  meta = {
    homepage = "https://www.clamav.net";
    description = "Antivirus engine designed for detecting Trojans, viruses, malware and other malicious threats";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.unix;
    mainProgram = "clamscan";
  };
})
