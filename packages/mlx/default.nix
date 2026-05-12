{ lib
, runCommandNoCC
, buildPythonPackage
, fetchPypi
, fetchurl
, nix-update-script
, python
, pythonOlder
, pythonAtLeast
}:

let
  baseMeta = {
    description = "Array framework for machine learning on Apple silicon";
    homepage = "https://github.com/ml-explore/mlx";
    license = lib.licenses.mit;
    mainProgram = "mlx.launch";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
in
if !(python.stdenv.hostPlatform.isDarwin && python.stdenv.hostPlatform.isAarch64) then
  runCommandNoCC "mlx-unsupported-${python.stdenv.hostPlatform.system}"
  {
    meta = baseMeta;
  } ''
    echo "error: mlx is only packaged for aarch64-darwin in nixautopkgs because upstream primarily ships Apple Silicon MLX binaries for macOS." >&2
    exit 1
  ''
else
  buildPythonPackage rec {
    pname = "mlx";
    version = "0.31.2";
    format = "wheel";

    mlxMetalWheel = fetchurl {
      url = "https://files.pythonhosted.org/packages/3f/69/fe3b783ebe999f3118234e1e940feb622518bfb1dea6ac5d13b1d36a8449/mlx_metal-${version}-py3-none-macosx_14_0_arm64.whl";
      hash = "sha256-slOFvO4Y/BlAkiVbi1O5o9hInrZQ5ZFg8bV6rdB6otw=";
    };

    disabled = pythonOlder "3.13" || pythonAtLeast "3.14";

    pythonRemoveDeps = [ "mlx-metal" ];

    src =
      let
        pyShortVersion = "cp${builtins.replaceStrings [ "." ] [ "" ] python.pythonVersion}";
      in
      fetchPypi {
        inherit version format;
        pname = "mlx";
        dist = pyShortVersion;
        python = pyShortVersion;
        abi = pyShortVersion;
        platform = "macosx_14_0_arm64";
        hash =
          {
            cp313 = "sha256-Gz+w3alVsNVSzle91vQrMwmrIbBn5AWH1oSEQ9MH6R8=";
          }.${pyShortVersion} or (throw "${pname} is missing a wheel hash for ${pyShortVersion}");
      };

    postInstall = ''
      export MLX_SITE_PACKAGES="$out/${python.sitePackages}/mlx"
      export MLX_METAL_WHEEL="$mlxMetalWheel"

      ${python.interpreter} - <<'PY'
      import os
      import pathlib
      import zipfile

      site_packages = pathlib.Path(os.environ["MLX_SITE_PACKAGES"])
      wheel_path = pathlib.Path(os.environ["MLX_METAL_WHEEL"])

      with zipfile.ZipFile(wheel_path) as wheel:
          for member in wheel.infolist():
              path = pathlib.PurePosixPath(member.filename)
              if len(path.parts) < 2 or path.parts[0] != "mlx":
                  continue
              if path.parts[1] not in {"include", "lib", "share"}:
                  continue

              destination = site_packages.joinpath(*path.parts[1:])
              if member.is_dir():
                  destination.mkdir(parents=True, exist_ok=True)
                  continue

              destination.parent.mkdir(parents=True, exist_ok=True)
              with wheel.open(member) as src, open(destination, "wb") as dst:
                  dst.write(src.read())
      PY
    '';

    pythonImportsCheck = [ "mlx" ];

    passthru = {
      updateScript = nix-update-script { };
      nixautopkgs.upstream = {
        type = "github";
        owner = "ml-explore";
        repo = "mlx";
      };
    };

    meta = baseMeta // {
      changelog = "https://github.com/ml-explore/mlx/releases/tag/v${version}";
    };
  }
