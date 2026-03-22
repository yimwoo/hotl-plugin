---
name: requesting-code-review
description: Use at executor review checkpoints to dispatch the code-reviewer agent with structured context — git range, workflow contracts, and verification evidence.
---

# HOTL Requesting Code Review

## Lifecycle

Executors invoke `requesting-code-review` at defined checkpoints. This skill dispatches the `code-reviewer` agent with structured context. Returned findings are handled by `receiving-code-review`.

## Precondition

Only request review when the checkpoint work is in a reviewable state and its planned verification has completed. Do not request review for code that has failing required verification unless the purpose of the review is to diagnose the failure.

## When to Request Review

### Mandatory Triggers

- **executing-plans:** After each 3-step batch boundary
- **subagent-execution:** After meaningful delegated implementation batches (3+ completed implementation steps, or cross-module change, or high-risk/user-facing/shared-infra change)
- **All executors:** Before final completion (claiming done, merging, or creating a PR)

### Conditional Triggers

- **loop-execution:** At intermediate gates only when the change is high-risk, cross-module, or feature-scale. Always at final completion.
- **Ad-hoc development:** Before merge to main. Optionally when stuck or before a large refactor.

### When NOT to Request

- After trivial single-step changes (typo, config value, import fix)
- Mid-loop iterations that haven't reached a gate
- When the same code was already reviewed and hasn't changed since
- Do not request a second full review when a scoped follow-up review is enough

## Review Base (Deterministic)

The review base defines the git range for the reviewer. Executors record this before starting each reviewable batch.

- **Batch review:** `git rev-parse HEAD` recorded by the executor before starting the batch
- **Final review:** Branch point or last recorded review base, whichever is more recent. A final review is required unless the most recent review already covers all current changes and no code changed afterward.
- **Follow-up review:** `HEAD` immediately before the fix. Re-review only the changed scope unless the fix affects shared architecture, risk level, or multiple modules.

## Dispatch Template

When dispatching the `hotl:code-reviewer` agent, provide this context:

```
Review the following implementation work.

**Review type:** checkpoint | final | follow-up | direct
**Workflow:** {workflow_file} (or "No workflow — reviewing against stated intent")
**Steps reviewed:** {step_range} (or "N/A")
**Git range:** {review_base}..{HEAD_SHA}

**Intent contract:**
- intent: {intent}
- constraints: {constraints}
- success_criteria: {success_criteria}
- risk_level: {risk_level}
(or "No formal contract — review against stated intent and general correctness/risk")

**Implementation summary:**
{summary}

**Changed files:**
{git_diff_stat}

**Verification evidence:**
- Commands run: {verification_commands}
- Outcomes: {pass_fail_status}
- Known gaps: {limitations}

Review against the workflow plan and HOTL contracts (if provided),
or against the stated intent and general correctness/risk.
Produce findings with file:line references.
```

## Acting on Results

1. Invoke `receiving-code-review`
2. Follow Verify → Evaluate → Respond → Implement
3. If any accepted BLOCK finding requires re-review after fix, dispatch a scoped follow-up review
4. Do not proceed past the checkpoint until all BLOCK findings are resolved

## Review Types

- **checkpoint** — executor mid-run at a batch boundary (uses PROCEED/HOLD verdict)
- **final** — executor completing a governed workflow run (uses READY/NOT READY verdict)
- **follow-up** — scoped re-review after fixing BLOCK findings
- **direct** — user-invoked review via `hotl:code-review` (uses READY/NOT READY verdict). Findings are returned to the user without automatically invoking `receiving-code-review`.
