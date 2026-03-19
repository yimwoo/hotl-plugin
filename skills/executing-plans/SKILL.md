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
     • docs/plans/*-design.md (design docs from brainstorming)
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
- **type: human-review** — ALWAYS pause for human, show prompt, wait for approval (never auto-approve)
- **type: artifact** — check path exists, evaluate assert (kind: exists | contains | matches-glob)

## Execution State Persistence

This executor writes execution state to `.hotl/state/<run-id>.json` using the same sidecar lifecycle as loop-execution (create on start, update on step transition, capture verify output). See `skills/loop-execution/SKILL.md` for the full persistence spec and `skills/resuming/SKILL.md` for the sidecar schema.

To resume an interrupted executing-plans run, use `/hotl:resume`.

## Process

1. Resolve and read the plan (see above)
2. Run Branch/Worktree Preflight (see above)
3. Execute tasks in order, 3 at a time
4. Run typed verification for each step (see above)
5. After each batch: show what was done, ask "Continue to next batch?"
6. On failure: stop and report — never silently skip a failed step
7. When complete: invoke `hotl:verification-before-completion`

Use this over `loop-execution` when you want explicit human checkpoints at every stage rather than auto-approve.

## Reporting

Inherits the canonical Execution Reporting Contract and Execution Report spec from `skills/loop-execution/SKILL.md` — same final summary table column rules, same verbose progress format, same precedence for verbose mode, same durable `.hotl/reports/<run-id>.md` artifact.
