{ lib
, runCommandNoCC
, buildPythonPackage
, fetchPypi
, nix-update-script
, python
, pythonOlder
, pythonAtLeast
, setuptools
, mlx
, numpy
, transformers
, sentencepiece
, protobuf
, pyyaml
, jinja2
}:

let
  baseMeta = {
    description = "LLMs with MLX and the Hugging Face Hub";
    homepage = "https://github.com/ml-explore/mlx-lm";
    license = lib.licenses.mit;
    mainProgram = "mlx_lm";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
in
if !(python.stdenv.hostPlatform.isDarwin && python.stdenv.hostPlatform.isAarch64) then
  runCommandNoCC "mlx-lm-unsupported-${python.stdenv.hostPlatform.system}"
  {
    meta = baseMeta;
  } ''
    echo "error: mlx-lm is only packaged for aarch64-darwin in nixautopkgs because it depends on Apple's MLX runtime." >&2
    exit 1
  ''
else
  buildPythonPackage rec {
    pname = "mlx-lm";
    version = "0.31.3";
    format = "setuptools";

    disabled = pythonOlder "3.13" || pythonAtLeast "3.14";

    src = fetchPypi {
      pname = "mlx_lm";
      inherit version;
      hash = "sha256-YesOO6CURPd/h0r/KVQB18zSCzlJXLvODHgqFUdM5zM=";
    };

    nativeBuildInputs = [ setuptools ];

    dependencies = [
      mlx
      numpy
      transformers
      sentencepiece
      protobuf
      pyyaml
      jinja2
    ];

    pythonImportsCheck = [ "mlx_lm" ];

    passthru = {
      updateScript = nix-update-script { };
      nixautopkgs.upstream = {
        type = "github";
        owner = "ml-explore";
        repo = "mlx-lm";
      };
    };

    meta = baseMeta // {
      changelog = "https://github.com/ml-explore/mlx-lm/releases/tag/v${version}";
    };
  }
