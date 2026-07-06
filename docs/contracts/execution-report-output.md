# Execution Report Output Contract

This contract defines the canonical output schema for HOTL execution reports. It specifies the durable report format, execution status vocabulary, final summary semantics, finish-outcome recording, and platform rendering tables for final artifacts. All executors (loop-execution, executing-plans, subagent-execution) must conform to this contract.

Presentation of live progress is executor behavior, not part of this contract. See executor skill files for live step visibility rules.

## Required Sections

Every execution report (`.hotl/reports/<run-id>.md`) must contain these 5 required sections during execution. If HOTL later records a post-execution finish decision, it appends an optional sixth section.

### 1. Report Metadata

```markdown
# Execution Report: <run-id>

**Workflow:** docs/plans/YYYY-MM-DD-<slug>-workflow.md
**Source Workflow:** /abs/path/to/original/workflow.md
**Intent:** <intent from frontmatter>
**Branch:** <branch name>
**Executor:** loop | executing-plans | subagent
**Execution Root:** /abs/path/to/repo-or-worktree
**Worktree:** /abs/path/to/worktree (optional)
**Started:** <ISO 8601>
**Updated:** <ISO 8601>
**Status:** running | paused | blocked | ready_to_finish | completed
```

### 2. Summary Table

Updated in-place at each step transition:

```markdown
| Step | Name              | Status      | Iterations |
|------|-------------------|-------------|------------|
|  1   | Write tests       | ✓ Done      | 1          |
|  2   | Implement feature | → Running   | -          |
|  3   | Human review      | · Pending   | -          |
```

### 3. Event Log

Timestamped entries appended after each step transition:

```markdown
## Event Log

**[10:00:05]** → Step 1: Write tests
**[10:01:12]** ✓ Step 1: Done (1 attempt)
**[10:01:15]** → Step 2: Implement feature
**[10:02:30]** ↻ Step 2: Retrying (2/3)
  verify output:
  FAILED: test_auth - AssertionError: expected 401, got 200
```

### 4. Final Summary

Every execution run must end with a visible summary. The summary must include step number, name, status, and iterations for every step. See Platform Rendering below for format per platform.

For Codex, the compact summary itself must appear as visible chat text in the final assistant message. A prose recap without the rendered step list is non-compliant.

### 5. Verification Notes

What verification was performed across the run — test commands, linter results, artifacts inspected. Brief, just enough to show what informed the execution outcomes.

### 6. Finish Outcome (Required For Successful Completion)

During execution this section is absent. After an explicit disposition, append:

```markdown
## Finish Outcome

**Disposition:** kept | merged | published | discarded
**Recorded:** <ISO 8601>
**Target Branch:** <branch>                 (optional)
**Remote:** <remote>                        (optional)
**PR URL:** <url>                           (optional)
**Branch Action:** kept | deleted | merged-into-<branch>
**Worktree Action:** kept | removed         (optional)
**Artifacts Preserved At:** /abs/path/.hotl (optional)
**Notes:** <short explanation>              (optional)
```

## Execution Status Vocabulary

These are step and run state indicators — status labels, not a severity system.

**Step status values:**

| Symbol | Status | Meaning |
|--------|--------|---------|
| `·` | Pending | Step not yet started |
| `→` | Running | Step currently executing |
| `↻` | Retrying | Step failed verification, retrying |
| `⚡` | Auto-approved | Gate auto-approved (low/medium risk) |
| `✓` | Done | Step completed and verified |
| `✓` | Approved | Gate approved by human |
| `✗` | Failed | Step verification failure |
| `✗` | Blocked | Executor stopped (max retries, gate denied, etc.) |

**Run status values:** `running`, `paused`, `blocked`, `ready_to_finish`, `completed`

- `ready_to_finish` means steps, verification, gates, sensitive-effect evidence, and budgets are terminal, but no branch/worktree disposition has been recorded.
- `completed` means a successful `ready_to_finish` run also recorded an explicit finish disposition. Host session completion or a rendered summary cannot create this status.

## Report Lifecycle

The `hotl-rt` runtime manages all report updates automatically via its subcommands:

1. **`hotl-rt init --require-owner`:** Create report with metadata and full table (all `· Pending`). Store `report_path` plus execution-root metadata in sidecar JSON.
2. **`hotl-rt owner claim|heartbeat|handoff|release|takeover`:** Record controller lifecycle without exposing the raw token.
3. **`hotl-rt step N start --run-id <run-id>`:** Update table to `→ Running`, update `Updated:`, append event.
4. **`hotl-rt step N verify --run-id <run-id>` (fail):** Update table, append captured stdout/stderr to event log.
5. **`hotl-rt step N retry --run-id <run-id>`:** Update table to `↻ Retrying`, append retry event.
6. **`hotl-rt step N verify --run-id <run-id>` (pass):** Update table to `✓ Done`, append completion event.
7. **`hotl-rt gate N --run-id <run-id>`:** Update table to `⚡ Auto-approved` or `✓ Approved`.
8. **`hotl-rt action request|decide|begin|complete|reconcile`:** Record bounded authorization, pre-effect intent, and observed effect outcome.
9. **`hotl-rt finalize --run-id <run-id>`:** Validate terminal evidence. Set a successful run to `ready_to_finish`; blocked evidence remains `blocked`.
10. **`hotl-rt step N block --run-id <run-id>`:** Set status to `blocked`, include report path in response.
11. **`hotl-rt finish <disposition> --run-id <run-id>`:** Record the disposition, append Finish Outcome, and move successful `ready_to_finish` to `completed`.
12. **`hotl-rt receipt <run-id>`:** Derive sufficiency from state. A successful completion claim requires `sufficiency.sufficient: true` after finish.

## Verify Output Policy

- **Default:** Failed verifies include captured stdout/stderr in the event log. Successful verifies get a one-line result only.
- **`report_detail: full`** (frontmatter opt-in): All verify output included for every step, successful or not.

## Report Path Reference

The executor must reference the report path in its response:
- At successful completion
- On gate pause / human review pause
- On blocked / failed / max iterations stop
- When detecting interrupted runs for resume

## Relationship to Other Artifacts

- **Chat output** = primary live UX (per-step logs, verbose progress, final summary)
- **Markdown report** = durable human-readable record (survives app rendering quirks)
- **JSON sidecar** = authoritative machine state (resume, tooling, structured queries)

## Platform Rendering (Final Artifacts)

These tables define how the verified-step summary and durable report render per platform. A renderer formats evidence but does not change `ready_to_finish` into `completed`; completion still requires finish and a sufficient receipt.

| Platform | Final Summary Format | Durable Report |
|----------|---------------------|----------------|
| Codex | Compact list in chat | Full markdown table |
| Claude Code | Markdown table | Full markdown table |
| Cline | Markdown table | Full markdown table |

### Deterministic Renderer

Use the repo-owned deterministic renderer at `scripts/render-execution-summary.sh` for final summary output. Do not freehand the final summary when the renderer is available. The renderer normalizes gate results before formatting, so `gate_result=approved` renders as `Approved` instead of raw `Done`.

For Codex, use `scripts/finalize-codex-summary.sh` so evidence finalization and rendering happen sequentially from one helper. Its successful output may represent `ready_to_finish`; record the explicit finish disposition and check the receipt before calling the run completed.

### Claude Code and Cline — Markdown Table

```
| Step | Name                    | Status             | Iterations |
|------|-------------------------|--------------------|------------|
|  1   | Write failing tests     | ✓ Done (17 tests)  | 1          |
|  2   | Implement auth logic    | ✓ Done             | 3          |
|  3   | Security review gate    | ⚡ Auto-approved    | -          |
|  4   | Run full test suite     | ✓ Done (65 tests)  | 1          |
|  5   | Human review            | ✓ Approved         | -          |
```

**Column rules:**
- **Step** — step number only
- **Name** — step name from the workflow
- **Status** — outcome + details. Values: `✓ Done`, `✓ Done (N tests)`, `⚡ Auto-approved`, `✓ Approved`, `✗ Failed`, `✗ Blocked`
- **Iterations** — attempt count as a number only (`1`, `2`, `3`). For gates: `-`. Never put test counts or details here.

### Codex — Compact List

Wide tables render poorly in the Codex app. Use a compact list instead:

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
- The rendered compact list must be included directly in the final Codex response; do not replace it with narrative prose

### Durable Report

`.hotl/reports/<run-id>.md` always uses the full markdown table regardless of platform.
