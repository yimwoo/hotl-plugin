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
4. Initialize run via runtime:
   - Run: `hotl-rt init <workflow-file>`
   - This parses the workflow, creates .hotl/state/<run-id>.json with all steps, and initializes .hotl/reports/<run-id>.md
   - Capture the run_id from stdout
   - Only after init succeeds should chat output or native plan/progress UI show anything

5. For each step in order:

   a. Start step via runtime:
      - Run: `hotl-rt step N start`
      - This persists step start (status, timestamp, attempts) to state and report
      - Only after the runtime call succeeds should chat show "→ Step N"

   b. Announce: "→ Step N: [name]"

   c. Execute the action (agent implements the work)

   d. Verify via runtime:
      - Run: `hotl-rt step N verify`
      - The runtime runs the verify command, captures stdout/stderr, and atomically transitions the step to done or failed
      - If the verify type is unsupported, the runtime blocks the step with a clear reason
      - For type: browser — if browser tooling unavailable, downgrade to type: human-review
      - For type: human-review — ALWAYS pause for human (never auto-approve)
      - For type: artifact — runtime checks path exists and evaluates assert

   e. If verify fails (runtime returns non-zero):

      f. If loop: false
         → STOP, report to human
         → Run: `hotl-rt step N block --reason "verify failed"` if not already marked failed by verify
         → Show last verify output. Wait for human guidance.

      g. If loop: until [condition]
         → if iterations < max_iterations:
             Run: `hotl-rt step N retry` then `hotl-rt step N start`
             log "↻ Retrying ([n]/[max])...", retry the action
         → if iterations = max_iterations: STOP
             Report: "Step N reached max iterations ([max]). [condition] not met."
             Show last verify output. Wait for human guidance.

      h. On step completion (verify passed):
      - The runtime has already persisted the done status
      - Update the workflow checkbox to [x]
      - Only after the runtime confirms success should chat show "✓ Step N"

   i. If gate: human
      → if auto_approve: true AND risk_level != high:
          Run: `hotl-rt gate N approved --mode auto`
          log "⚡ Auto-approved: Step N gate (risk: [risk_level])"
          continue
      → else:
          PAUSE. Show summary of what was done in this step.
          Ask: "Gate reached at Step N. Continue? (yes/no/show-details)"
          Wait for human response.
          Run: `hotl-rt gate N approved --mode human` or `hotl-rt gate N rejected --mode human`

   j. If gate: auto
      → Run: `hotl-rt gate N approved --mode auto`
      → always continue, log "⚡ Auto-approved: Step N gate"

6. All steps complete:
   → Run: `hotl-rt finalize --json`
   → Render the summary payload with the deterministic renderer: `scripts/render-execution-summary.sh --platform <codex|claude|cline> <summary-json-file>`
   → Never freehand the final summary when the renderer is available
   → Invoke hotl:verification-before-completion skill
```

## Execution State Persistence

All state persistence is handled by the `hotl-rt` shared runtime (`runtime/hotl-rt`). Agents do not manage state files directly.

The runtime owns:
- `.hotl/state/<run-id>.json` — authoritative machine state (created by `hotl-rt init`, updated by `hotl-rt step/gate/finalize`)
- `.hotl/reports/<run-id>.md` — durable Markdown report (initialized at init, updated incrementally, finalized at finalize)

Run ID format: `<slug>-<YYYYMMDDTHHMMSSZ>` (e.g., `add-auth-20260320T212315Z`).

Workflow checkboxes (`- [x]`) are a human-visible mirror updated by the agent on step completion. The sidecar is the source of truth.

Operational rule: `hotl-rt` calls happen before the corresponding chat log or Codex native plan/progress update. Native progress UI is never a substitute for the runtime-managed artifacts.

See `skills/resuming/SKILL.md` for the full sidecar schema, stale run detection, and verify-first resume flow.

## Execution Report

The `hotl-rt` runtime writes a durable Markdown report to `.hotl/reports/<run-id>.md` incrementally during execution. This is the canonical report spec — other executors inherit it.

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

The `hotl-rt` runtime manages all report updates automatically via its subcommands:

1. **`hotl-rt init`:** Create report with metadata (including `Updated:`) and full table (all `· Pending`). Store `report_path` in sidecar JSON.
2. **`hotl-rt step N start`:** Update table to `→ Running`, update `Updated:`, append event
3. **`hotl-rt step N verify` (fail):** Update table, append captured stdout/stderr to event log
4. **`hotl-rt step N retry`:** Update table to `↻ Retrying`, append retry event
5. **`hotl-rt step N verify` (pass):** Update table to `✓ Done`, append completion event
6. **`hotl-rt gate N`:** Update table to `⚡ Auto-approved` or `✓ Approved`
7. **`hotl-rt finalize`:** Set status to `completed`, update `Updated:`, finalize report
8. **`hotl-rt step N block`:** Set status to `blocked`, include report path in response

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

### Platform Rendering

| Platform | Live step visibility | Final summary format |
|---|---|---|
| Codex | Native progress card (primary). Per-step chat logs as fallback. | Compact list in chat |
| Claude Code | Per-step one-line chat logs | Markdown table |
| Cline | Per-step one-line chat logs | Markdown table |

Durable report (`.hotl/reports/<run-id>.md`) always uses full markdown table regardless of platform.

### Live Step Visibility (mandatory)

Every execution run MUST provide live step visibility — the user must see which step is currently executing and which are done, during execution. This is not optional on any platform.

### Codex Native Progress (mandatory with fallback)

When running in the Codex app, the executor MUST use the native plan/progress UI as the primary live step visibility surface:

- MUST initialize the native progress card immediately after run setup (step 4 of the state machine)
- MUST update it on every step transition — exactly one step `in_progress` at a time
- MUST keep the native card high-level: major workflow steps only, not retries or verify substeps
- If the native progress tool is unavailable or errors, MUST immediately switch to per-step chat logs for the remainder of the run. Do not silently drop visibility.
- Native progress never replaces the final chat summary, durable report, or sidecar state

On platforms without native progress (Claude Code, Cline), the executor MUST use per-step chat logs for live visibility.

### Per-Step Log (default, always shown)

After each step, log one line:
```
✓ Step 1: Write failing tests
✓ Step 2: Implement auth logic (3 attempts)
⚡ Step 3: Security review gate (auto-approved)
✓ Step 4: Update docs
```

### Final Summary (mandatory)

Every execution run MUST end with a visible summary in chat. The summary MUST include: step number, name, status, and iterations for every step. This is not optional.

**Required information per step:** step number, step name, final status, iteration count.

**Rendering rule:** use the repo-owned deterministic renderer at `scripts/render-execution-summary.sh` for the final summary output. Do not freehand the final summary when the renderer is available. The renderer normalizes gate results before formatting, so `gate_result=approved` renders as `Approved` instead of raw `Done`.

**Platform rendering rules:**

**Claude Code and Cline** — use a markdown table (renders cleanly in terminal):

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

**Codex** — use a compact list (wide tables render poorly in the Codex app):

```
Execution Summary

✓ Step 1: Write failing tests - Done (1 attempt)
✓ Step 2: Implement auth logic - Done (3 attempts)
⚡ Step 3: Security review gate - Auto-approved (-)
✓ Step 4: Run full test suite - Done (65 tests, 1 attempt)
✓ Step 5: Human review - Approved (1 attempt)
```

**Compact list rules:**
- Step name first, then inline status detail after ` - `
- Include status word on every line: `Done`, `Approved`, `Auto-approved`, `Failed`, `Blocked`
- Include iteration count: `1 attempt` / `N attempts`. For gates: `(-)`
- Test counts go inside status detail before attempt count: `Done (28/28, 2 attempts)`

**Durable report** (`.hotl/reports/<run-id>.md`) always uses the full markdown table regardless of platform.

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
