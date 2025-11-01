## Why

Currently, when Renovate creates PRs to update package versions, the hashes in the Nix package definitions become outdated and cause build failures. Manual intervention is required to update these hashes using `nix-update --version=skip`, which is time-consuming and error-prone across multiple platforms (aarch64-darwin, x86_64-linux, etc.).

## What Changes

- Add GitHub Actions workflow that automatically triggers on Renovate PRs
- Implement automatic hash updates using `nix-update --version=skip` for compatible packages
- Add build verification step to ensure updated packages compile successfully
- Support multi-platform hash updates (aarch64-darwin, x86_64-linux, x86_64-darwin, aarch64-linux)
- Focus on packages that don't require manual intervention (starting with GCS)
- Handle opencode package partially (TUI component works, main package requires manual intervention)

## Impact

- Affected specs: ci-cd (new capability)
- Affected code: New `.github/workflows/` directory, package definition files
- Reduces manual maintenance overhead for dependency updates
- Improves CI/CD reliability by ensuring hash consistency across platforms
