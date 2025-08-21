# Research Synopsis: GitHub Actions Workflow Dispatch Branch Selection

## Process Log

- **Initial Query:** Research the complex logic around GitHub Actions workflow dispatch and branch selection to understand the correct approach for the nixautopkgs automation pipeline
- **Key Research Questions:**
  - What does the `ref` parameter control in `createWorkflowDispatch`?
  - Should workflow definitions come from the trusted master branch or PR branch?
  - How does this interact with security validation and code checkout?
  - What are the security implications and best practices?
- **Search Strategy:** GitHub official documentation, Security Lab articles, real-world code examples from major projects, security best practices analysis
- **Sources Investigated:**
  - https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event
  - https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch
  - https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
  - https://securitylab.github.com/resources/github-actions-preventing-pwn-requests
  - Real-world examples from Facebook React Native, Microsoft TypeScript, Sentry, Vercel, AWS, and others
- **Key Learnings & Dead Ends:**
  - The `ref` parameter controls workflow definition source, not checkout target
  - Industry standard is to use main/master branch for security
  - The issue is in branch validation logic, not workflow dispatch architecture
  - Dead end: Searching for `workflow_dispatch.*checkout` patterns yielded no relevant results

---

# Final Deliverable

# GitHub Actions Workflow Dispatch and Branch Selection Research Report

## 1. Executive Summary

The `ref` parameter in GitHub Actions `createWorkflowDispatch` determines **which version of the workflow file is executed**, not which code is checked out. For security-sensitive automation pipelines like nixautopkgs, using `ref: 'master'` ensures that workflow definitions come from the trusted main branch, preventing malicious PR authors from modifying workflow logic. The current implementation is correct and follows security best practices.

## 2. Research Objectives

This research aimed to answer:

- What does the `ref` parameter control in `createWorkflowDispatch`?
- Should workflow definitions come from the trusted master branch or PR branch?
- How does this interact with security validation and code checkout?
- What are the security implications and best practices?

## 3. Key Findings

**Finding A: `ref` Parameter Controls Workflow Definition Source**

- **Evidence:** GitHub's official documentation states: "The git reference for the workflow. The reference can be a branch or tag name." This determines which version of the workflow YAML file is executed.
- **Analysis:** The `ref` parameter does NOT control which code gets checked out - that's handled by the `checkout` action's `ref` parameter.
- **Implications:** Using `ref: 'master'` ensures the workflow logic comes from the trusted main branch, preventing malicious modifications.

**Finding B: Security Best Practice Supports Master Branch Reference**

- **Evidence:** GitHub Security Lab's "Preventing pwn requests" article warns: "Combining `pull_request_target` workflow trigger with an explicit checkout of an untrusted PR is a dangerous practice that may lead to repository compromise."
- **Analysis:** While this applies to `pull_request_target`, the same principle applies to workflow dispatch - workflow definitions should come from trusted sources.
- **Implications:** Using `ref: 'master'` prevents attackers from modifying workflow security validation logic.

**Finding C: Real-World Patterns Confirm Master Branch Usage**

- **Evidence:** Analysis of major projects shows consistent patterns:
  - Sentry: `ref: 'master'`
  - Vercel: `ref: 'main'`
  - Microsoft TypeScript: `ref: "main"`
  - AWS EKS AMI: `ref: 'main'`
- **Analysis:** Industry standard is to use the main/master branch for workflow dispatch.
- **Implications:** The nixautopkgs implementation follows established best practices.

**Finding D: Security Validation Logic Must Match Repository State**

- **Evidence:** The current nixautopkgs security validation checks `pr.head.ref.startsWith('update/')` but the branch prefix check is failing.
- **Analysis:** The issue is not with the `ref` parameter but with the branch validation logic expecting a different prefix pattern.
- **Implications:** The security validation needs to be updated to match the actual Renovate branch naming pattern.

## 4. Comparative Analysis

| Approach         | Pros                                                                                       | Cons                                                   | Recommendation  |
| ---------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------ | --------------- |
| `ref: 'master'`  | Trusted workflow definitions, prevents malicious workflow modifications, industry standard | Workflow file updates require rebase of open PRs       | **Recommended** |
| `ref: branchRef` | Uses latest workflow from PR branch                                                        | Allows malicious workflow modifications, security risk | Not Recommended |
| Conditional ref  | Flexible based on context                                                                  | Complex logic, potential for errors                    | Alternative     |

## 5. Recommendation

**Use `ref: 'master'` and fix the security validation logic.**

The current implementation is correct from a security perspective. The issue is in the branch validation logic, not the workflow dispatch `ref` parameter.

**Specific fixes needed:**

1. **Update security validation** in `test-builds.yml` line 77-80:

   ```yaml
   # Current (failing):
   if (!pr.head.ref.startsWith('update/')) {

   # Should be (based on actual Renovate pattern):
   if (!pr.head.ref.startsWith('renovate/')) {
   ```

2. **Keep `ref: 'master'`** in the workflow dispatch call (line 195 in `update-hash.yml`)

3. **Alternative approach** - Make validation more flexible:
   ```javascript
   // Accept both patterns
   if (!pr.head.ref.startsWith('update/') && !pr.head.ref.startsWith('renovate/')) {
   ```

## 6. Step-by-Step Logic

1. **Workflow 1 triggers** on Renovate PR
2. **Workflow 1 dispatches Workflow 2** with `ref: 'master'`
3. **GitHub loads Workflow 2 definition** from master branch (trusted)
4. **Workflow 2 security validation** checks PR details against trusted logic
5. **Workflow 2 checks out PR code** using `commit_sha` (untrusted code)
6. **Workflow 2 builds/tests** the untrusted code in isolated environment

This separation ensures workflow logic is trusted while still testing untrusted code.

## 7. Alternative Solutions

If the current approach proves problematic:

1. **Use `workflow_run` trigger** instead of `workflow_dispatch`
2. **Implement label-based approval** for additional manual oversight
3. **Use environment protection rules** for additional security layers

## 8. Best Practices Summary

- **Always use main/master branch** for workflow dispatch `ref`
- **Validate PR details** in the dispatched workflow
- **Separate workflow logic** (trusted) from code being tested (untrusted)
- **Use specific commit SHAs** for checkout to prevent race conditions
- **Implement comprehensive security validation** before any dangerous operations

The nixautopkgs implementation follows security best practices correctly. The issue is a mismatch between expected and actual branch naming patterns, not the workflow dispatch architecture.

## References

- [GitHub REST API - Create a workflow dispatch event](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
- [GitHub Actions - Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)
- [GitHub Security Lab - Preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- Real-world examples from Facebook React Native, Microsoft TypeScript, Sentry, Vercel, AWS EKS AMI, and other major projects
