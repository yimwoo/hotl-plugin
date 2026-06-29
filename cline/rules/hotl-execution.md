## HOTL Execution

**When to use:** When you have a HOTL workflow to execute, preferably `docs/plans/YYYY-MM-DD-<slug>-workflow.md`.

**Full skills:** Prefer `__HOTL_HOME__/skills/governed-execution/SKILL.md` for native-or-fallback routing. Use `__HOTL_HOME__/skills/executing-plans/SKILL.md` (linear), `__HOTL_HOME__/skills/loop-execution/SKILL.md` (autonomous), or `__HOTL_HOME__/skills/subagent-execution/SKILL.md` (delegated same-session execution) as explicit compatibility profiles. If unavailable, follow the condensed version below.

### MANDATORY RULES

- **NEVER skip steps.** Execute every step in order.
- **NEVER skip verification.** Run the verify command for every step.
- **NEVER claim a step passed if verify failed.** Report the failure and retry or stop.
- **NEVER mark task complete without running ALL verify commands.**

### Workflow Resolution

1. If the user specifies a filename → use it
2. Else look for canonical workflows in `docs/plans/*-workflow.md`:
   - One match → use it
   - Multiple → if one is clearly the newest revision for the same semantic slug, prefer it; otherwise list and ask user to pick
3. If no canonical workflow exists, look for legacy `hotl-workflow-*.md` in project root:
   - One match → use it
   - Multiple → list and ask user to pick
   - None → ask if they want to create one

### Dirty Worktree Handling

Preflight automatically excludes HOTL-owned artifacts (`docs/plans/*-workflow.md`, `hotl-workflow-*.md`, `docs/designs/*.md`, legacy `docs/plans/*-design.md`, legacy `docs/plans/*-plan.md`, `.hotl/`) from dirty worktree checks. If only those files are dirty, execution proceeds normally.

For non-HOTL dirty files: if `dirty_worktree: allow` is set in the workflow frontmatter, proceed without prompting. Otherwise, pause and ask the user to clean up, stash, or approve.

### Structural Lint Preflight

After resolving the workflow file, run HOTL structural lint automatically before any git mutation or step execution:

```bash
bash __SCRIPTS_HOME__/document-lint.sh <workflow-file>
```

If lint **fails:** STOP. Show all errors. The workflow must be fixed before execution can proceed.
If lint **passes:** Continue silently to execution.

### Branch / Worktree Execution Root

After lint passes, resolve the execution root before step 1:

```bash
bash __SCRIPTS_HOME__/hotl-prepare-execution-root.sh <workflow-file> --executor-mode <loop|executing-plans|subagent>
```

This helper returns JSON with `branch`, `repo_root`, `execution_root`, `workflow_path`, `source_workflow_path`, and `worktree_path`.

- By default, it creates a linked worktree, copies the current workflow into it, and returns that worktree as `execution_root`.
- If `worktree: false`, it creates/switches to the dedicated branch in the current checkout and returns the repo root as `execution_root`.
- If `worktree: host`, it keeps the current feature branch exactly as provided by the host tool and returns the current checkout as `execution_root`; `main` and `master` are rejected.
- If already running inside a named linked git worktree and the workflow does not set `branch:` or `worktree:`, the helper uses host mode automatically to avoid stacking another worktree.
- After that, every git command, runtime call, helper call, and review command for the run MUST execute from `execution_root`.

### Typed Verification

The `verify` field supports 4 types. Scalar string = type: shell. List = all must pass.

- **type: shell** — run command, check exit code
- **type: browser** — use browser tooling; if unavailable, downgrade to human-review with check text as prompt
- **type: human-review** — ALWAYS pause, show prompt (never auto-approve)
- **type: artifact** — check path exists, evaluate assert (kind: exists | contains | matches-glob)
  For `matches-glob`, keep the directory in `path` and use a filename glob in `value`; `src/*` is invalid and should be authored as `path: src`

### Execution Process

For each step in the workflow:

1. **Announce:** "Step N: [name]"
2. **Execute** the action
3. **Run typed verification** — show the actual output
4. **If verify passes:** Log "Done — Step N: [name]" and continue
5. **If verify fails AND loop is set:** Retry up to max_iterations. Show each attempt.
6. **If verify fails AND max_iterations reached:** STOP. Show the output. Ask the user what to do.
7. **If gate: human:** STOP. Show what was done. Ask "Continue?" Wait for response.

### After Each 3 Steps — Checkpoint

After every 3 completed steps, pause and show:
- Summary of what was done
- What's coming next
- Ask: "Continue with next batch?"

### Safety Rules

- `risk_level: high` ALWAYS requires human approval at gates, even with `auto_approve: true`
- NEVER skip gates on security-sensitive steps (auth, encrypt, secret, password, token, billing)
- On failure: show the actual verify output — do not summarize or hide errors

### Execution State Persistence

HOTL persists execution state in `.hotl/state/<run-id>.json` (sidecar). This is the authoritative source of truth — workflow checkboxes are a human-visible mirror. State is updated on each step transition, verify result, and status change.

After `hotl-rt init` returns a run id, pin every later runtime/helper call to that run (`--run-id <run-id>` or `HOTL_RUN_ID=<run-id>`). Never rely on "the newest file in .hotl/state" when multiple runs exist.

If the session is interrupted, use `/hotl:resume` to continue. Executors also auto-detect interrupted runs and offer resume when starting a workflow that has unfinished state.

### Durable Execution Report

HOTL writes a durable Markdown report to `.hotl/reports/<run-id>.md` incrementally during execution. The report has a summary table (updated in-place) and a timestamped event log (appended). Reference the report path at completion and on any stop/block/pause. The `report_path` is stored in the sidecar JSON for deterministic access.

### Delegated Execution (optional)

Execution supports an optional delegation mode where eligible steps run in fresh subagents while the controller keeps verification and gates. See `hotl-subagent-execution.md` for delegation rules and critical invariants.

### Reporting (mandatory)

**Live step visibility:** Cline must use per-step one-line chat logs during execution. The user must see which step is running.

**Final summary — preferred path:** After all steps complete, run the deterministic renderer:

```bash
bash __SCRIPTS_HOME__/render-execution-summary.sh --platform cline <summary-json-file>
```

Emit the renderer output directly as visible chat text. Do not paraphrase or replace it.

**Final summary — fallback:** If the renderer cannot be run (jq missing, no terminal access, script not found), emit the markdown table directly using the template below. Do not substitute a prose summary for the fallback.

**Do not end a run with prose-only output.**

**Column rules** (apply to both renderer output and fallback table):
- **Step** — number only
- **Name** — step name
- **Status** — outcome + details: `✓ Done`, `✓ Done (N tests)`, `⚡ Auto-approved`, `✓ Approved`, `✗ Failed`, `✗ Blocked`
- **Iterations** — attempt count only (`1`, `2`, `3`). Gates: `-`. Never put test counts here.

**Verbose progress** (opt-in via `progress: verbose` in frontmatter or invocation override):
Print compact step list at each transition: `✓` completed, `→` current, `·` pending, `⚡` auto-approved, `✗` failed/blocked.

### When All Steps Complete

Show the final summary table. Then run a final verification:
- Run the test suite
- Run the linter
- Confirm the success criteria from the intent contract are met
- Show evidence — NEVER claim success without proof

After that, do not silently merge or delete the execution branch/worktree. Present the explicit finish options: merge back locally, publish/create PR, keep, or discard.

**ONLY THEN mark the task as complete.**

### Final Summary Hard Gate

<HARD-GATE>
Do not end a run with prose-only output.

Preferred: run `bash __SCRIPTS_HOME__/render-execution-summary.sh --platform cline <summary-json>`

Fallback: if the renderer cannot be run, emit this table directly:

## Execution Summary

| Step | Name | Status | Iterations |
|------|------|--------|------------|
| 1 | [step name] | [status] | [iterations] |

- `Status` must be one of: `✓ Done`, `✓ Done (N tests)`, `⚡ Auto-approved`, `✓ Approved`, `✗ Failed`, `✗ Blocked`
- `Iterations` must be attempt count only, or `-` for gates
- One row per step. Every step must appear.

Only after the table may you add a short prose note.
</HARD-GATE>
