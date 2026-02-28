{ lib
, fetchFromGitHub
, python3Packages
}:

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
    transformers
  ];

  pythonImportsCheck = [ "surya" ];
  doCheck = false;

  passthru.category = "Utilities";

  meta = {
    description = "OCR, layout, reading order, and table recognition toolkit";
    homepage = "https://github.com/datalab-to/surya";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "surya_ocr";
  };
}
