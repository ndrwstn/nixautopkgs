{ lib
, fetchFromGitHub
, python3Packages
, surya
}:

let
  version = "1.10.2";
  hash = "sha256-/1bvqkUGBJj5NpSeE0fksnAbVzlBolWQMn6OYdjAEdk=";

  pdftextVersion = "0.6.3";
  pdftextHash = "sha256-EGVjzjDWtdcEPX//cOm5+xm9FvX0aP+h6fsD25hC8gA=";

  pdftext = python3Packages.buildPythonPackage rec {
    pname = "pdftext";
    version = pdftextVersion;
    pyproject = true;

    src = fetchFromGitHub {
      owner = "datalab-to";
      repo = "pdftext";
      rev = "v${version}";
      hash = pdftextHash;
    };

    nativeBuildInputs = with python3Packages; [
      poetry-core
      pythonRelaxDepsHook
    ];

    pythonRelaxDeps = true;
    pythonRemoveDeps = [ "pre-commit" ];

    dependencies = with python3Packages; [
      click
      pydantic
      pydantic-settings
      pypdfium2
    ];

    pythonImportsCheck = [ "pdftext" ];
    doCheck = false;
  };

  transformersCompat = surya.passthru.transformersCompat or python3Packages.transformers;
in
python3Packages.buildPythonPackage rec {
  pname = "marker-pdf";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "datalab-to";
    repo = "marker";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = with python3Packages; [
    poetry-core
    pythonRelaxDepsHook
  ];

  pythonRelaxDeps = true;
  pythonRemoveDeps = [ "pre-commit" ];

  dependencies = with python3Packages; [
    anthropic
    click
    filetype
    fastapi
    ftfy
    google-genai
    markdown2
    markdownify
    openai
    pillow
    pydantic
    pydantic-settings
    python-multipart
    python-dotenv
    rapidfuzz
    regex
    scikit-learn
    surya
    streamlit
    pdftext
    torch
    tqdm
    transformersCompat
    uvicorn
  ];

  postPatch = ''
    substituteInPlace marker/scripts/run_streamlit_app.py \
      --replace-fail '"streamlit",' '"${python3Packages.streamlit}/bin/streamlit",'
  '';

  doCheck = false;
  doInstallCheck = true;
  installCheckPhase = ''
        runHook preInstallCheck
        $out/bin/marker --help >/dev/null
        ${python3Packages.streamlit}/bin/streamlit --help >/dev/null
        $out/bin/marker_server --help >/dev/null
        ${python3Packages.python.interpreter} - <<'PY'
    from transformers.onnx import OnnxConfig
    import fastapi
    import marker
    import multipart
    import uvicorn

    print(OnnxConfig)
    print(fastapi.__name__)
    print(marker.__name__)
    print(multipart.__name__)
    print(uvicorn.__name__)
    PY
        runHook postInstallCheck
  '';

  passthru.category = "Utilities";

  meta = {
    description = "Convert PDFs and images into markdown with structured OCR";
    homepage = "https://github.com/datalab-to/marker";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "marker";
  };
}
