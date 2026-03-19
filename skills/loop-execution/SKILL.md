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

### Interrupted Run Detection

After resolving the workflow file, check `.hotl/state/*.json` for interrupted runs matching that workflow:

- **One interrupted run found** → ask: "Found an interrupted run (step N/M). Resume from step N, or start fresh?"
- **Multiple interrupted runs found** → list all with run_id, step progress, branch, age. Ask which to resume or start fresh. **Never silently choose.**
- **No interrupted runs** → proceed normally (new run)

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

## HOTL Execution State Machine

This is the canonical HOTL execution state machine. Other execution modes (e.g., subagent-execution) reference this spec and define only their differences.

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

## Execution State Persistence

HOTL persists execution state in `.hotl/state/<run-id>.json` (sidecar file). This is the authoritative source of truth — workflow checkboxes are a human-visible mirror.

### Lifecycle

1. **On execution start:** Create `.hotl/state/<run-id>.json` with workflow metadata, step list, and `status: running`
2. **On each step transition:** Update `current_step`, step status, `attempts`, and `last_update`
3. **On verify:** Capture last verify output in `last_verify_output`
4. **On step completion:** Set step status to `completed`, update workflow checkbox to `[x]`
5. **On completion:** Set run status to `completed`
6. **On gate pause:** Set run status to `paused`
7. **On failure/stop:** Set run status to `blocked` with last verify output

Run ID format: `<slug>-<unix-timestamp>` (e.g., `add-auth-1710700000`).

The sidecar also stores `report_path` — the path to the durable Markdown report for this run. This makes resume and stop/block messaging deterministic.

See `skills/resuming/SKILL.md` for the full sidecar schema, stale run detection, and verify-first resume flow.

## Execution Report

HOTL writes a durable Markdown report to `.hotl/reports/<run-id>.md` incrementally during execution. This is the canonical report spec — other executors inherit it.

The report survives app rendering quirks (e.g., Codex suppressing intermediate output) and provides a reliable post-run artifact for debugging, trust, and resume.

### Report Format

**Metadata header:**
```markdown
# Execution Report: <run-id>

**Workflow:** hotl-workflow-<slug>.md
**Intent:** <intent from frontmatter>
**Branch:** <branch name>
**Executor:** loop | executing-plans | subagent
**Started:** <ISO 8601>
**Updated:** <ISO 8601>
**Status:** running | completed | paused | blocked
```

**Summary table** (updated in-place at each step transition):
```markdown
| Step | Name              | Status      | Iterations |
|------|-------------------|-------------|------------|
|  1   | Write tests       | ✓ Done      | 1          |
|  2   | Implement feature | → Running   | -          |
|  3   | Human review      | · Pending   | -          |
```

Table status values: `· Pending`, `→ Running`, `↻ Retrying`, `⚡ Auto-approved`, `✓ Done`, `✓ Approved`, `✗ Failed`, `✗ Blocked`

**Timestamped event log** (appended after each step transition):
```markdown
## Event Log

**[10:00:05]** → Step 1: Write tests
**[10:01:12]** ✓ Step 1: Done (1 attempt)
**[10:01:15]** → Step 2: Implement feature
**[10:02:30]** ↻ Step 2: Retrying (2/3)
  verify output:
  FAILED: test_auth - AssertionError: expected 401, got 200
```

### Report Lifecycle

1. **On execution start:** Create report with metadata (including `Updated:`) and full table (all `· Pending`). Store `report_path` in sidecar JSON.
2. **On step start:** Update table to `→ Running`, update `Updated:`, append event
3. **On verify fail:** Append captured stdout/stderr to event log
4. **On retry:** Update table to `↻ Retrying`, append retry event
5. **On step complete:** Update table to `✓ Done`, append completion event
6. **On gate:** Update table to `⚡ Auto-approved` or `✓ Approved`
7. **On completion:** Set status to `completed`, update `Updated:`, finalize report
8. **On stop/block:** Set status to `blocked`, include report path in response

### Verify Output Policy

- **Default:** failed verifies include captured stdout/stderr in the event log. Successful verifies get a one-line result only.
- **`report_detail: full`** (frontmatter opt-in): all verify output included for every step, successful or not.

### Report Path Reference

The executor must reference the report path in its response:
- At successful completion
- On gate pause / human review pause
- On blocked / failed / max iterations stop
- During resume detection for interrupted runs

### Relationship to Other Artifacts

- **Chat output** = primary live UX (per-step logs, verbose progress, final summary table)
- **Markdown report** = durable human-readable record (survives app rendering quirks)
- **JSON sidecar** = authoritative machine state (resume, tooling, structured queries)

## Safety Rules

- `risk_level: high` in frontmatter **always** forces human approval at `gate: human` steps, even if `auto_approve: true`
- Never skip a `gate: human` on steps with security-sensitive keywords (auth, encrypt, secret, key, password, token, permission, role, billing)
- On STOP: always show the failing verify output so human can diagnose

## Execution Reporting Contract

This is the canonical reporting spec. Other executors (executing-plans, subagent-execution) inherit this contract.

### Codex Native Progress (advisory)

When running in the Codex app, use the native plan/progress UI for top-level execution visibility when available. Mirror the active workflow as a short step list with `pending`, `in_progress`, and `completed` states so the user gets the built-in progress card during execution.

Rules:
- Treat the native plan/progress UI as additive. Do not remove or weaken the existing chat logs, compact summaries, or durable `.hotl/reports/...` artifact.
- Keep the native plan list high-level and short. Use major execution phases or top-level workflow steps, not every retry, verify substep, or low-level log line.
- Only one native plan step should be `in_progress` at a time.
- On platforms without a native progress UI, including Claude Code and Cline, keep the existing HOTL chat/report layout unchanged.

### Per-Step Log (default, always shown)

After each step, log one line:
```
✓ Step 1: Write failing tests
✓ Step 2: Implement auth logic (3 attempts)
⚡ Step 3: Security review gate (auto-approved)
✓ Step 4: Update docs
```

### Final Summary Table

**Codex rendering advisory:** in chat output, prefer the compact list form below instead of a wide markdown table. Keep the same status and iteration semantics by carrying both status and iteration count inline on each line. Reserve the full table form for the durable execution report or platforms where tabular markdown renders cleanly.

Compact list example:
```
Execution Summary

✓ Step 1: Write failing tests — Done (1 attempt)
✓ Step 2: Implement auth logic — Done (3 attempts)
⚡ Step 3: Security review gate — Auto-approved (-)
✓ Step 4: Run full test suite — Done (65 tests, 1 attempt)
✓ Step 5: Human review — Approved (1 attempt)
```

If a table is rendered, use these strict column rules:

**Compact list rules:**
- Keep the step name first, then append inline status detail after an em dash.
- Include the final status word on every line: `Done`, `Approved`, `Auto-approved`, `Failed`, or `Blocked`.
- Include the iteration count on every line. Use `1 attempt` / `N attempts` for executed steps. For gates, use `(-)` if no retries/attempt count applies.
- If there is useful result detail such as test counts, keep it inside the status detail before the attempt count: `Done (28/28, 2 attempts)`.

Print at the end of execution. Strict column rules:

```
| Step | Name                    | Status            | Iterations |
|------|-------------------------|--------------------|------------|
|  1   | Write failing tests     | ✓ Done (17 tests)  | 1          |
|  2   | Implement auth logic    | ✓ Done              | 3          |
|  3   | Security review gate    | ⚡ Auto-approved    | -          |
|  4   | Run full test suite     | ✓ Done (65 tests)   | 1          |
|  5   | Human review            | ✓ Approved          | -          |
```

**Column rules:**
- **Step** — step number only
- **Name** — step name from the workflow
- **Status** — outcome + details. Values:
  - `✓ Done` — step completed
  - `✓ Done (N tests)` — step completed with test count detail
  - `⚡ Auto-approved` — gate auto-approved
  - `✓ Approved` — gate approved by human
  - `✗ Failed` — step verify failure
  - `✗ Blocked` — executor stopped (max retries reached, gate denied, etc.)
- **Iterations** — attempt count as a number only (`1`, `2`, `3`). For gates: `-`. Never put test counts or details here.

### Verbose Progress View (opt-in)

When verbose mode is enabled, print a compact step list at each step transition (before starting a step, after a step completes/fails/auto-approves):

```
  ✓ Step 1: Write failing tests
  ✓ Step 2: Implement feature
  → Step 3: Run full test suite (attempt 1/3)
  · Step 4: Update docs
  · Step 5: Human review
```

**Symbols:**
- `✓` — completed
- `→` — current step (include attempt info if looping)
- `·` — pending
- `⚡` — auto-approved gate
- `✗` — blocked/failed

Include short result details only when useful (test counts on completed steps, attempt progress on current step, failure reason on blocked steps).

### Verbose Mode Precedence

1. **Executor invocation override wins** — user says "run with verbose progress"
2. **Workflow frontmatter** — `progress: verbose`
3. **Default** — non-verbose (per-step log only, no full list)

## What to Do If No Workflow Found

If no `hotl-workflow*.md` found in project root:
"No workflow file found. Would you like to:
1. Create one from a template (`/hotl:write-plan`)
2. Use a workflow template from the plugin (`workflows/feature.md`, `workflows/bugfix.md`, `workflows/refactor.md`)"
