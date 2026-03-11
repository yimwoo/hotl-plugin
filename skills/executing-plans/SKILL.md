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

After resolving the workflow file (and after document review if applicable), run this preflight **before executing any steps**:

```
1. Is this a git repo with at least one commit?
   - No  → log "Skipping branch setup (no git history)" → proceed to step execution
   - Yes → continue

2. Check for uncommitted changes
   - Dirty → HARD-FAIL. Tell the user why execution is blocked. Offer choices:
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
- Document review runs before any git mutation.

## Process

1. Resolve and read the plan (see above)
2. Run Branch/Worktree Preflight (see above)
3. Execute tasks in order, 3 at a time
4. After each batch: show what was done, ask "Continue to next batch?"
5. On failure: stop and report — never silently skip a failed step
6. When complete: invoke `hotl:verification-before-completion`

Use this over `loop-execution` when you want explicit human checkpoints at every stage rather than auto-approve.
