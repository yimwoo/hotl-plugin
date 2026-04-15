---
name: executing-plans
description: Use when executing an implementation plan linearly with explicit human checkpoints between batches of tasks.
---

# Executing Plans (Linear with Checkpoints)

Execute the plan task by task. Pause after every 3 tasks for human review.

## Workflow File Resolution

Resolve which workflow file to execute:

1. If the user specified a filename → use that file
2. Else, glob for `hotl-workflow*.md` in project root:
   - **One match** → use it automatically
   - **Multiple matches** → list them and ask the user to pick
   - **No matches** → check `docs/plans/*.md` as fallback

## Branch/Worktree Preflight

After resolving the workflow file, run this preflight **before executing any steps**:

```
1. Is this a git repo with at least one commit?
   - No  → log "Skipping branch setup (no git history)" → proceed to step execution
   - Yes → continue

2. Check for uncommitted changes
   - First, exclude HOTL-owned transient artifacts from the dirty check:
     • hotl-workflow-*.md (workflow plan files)
     • docs/plans/*-design.md, docs/plans/*-plan.md (design/plan docs from brainstorming)
     • .hotl/ (runtime state, reports, cache)
   - If only HOTL artifacts are dirty → treat as clean, continue
   - If non-HOTL dirty files exist:
     • If dirty_worktree: allow in workflow frontmatter → proceed without prompting
     • Otherwise → HARD-FAIL. Tell the user which non-HOTL files are dirty. Offer choices:
       a. Clean up manually, then re-run
       b. Stash manually, then re-run
       c. Explicitly approve HOTL to stash and continue
   - Clean → continue

3. Determine branch name
   - If branch: field exists in workflow frontmatter → use it
   - Otherwise → derive hotl/<slug> from hotl-workflow-<slug>.md

4. Check if branch already exists locally
   - Exists, same HEAD    → ask: reuse, delete+recreate, or abort
   - Exists, different HEAD → ask: delete+recreate, or abort
   - Does not exist        → create (no prompt)

5. Create branch/worktree
   - If worktree: true in frontmatter → create git worktree with the branch
   - Otherwise → create branch and checkout in current directory
```

**Rules:**
- No auto-stash. Hidden state mutation weakens governance.
- Existing branch always prompts, even at the same HEAD.
- Non-git repos skip entirely — HOTL works without git ceremony.
- Run HOTL structural lint (`scripts/document-lint.sh`) automatically on the workflow file before any git mutation or step execution. If lint fails, STOP and show all errors. If lint passes, continue silently.

## Typed Verification

The `verify` field supports 4 types. A scalar string is shorthand for `type: shell`. If `verify` is a list, ALL checks must pass.

- **type: shell** — run command, check exit code, capture stdout/stderr
- **type: browser** — use browser tooling with url+check; if unavailable, downgrade to type: human-review with check text as prompt
- **type: human-review** — `hotl-rt step N verify` returns a `human review required: ...` block reason and pauses the run; show the prompt, wait for approval, then persist it with `hotl-rt gate N approved|rejected --mode human` (never auto-approve)
- **type: artifact** — check path exists, evaluate assert (kind: exists | contains | matches-glob)
  For `matches-glob`, `path` must be the directory and `value` must be a filename glob only; values like `src/*` are invalid and should be authored as `path: src`

## Execution State Persistence

All state persistence is handled by the `hotl-rt` shared runtime (`runtime/hotl-rt`). This executor calls `hotl-rt` for all state transitions:

- `hotl-rt init <workflow-file>` — at run start
- `hotl-rt step N start` — before each step
- `hotl-rt step N verify` — after each step's action
- `hotl-rt step N retry` / `hotl-rt step N block --reason "..."` — on failure
- `hotl-rt gate N approved|rejected` — at gate steps
- `hotl-rt finalize --json` — at run completion

The runtime owns `.hotl/state/<run-id>.json` and `.hotl/reports/<run-id>.md`. Agents do not manage these files directly. Runtime calls happen before the corresponding chat or progress UI update.

Use the same HOTL runtime and script path resolution order defined in `skills/loop-execution/SKILL.md`. Do not assume `runtime/` or `scripts/` exist in the user's project checkout.

To resume an interrupted executing-plans run, use the host tool's native resume entry point.
- **Codex:** ask me to use `$hotl:resuming` on the workflow file
- **Claude Code:** `/hotl:resume <workflow-file>`

## Process

1. Resolve and read the plan (see above)
2. Run Branch/Worktree Preflight (see above)
3. Run `hotl-rt init <workflow-file>` to initialize state and report
4. Execute tasks in order, 3 at a time:
   - `hotl-rt step N start` before each step
   - Execute the action
   - `hotl-rt step N verify` to run typed verification
   - If verify reports `human review required: ...`, pause and do not continue until `hotl-rt gate N approved|rejected --mode human` succeeds
   - On failure: `hotl-rt step N retry` or `hotl-rt step N block --reason "..."`
   - On gate: `hotl-rt gate N approved|rejected`
5. After each batch: run review checkpoint (see below), then show what was done, ask "Continue to next batch?"
6. On failure: stop and report — never silently skip a failed step
7. When complete: run final review checkpoint (see below), invoke `hotl:verification-before-completion`, then `hotl-rt finalize --json`, render the final summary via `scripts/render-execution-summary.sh`

## Review Checkpoints

Record `git rev-parse HEAD` as the review base before starting each batch.

### After Each Batch

After all steps in the batch have passed verification:
1. Invoke `requesting-code-review` to dispatch the `code-reviewer` agent
   - Review type: checkpoint
   - Review base: the recorded pre-batch HEAD
   - Steps reviewed: the batch step numbers
2. When findings return, invoke `receiving-code-review`
   - Follow Verify → Evaluate → Respond → Implement
3. Resolve all BLOCK findings before proceeding to the next batch

### Before Final Completion

A final review is required unless the most recent review already covers all current changes and no code changed afterward.

1. Invoke `requesting-code-review` with review type: final
   - Review base: branch point or last review base, whichever is more recent
2. When findings return, invoke `receiving-code-review`
3. Resolve all BLOCK findings before finalizing
4. If fixes after the last review changed scope, constraints, or risk_level, request a scoped follow-up review before completing

Review happens after step verification, before `verification-before-completion`, before `hotl-rt finalize`.

Use this over `loop-execution` when you want explicit human checkpoints at every stage rather than auto-approve.

## Reporting

Execution report output must conform to `docs/contracts/execution-report-output.md`. This is the canonical reporting contract from `skills/loop-execution/SKILL.md`. Live step visibility follows the same rules as `skills/loop-execution/SKILL.md` — per-step chat logs on all platforms, deterministic renderer for final summary.
