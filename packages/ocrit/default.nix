{ lib
, runCommandNoCC
, fetchFromGitHub
, swift
, swiftpm
, swiftpm2nix
, swiftPackages
, stdenv
, nix-update-script
}:

let
  generated = swiftpm2nix.helpers ./nix;

  meta = {
    description = "OCR CLI for images and PDFs using Apple's Vision framework";
    homepage = "https://github.com/insidegui/ocrit";
    license = lib.licenses.bsd2;
    mainProgram = "ocrit";
    platforms = lib.platforms.darwin;
  };
in
if !stdenv.hostPlatform.isDarwin then
  runCommandNoCC "ocrit-unsupported-${stdenv.hostPlatform.system}"
  {
    inherit meta;
  } ''
    echo "error: ocrit is macOS-only because it depends on Apple's Vision framework and upstream only supports macOS 12+." >&2
    exit 1
  ''
else
  swiftPackages.stdenv.mkDerivation (finalAttrs: {
    pname = "ocrit";
    version = "1.1";

    src = fetchFromGitHub {
      owner = "insidegui";
      repo = "ocrit";
      rev = finalAttrs.version;
      hash = "sha256-E5EKL1MZjXTMHvISDhTnFw6ddX7eQduq/f5ePHSzsvo=";
    };

    postPatch = ''
      cat > Sources/ocrit/Implementation/AppleTranslateOperation.swift <<'EOF'
      import Foundation

      struct AppleTranslateOperation: TranslationOperation {
          let text: String
          let inputLanguage: String
          let outputLanguage: String

          func run() async throws -> TranslationResult {
              throw Failure("Translation support is disabled in this Nix build because the packaged Swift/macOS SDK toolchain does not expose Apple's Translation framework APIs.")
          }

          static func availability(from inputLanguage: String, to outputLanguage: String) async -> TranslationAvailability {
              .supported
          }
      }
      EOF

      cat > Sources/ocrit/Output.swift <<'EOF'
      import ArgumentParser
      import Foundation
      import PathKit

      enum Output {
          case stdOutput
          case path(Path)
      }

      extension Output: ExpressibleByArgument {
          init?(argument: String) {
              if argument == "-" {
                  self = .stdOutput
                  return
              }

              let path = Path(argument).absolute()
              self = .path(path)
          }
      }

      extension Output {
          var isStdOutput: Bool {
              switch self {
              case .stdOutput:
                  return true
              default:
                  return false
              }
          }

          var path: Path? {
              switch self {
              case let .path(path):
                  return path
              default:
                  return nil
              }
          }
      }
      EOF

      cat > Sources/ocrit/Path+ArgumentParser.swift <<'EOF'
      import ArgumentParser
      import PathKit

      extension Path: ExpressibleByArgument {
          public init?(argument: String) {
              self = Path(argument).absolute()
          }
      }
      EOF
    '';

    nativeBuildInputs = [
      swift
      swiftpm
    ];

    buildInputs = [
      swiftPackages.Foundation
    ];

    configurePhase = generated.configure;

    installPhase = ''
      runHook preInstall
      install -Dm755 "$(swiftpmBinPath)/ocrit" "$out/bin/ocrit"
      runHook postInstall
    '';

    passthru = {
      updateScript = nix-update-script { };
      nixautopkgs.upstream = {
        type = "github";
        owner = "insidegui";
        repo = "ocrit";
      };
    };

    meta = meta // {
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
    };
  })
