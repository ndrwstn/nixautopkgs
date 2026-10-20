{ pkgs }:

let
  common = pkgs.callPackage ./common.nix { };
in
{
  photocraft = common {
    pname = "photocraft";
    displayName = "PhotoCraft";
    version = "0.9.0";
    description = "Raster photo editor written in Rust";
    sourceHash = "sha256-muKVyGM/lG0Ffav5wk4SbinrPkoCzvBYmcpM/Vwp6bk=";
    outputHashes = {
      "craft-print-0.1.0" = "sha256-uXP0zITi8i1JDUyc451FmZ0Pl1ZK4D0rlTJQmGFVm0I=";
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "craft-winprint-gdi-0.1.0" = "sha256-n1pcNaBGrnvSsE5MedeSRczJOMhfmF/LGFiiDTrG1GM=";
      "winprint-0.2.1" = "sha256-wnz/VbqQ3j/x1PEq6Elxu/oSjVqdONfqQmZ31NsTIIc=";
    };
  };

  vectorcraft = common {
    pname = "vectorcraft";
    displayName = "VectorCraft";
    version = "0.12.0";
    description = "Vector graphics editor written in Rust";
    sourceHash = "sha256-8wlih5NQtcDBRBv7wJ+AQP3M5yHSAYpT+5xDEFiS4yY=";
    outputHashes = {
      "craft-pdf-0.1.0" = "sha256-6r1iIlwK6HlUkascw0e4R9L2H5WMgKO2y6PEa51Flws=";
      "craft-print-0.1.0" = "sha256-J/EJJeDDWXc+QQtpUqnAKKA4piOdPRbH3uG1ms2BRgY=";
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "hayro-interpret-0.7.0" = "sha256-6r1iIlwK6HlUkascw0e4R9L2H5WMgKO2y6PEa51Flws=";
      "hayro-jbig2-0.3.0" = "sha256-6r1iIlwK6HlUkascw0e4R9L2H5WMgKO2y6PEa51Flws=";
      "hayro-syntax-0.7.2" = "sha256-6r1iIlwK6HlUkascw0e4R9L2H5WMgKO2y6PEa51Flws=";
      "krilla-0.8.2" = "sha256-6r1iIlwK6HlUkascw0e4R9L2H5WMgKO2y6PEa51Flws=";
    };
  };

  filmcraft = common {
    pname = "filmcraft";
    displayName = "FilmCraft";
    version = "0.8.0";
    description = "Nonlinear video editor written in Rust";
    sourceHash = "sha256-CxmUZ0felNb371LiQy1bNOfc2V/16DixvCkzyuFRhMM=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  lightcraft = common {
    pname = "lightcraft";
    displayName = "LightCraft";
    version = "0.8.0";
    description = "Nondestructive photo and RAW editor written in Rust";
    sourceHash = "sha256-a84KDuTcYNsf5Te4U2PYOp2P1VwK0sGoJ0qIxaRjR80=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  effectcraft = common {
    pname = "effectcraft";
    displayName = "EffectCraft";
    version = "0.10.0";
    description = "Motion graphics and compositing tool written in Rust";
    sourceHash = "sha256-3a5aeR9L6iS1nWdZQPlm+4RmrOIfrHzgzL+tABwctCc=";
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
    version = "0.8.0";
    description = "Page layout and publishing editor written in Rust";
    sourceHash = "sha256-Ze5eAiIZkL1ccTFA6dNZ9TG6/SxuIb9c8/v0v0dwX2Y=";
    outputHashes = {
      "craft-print-0.1.0" = "sha256-J/EJJeDDWXc+QQtpUqnAKKA4piOdPRbH3uG1ms2BRgY=";
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "hayro-0.7.1" = "sha256-xGbwY2SCjT1QTwVczSm3kSOxpweYfjd/2zgGk7EhqCE=";
      "hayro-interpret-0.7.0" = "sha256-xGbwY2SCjT1QTwVczSm3kSOxpweYfjd/2zgGk7EhqCE=";
      "hayro-jbig2-0.3.0" = "sha256-xGbwY2SCjT1QTwVczSm3kSOxpweYfjd/2zgGk7EhqCE=";
      "hayro-syntax-0.7.2" = "sha256-xGbwY2SCjT1QTwVczSm3kSOxpweYfjd/2zgGk7EhqCE=";
      "winit-0.30.13" = "sha256-q1gDwAj8xU/2OC4CtCG72ZvrkZ436V3zsqh5hovLTcs=";
    };
  };

  pdfcraft = common {
    pname = "pdfcraft";
    displayName = "PdfCraft";
    version = "0.8.0";
    description = "PDF reader and editor written in Rust";
    sourceHash = "sha256-gPd3NSEaeBEP5m0zUHI92vrqPd0pQSItuF44ZHaTnco=";
    outputHashes = {
      "craft-print-0.1.0" = "sha256-QtSjPVQSYsqqmg/9mtfC4ueAFcZ3IcL4gb29B+BfgmY=";
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
      "winprint-0.2.1" = "sha256-wnz/VbqQ3j/x1PEq6Elxu/oSjVqdONfqQmZ31NsTIIc=";
    };
    postPatch = ''
      patch -d "$cargoDepsCopy" -p1 < ${./rten-gemm-0.26-vpdpbusd-inline-asm.patch}
    '';
  };

  deckcraft = common {
    pname = "deckcraft";
    displayName = "DeckCraft";
    version = "0.7.0";
    description = "Presentation and slide editor written in Rust";
    sourceHash = "sha256-MEocLbrEyQ2X+YTxmbsqg69Eox/X7NIFySvuFDMbKV8=";
  };

  gridcraft = common {
    pname = "gridcraft";
    displayName = "GridCraft";
    version = "0.7.0";
    description = "Spreadsheet editor written in Rust";
    sourceHash = "sha256-8qlbNJWvONfZ8BvY8fij1QrLwoikFKBgmTiklpu4LOM=";
    outputHashes = {
      "craft-print-0.1.0" = "sha256-u2AR5YZZSRzhWaevgR2S/jofD99J3YWKJA+CktUJbRY=";
      "craft-ui-0.1.0" = "sha256-u2AR5YZZSRzhWaevgR2S/jofD99J3YWKJA+CktUJbRY=";
    };
  };

  cadcraft = common {
    pname = "cadcraft";
    displayName = "CADCraft";
    version = "0.7.0";
    description = "Computer-aided design and drafting application written in Rust";
    sourceHash = "sha256-/7mlDxYCeE6vKKJWghfMj4WtHbjPWfPnhb+HoHgA0q4=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  soundcraft = common {
    pname = "soundcraft";
    displayName = "SoundCraft";
    version = "0.7.0";
    description = "Digital audio workstation written in Rust";
    sourceHash = "sha256-5jtnIqtpPF68JQfIGIjXHrW//4Xwkzs7OOXGKZ6hfxg=";
    outputHashes = {
      "craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
    };
  };

  wordcraft = common {
    pname = "wordcraft";
    displayName = "WordCraft";
    version = "0.7.0";
    description = "Word processor written in Rust";
    sourceHash = "sha256-SfrnSydUVuh+3tJ69OINsc1thkubgVh8aEVBfZyXmsM=";
    outputHashes = {
      "craft-print-0.1.0" = "sha256-u2AR5YZZSRzhWaevgR2S/jofD99J3YWKJA+CktUJbRY=";
      "craft-ui-0.1.0" = "sha256-u2AR5YZZSRzhWaevgR2S/jofD99J3YWKJA+CktUJbRY=";
    };
  };

  figcraft = common {
    pname = "figcraft";
    displayName = "FigCraft";
    version = "0.6.0";
    description = "Interface design and prototyping tool written in Rust";
    sourceHash = "sha256-+tZk3xkpazqOn8oCwOLmFCIDtwfIxrpVgfZkq3xDvTM=";
  };
}
