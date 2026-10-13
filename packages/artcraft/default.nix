{ pkgs }:

let
  common = pkgs.callPackage ./common.nix { };
in
{
  photocraft = common {
    pname = "photocraft";
    displayName = "PhotoCraft";
    version = "0.8.2";
    description = "Raster photo editor written in Rust";
    sourceHash = "sha256-kqKpZ8IBPmCd93XXvyxyAjPjJEWFfZh49qQc9KMSp4Y=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  vectorcraft = common {
    pname = "vectorcraft";
    displayName = "VectorCraft";
    version = "0.10.0";
    description = "Vector graphics editor written in Rust";
    sourceHash = "sha256-Z663KKE+y80cuKrTeTVg8V4+HFd6sM4Bg3gq7fVL2/k=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "craft-print-0.1.0" = "sha256-J/EJJeDDWXc+QQtpUqnAKKA4piOdPRbH3uG1ms2BRgY=";
    };
  };

  filmcraft = common {
    pname = "filmcraft";
    displayName = "FilmCraft";
    version = "0.7.2";
    description = "Nonlinear video editor written in Rust";
    sourceHash = "sha256-mjOCE4SwtooJ2hU1dUeu407Exh0BDmwAwqTcF+SMwEc=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  lightcraft = common {
    pname = "lightcraft";
    displayName = "LightCraft";
    version = "0.7.1";
    description = "Nondestructive photo and RAW editor written in Rust";
    sourceHash = "sha256-QJROx0tqJsehBJyknfzGLlvSPERax170ErB0PWdzOFI=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  effectcraft = common {
    pname = "effectcraft";
    displayName = "EffectCraft";
    version = "0.9.2";
    description = "Motion graphics and compositing tool written in Rust";
    sourceHash = "sha256-Ra2oQ+ynFhcRS/X6xpiYXC60vNjOKvrDS3J2f8HipeE=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    } // pkgs.lib.genAttrs [
      "filmcraft-aac-0.1.1"
      "filmcraft-ac3-0.1.1"
      "filmcraft-av1-0.1.1"
      "filmcraft-bitstream-0.1.1"
      "filmcraft-cfb-0.1.1"
      "filmcraft-codecs-0.1.1"
      "filmcraft-color-0.1.1"
      "filmcraft-dnx-0.1.1"
      "filmcraft-frame-0.1.1"
      "filmcraft-geom-0.1.1"
      "filmcraft-h264-0.1.1"
      "filmcraft-h264enc-0.1.1"
      "filmcraft-hevc-0.1.1"
      "filmcraft-interchange-0.1.1"
      "filmcraft-isobmff-0.1.1"
      "filmcraft-matroska-0.1.1"
      "filmcraft-media-0.1.1"
      "filmcraft-mpeg2v-0.1.1"
      "filmcraft-mpegts-0.1.1"
      "filmcraft-mxf-0.1.1"
      "filmcraft-ogg-0.1.1"
      "filmcraft-opus-0.1.1"
      "filmcraft-project-0.1.1"
      "filmcraft-prores-0.1.1"
      "filmcraft-time-0.1.1"
      "filmcraft-vp9-0.1.1"
    ]
      (_: "sha256-WXiX4rF7zSwfu3yu9aNH2/xWYhAYFVX1rdrnccuTD7g=");
  };

  designcraft = common {
    pname = "designcraft";
    displayName = "DesignCraft";
    version = "0.7.1";
    description = "Page layout and publishing editor written in Rust";
    sourceHash = "sha256-9pCZ8SRT9EqIkz4i/EAGM0FJJSn/YzxC4zZhgwRx31E=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "craft-print-0.1.0" = "sha256-J/EJJeDDWXc+QQtpUqnAKKA4piOdPRbH3uG1ms2BRgY=";
    };
  };

  pdfcraft = common {
    pname = "pdfcraft";
    displayName = "PdfCraft";
    version = "0.7.1";
    description = "PDF reader and editor written in Rust";
    sourceHash = "sha256-NX13tMfH0Vlaas8XUrU2gCafBznsJNofsz5umoM6oFM=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "craft-print-0.1.0" = "sha256-J/EJJeDDWXc+QQtpUqnAKKA4piOdPRbH3uG1ms2BRgY=";
    };
  };

  deckcraft = common {
    pname = "deckcraft";
    displayName = "DeckCraft";
    version = "0.6.1";
    description = "Presentation and slide editor written in Rust";
    sourceHash = "sha256-c6uNNn58NsSeAoa87AU2bIMhCWmgPk/HoJ11IRhU4HU=";
  };

  gridcraft = common {
    pname = "gridcraft";
    displayName = "GridCraft";
    version = "0.6.1";
    description = "Spreadsheet editor written in Rust";
    sourceHash = "sha256-w9OnCWA/uZ5tD6L6bRzRa9U7hpsZSeol9plWCoyYAEg=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-u2AR5YZZSRzhWaevgR2S/jofD99J3YWKJA+CktUJbRY=";
      "craft-print-0.1.0" = "sha256-u2AR5YZZSRzhWaevgR2S/jofD99J3YWKJA+CktUJbRY=";
    };
  };

  cadcraft = common {
    pname = "cadcraft";
    displayName = "CADCraft";
    version = "0.6.2";
    description = "Computer-aided design and drafting application written in Rust";
    sourceHash = "sha256-kyNUKQvYg9SLE7E7LD/qBMAcxueEPdP9XRz9+H82I1M=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  soundcraft = common {
    pname = "soundcraft";
    displayName = "SoundCraft";
    version = "0.6.1";
    description = "Digital audio workstation written in Rust";
    sourceHash = "sha256-VC9DzuzajyGr82cEKPpgc0rezU9lJdaGNKd+foazRU8=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  wordcraft = common {
    pname = "wordcraft";
    displayName = "WordCraft";
    version = "0.6.1";
    description = "Word processor written in Rust";
    sourceHash = "sha256-10djkguZ4kJBvZTH5Oni5D0XZrfe1gayy7WhsBlpd+0=";
  };

  figcraft = common {
    pname = "figcraft";
    displayName = "FigCraft";
    version = "0.5.1";
    description = "Interface design and prototyping tool written in Rust";
    sourceHash = "sha256-fA92f+eJ9KI5HklXzRsPF6XWTNCVYmbonHyY4HBm5L4=";
  };
}
