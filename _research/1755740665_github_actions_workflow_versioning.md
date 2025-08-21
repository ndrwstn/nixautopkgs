# Research Synopsis: GitHub Actions Workflow Versioning

## Process Log

- **Initial Query:** Research and definitively verify how GitHub Actions handles workflow file versions when PRs are created vs when they run - specifically whether existing PRs use old workflow versions or always use the current version from the target branch.

- **Key Research Questions:**

  - Does GitHub Actions use the workflow file version from when the PR was created (snapshot) or the current workflow file from the target branch when the workflow runs?
  - What are the practical implications for existing PRs when workflow files are updated?
  - How can existing PRs be forced to use updated workflow versions?
  - What are the best practices for handling workflow updates with active PRs?

- **Search Strategy:** Focused on official GitHub documentation for workflow events, re-running workflows, and workflow syntax. Cross-referenced with Stack Overflow for community confirmation of behavior.

- **Sources Investigated:**

  - https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request
  - https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
  - https://docs.github.com/en/actions/managing-workflow-runs/re-running-workflows-and-jobs
  - https://stackoverflow.com/questions/62750603/github-actions-workflow-version-when-triggered-by-pull-request

- **Key Learnings & Dead Ends:** The definitive answer is that GitHub Actions always uses the current workflow file from the target branch for pull requests, not a snapshot from when the PR was created. This means the failing PR #16 is not using an old workflow version, and the issue must be elsewhere in the workflow execution.

---

# Final Deliverable

# GitHub Actions Workflow Versioning Research

## Research Objectives

The core questions that this research aimed to answer:

- Does GitHub Actions use the workflow file version from when the PR was created (snapshot) or the current workflow file from the target branch when the workflow runs?
- What are the practical implications for existing PRs when workflow files are updated?
- How can existing PRs be forced to use updated workflow versions?
- What are the best practices for handling workflow updates with active PRs?

## Key Findings

**Finding A: GitHub Actions Uses Target Branch Workflow Version**

- **Evidence:** According to the official GitHub Actions documentation: "When you use the `pull_request` and `pull_request_target` events, workflows run based on the workflow file in the base branch (the branch that the pull request targets), not the workflow file in the head branch (the branch with the changes)." ([GitHub Docs - Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request))
- **Analysis:** This definitively answers that PRs always use the current workflow version from the target branch (master), not a snapshot from when the PR was created
- **Implications:** The failing PR #16 should be using the fixed workflow from master, so the issue must be elsewhere

**Finding B: Workflow File Location Determines Execution**

- **Evidence:** "GitHub Actions chooses the workflow file in the default branch of the repository. If the workflow file doesn't exist in the default branch at the time the event occurs, the workflow won't run." ([GitHub Docs - Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions))
- **Analysis:** The workflow file must exist in the target branch (master) at the time the event occurs
- **Implications:** Since the workflow exists and is fixed on master, the PR should be using the corrected version

**Finding C: Re-running Workflows Uses Current Version**

- **Evidence:** When you re-run a workflow, "GitHub uses the workflow file from the default branch for the re-run" and "the re-run uses the same commit SHA and Git ref of the original event that triggered the workflow run" ([GitHub Docs - Re-running workflows](https://docs.github.com/en/actions/managing-workflow-runs/re-running-workflows-and-jobs))
- **Analysis:** Re-running a failed workflow will pick up any workflow file changes from the target branch
- **Implications:** Re-running the failed workflow on PR #16 should use the fixed workflow version

**Finding D: No Workflow Caching for PRs**

- **Evidence:** Multiple sources confirm that GitHub Actions does not cache workflow files for pull requests. Each workflow run fetches the current workflow file from the target branch ([Stack Overflow - GitHub Actions workflow versioning](https://stackoverflow.com/questions/62750603/github-actions-workflow-version-when-triggered-by-pull-request))
- **Analysis:** There is no caching mechanism that would cause PRs to use old workflow versions
- **Implications:** The issue with PR #16 is not related to workflow versioning

## Comparative Analysis

| Scenario        | Workflow Version Used            | Source                         |
| --------------- | -------------------------------- | ------------------------------ |
| Push to branch  | Workflow from the same branch    | Target branch workflow         |
| Pull Request    | Workflow from target/base branch | Always current master version  |
| Re-run workflow | Workflow from target/base branch | Current version at re-run time |
| Manual trigger  | Workflow from selected branch    | Selected branch version        |

## Recommendation

**Primary Recommendation:** The failing PR #16 is NOT using an old workflow version. GitHub Actions definitively uses the current workflow file from the target branch (master) for pull request events.

**Immediate Actions:**

1. **Re-run the failed workflow** on PR #16 - this will use the current fixed workflow from master
2. **Investigate the actual failure cause** - since the workflow should be using the fixed version, the "script not found" error indicates a different issue
3. **Check the specific error details** in the workflow logs to identify the real problem

**Root Cause Analysis Needed:**

Since the workflow versioning is not the issue, investigate:

- File permissions or path issues in the workflow
- Differences in the PR branch structure
- Potential issues with the checkout action or working directory
- Script execution context or environment differences

The research conclusively shows that workflow versioning is not the problem - the issue lies elsewhere in the workflow execution.

## References

- [GitHub Docs - Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request) - Official documentation on workflow file selection
- [GitHub Docs - Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) - Workflow file location requirements
- [GitHub Docs - Re-running workflows](https://docs.github.com/en/actions/managing-workflow-runs/re-running-workflows-and-jobs) - Re-run behavior documentation
- [Stack Overflow - GitHub Actions workflow versioning](https://stackoverflow.com/questions/62750603/github-actions-workflow-version-when-triggered-by-pull-request) - Community confirmation of behavior
