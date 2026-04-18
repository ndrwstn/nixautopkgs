{ lib
, runCommandNoCC
, fetchFromGitHub
, swift
, swiftpm
, swiftpm2nix
, swiftPackages
, stdenv
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
      #if canImport(Translation) && canImport(SwiftUI)
      import Foundation
      import Translation
      import SwiftUI

      @available(macOS 15.0, *)
      struct AppleTranslateOperation: TranslationOperation {
          let text: String
          let inputLanguage: String
          let outputLanguage: String

          func run() async throws -> TranslationResult {
              let translator = Translator(sourceLanguage: inputLanguage, targetLanguage: outputLanguage)

              let response = try await translator.run(text)

              return TranslationResult(
                  sourceText: text,
                  translatedText: response.targetText,
                  inputLanguage: inputLanguage,
                  outputLanguage: outputLanguage
              )
          }

          static func availability(from inputLanguage: String, to outputLanguage: String) async -> TranslationAvailability {
              let availability = LanguageAvailability()
              let status = await availability.status(from: .init(identifier: inputLanguage), to: .init(identifier: outputLanguage))

              switch status {
              case .supported: return .supported
              case .installed: return .installed
              case .unsupported: return .unsupported
              @unknown default: return .unsupported
              }
          }
      }

      // MARK: - Translation Shenanigans

      /**
       So, here's the thing: Translation was REALLY not meant to be run outside of an app's user interface,
       but I also REALLY wanted this capability in OCRIT, so I did what I had to do. Don't judge me.
       */
      @available(macOS 15.0, *)
      @MainActor
      private struct Translator {
          let sourceLanguage: String
          let targetLanguage: String

          private struct _UIShim: View {
              var sourceLanguage: String
              var targetLanguage: String
              var text: String
              var callback: (Result<TranslationSession.Response, Error>) -> ()

              var body: some View {
                  EmptyView()
                      .translationTask(source: .init(identifier: sourceLanguage), target: .init(identifier: targetLanguage)) { session in
                          do {
                              let result = try await session.translate(text)
                              callback(.success(result))
                          } catch {
                              callback(.failure(error))
                          }
                      }
              }
          }

          func run(_ text: String) async throws -> TranslationSession.Response {
              try await withCheckedThrowingContinuation { continuation in
                  let shim = _UIShim(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, text: text) {
                      continuation.resume(with: $0)
                  }

                  /// This somehow works when running from a SPM-based executable...
                  let window = NSWindow(contentViewController: NSHostingController(rootView: shim))
                  window.setFrame(.zero, display: false)
                  window.alphaValue = 0
                  window.makeKeyAndOrderFront(nil)
              }
          }
      }

      @available(macOS 15.0, *)
      extension TranslationSession: @retroactive @unchecked Sendable { }
      #else
      import Foundation

      struct AppleTranslateOperation: TranslationOperation {
          let text: String
          let inputLanguage: String
          let outputLanguage: String

          func run() async throws -> TranslationResult {
              throw Failure("Translation support requires a newer macOS SDK than the one available in this build environment.")
          }

          static func availability(from inputLanguage: String, to outputLanguage: String) async -> TranslationAvailability {
              .unsupported
          }
      }
      #endif
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

    passthru.nixautopkgs.upstream = {
      type = "github";
      owner = "insidegui";
      repo = "ocrit";
    };

    meta = meta // {
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
    };
  })
