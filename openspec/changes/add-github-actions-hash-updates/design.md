## Context

The project uses Renovate for automated dependency updates, but Nix package definitions require hash updates when versions change. Currently, this requires manual intervention using `nix-update --version=skip` across multiple platforms. The manual process is documented in `20251031_actions.md` and involves checking out renovate PR branches and running hash updates for each affected package.

## Goals / Non-Goals

**Goals:**

- Automate hash updates for renovate PRs using GitHub Actions
- Support multi-platform builds (aarch64-darwin, x86_64-linux, x86_64-darwin, aarch64-linux)
- Focus on packages that don't require manual intervention (GCS works fully, OpenCode TUI works)
- Provide build verification after hash updates
- Maintain PR author information and commit structure

**Non-Goals:**

- Handle all packages automatically (some require manual intervention)
- Implement complex merge conflict resolution
- Support packages with complex update requirements beyond hash updates
- Replace manual intervention for packages that fundamentally require it

## Decisions

**Decision: Use GitHub Actions for automation**

- **Rationale**: Native integration with GitHub PRs, free for public repos, supports matrix builds
- **Alternatives considered**: External CI systems, custom webhooks - rejected due to complexity

**Decision: Trigger on PR creation and updates from renovate bot**

- **Rationale**: Ensures hash updates happen as soon as version changes are proposed
- **Alternatives considered**: Scheduled runs, manual triggers - rejected due to timeliness

**Decision: Use matrix strategy for multi-platform builds**

- **Rationale**: Allows parallel execution across platforms, faster feedback
- **Alternatives considered**: Sequential builds - rejected due to performance

**Decision: Focus on "version=skip" pathway initially**

- **Rationale**: Matches current manual process, handles hash-only updates
- **Alternatives considered**: Full version updates - rejected due to complexity and manual intervention requirements

**Decision: Separate handling for GCS vs OpenCode packages**

- **Rationale**: GCS updates work fully automated, OpenCode requires partial manual intervention
- **Alternatives considered**: One-size-fits-all approach - rejected due to package-specific requirements

## Risks / Trade-offs

**Risk: Build failures on some platforms**

- **Mitigation**: Report platform-specific results, allow manual intervention for failed platforms

**Risk: Merge conflicts with existing PR changes**

- **Mitigation**: Implement proper git pull/rebase before committing hash updates

**Risk: Race conditions with multiple renovate PRs**

- **Mitigation**: GitHub Actions concurrency controls, proper branch management

**Risk: Complex error scenarios in nix-update**

- **Mitigation**: Comprehensive error capture and reporting, continue processing other packages

## Migration Plan

1. **Phase 1**: Implement basic workflow for GCS package only
2. **Phase 2**: Add OpenCode TUI component support
3. **Phase 3**: Add comprehensive error handling and reporting
4. **Phase 4**: Test with real renovate PRs and refine based on feedback

**Rollback**: Disable workflow by removing the YAML file or commenting out triggers

## Open Questions

- How to handle packages that require manual intervention beyond hash updates?
- Should we implement automatic PR approval for successful hash updates?
- How to handle cases where nix-update succeeds but builds fail due to other issues?
- What's the optimal concurrency strategy for matrix builds?
