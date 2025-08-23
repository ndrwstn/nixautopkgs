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
- **Check Transfer**: Automatically transfers existing checks to new commit after hash updates
- **Next**: Triggers `test-builds.yml`

### `test-builds.yml` (Workflow 2/3)

- **Trigger**: Workflow dispatch from hash update
- **Security**: Validates Renovate PR origin and commit SHA
- **Action**: Matrix builds on all platforms (x86_64/aarch64 Linux/Darwin)
- **Check Names**: Clear naming with "Build Matrix - {platform}" format
- **Next**: Triggers `auto-merge.yml` if all builds pass

### `check-transfer.yml` (Support Workflow)

- **Trigger**: Pull request synchronize events on Renovate PRs
- **Security**: Only `renovate[bot]` with `update/` branch prefix
- **Action**: Transfers checks from previous commit when manual commits are pushed
- **Prevention**: Skips transfer for commits made by hash update workflow to avoid loops

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

## Check Transfer System

The workflow pipeline includes an automated check transfer system to prevent checks from "falling off" PRs when commits are pushed:

### How It Works

1. **Hash Update Transfer**: When `update-hash.yml` pushes a new commit with hash updates, it automatically transfers all existing checks from the original commit to the new commit
2. **Manual Commit Transfer**: When manual commits are pushed to Renovate PRs, `check-transfer.yml` transfers checks from the previous commit
3. **Loop Prevention**: The system intelligently skips transferring its own workflow checks to prevent infinite loops
4. **Audit Trail**: Transferred checks are clearly marked with `[TRANSFERRED]` prefix and include links to original checks

### Benefits

- **Persistent Checks**: All checks remain visible on the PR regardless of new commits
- **Clear History**: Transferred checks maintain full audit trail with original timestamps and results
- **No Manual Intervention**: Fully automated with no user action required
- **Security Maintained**: Only works on validated Renovate PRs with proper security checks

## Supported Packages

- **gcs**: GURPS Character Sheet (`richardwilkes/gcs`)
- **opencode**: AI Coding Agent (`sst/opencode`)

## Platform Support

- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin
