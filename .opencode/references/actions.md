# Action targeting

Reference for `.github/workflows/*.yml` in this repository.

A workflow's trigger, path filter, guard, checkout ref, and build target all have
to describe the same commit and the same package. When they drift, CI reports on
code that will never be merged: red on a commit that has already been superseded,
or green on nothing at all. Both have happened here (see [Precedents](#precedents)).

Rules are ordered the way a run reads: placement → trigger → paths → guards →
checkout → mutate → build → report → bounds → verify. Reviewing a workflow is one
pass down the list; stop at the first rule that does not hold.

Each rule carries four fields:

| Field        | Job                                                             |
| ------------ | --------------------------------------------------------------- |
| **Rule**     | Imperative, one sentence, independently checkable               |
| **Why**      | The mechanism, not the opinion                                  |
| **Prevents** | A failure this repo has actually hit, or the named failure mode |
| **Check**    | A command or a specific thing to read in the YAML               |

A rule with no concrete failure behind it does not belong in this list. House
style lives in [Preferences](#preferences).

---

## How GitHub decides what runs

Verified against GitHub's docs; do not re-derive these from intuition.

| Event                            | Workflow file used         | `GITHUB_SHA`                   | Token                                                             |
| -------------------------------- | -------------------------- | ------------------------------ | ----------------------------------------------------------------- |
| `pull_request`                   | The PR head's copy         | Merge commit                   | Read-only for forks; write for same-repo when the job requests it |
| `pull_request_target`            | The **base branch's** copy | Last commit on the base branch | Write, including from forks                                       |
| `schedule` / `workflow_dispatch` | The default branch's copy  | Branch head                    | Write when requested                                              |

Consequences that drive every rule below:

1. **`paths` and `branches` filters match the PR's changed files** for both PR
   events. They are an input manifest, not a build graph.
2. **A push made with `GITHUB_TOKEN` starts no workflows.** The exceptions are
   `workflow_dispatch` and `repository_dispatch`, which always run.
3. **A `GITHUB_TOKEN` push that updates a PR creates `pull_request` runs in
   approval-required state.** They never execute, and they hold the PR pending,
   so Renovate will not merge. `pull_request_target` runs are fully suppressed
   for the same push, which is why every workflow here uses that event.
4. Therefore **workflow B cannot validate workflow A's push** — not with a
   different event, not with a shared concurrency group, not with `paths`. The
   only ways across are a non-`GITHUB_TOKEN` credential, a `workflow_dispatch`,
   or doing the work in the same run.
5. A `pull_request_target` run uses the base branch's copy of the workflow, so
   edits to that file in a PR are not exercised until after merge.
6. `pull_request` does not run on a conflicted PR; `pull_request_target` does.
7. This repo sets `default_workflow_permissions: write`, has no rulesets, and has
   no branch protection. Nothing _requires_ a check; a missing check is a silent
   stall, not a hard block.

---

## Model

A package family is one derivation plus the inputs it reads. Each family gets two
workflows at most, split by branch class:

| Shape       | Trigger                                     | Covers                       | Does                                         |
| ----------- | ------------------------------------------- | ---------------------------- | -------------------------------------------- |
| A — updater | `pull_request_target`                       | `update/*` only              | refresh → build → push → status → dispatch B |
| B — checks  | `pull_request_target` + `workflow_dispatch` | everything except `update/*` | build every target on every platform         |

Only Shape A may write. Only Shape A reports on `update/*`. Only Shape B reports
on human branches and flake bumps. Neither reports on the other's class.

Both shapes use `pull_request_target`. On `pull_request`, a bot push would park
an approval-required run that never executes and keeps the PR pending; the
`update/*` skip in Shape B does not help, because the run object is created
before any `if:` is evaluated.

Shape B is also triggered by Renovate's first push, on the unfixed commit. It
skips `update/*` so it never reports on an intermediate state; Shape A dispatches
it once the branch is fixed. `workflow_dispatch` is exempt from the
`GITHUB_TOKEN` suppression, so that dispatch executes.

### Merging belongs to Renovate

The workflow never merges a Renovate PR. `automerge` in `renovate.json` is the
switch:

- `false` — the fixer still refreshes, builds, and pushes, and you merge by hand
  once you have looked at it.
- `true` — the fixer refreshes, builds, pushes, and posts its status; Renovate
  merges once the branch is green on every platform.

Currently `true` for `NixOS/nixpkgs` and `tangency-labs/solidcraft`; the other
families are still manual. Flipping it is a deliberate `renovate.json` change,
never a runtime decision.

Renovate does not read the PR's `statusCheckRollup`. Its GitHub platform calls
`GET /commits/<ref>/check-runs` and requires every run to be
`success`/`skipped`/`neutral`, so the checks a fixer dispatches on the pushed
head do gate automerge — even though GitHub's PR rollup omits
`workflow_dispatch` check suites (verified on #618, #619 and #621, whose rollups
contain only the fixer's status).

### The status is what makes this work

Renovate merges a branch that is green. A `GITHUB_TOKEN` push produces a commit
with no checks at all, so a fixer that only pushes leaves a branch Renovate will
never touch. The fixer must therefore leave a verdict on the SHA Renovate reads:

```sh
gh api "repos/$GITHUB_REPOSITORY/statuses/$sha" \
  -f state=success \
  -f context="hash-update/<family>" \
  -f description="built <targets> on <platforms>"
```

Post `success` only for a tree that was actually built, on every platform.
Post `failure` on the evaluated head when the refresh or build fails, so an
unfixed version bump cannot sit on a clean-looking PR.

### What manual mode looks like

Expected, and not a defect to repair:

- The PR's pushed head has no check runs. The human is approving the content the
  fixer just built; that is the validation period.
- Do not "fix" it by moving the fixer to `pull_request_target`. That changes
  which commit the run reports on; it does not make the push trigger anything.
- The posted commit status is the record. If it is missing, the fixer did not
  finish.

---

## Rules

### R1 — One reporting owner per branch class

**Rule.** For each package family and each branch class, exactly one workflow
produces the verdict. Two workflows must never both report on the same branch.

**Why.** Two reports means one of them evaluated a different commit or a
different set of targets. The failing one gates nothing and the passing one
proves nothing.

**Prevents.** #602: `solidcraft-checks` built the pre-hash-update commit and went
red while `solidcraft-hash-update` was still running. The PR head was never
evaluated by either.

**Check.** For each package, list the workflows whose `paths` match it and whose
job `if:` can be true for the same head ref. More than one per class is a
violation.

---

### R2 — One merge owner per PR

**Rule.** Exactly one actor merges a PR. For Renovate PRs that actor is Renovate
via `automerge`; the workflow must not call `gh pr merge`.

**Why.** Two merge owners means the faster one wins regardless of validation
state.

**Prevents.** A workflow merging a commit while `automerge: false` is meant to
hold it for review.

**Check.** `grep -n 'pr merge' .github/workflows/*.yml`. A hit is allowed only
where the workflow creates its own PR and is listed under
[Exceptions](#exceptions).

---

### R3a — Updaters run on `pull_request_target`

**Rule.** A workflow that pushes to a PR branch uses `pull_request_target`, not
`pull_request`.

**Why.** `pull_request` re-triggers itself on the bot's own push, and that run is
created in approval-required state: it never executes, and it keeps the PR
pending so Renovate will not merge. `pull_request_target` runs are suppressed for
the same push, so the branch is left with exactly the verdict the updater chose
to post.

**Prevents.** P7: #604 and #605 sat in `action_required` after their hash fix was
pushed, with the PR `UNSTABLE` and no way to merge without a human clicking
approve.

**Check.** `grep -n 'pull_request:' .github/workflows/*.yml` returns nothing.
`pull_request_target:` is expected on every workflow.

---

### R3b — Checks never report on a branch an updater owns

**Rule.** A checks workflow skips exactly the Renovate branches that have a hash
updater for its family, and that updater dispatches the checks after pushing.

**Why.** The checks are triggered by Renovate's first push, which is the unfixed
commit — broken by construction. Reporting on it produces a red check that
describes code nobody will merge, and the fixed commit never gets a run.

Skip the family's branches, not every `update/*` branch: `update/nixpkgs` has no
updater, and is exactly the PR that needs the checks.

**Prevents.** P1: #602's red hash-mismatch check on the pre-fix commit.

**Check.** Each checks workflow has `workflow_dispatch:` and an `if:` that
excludes its own updater's branches; each updater dispatches it with
`gh workflow run <checks>.yml --ref "$GITHUB_HEAD_REF"`.

---

### R3c — `workflow_dispatch` is the only bridge between workflows

**Rule.** When one workflow must trigger another, use `workflow_dispatch` and
grant `actions: write`.

**Why.** It is the only event a `GITHUB_TOKEN` push can cause to execute. `push`,
`pull_request`, and `pull_request_target` are all suppressed or parked.

**Prevents.** Believing a dispatch can be replaced by `paths`, `concurrency`, or
a `workflow_run` trigger that reports on the wrong commit.

**Check.** Cross-workflow triggers are `gh workflow run ... --ref "$GITHUB_HEAD_REF"`
with `actions: write` on the caller.

---

### R3d — `schedule`/`workflow_dispatch` only for discovery

**Rule.** Scheduled or dispatched workflows that are not checks exist only to
discover an update, cut their own branch, and open their own PR. They must not
depend on `github.head_ref` or on path filters.

**Why.** A scheduled run has no PR context; filters and guards are meaningless
there.

**Prevents.** Treating a scheduled updater as if it were a PR check.

**Check.** Every `schedule:` workflow has a `git switch -c`/`git push` of its own
branch and no `head_ref` guard.

---

### R4 — Paths are an input manifest

**Rule.** `paths` lists every input whose change alters the result: the
derivation, `locks/*`, `patches/*`, shared includes such as
`packages/artcraft/common.nix`, `flake.nix`/`flake.lock` where the package is
nixpkgs-sensitive, and the workflow plus any script it runs.

**Why.** A filter that misses an input means the workflow silently does not run,
and the PR looks clean.

**Prevents.** `artcraft-hash-update` ignoring lock-only changes; and no updater or
check firing on `flake.lock` for `gcs`, `clamav`, `television`, `mlx`, `ocrit`,
`agent-browser`.

**Check.** Compare the `paths:` block against what the derivation reads
(`rg 'readFile|\./locks/|\.patch|callPackage' packages/<name>/`).

---

### R5 — Guards are asserted twice

**Rule.** Every writing workflow asserts its preconditions twice: the job-level
`if:` expression, and an `[[ ... ]]` assertion in the first step.

**Why.** A job-level `if` is easy to delete in a refactor and fails silently
open, with write access.

**Prevents.** A fixer acting on a fork PR, or on a branch whose name no longer
matches the intended prefix.

**Check.** One `startsWith(github.head_ref` in `if:` and one matching `[[` per
workflow that pushes.

---

### R6 — Checkout is explicit

**Rule.** A workflow that pushes or diffs checks out an explicit ref —
`ref: ${{ github.event.pull_request.head.ref }}` — with `fetch-depth: 0` and
`token: ${{ secrets.GITHUB_TOKEN }}`.

**Why.** `pull_request` defaults to the merge commit and `pull_request_target`
defaults to the base branch. Neither is the branch being pushed.

**Prevents.** Pushing the hash fix to the wrong ref, or diffing against a base
commit that is not the one being updated.

**Check.** Every pushing workflow has explicit `ref`, `fetch-depth: 0`, `token`.

---

### R7 — Build every target the derivation installs

**Rule.** Enumerate the binaries from `installPhase` and assert each one with
`test -x "$out/bin/<name>"`. A successful `nix build` is not evidence the package
is complete.

**Why.** `buildRustPackage` succeeds as long as the install phase exits 0; an
individual target can silently stop being produced.

**Prevents.** `artcraft-checks` building 7 of 14 exposed packages; `ccad` and
`solidcraft-cli` never being proven to exist.

**Check.** `grep -A6 installPhase packages/*/default.nix`, then confirm one
`nix build --no-link --print-out-paths` plus one `test -x` per binary.

---

### R8 — Matrix equals `meta.platforms`

**Rule.** The check matrix enumerates exactly the systems in `meta.platforms`.

**Why.** A platform in `meta` that is never built is an untested claim; a
platform in the matrix that is not in `meta` will fail `nix flake check`.
`meta.platforms` may be narrower than the flake's `systems` list — upstream
artifacts are not always published for every system, and claiming support for one
we cannot build is a lie.

**Prevents.** The updaters building one platform while the checks claimed three,
so "validated" meant different things in different workflows; and
`opencode-desktop` claiming Linux support while its aarch64-linux build pulled
WebKit from source and never finished.

**Check.** Compare the matrix `include:` list with `meta.platforms`; confirm
`nix eval .#packages.<unsupported>.$pkg` fails with "does not provide attribute".

---

### R9 — Validate before mutating

**Rule.** Order is refresh → build → push. Nothing is pushed that has not been
built on every platform.

**Why.** A push is permanent; a failure after it leaves an unvalidated head that
looks mergeable.

**Prevents.** Pushing a hash that later fails to build, leaving a green-looking
PR for `automerge` to pick up under R2.

**Check.** Step order in each writing workflow, and that the build step has no
`continue-on-error`.

---

### R10 — Leave a verdict on the SHA being read

**Rule.** Every run that evaluates a family ends with a status on the head it
evaluated: `success` on the pushed SHA, `failure` on the evaluated SHA.

**Why.** `GITHUB_TOKEN` pushes trigger nothing, so the new head has no checks and
Renovate never sees a passing branch.

**Prevents.** #601 and #603: `CLEAN`, mergeable, `automerge: true`,
`autoMergeRequest: null`, empty `statusCheckRollup` — stuck because nothing had
ever reported on the pushed commit.

**Check.** Each writing workflow ends with `.github/scripts/report-status.sh
success <context> <description>` after a green build, and
`.github/scripts/report-status.sh failure ...` under `if: failure()`, and declares
`statuses: write`.

---

### R11 — Bounded runtime, and timeout is failure

**Rule.** Every build has an explicit timeout sized for the worst cold build, and
a timeout is reported as failure.

**Why.** The default job timeout is six hours; a hung fetch stalls the family,
and a timeout treated as a pass is a lie about what was validated.

**Prevents.** `run-opencode-checks.sh` failing the whole update on a 1800s
desktop build, and the reverse hazard of a timeout reading as success.

**Check.** A timeout per build step or per helper; the helper maps its timeout
branch to `failure`, never to `success`.

---

### R12 — Concurrency cancels, never orders

**Rule.** Concurrency groups are scoped per family and per head ref, and no
sequencing logic relies on them. `cancel-in-progress: true` is only allowed when a
run reliably finishes inside its trigger interval.

**Why.** A shared group cancels in-flight runs. It cannot make workflow B wait for
workflow A. And if the interval is shorter than the run, every run is killed by
the next tick and nothing ever reports.

**Prevents.** P1, the assumption that `*-checks` would run after `*-hash-update`
finished fixing the branch; P8, `opencode-update` cancelling itself every 30
minutes because a validate run takes longer than that.

**Check.** No workflow's correctness depends on another workflow's completion;
`group:` includes `github.head_ref`; for scheduled workflows, compare the cron
interval with the observed run duration.

---

### R13 — Package lists have one home

**Rule.** A set of packages that must stay in sync is stored once and read by
every workflow that needs it.

**Why.** Hand-maintained copies drift, and the drift is invisible until a package
is quietly unvalidated.

**Prevents.** P3: the ArtCraft list existed separately in
`artcraft-hash-update.yml`, `artcraft-checks.yml`, and `README.md`, and the first
two disagreed about how many packages to build.

**Check.** The list lives in `.github/artcraft-packages.txt`; both ArtCraft
workflows read it, and it is listed under `paths` so editing it re-runs them.

---

### R14 — Verify against the head SHA

**Rule.** A green result only counts if it is attached to the current PR head.

**Why.** A green check on a superseded commit is worse than no check, because it
looks like coverage.

**Prevents.** Reading a workflow's success as validation of a branch it never
evaluated.

**Check.** `gh pr view <n> --json headRefOid,statusCheckRollup` and confirm at
least one run or status on `headRefOid`.

---

## Precedents

Append-only. Rules cite these; do not edit history, add entries.

| ID  | Date       | Incident                                                                                                                                                                          | Rules         |
| --- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| P1  | 2026-11-14 | #602 `solidcraft` 0.41.0: checks failed with a source hash mismatch while the hash updater was still running. Both workflows were triggered by the same event on the same branch. | R1, R12, R14  |
| P2  | 2026-11-14 | #601, #603: after the bot pushed hashes, `statusCheckRollup` was empty and `autoMergeRequest` was `null`. Renovate never merged them.                                             | R10           |
| P3  | 2026-11-14 | `artcraft-checks` built 7 of 14 exposed packages; `artcraft-hash-update` built 14.                                                                                                | R7, R13       |
| P4  | 2026-11-14 | `constructcraft-checks` never proved `ccad` exists; `solidcraft-checks` never proved `solidcraft-cli` exists.                                                                     | R7            |
| P5  | 2026-11-14 | `mlx-hash-update-darwin` and `renovate-hash-update-darwin` used `pull_request` while every sibling used `pull_request_target`.                                                    | R3a           |
| P6  | 2026-11-14 | OpenCode `aarch64-linux` desktop builds timed out at 1800s; the timeout was reported as a package failure, failing every scheduled run.                                           | R11           |
| P7  | 2026-11-15 | #604, #605: after the hash fix was pushed, the follow-up `pull_request` checks run sat in `action_required` and the PR stayed `UNSTABLE` with nothing validating the head.        | R3a, R3c, R10 |
| P8  | 2026-11-15 | `opencode-update` ran on a 30 minute schedule with `cancel-in-progress: true`, but a validate run needs longer than 30 minutes, so every run was cancelled by the next tick.      | R11, R12      |
| P9  | 2026-11-15 | `opencode-desktop` listed Linux in `meta.platforms` and pulled `webkitgtk_4_1`, so the aarch64-linux check built WebKit from source and could never finish.                       | R8, R11       |

---

## Inventory

Current mapping. Regenerate this table whenever a workflow's trigger, `paths`,
targets, or reporting changes.

| Workflow                      | Event                                      | Guard                               | Paths                                           | Builds                                       | Reports via                | Merge owner      |
| ----------------------------- | ------------------------------------------ | ----------------------------------- | ----------------------------------------------- | -------------------------------------------- | -------------------------- | ---------------- |
| `agent-browser-hash-update`   | `pull_request_target`                      | `update/` + same repo               | derivation, scripts, self                       | `agent-browser` (1 platform)                 | status                     | Renovate         |
| `renovate-hash-update`        | `pull_request_target`                      | `update/` + same repo               | gcs/clamav/television derivations, script, self | the three changed attrs (1 platform)         | status                     | Renovate         |
| `renovate-hash-update-darwin` | `pull_request_target`                      | `update/` + same repo               | ocrit derivation, script, self                  | `ocrit` (darwin)                             | status                     | Renovate         |
| `mlx-hash-update-darwin`      | `pull_request_target`                      | `update/` + same repo               | mlx, mlx-lm derivations, script, self           | `mlx`, `mlx-lm` (darwin)                     | status                     | Renovate         |
| `artcraft-hash-update`        | `pull_request_target`                      | `update/` + same repo               | `packages/artcraft/**`, list, script, self      | 14 attrs (1 platform)                        | status + dispatched checks | Renovate         |
| `constructcraft-hash-update`  | `pull_request_target`                      | `update/` + same repo               | `packages/constructcraft/**`, script, self      | `constructcraft` + `ccad` (1 platform)       | status + dispatched checks | Renovate         |
| `solidcraft-hash-update`      | `pull_request_target`                      | `update/` + same repo               | `packages/solidcraft/**`, script, self          | `solidcraft` + `solidcraft-cli` (1 platform) | status + dispatched checks | Renovate         |
| `artcraft-checks`             | `pull_request_target`, `workflow_dispatch` | same repo, not its updater branches | `packages/artcraft/**`, list, `flake.*`, self   | 14 attrs × 3 systems                         | check runs                 | —                |
| `constructcraft-checks`       | `pull_request_target`, `workflow_dispatch` | same repo, not its updater branches | `packages/constructcraft/**`, `flake.*`, self   | `constructcraft` + `ccad` × 3 systems        | check runs                 | —                |
| `solidcraft-checks`           | `pull_request_target`, `workflow_dispatch` | same repo, not its updater branches | `packages/solidcraft/**`, `flake.*`, self       | `solidcraft` + `solidcraft-cli` × 3 systems  | check runs                 | —                |
| `opencode-update`             | `schedule`, `workflow_dispatch`            | none                                | n/a                                             | CLI + desktop × 3 systems                    | own PR                     | self (exception) |

Families with no Shape B coverage today: `gcs`, `clamav`, `television`, `mlx`,
`mlx-lm`, `ocrit`, `agent-browser`, `mekhq`, `cleverswitch`, `craft-fonts`. A
`flake.lock` bump can break any of them with nothing reporting.

---

## Conformance

Gap between the inventory and the model. This section is allowed to shrink; it is
the migration list, not a permanent record.

| Gap                                                          | Target                                                        | Rule  |
| ------------------------------------------------------------ | ------------------------------------------------------------- | ----- |
| Fixers build 1 platform, checks build 3                      | decide one platform set per family                            | R8    |
| No Shape B for gcs/clamav/television/mlx/ocrit/agent-browser | add, or accept the gap and keep the fixer as the only verdict | R1    |
| `opencode-update` merges its own PR                          | gate the merge step during its validation period              | R2    |
| `renovate.json` `automerge`                                  | `true` for nixpkgs and solidcraft; flip others once validated | Model |

---

## Exceptions

Each exception names the guard that makes it safe.

- **`opencode-update` merges its own PR.** It creates the branch and PR itself, so
  there is no Renovate PR for `automerge` to govern. Today the guard is
  `needs.discover.outputs.changed == 'true'` plus a green validate matrix; it does
  not assert that the candidate SHA still equals the PR head before merging.
  During its validation period, gate the merge step directly instead of relying
  on `renovate.json`.

---

## Preferences

House style. Violating these is untidy, not incorrect.

- Invoke `nix run nixpkgs#nix-update -- ...` rather than a `nix-update` on `PATH`.
- Prefer `nix build --no-link --print-out-paths` plus assertions over a bare
  `nix build`.
- Keep helper scripts in `.github/scripts/` and list them under `paths`.
- `ubuntu-26.04` and `macos-26` are valid runner labels; actionlint's bundled
  label list lags and will report them as unknown. Do not add an `actionlint.yaml`
  just to silence that.

---

## Verify

After changing any workflow:

```sh
# syntax and expressions
actionlint
ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |f| YAML.load_file(f); puts f }'

# helpers
shellcheck .github/scripts/*.sh
bash -n .github/scripts/*.sh

# flake still evaluates
nix flake check --no-build
```

After a run lands on a PR:

```sh
gh pr view <n> --json headRefOid,mergeStateStatus,statusCheckRollup
# expect: at least one entry whose run is on headRefOid, and the status posted
# by the fixer for the pushed SHA

gh run list --workflow <file> --limit 5 --json conclusion,headSha,event
# expect: no run whose headSha is a superseded commit being read as a verdict
```

Reviewing a new or edited workflow: walk R1 → R14 in order and stop at the first
rule that does not hold.
