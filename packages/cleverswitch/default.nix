{ lib
, python313Packages
, fetchFromGitHub
, hidapi
, makeWrapper
, nix-update-script
, stdenv
}:

let
  inherit (python313Packages) buildPythonApplication bleak pyyaml setuptools setuptools-scm;
in
buildPythonApplication rec {
  pname = "cleverswitch";
  version = "2.1.6";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "MikalaiBarysevich";
    repo = "CleverSwitch";
    rev = "v${version}";
    hash = "sha256-ZY4iipUmN2VW+ehGqkpJyfSabGixEoeO3sj+ztB8DDA=";
  };

  nativeBuildInputs = [
    makeWrapper
    setuptools
    setuptools-scm
  ];

  dependencies = [
    pyyaml
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin bleak
  ++ lib.optional stdenv.hostPlatform.isDarwin python313Packages."pyobjc-framework-CoreBluetooth";

  buildInputs = [ hidapi ];

  # nixpkgs currently provides Bleak 3.x; CleverSwitch's macOS code remains
  # compatible, but upstream still declares the older upper bound.
  pythonRelaxDeps = [ "bleak" ];

  # The GitHub source archive does not contain .git metadata for setuptools-scm.
  env = {
    SETUPTOOLS_SCM_PRETEND_VERSION = version;
    SETUPTOOLS_SCM_PRETEND_VERSION_FOR_CLEVERSWITCH = version;
  };

  # Hardware access is not available in the sandbox; the upstream suite also
  # requires physical Logitech devices for its integration coverage.
  doCheck = false;
  pythonImportsCheck = [ "cleverswitch" ];

  postInstall = ''
    wrapProgram $out/bin/cleverswitch \
      ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ hidapi ]}"} \
      ${lib.optionalString stdenv.hostPlatform.isDarwin "--prefix DYLD_LIBRARY_PATH : ${lib.makeLibraryPath [ hidapi ]}"}
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm644 rules.d/42-cleverswitch.rules \
      $out/share/cleverswitch/udev/42-cleverswitch.rules
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Synchronize host switching between Logitech devices";
    homepage = "https://github.com/MikalaiBarysevich/CleverSwitch";
    changelog = "https://github.com/MikalaiBarysevich/CleverSwitch/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "cleverswitch";
    platforms = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    nixautopkgs = {
      upstream = "MikalaiBarysevich/CleverSwitch";
    };
  };
}
