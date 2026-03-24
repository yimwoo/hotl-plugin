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
   → Run review checkpoint (see Review Checkpoints below)
   → Invoke hotl:verification-before-completion skill
   → Run: `hotl-rt finalize --json`
   → Render the summary payload with the deterministic renderer: `scripts/render-execution-summary.sh --platform <codex|claude|cline> <summary-json-file>`
   → Never freehand the final summary when the renderer is available
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

Execution report output must conform to `docs/contracts/execution-report-output.md`. The contract defines the durable report format (metadata, summary table, event log), execution status vocabulary, final summary semantics, platform rendering tables, and the deterministic renderer reference.

The `hotl-rt` runtime writes the durable report to `.hotl/reports/<run-id>.md` incrementally. The report survives app rendering quirks and provides a reliable post-run artifact for debugging, trust, and resume.

## Review Checkpoints

Record `git rev-parse HEAD` as the review base at run start and after each review.

### At Final Completion

After all steps have passed verification, before `hotl-rt finalize`:
1. A final review is required unless the most recent review already covers all current changes and no code changed afterward
2. Invoke `requesting-code-review` with review type: final
   - Review base: branch point or last review base, whichever is more recent
3. When findings return, invoke `receiving-code-review`
   - Follow Verify → Evaluate → Respond → Implement
4. Resolve all BLOCK findings before finalizing
5. If fixes after the last review changed scope, constraints, or risk_level, request a scoped follow-up review before completing

### At Intermediate Gates (Conditional)

At intermediate `gate: human` steps, request review only when:
- risk_level is high
- The gate covers cross-module or feature-scale changes
- Multiple steps have completed since the last review

When triggered, scope the review to steps completed since the last review checkpoint, not the entire run. Use review type: checkpoint.

Do not request review at every gate by default.

### Review Ordering

Review happens:
1. After step verification is complete
2. Before `verification-before-completion`
3. Before `hotl-rt finalize` / any "done" claim

## Safety Rules

- `risk_level: high` in frontmatter **always** forces human approval at `gate: human` steps, even if `auto_approve: true`
- Never skip a `gate: human` on steps with security-sensitive keywords (auth, encrypt, secret, key, password, token, permission, role, billing)
- On STOP: always show the failing verify output so human can diagnose

## Live Execution Behavior

Report format, status vocabulary, final summary semantics, and platform rendering tables for final artifacts are defined in `docs/contracts/execution-report-output.md`. This section covers runtime behavior that is executor-owned: live step visibility, progress updates, and verbose mode.

### Platform Live Step Visibility

| Platform | Live step visibility |
|---|---|
| Codex | Native progress card (primary). Per-step chat logs as fallback. |
| Claude Code | Per-step one-line chat logs |
| Cline | Per-step one-line chat logs |

### Live Step Visibility (mandatory)

Every execution run MUST provide live step visibility — the user must see which step is currently executing and which are done. This is not optional on any platform.

### Codex Native Progress (mandatory with fallback)

When running in the Codex app, the executor MUST use the native plan/progress UI as the primary live step visibility surface:

- MUST initialize the native progress card immediately after run setup (step 4 of the state machine)
- MUST update it on every step transition — exactly one step `in_progress` at a time
- MUST keep the native card high-level: major workflow steps only, not retries or verify substeps
- If the native progress tool is unavailable or errors, MUST immediately switch to per-step chat logs for the remainder of the run. Do not silently drop visibility.
- Native progress never replaces the final chat summary, durable report, or sidecar state
- If Codex needs an explicit readout of the active workflow step, use `scripts/show-codex-current-step.sh` to print the current step number, name, status, and attempts from the active run without mutating state

On platforms without native progress (Claude Code, Cline), the executor MUST use per-step chat logs for live visibility.

### Per-Step Log (default, always shown)

After each step, log one line:
```
✓ Step 1: Write failing tests
✓ Step 2: Implement auth logic (3 attempts)
⚡ Step 3: Security review gate (auto-approved)
✓ Step 4: Update docs
```

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
