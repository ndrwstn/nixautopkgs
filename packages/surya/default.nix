{ lib
, fetchFromGitHub
, python3Packages
}:

let
  transformersCompat = python3Packages.buildPythonPackage rec {
    pname = "transformers";
    version = "4.56.2";
    format = "setuptools";

    src = python3Packages.fetchPypi {
      pname = "transformers";
      inherit version;
      hash = "sha256-XnxiPi10lBBccm3RD2+QwsmaVevobu9yM3ZavQyxxSk=";
    };

    postPatch = ''
      substituteInPlace src/transformers/dependency_versions_table.py \
        --replace-fail '"huggingface-hub>=0.34.0,<1.0"' '"huggingface-hub>=0.34.0,<2.0"'
    '';

    nativeBuildInputs = with python3Packages; [
      setuptools
      wheel
    ];

    dependencies = with python3Packages; [
      filelock
      huggingface-hub
      numpy
      packaging
      pyyaml
      regex
      requests
      safetensors
      tokenizers
      tqdm
    ];

    pythonImportsCheck = [ "transformers" "transformers.onnx" ];
    doCheck = false;
  };
in
python3Packages.buildPythonPackage rec {
  pname = "surya-ocr";
  version = "0.17.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "datalab-to";
    repo = "surya";
    rev = "v${version}";
    hash = "sha256-VzugHhR4di+WCfiZDbiNJ+kA6lkAjjcWZV/4oG0sjxs=";
  };

  nativeBuildInputs = with python3Packages; [
    poetry-core
    pythonRelaxDepsHook
  ];

  pythonRelaxDeps = true;
  pythonRemoveDeps = [ "pre-commit" ];

  dependencies = with python3Packages; [
    click
    einops
    filetype
    opencv-python-headless
    pillow
    platformdirs
    pydantic
    pydantic-settings
    pypdfium2
    python-dotenv
    streamlit
    torch
    transformersCompat
  ];

  postPatch = ''
    substituteInPlace surya/scripts/run_streamlit_app.py \
      --replace-fail '["streamlit", "run",' '["${python3Packages.streamlit}/bin/streamlit", "run",'

    substituteInPlace surya/scripts/run_texify_app.py \
      --replace-fail '["streamlit", "run",' '["${python3Packages.streamlit}/bin/streamlit", "run",'
  '';

  postInstall = ''
    ln -s $out/bin/surya_ocr $out/bin/surya
  '';

  doCheck = false;
  doInstallCheck = true;
  installCheckPhase = ''
        runHook preInstallCheck
        $out/bin/surya --help >/dev/null
        ${python3Packages.streamlit}/bin/streamlit --help >/dev/null
        ${python3Packages.python.interpreter} - <<'PY'
    from transformers.onnx import OnnxConfig
    import surya

    print(OnnxConfig)
    print(surya.__name__)
    PY
        runHook postInstallCheck
  '';

  passthru = {
    category = "Utilities";
    inherit transformersCompat;
  };

  meta = {
    description = "OCR, layout, reading order, and table recognition toolkit";
    homepage = "https://github.com/datalab-to/surya";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "surya";
  };
}
