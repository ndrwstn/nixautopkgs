# Workflow Security

Comprehensive security measures prevent unauthorized auto-merge of PRs.

## Security Layers

### Actor Validation

- **Check**: `github.actor == 'renovate[bot]'`
- **Applied**: All workflow entry points

### Branch Validation

- **Check**: Branch starts with `update/` prefix
- **Purpose**: Renovate uses this pattern

### Title Validation

- **Check**: Matches `chore: update {package} to {version}`
- **Purpose**: Renovate follows this format

### Label Validation

- **Check**: PR has `dependencies` label
- **Applied**: Auto-merge workflow only

### State Validation

- **Check**: PR is open and mergeable
- **Applied**: Auto-merge workflow only

## Blocked Attack Vectors

✅ **Manual workflow dispatch** - Entry workflows don't allow manual triggers  
✅ **Actor impersonation** - GitHub platform prevents this  
✅ **Branch spoofing** - Multiple validation layers required  
✅ **Label manipulation** - Actor validation prevents this  
✅ **Title mimicking** - Actor + branch validation required  
✅ **Workflow injection** - All workflows validate PR origin

## Security Validation by Workflow

### `update-hash.yml`

- Actor is `renovate[bot]`
- Branch starts with `update/`
- Title matches pattern

### `test-builds.yml`

- PR author is `renovate[bot]`
- Commit SHA matches PR head
- Branch has Renovate prefix

### `auto-merge.yml`

- All above validations
- PR has `dependencies` label
- PR is open and mergeable
- Build success validated

## Monitoring

All validations log security checks with clear pass/fail messages for audit purposes.
