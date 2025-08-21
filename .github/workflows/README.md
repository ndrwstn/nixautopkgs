# GitHub Actions Workflows

Automated CI/CD pipeline for Nix package updates via Renovate.

## Workflow Chain

```
Renovate PR → Hash Update → Build Matrix → Auto-merge
```

## Core Workflows

### `update-hash.yml` (Workflow 1/3)

- **Trigger**: Renovate PRs modifying `packages/*.nix`
- **Security**: Only `renovate[bot]` with `update/` branch prefix
- **Action**: Extracts package name, runs `bin/update-{package}`, commits hash updates
- **Next**: Triggers `test-builds.yml`

### `test-builds.yml` (Workflow 2/3)

- **Trigger**: Workflow dispatch from hash update
- **Security**: Validates Renovate PR origin and commit SHA
- **Action**: Matrix builds on all platforms (x86_64/aarch64 Linux/Darwin)
- **Next**: Triggers `auto-merge.yml` if all builds pass

### `auto-merge.yml` (Workflow 3/3)

- **Trigger**: Workflow dispatch from successful builds
- **Security**: Multi-layer validation (actor, branch, labels, title, state)
- **Action**: Squash merges validated Renovate PRs

## Security Features

- **Actor validation**: Only `renovate[bot]` can trigger automation
- **Branch validation**: Must start with `update/` (Renovate pattern)
- **Title validation**: Must match `chore: update {package} to {version}`
- **Label validation**: Must have `dependencies` label
- **State validation**: PR must be open and mergeable
- **No manual triggers**: Users cannot manually trigger auto-merge

## Supported Packages

- **gcs**: GURPS Character Sheet (`richardwilkes/gcs`)
- **opencode**: AI Coding Agent (`sst/opencode`)

## Platform Support

- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin
