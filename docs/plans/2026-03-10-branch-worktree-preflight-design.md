# Branch/Worktree Preflight for Execution Skills

**Date:** 2026-03-10
**Status:** Implemented, then superseded

## Historical Note

This design was approved when HOTL still treated `worktree` as an opt-in field with shared-checkout branch switching as the normal path.

The current repo has moved beyond this exact contract:

- worktree execution is now the default for git repos with history
- `worktree: false` is the explicit opt-out
- execution is anchored to an `execution_root`, not just to “whatever branch the current checkout is on”

The original design remains useful as the first branch/worktree preflight milestone, but it is no longer the live contract.

## Problem

HOTL execution skills (executing-plans, loop-execution, subagent-execution) run on whatever branch the user happens to be on. In team environments this means work lands directly on main/master, risking conflicts and accidental overwrites.

## Design Decisions

1. **Execution owns git side effects.** Planning skills describe work; execution skills create branches.
2. **Document review happens before any git mutation.** The branch is created after the workflow passes review, not before.
3. **`branch:` is optional in workflow frontmatter.** If present, execution uses it. If absent, execution derives `hotl/<slug>` from `hotl-workflow-<slug>.md`.
4. **`worktree:` is optional, default `false`.** When `true`, execution creates a git worktree instead of a plain branch checkout.
5. **Dirty repo hard-fails.** No auto-stash. User is told why and offered explicit choices: clean up manually, stash manually and re-run, or explicitly approve HOTL to stash and continue.
6. **Existing branch always prompts.** Even if the branch points to the current HEAD, HOTL stops and asks: reuse, delete+recreate, or abort.
7. **Non-git repos skip preflight.** If there's no `.git` directory or no commits, preflight logs "skipping branch setup" and executes in place.
8. **Document-lint ignores `branch:` and `worktree:` in v1.** Validation happens at execution runtime only.
9. **Preflight logic is one shared contract.** All three execution skills reference the same preflight spec to prevent drift.

## Workflow Frontmatter

```yaml
---
intent: Add auth
success_criteria: ...
risk_level: medium
auto_approve: true
branch: feat/add-auth   # optional — override derived name
worktree: true           # optional — default false
---
```

## Execution Flow

```
1. Resolve workflow file
2. Document review (if not already reviewed)
3. ── review approved ──
4. Branch/worktree preflight
   a. Is this a git repo with commits?
      - No  → log "skipping branch setup (no git history)" → go to 5
      - Yes → continue
   b. Check for uncommitted changes
      - Dirty → hard-fail, show choices (clean up / manual stash / approve stash)
   c. Determine branch name
      - If branch: field exists → use it
      - Otherwise → derive hotl/<slug> from workflow filename
   d. Check if branch exists
      - Exists, same HEAD    → ask: reuse, delete+recreate, or abort
      - Exists, different HEAD → ask: delete+recreate, or abort
      - Does not exist        → create (no prompt)
   e. If worktree: true → create worktree + branch
      Otherwise → create branch + checkout
5. Execute step 1...N
```

## Branch Naming

| Scenario | Branch Name |
|---|---|
| `branch: feat/add-auth` in frontmatter | `feat/add-auth` |
| No `branch:`, file is `hotl-workflow-add-auth.md` | `hotl/add-auth` |
| No `branch:`, file is `hotl-workflow-fix-login-timeout.md` | `hotl/fix-login-timeout` |

## HOTL Contracts

### Intent Contract

```
intent: Add branch/worktree preflight to execution skills
constraints:
  - No git mutation before document review passes
  - No auto-stash, no hidden state changes
  - Planning skills must not create branches
  - Non-git repos must work without branching
  - Preflight logic is one shared contract across all three execution skills
success_criteria:
  - All three execution skills run branch preflight before step 1
  - Optional branch: and worktree: fields accepted in workflow frontmatter
  - Default branch derived as hotl/<slug> from workflow filename
  - Dirty repo hard-fails with explicit choices offered
  - Existing branch always prompts (even at same HEAD)
  - Non-git repos skip preflight and execute in place
  - workflow-format.md documents new fields
  - document-lint ignores branch:/worktree: in v1
risk_level: medium
```

### Verification Contract

```
verify_steps:
  - run tests: bats test/smoke.bats
  - check: each execution skill SKILL.md contains identical preflight section
  - check: workflow templates do NOT include branch:/worktree: by default
  - check: writing-plans mentions branch:/worktree: as optional but creates nothing
  - check: workflow-format.md documents both fields
  - confirm: manual test — run execution on dirty repo → hard-fail
  - confirm: manual test — run execution on clean repo → branch created
  - confirm: manual test — run execution in non-git dir → no branch, executes normally
```

### Governance Contract

```
approval_gates:
  - Design approval (this brainstorm) → before any implementation
  - Document review of the workflow file before execution
  - Final review after implementation → before merge
rollback: git revert the commit(s) — all changes are additive
ownership: user approves design and plan; AI implements within guardrails
```

## Files to Modify

- `skills/executing-plans/SKILL.md` — add preflight stage
- `skills/loop-execution/SKILL.md` — add preflight stage
- `skills/subagent-execution/SKILL.md` — add preflight stage
- `skills/writing-plans/SKILL.md` — mention optional branch:/worktree: fields
- `docs/workflow-format.md` — document new frontmatter fields
- `workflows/feature.md`, `workflows/bugfix.md`, `workflows/refactor.md` — no changes (templates stay clean)
