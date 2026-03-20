---
name: subagent-execution
description: Delegated step runner over the HOTL execution state machine — delegates eligible steps to fresh subagents while the controller keeps governance, verification, and stop conditions.
---

# HOTL Subagent Execution

## Overview

This is a **delegation profile** over the HOTL execution state machine defined in `skills/loop-execution/SKILL.md`. It follows the same resolve → preflight → lint → execute → verify → loop → gate → summarize flow, but eligible steps are delegated to fresh subagents instead of running inline.

**Core principle:** delegation is allowed; governance is not delegated.

## When to Use

- The workflow file already exists
- Steps are independent enough to hand to one worker at a time
- You want the controller to stay in this session and keep ownership of gates and verification

## Execution

Follow the **HOTL Execution State Machine** in `skills/loop-execution/SKILL.md` for the full execution flow (workflow resolution, interrupted run detection, branch/worktree preflight, structural lint, execution state persistence, typed verification, loop rules, gate rules, completion).

The controller owns all `hotl-rt` runtime calls. The controller calls `hotl-rt init`, `hotl-rt step N start/verify/retry/block`, `hotl-rt gate N`, and `hotl-rt finalize` — subagents never call the runtime directly. The runtime-managed `.hotl/state/<run-id>.json` and `.hotl/reports/<run-id>.md` are the source of truth; delegated workers do implementation only.

The only difference is **how each step body runs:**

1. Announce the step
2. Decide whether to delegate or run inline (see Delegation Rules below)
3. If delegated:
   - Dispatch a fresh subagent with the full step text, the relevant files, and the success condition
   - Do not make the subagent infer the plan from scratch — provide the step directly
   - Answer clarifying questions before letting the subagent continue
4. If inline: execute the step directly in the controller session
5. Run verification, loop rules, and gate rules as defined in the state machine

## Critical Invariants

These rules apply regardless of delegation decisions:

1. **Verification always runs in the controller session** — never in the subagent
2. **Gates always stay in the controller session** — `gate: human` pauses the controller, not the subagent
3. **No nested delegation** — subagents cannot spawn other subagents
4. **No parallel write-heavy steps** — do not run multiple implementation subagents in parallel against the same workflow
5. **Controller owns stop conditions** — on repeated verify failure, the controller stops and reports; it does not let the subagent retry silently

## Delegation Rules

**Delegate by default:**
- Test-writing steps
- Implementation steps
- Localized documentation changes
- Contained refactors

**Keep controller-owned by default:**
- Human-gated steps
- Security-sensitive decisions
- Final verification and summaries
- Any step whose failure would require architectural judgment

## Reporting

Inherits the mandatory Execution Reporting Contract from `skills/loop-execution/SKILL.md` — same platform rendering rules, same live step visibility requirements, same final summary (must be shown), same durable `.hotl/reports/<run-id>.md` artifact.

## Related Skills

- `hotl:loop-execution` — the canonical execution state machine (this skill builds on it)
- `hotl:verification-before-completion` — required before claiming done
- `hotl:dispatch-agents` — use for generic parallel independent tasks, not governed workflow execution
