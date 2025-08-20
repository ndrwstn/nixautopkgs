# GitHub Actions Workflow Architecture

This repository uses a modular GitHub Actions workflow architecture that separates concerns into focused, reusable components.

## Workflow Components

### 1. Package Detection (`detect-package.yml`)

**Purpose:** Identifies which package needs to be updated from Renovate PRs or manual input.

**Triggers:**

- Pull requests that modify `packages/*.nix`
- Manual workflow dispatch with package selection

**Outputs:**

- `package`: The detected package name (gcs, opencode, or all)
- `should-update`: Whether an update should proceed
- `pr-number`: The PR number (if applicable)

**Flow:** Parses PR titles or manual input → Triggers hash update workflow

### 2. Hash Update Component (`update-hashes.yml`)

**Purpose:** Updates package hashes for the specified package and triggers build validation.

**Triggers:**

- Workflow dispatch from detect-package workflow
- Pull requests that modify `packages/*.nix`

**Inputs:**

- `package`: Package to update (gcs, opencode, or all)
- `pr_number`: PR number (if applicable)

**Flow:** Updates hashes → Commits changes → Triggers build validation → Triggers auto-merge (if successful)

### 3. Build Validation Component (`update-build.yml`)

**Purpose:** Validates builds across all supported platforms for the specified package.

**Triggers:**

- Workflow dispatch from hash update workflow

**Inputs:**

- `package`: Package to validate (gcs, opencode, or all)
- `pr_number`: PR number (if applicable)

**Platforms Tested:**

- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin

**Flow:** Runs builds on all platforms → Reports results → Triggers auto-merge (if successful)

### 4. Auto-merge (`auto-merge.yml`)

**Purpose:** Automatically merges PRs when all builds pass.

**Triggers:**

- Workflow dispatch from build validation workflow (when builds pass)
- Direct PR events (legacy compatibility)

**Flow:** Validates build success → Merges PR or reports failure

## Workflow Execution Flow

```
PR Created/Updated (Renovate)
         ↓
Package Detection (detect-package.yml)
         ↓
Hash Update (update-hashes.yml)
         ↓
Build Validation (update-build.yml)
         ↓
Auto-merge (auto-merge.yml)
```

## Benefits of Modular Architecture

### 1. **Separation of Concerns**

- Each workflow has a single, focused responsibility
- Easier to understand, debug, and maintain
- Clear boundaries between different operations

### 2. **Reusability**

- Components can be triggered independently
- Manual testing of specific components
- Flexible orchestration patterns

### 3. **Better Error Handling**

- Isolated failure points
- Specific error reporting for each component
- Easier troubleshooting and debugging

### 4. **Maintainability**

- Smaller, focused workflow files
- Easier to modify individual components
- Clear dependency relationships

### 5. **Backward Compatibility**

- Legacy orchestrator maintains existing behavior
- Gradual migration path
- No disruption to existing processes

## Manual Usage

### Test a Specific Package

```bash
# Trigger hash update for GCS only
gh workflow run update-hashes.yml -f package=gcs

# Test builds for OpenCode only
gh workflow run update-build.yml -f package=opencode
```

### Full Manual Update

```bash
# Trigger full update process
gh workflow run detect-package.yml
```

## Migration Notes

- **Existing behavior preserved:** All existing triggers and functionality remain the same
- **New capabilities added:** Individual component testing and manual orchestration
- **No breaking changes:** Renovate PRs continue to work as before
- **Enhanced debugging:** Each component can be tested independently

## Monitoring and Debugging

1. **Check workflow runs:** Each component creates separate workflow runs for better visibility
2. **Component isolation:** Issues can be traced to specific components
3. **Manual testing:** Individual components can be triggered for testing
4. **Clear logging:** Each workflow provides detailed logging for its specific function

This modular architecture provides a robust, maintainable foundation for the repository's CI/CD processes while preserving all existing functionality.
