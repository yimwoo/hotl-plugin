---
name: loop-execution
description: Use when executing a hotl-workflow-*.md — reads steps, loops until success criteria met, auto-approves low-risk gates, pauses at high-risk gates.
---

# HOTL Loop Execution

## Overview

Execute a `hotl-workflow-<slug>.md` file autonomously. Loop on steps with success criteria. Auto-approve low-risk gates. Always pause for high-risk gates.

**Announce:** "Starting HOTL loop execution. Looking for workflow file..."

## Workflow File Resolution

Resolve which workflow file to execute:

1. If the user specified a filename (e.g., `/hotl:loop hotl-workflow-add-auth.md`) → use that file
2. Else, glob for `hotl-workflow*.md` in project root:
   - **One match** → use it automatically
   - **Multiple matches** → list them and ask the user to pick
   - **No matches** → see "What to Do If No Workflow Found" below

## Branch/Worktree Preflight

After resolving the workflow file, run this preflight **before executing any steps**:

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
- Run HOTL structural lint (`scripts/document-lint.sh`) automatically on the workflow file before any git mutation or step execution. If lint fails, STOP and show all errors. If lint passes, continue silently.

## Execution Algorithm

```
1. Resolve workflow file (see above)
2. Parse frontmatter: intent, risk_level, auto_approve, branch, worktree
3. Run Branch/Worktree Preflight (see above)
4. For each step in order:

   a. Announce: "→ Step N: [name]"

   b. Execute the action

   c. Run verify (typed verification):
      → If verify is a scalar string: treat as type: shell
      → If verify is a list: run all checks, ALL must pass
      → type: shell — run command, check exit code, capture stdout/stderr
      → type: browser — if browser tooling available, use it with url+check;
          if unavailable, downgrade to type: human-review with check text as prompt
      → type: human-review — ALWAYS pause for human, show prompt, wait for approval
          (never auto-approve, even if auto_approve: true)
      → type: artifact — check path exists, then evaluate assert:
          kind: exists → file/dir at path exists
          kind: contains → file at path contains value text
          kind: matches-glob → directory at path has file matching value glob

   d. If loop: false
      → run verify if present
      → if verify fails: STOP, report to human
      → continue to next step

   e. If loop: until [condition]
      → run verify
      → if pass: log "✓ [condition] met", continue to next step
      → if fail AND iterations < max_iterations: log "↻ Retrying ([n]/[max])...", retry
      → if fail AND iterations = max_iterations: STOP
          Report: "Step N reached max iterations ([max]). [condition] not met."
          Show last verify output. Wait for human guidance.

   f. If gate: human
      → if auto_approve: true AND risk_level != high:
          log "⚡ Auto-approved: Step N gate (risk: [risk_level])"
          continue
      → else:
          PAUSE. Show summary of what was done in this step.
          Ask: "Gate reached at Step N. Continue? (yes/no/show-details)"
          Wait for human response before proceeding.

   g. If gate: auto
      → always continue, log "⚡ Auto-approved: Step N gate"

5. All steps complete:
   → Print summary table (step name | status | iterations used)
   → Invoke hotl:verification-before-completion skill
```

## Safety Rules

- `risk_level: high` in frontmatter **always** forces human approval at `gate: human` steps, even if `auto_approve: true`
- Never skip a `gate: human` on steps with security-sensitive keywords (auth, encrypt, secret, key, password, token, permission, role, billing)
- On STOP: always show the failing verify output so human can diagnose

## Reporting

After each step, log one line:
```
✓ Step 1: Write failing tests (1 iteration)
✓ Step 2: Implement auth logic (3 iterations, tests now pass)
⚡ Step 3: Security review gate (auto-approved, risk: low)
✓ Step 4: Update docs (1 iteration)
```

## What to Do If No Workflow Found

If no `hotl-workflow*.md` found in project root:
"No workflow file found. Would you like to:
1. Create one from a template (`/hotl:write-plan`)
2. Use a workflow template from the plugin (`workflows/feature.md`, `workflows/bugfix.md`, `workflows/refactor.md`)"
