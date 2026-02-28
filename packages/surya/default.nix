{ lib
, fetchFromGitHub
, python3Packages
}:

let
  transformersCompat = python3Packages.transformers.overridePythonAttrs (_: rec {
    version = "4.56.2";
    src = python3Packages.fetchPypi {
      pname = "transformers";
      inherit version;
      hash = "sha256-XnxiPi10lBBccm3RD2+QwsmaVevobu9yM3ZavQyxxSk=";
    };
  });
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
    torch
    transformersCompat
  ];

  postInstall = ''
    ln -s $out/bin/surya_ocr $out/bin/surya
  '';

  doCheck = false;
  doInstallCheck = true;
  installCheckPhase = ''
        runHook preInstallCheck
        $out/bin/surya --help >/dev/null
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
