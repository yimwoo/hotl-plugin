## HOTL Subagent Execution

**When to use:** When you have a HOTL workflow, preferably `docs/plans/YYYY-MM-DD-<slug>-workflow.md`, and want same-session execution with delegated subagent steps.

**Full skill:** Read `__HOTL_HOME__/skills/subagent-execution/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### Relationship to Loop Execution

This is a **delegation profile** over the HOTL execution state machine. Follow the same execution process as `hotl-execution.md` (resolve → preflight → lint → execute → verify → loop → gate → summarize). The only difference is how step bodies run.

### Process

1. Resolve the workflow file
2. Run preflight and structural lint (same as hotl-execution.md), change into the resolved `execution_root`, and pin runtime/helper calls to the captured `run_id`
3. For each step in order:
   - Decide whether to delegate or run inline
   - If delegated: use a fresh subagent with the exact step text and relevant context
   - Run verification in the controller session (typed verification applies)
   - Obey loop and max_iterations
   - Pause on gate: human
4. Run final verification before claiming done

### Critical Invariants

- **Verification always in controller** — never in the subagent
- **Gates always in controller** — gate: human pauses the controller, not the subagent
- **No nested delegation** — subagents cannot spawn other subagents
- **No parallel write-heavy steps** — do not run multiple implementation subagents in parallel

### Default Delegation Heuristic

- Delegate: contained implementation, test, and localized docs steps
- Keep controller-owned: security-sensitive, human-gated, and final verification steps

### Review Checkpoints

The controller invokes `requesting-code-review` after meaningful delegated batches (3+ implementation steps, cross-module, or high-risk/user-facing/shared-infra changes) and before final completion. Findings are handled via `receiving-code-review` in the controller — never in a subagent. All BLOCK findings must be resolved before delegating the next batch.

### Reporting

Follows the same Execution Reporting Contract as `hotl-execution.md` — same final summary table column rules, same verbose progress format, same durable `.hotl/reports/<run-id>.md` artifact.
