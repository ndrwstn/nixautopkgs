# nixautopkgs Implementation Plan

## Overview

Replace the brittle custom scripts with a robust, metadata-driven system using nix-update for automated package maintenance. The system will handle Renovate PRs, update hashes for working platforms only, verify builds, provide detailed error feedback, and prepare for automatic merging.

## Architecture

### 1. Package Metadata System

**Location**: Each package file (`packages/*.nix`) will include standardized metadata in the `meta.nixautopkgs` section.

**Structure**:

```nix
meta = {
  # ... existing meta fields
  nixautopkgs = {
    upstream = "owner/repo";
    nixpkgsPath = "path/to/nixpkgs/package.nix";
    updateConfig = {
      # Update behavior flags
      hasSubPackages = false;           // For packages like opencode with multiple derivations
      subPackages = [];                 // List of subpackage names if hasSubPackages = true
      updateVersion = true;             // Whether to update version (false for hash-only updates)
      buildAfterUpdate = true;          // Whether to build after hash updates

      # Platform configuration
      supportedPlatforms = [            // Platforms to update (overrides meta.platforms)
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Build configuration
      buildSystems = [                  // Systems to build on (may differ from supportedPlatforms)
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };
  };
};
```

### 2. Simplified Workflow Pipeline

**Trigger**: Renovate creates PR with version update

**Steps**:

1. **Parse PR**: Extract package name from Renovate PR title
2. **Read Metadata**: Load package configuration from `meta.nixautopkgs.updateConfig`
3. **Update Hashes**: Use nix-update with appropriate flags based on metadata
4. **Build Matrix**: Test builds on configured platforms
5. **Report Results**: Comment on PR with detailed status
6. **Prepare Merge**: Mark as ready for merge (future: auto-merge)

### 3. nix-update Integration

**Command Generation**:

```bash
# Simple package (gcs)
nix-update --commit --build gcs

# Complex package (opencode with subpackages)
nix-update --commit --build --subpackage tui --subpackage node_modules opencode
```

**Platform Handling**:

- Use `--system` flag for platform-specific hash updates
- Skip platforms marked as broken in package metadata
- Parallel hash updates for multiple platforms

### 4. Error Handling & Feedback

**Failure Scenarios**:

- Hash update fails: Comment with error details, assign for manual intervention
- Build fails on platform: Comment with platform-specific build logs, assign
- Partial success: Report successful platforms, detail failures

**Feedback Format**:

```markdown
## Update Results for {package}

✅ Hash Updates: Successful
✅ Build x86_64-linux: Successful  
✅ Build x86_64-darwin: Successful
❌ Build aarch64-darwin: Failed

### Error Details

[Platform-specific error logs]

### Next Steps

@ndrwstn Manual intervention required for aarch64-darwin build failure.
```

### 5. Workflow Implementation

**File Structure**:

```
.github/workflows/
  └── update-packages.yml    # New simplified workflow
bin/
  └── build-package          # Keep for manual builds
packages/
  ├── gcs.nix               # Updated with metadata
  └── opencode.nix          # Updated with metadata
```

**Workflow Jobs**:

1. **parse-pr**: Extract package and validate
2. **update-hashes**: Run nix-update based on metadata
3. **build-matrix**: Test on configured platforms
4. **report-results**: Comment and assign if needed
5. **prepare-merge**: Mark ready (future: auto-merge)

### 6. Migration Strategy

**Phase 1**: Update package metadata

- Add `updateConfig` to gcs.nix and opencode.nix
- Test metadata parsing logic

**Phase 2**: Replace workflow

- Create new `update-packages.yml` workflow
- Test with existing packages
- Disable old `update-build.yml`

**Phase 3**: Remove legacy scripts

- Delete `update-gcs` and `update-opencode` scripts
- Clean up unused workflow files

### 7. Future Cachix Integration

**Preparation**:

- Workflow structure designed to add cachix push step after successful builds
- Metadata ready for cache configuration (stored separately)
- No breaking changes required

**Integration Point**:

```yaml
# After successful builds
- name: Push to Cachix
  if: success()
  uses: cachix/cachix-action@vX
  with:
    name: ${{ env.CACHIX_CACHE_NAME }}
    authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

## Benefits

1. **Robustness**: Leverages mature nix-update tool instead of custom scripts
2. **Maintainability**: Abstract metadata reduces coupling to specific tool flags
3. **Scalability**: Easy to add new packages by just adding metadata
4. **Reliability**: Better error handling and detailed feedback
5. **Future-Proof**: Ready for auto-merge and cachix integration

## Implementation Order

1. Add metadata to existing package files
2. Create new workflow with nix-update integration
3. Test with Renovate PRs
4. Remove legacy scripts and workflows
5. Document new system

This plan eliminates 247+ lines of custom script code while providing a more reliable, maintainable system that can grow to support additional packages with minimal overhead.
