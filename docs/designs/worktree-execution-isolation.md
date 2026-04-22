# Worktree Execution Isolation

**Date:** 2026-04-22
**Status:** Implemented

## Historical Note

This document preserves the pre-cutover analysis that justified HOTL's move from shared-checkout branch switching to execution-root/worktree isolation.

It is no longer a description of the current repo state. The live implementation now includes:

- explicit runtime fields for `workflow_slug`, `source_workflow_path`, `repo_root`, `execution_root`, `worktree_path`, and `executor_mode`
- a deterministic execution-root bootstrap helper at `scripts/hotl-prepare-execution-root.sh`
- explicit `--run-id` pinning for runtime/helper operations when multiple runs exist
- worktree-by-default execution for git repos with history, with `worktree: false` as the opt-out

Read this file as design history and rationale, not as the current contract. For the live contract, use `docs/workflow-format.md`, `docs/how-it-works.md`, and the executor skills.

## Problem

HOTL execution is documented as branch/worktree-aware, but the real contract is still shared-checkout-first:

- `docs/workflow-format.md` and `docs/how-it-works.md` define `worktree` as optional and default `false`
- execution skills describe branch switching in the current checkout as the normal path
- `runtime/hotl-rt` persists only branch-oriented metadata and assumes `.hotl/` lives in the current working directory

Moving to git worktree-based isolation would reduce risk to the shared checkout, but it is not safe to flip by changing prose alone. The current model has hidden coupling to the shared checkout for workflow-file presence, runtime state discovery, helper scripts, and review scope.

## Inputs

- Execution skills:
  - `skills/loop-execution/SKILL.md`
  - `skills/executing-plans/SKILL.md`
  - `skills/subagent-execution/SKILL.md`
  - `skills/resuming/SKILL.md`
  - `skills/writing-plans/SKILL.md`
  - `skills/requesting-code-review/SKILL.md`
- Runtime and scripts:
  - `runtime/hotl-rt`
  - `scripts/finalize-codex-summary.sh`
  - `scripts/show-codex-current-step.sh`
  - `scripts/document-lint.sh`
- Docs:
  - `docs/workflow-format.md`
  - `docs/how-it-works.md`
  - `docs/contracts/execution-report-output.md`
- Prior design docs:
  - `docs/plans/2026-03-10-branch-worktree-preflight-design.md`
  - `docs/plans/2026-03-18-resumable-execution-design.md`
  - `docs/plans/2026-03-19-smart-dirty-worktree-design.md`
  - `docs/plans/2026-03-20-shared-runtime-design.md`
- Research:
  - `docs/research/2026-03-30-state-audit-and-competitive-update.md`
- Strategy docs:
  - None found under `docs/strategies/`

## Current-State Assessment

### What is already in place

- HOTL already has the concept of branch/worktree preflight in the execution skills.
- Workflow frontmatter already has `branch`, `worktree`, and `dirty_worktree`.
- `hotl-rt` already persists durable state/report artifacts and exposes a stable run lifecycle.
- The resumable-execution design already anticipated `worktree_path` in sidecar state, even though the runtime does not yet write it.

### What is coupled to the shared checkout today

1. **Worktree is documented as an opt-in escape hatch, not the default model.**
   - `docs/workflow-format.md` says `worktree` defaults to `false`.
   - `docs/how-it-works.md` describes branch creation as the normal isolation path and worktree as “full isolation”.

2. **The runtime has no first-class execution-root concept.**
   - `runtime/hotl-rt` stores `workflow_path`, `branch`, and `report_path`, but not `worktree_path`, `execution_root`, `repo_root`, or `executor_mode`.
   - The report header hard-codes `**Executor:** loop`, so even executor identity is not fully modeled in runtime state.

3. **Resume docs and runtime schema have already drifted.**
   - `skills/resuming/SKILL.md` documents `workflow_slug`, `worktree_path`, `executor_mode`, `start_time`, and `last_verify_output`.
   - `runtime/hotl-rt` does not currently persist those fields.
   - This is manageable in the branch-first world, but it becomes a real safety issue once run location matters.

4. **All runtime artifact discovery is cwd-relative.**
   - `runtime/hotl-rt` writes `.hotl/state` and `.hotl/reports` relative to the current working directory.
   - `scripts/show-codex-current-step.sh` looks only in `./.hotl/state/*.json`.
   - This is acceptable only if the entire execution session consistently runs from one root.

5. **Workflow files are allowed to be uncommitted and excluded from dirty checks.**
   - `skills/loop-execution/SKILL.md` and `skills/executing-plans/SKILL.md` exclude `hotl-workflow-*.md`, `docs/plans/*-design.md`, `docs/plans/*-plan.md`, and `.hotl/` from dirty detection.
   - `docs/plans/2026-03-19-smart-dirty-worktree-design.md` explicitly approved that behavior.
   - A fresh git worktree created from `HEAD` will therefore often not contain the workflow file being executed.

6. **Review checkpoints assume “current repo state” means the execution target.**
   - Executors record `git rev-parse HEAD` before review checkpoints.
   - `skills/requesting-code-review/SKILL.md` and the code-review dispatch design rely on the current git scope for diff calculation.
   - If the controller stays in the shared checkout while implementation happens in a worktree, review scope becomes wrong.

7. **Tests do not cover worktree execution as a real runtime mode.**
   - `test/smoke.bats` checks doc/lint coverage for branch/worktree fields.
   - `test/runtime.bats`, `test/runtime-integration.bats`, and `test/codex-execution-helpers.bats` assume a single cwd-local `.hotl/`.
   - There is no end-to-end test for “workflow file authored in shared checkout, execution moved into a worktree, state/report/helper scripts still resolve correctly”.

### Assessment

**Conclusion:** HOTL can move to worktree-based isolation, but not safely by only flipping `worktree` defaults in docs or skills. The safe migration requires:

- a first-class `execution_root` / `worktree_path` state contract
- deterministic worktree bootstrap for uncommitted workflow files
- executor rules that force all post-preflight git/runtime/helper operations to run from the execution root
- tests that validate that behavior with a real git repo

Without those changes, the move is likely to produce missing workflow files, broken resume behavior, wrong review diffs, and helper scripts that point at the wrong `.hotl/`.

## Approach Options

### Approach 1: Prose-only default flip

Change docs/skills so worktrees become the default, but keep git/worktree setup in executor prose and agent behavior.

**Pros**
- Smallest diff to docs
- No runtime API change

**Cons**
- Unsafe: the current trust boundary is too loose for worktree bootstrap
- No deterministic handling of uncommitted workflow files
- No authoritative execution-root metadata for resume/helpers/review

**Assessment**
- Reject. This is the fastest path to silent drift.

### Approach 2: Deterministic worktree bootstrap plus runtime schema alignment

Introduce a shared preflight/bootstrap mechanism for execution, persist execution-root metadata in runtime state, and make worktree isolation the intended git-backed execution mode. Keep shared-checkout execution only as an explicit fallback/escape hatch.

**Pros**
- Minimal change that is actually safe
- Preserves current workflow format with modest extensions
- Fits HOTL’s existing “runtime owns the hard parts” architecture

**Cons**
- Requires runtime/schema/test/doc changes together
- Expands the runtime boundary slightly toward execution setup

**Assessment**
- Recommended.

### Approach 3: Full multi-worktree orchestration

Treat worktrees as a per-step or per-subagent primitive, add a global run registry, support nested or parallel worktree allocation, and prepare for dependency-DAG execution.

**Pros**
- Strong long-term foundation for parallel execution
- Aligns with the competitive direction noted in `docs/research/2026-03-30-state-audit-and-competitive-update.md`

**Cons**
- Scope creep for the problem at hand
- Requires new workflow semantics, more runtime surface, and much larger test coverage

**Assessment**
- YAGNI for this migration. Parallel DAG execution should be a later design, not bundled into the worktree-isolation cutover.

## Recommended Decision

Adopt **Approach 2** in two phases:

1. **Capability phase:** make worktree execution deterministic and testable while still supporting the current fallback path.
2. **Cutover phase:** once that path is stable, make worktree isolation the default for git repos with history; keep shared-checkout execution only for explicit opt-out or non-git/no-history repos.

This keeps the migration safe without mixing in DAG execution, nested delegation, or global orchestration features.

## Minimal Viable Design

### Core decisions

1. **Execution happens in exactly one execution root.**
   - After preflight completes, all git commands, runtime calls, helper-script invocations, reviews, and step actions run from `execution_root`.
   - For git-backed isolated runs, `execution_root == worktree_path`.
   - For non-git repos or no-history repos, `execution_root == repo_root`.

2. **The runtime state must explicitly record execution location.**
   Add these fields to sidecar state and keep them authoritative:

```json
{
  "workflow_slug": "add-auth",
  "source_workflow_path": "/repo/hotl-workflow-add-auth.md",
  "workflow_path": "/repo-parent/.hotl-worktrees/project/add-auth/hotl-workflow-add-auth.md",
  "repo_root": "/repo",
  "execution_root": "/repo-parent/.hotl-worktrees/project/add-auth",
  "branch": "hotl/add-auth",
  "worktree_path": "/repo-parent/.hotl-worktrees/project/add-auth",
  "executor_mode": "loop | executing-plans | subagent"
}
```

3. **The workflow file must be bootstrapped into the worktree before `hotl-rt init`.**
   - The authored workflow file in the shared checkout remains the source artifact.
   - Preflight copies that file into the execution root before runtime initialization.
   - Resume uses `source_workflow_path` for lookup and `workflow_path` for in-worktree execution.

4. **Workflow checkbox mirroring should be synchronized back only at stable points.**
   - On `paused`, `blocked`, and `completed`, sync the execution-copy workflow file back to `source_workflow_path`.
   - Do not add per-step bidirectional sync. That is unnecessary complexity for the MVP.

5. **Review scope is execution-root scoped, not controller-root scoped.**
   - Review-base capture, diff generation, and checkpoint review all run from `execution_root`.
   - Subagent execution stays single-worktree: delegated workers use the same execution root as the controller.

6. **No nested or per-step worktrees in the MVP.**
   - `subagent-execution` continues to forbid parallel write-heavy steps.
   - This migration is about isolation of the workflow run, not parallelism.

### Preflight/bootstrap contract

The current duplicated prose preflight is not strong enough for safe worktree execution. Add a deterministic shared preflight/bootstrap command, ideally runtime-owned or runtime-adjacent.

Recommended shape:

```bash
hotl-rt prepare <workflow-file> --executor <loop|executing-plans|subagent> --json
```

Behavior:

1. Resolve repo state and lint the workflow before mutation.
2. Apply dirty-check exclusions already documented for HOTL-owned artifacts.
3. Determine branch name.
4. Decide execution mode:
   - non-git / no commits: in-place execution
   - git repo with history: worktree execution, unless explicitly opted out
5. Create or reuse the worktree path.
6. Copy the workflow file into the execution root.
7. Emit JSON with `repo_root`, `execution_root`, `worktree_path`, `branch`, `source_workflow_path`, `workflow_path`, and review-base metadata.

This is the smallest deterministic boundary that makes the rest of the runtime and executors coherent.

### Worktree path policy

Use a stable sibling directory outside the tracked repo tree, not a nested checkout inside the repo:

```text
<repo-parent>/.hotl-worktrees/<repo-name>/<workflow-slug>
```

Reasons:
- avoids nested-checkout confusion inside the shared repo
- survives session restarts better than temp dirs
- keeps path deterministic for resume

### Rollout semantics

**Capability phase**
- Preserve existing `worktree: true|false` parsing.
- Treat worktree execution as supported and deterministic.
- Keep shared-checkout execution available.

**Cutover phase**
- Make worktree isolation the default for git repos with history.
- Keep `worktree: false` as explicit opt-out, or replace with a clearer `execution_mode: shared-checkout` if a compatibility break is acceptable.

For the MVP, do **not** add new workflow fields unless needed. A silent default flip should wait until the capability phase is proven by tests.

## Files That Would Need Changes

### Required

- `skills/loop-execution/SKILL.md`
  - redefine preflight around `execution_root`
  - require all post-preflight runtime/git/helper commands to run from that root
  - update interrupted-run display to include worktree/execution path when present

- `skills/executing-plans/SKILL.md`
  - same preflight contract as `loop-execution`
  - same execution-root rule for batch review checkpoints and finalization

- `skills/subagent-execution/SKILL.md`
  - clarify that controller and delegated workers share one execution root
  - explicitly forbid nested worktree creation in the MVP

- `skills/resuming/SKILL.md`
  - align documented schema with actual runtime fields
  - specify behavior when the recorded worktree path is missing, stale, or dirty
  - resolve runs by `source_workflow_path`, not only execution-local `workflow_path`

- `runtime/hotl-rt`
  - add execution-root-aware metadata to sidecar state
  - add executor identity to runtime input instead of hard-coding `loop`
  - add deterministic prepare/bootstrap support or consume equivalent prepared inputs
  - update report metadata to include real executor and workspace location

- `docs/workflow-format.md`
  - change the execution model description from branch-first to execution-root/worktree-first
  - document bootstrap semantics for uncommitted workflow files
  - document new sidecar fields needed for worktree resume

- `docs/how-it-works.md`
  - update the narrative from “dedicated branch” to “isolated execution root”
  - describe when HOTL stays in place vs creates a worktree

- `docs/contracts/execution-report-output.md`
  - add workspace/execution-root metadata
  - clarify whether report paths are in-worktree paths and how users should interpret them

### Likely required

- `skills/writing-plans/SKILL.md`
  - stop teaching “branch checkout is the default” once cutover happens
  - if the default changes, update the commented frontmatter example

- `skills/requesting-code-review/SKILL.md`
  - make the execution-root assumption explicit for checkpoint review-base capture

- `scripts/finalize-codex-summary.sh`
  - possibly unchanged if always invoked with `workdir=execution_root`
  - otherwise add an explicit run/state-path argument

- `scripts/show-codex-current-step.sh`
  - same as above; it is safe only if the caller runs it from `execution_root`
  - if that invariant is too fragile, add `--run-id` or `--state-file`

### Tests and fixtures

- `test/smoke.bats`
  - update doc-contract assertions for the new default and preflight contract

- `test/execution-scenarios.bats`
  - assert execution-root/worktree language instead of branch-switching-only language

- `test/runtime.bats`
  - assert new state fields (`workflow_slug`, `source_workflow_path`, `repo_root`, `execution_root`, `worktree_path`, `executor_mode`)
  - assert report metadata includes the correct executor and workspace

- `test/runtime-integration.bats`
  - add a real git worktree bootstrap flow
  - verify that a workflow authored only in the shared checkout is copied into the worktree before init

- `test/codex-execution-helpers.bats`
  - verify helper behavior when the active run lives in a worktree execution root

- `test/fixtures/hotl-workflow-branch-sample.md`
  - likely rename or expand into a worktree-bootstrap fixture if needed

- New test coverage
  - a dedicated worktree execution integration suite is justified; current tests do not cover the migration risk surface

### Optional / phase-2 only

- `scripts/document-lint.sh`
  - only if workflow frontmatter changes beyond current `worktree` semantics

## Risks and Tradeoffs

### Main risks

1. **Workflow-file drift between shared checkout and worktree**
   - Mitigation: explicit `source_workflow_path` plus stable-point sync on pause/block/complete

2. **Resume breakage from stale or deleted worktree paths**
   - Mitigation: store both source and execution paths; define recreate-vs-abort behavior explicitly in `resuming`

3. **Reviewing the wrong diff**
   - Mitigation: all review-base capture and diff generation must run from `execution_root`

4. **Helper-script ambiguity**
   - Mitigation: either require helper invocation from `execution_root` or add explicit run/state-path args

5. **Default-flip compatibility**
   - Existing users may rely on shared-checkout branch switching behavior.
   - Mitigation: capability phase first, cutover second

### Tradeoffs

- **More runtime responsibility**
  - This expands `hotl-rt` beyond pure persistence/verification.
  - Worth it: worktree bootstrap is too stateful and cross-cutting to leave in prose.

- **More metadata in sidecar state**
  - Slightly heavier schema.
  - Worth it: worktree execution is not debuggable or resumable without location metadata.

- **Two copies of the workflow file during execution**
  - Slightly more complexity.
  - Worth it: current dirty-worktree rules mean the workflow file is often uncommitted and absent from a fresh worktree.

## YAGNI / Scope Guardrails

Do **not** bundle these into the MVP:

- dependency-aware parallel execution
- one-worktree-per-subagent allocation
- nested worktrees
- token budgeting
- global interrupted-run recovery across multiple repos

Those are separate initiatives. The March 30 research correctly identifies parallel worktree execution as a future differentiator, but it should not be smuggled into the isolation migration.

## Next Steps

1. Align the state contract first: decide the exact runtime fields and report metadata.
2. Design the deterministic prepare/bootstrap command and its JSON output.
3. Update executor skills and resume docs to use `execution_root` terminology consistently.
4. Add real worktree integration tests before flipping any defaults.
5. Only after those tests are green, change the documented default from shared-checkout branch switching to worktree isolation.

## HOTL Contracts

### Intent Contract

```yaml
intent: Move HOTL workflow execution from shared-checkout branch switching to worktree-based isolation without breaking runtime state, resume, review scope, or helper-script behavior
constraints:
  - Non-git repos and repos without commits must still execute in place
  - Existing workflow files may remain uncommitted before execution starts
  - Runtime artifacts remain the source of truth
  - Subagent execution stays single-worktree in the MVP
  - No default flip until worktree bootstrap and tests exist
success_criteria:
  - Every git-backed run has an explicit execution_root
  - Runtime sidecar and report record branch plus worktree/execution location
  - A workflow authored only in the shared checkout can execute safely in a worktree
  - Resume can locate or recover the execution root deterministically
  - Review checkpoints inspect diffs from the execution root, not the shared checkout
  - Tests cover real worktree bootstrap and helper-script behavior
risk_level: medium
```

### Verification Contract

```yaml
verify_steps:
  - run tests: bats test/smoke.bats
  - run tests: bats test/execution-scenarios.bats
  - run tests: bats test/runtime.bats
  - run tests: bats test/runtime-integration.bats
  - run tests: bats test/codex-execution-helpers.bats
  - check: runtime state includes execution_root and worktree_path when applicable
  - check: a workflow file excluded from dirty checks is bootstrapped into the worktree before init
  - check: resume resolves by source_workflow_path and execution_root
  - check: review-base capture happens inside the execution root
  - check: helper scripts work against a run living in a worktree
```

### Governance Contract

```yaml
approval_gates:
  - Approve runtime state schema changes before implementation
  - Approve the prepare/bootstrap command contract before implementation
  - Approve the default-flip only after worktree integration tests pass
rollback: keep shared-checkout execution as the compatibility fallback until the worktree path is proven
ownership: HOTL maintainers approve the migration contract; implementation must keep docs, runtime, and tests aligned
```
