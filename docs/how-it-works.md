# How HOTL Works — In Detail

This page expands on each phase of the HOTL workflow. For a quick overview, see the [main README](../README.md#the-hotl-workflow).

---

## 1. Brainstorm

HOTL asks clarifying questions, proposes options, and writes a design around three contracts:

- **Intent contract** — what you are building, constraints, success criteria, risk level
- **Verification contract** — what commands or checks prove the work is correct
- **Governance contract** — where human review is required and how to roll back

The brainstorming phase prevents the most common AI coding failure: jumping straight into code before requirements are clear.

## 2. Plan

HOTL creates a workflow file in the project root named `hotl-workflow-<slug>.md`:

```yaml
---
intent: Add Redis-backed sliding window rate limiter to FastAPI service
success_criteria: 429 after threshold, configurable per-endpoint, all tests pass
risk_level: medium
auto_approve: true
branch: feat/add-rate-limiter   # optional — defaults to hotl/<slug>
worktree: false                 # optional opt-out — default is isolated worktree execution
---

## Steps

- [ ] **Step 1: Write failing tests**
  action: Write tests for rate limit behavior
  loop: false
  verify: pytest tests/test_rate_limit.py -v

- [ ] **Step 2: Implement rate limiting**
  action: Add rate limiting middleware
  loop: until tests pass
  max_iterations: 5
  verify: pytest tests/test_rate_limit.py -v
```

Each step has an action, an optional loop condition, a verify command, and an optional gate (`human` or `auto`). See [workflow-format.md](workflow-format.md) for the full specification.

## 3. Review Before Execution

HOTL reviews both design docs and workflow plans before execution starts:

- **Structural lint** — `scripts/document-lint.sh` checks formatting and required fields
- **AI review** — `hotl:document-review` evaluates plan quality

Lint failures are hard blockers. AI review produces one of:

| Verdict | Meaning |
| --- | --- |
| `PASS` | Plan is ready for execution |
| `REVISE` | Issues found — fix before proceeding |
| `HUMAN_OVERRIDE_REQUIRED` | Requires explicit human approval |

Execution does not start from a structurally broken or obviously weak plan.

## 4. Git Execution Isolation

Before executing any steps, HOTL resolves a dedicated execution root so work never lands directly on `main`, `master`, or the wrong live checkout.

**Branch naming:**
- Default: derived from the workflow filename — `hotl-workflow-add-auth.md` becomes `hotl/add-auth`
- Override: set `branch: feat/add-auth` in the workflow frontmatter
- Default isolation: create a git worktree, copy the workflow into it, and execute from that isolated checkout
- Opt out: set `worktree: false` to stay in the current checkout on a dedicated branch

**Safety checks:**
- Uncommitted changes block execution (no auto-stash — you decide what to do)
- Existing branches always prompt: reuse, recreate, or abort
- Repos without git or with no commits skip branching and execute in place

Every workflow execution starts clean, on its own isolated execution root, with no risk to the main branch.
HOTL records the `execution_root` and `worktree_path` in runtime state so resume/reporting stay bound to the correct checkout rather than whatever branch another session switched later.

## 5. Execute

All execution modes share one engine: the **HOTL execution state machine** (resolve → preflight → lint → execute → verify → loop → gate → summarize). They differ in how steps run and how often human checkpoints occur.

### Loop Execution (universal engine)

The canonical execution mode. HOTL runs the workflow step by step, retries steps that are allowed to loop, auto-approves low-risk gates, and pauses on high-risk or human-gated steps. Works on all platforms.

For every step transition, HOTL must persist `.hotl/state/<run-id>.json` and update `.hotl/reports/<run-id>.md` before showing the corresponding progress in chat or the Codex progress card. The UI is a mirror; the sidecar and report are the durable record.

### Manual Execution (checkpointed)

Loop execution with explicit human checkpoints every 3 steps. You review progress before the next batch continues. Best for tighter oversight.

### Subagent Execution (delegated step runner)

Loop execution with a delegated step runner. The controller stays in the current session and keeps governance, verification, and stop conditions. Eligible implementation steps are delegated to fresh subagents. Requires platform support for subagents (Claude Code, Codex).

## 6. Code Review at Checkpoints

HOTL embeds code review into execution as a first-class lifecycle stage — not a post-hoc check.

**How it works:**
- Executors invoke `requesting-code-review` at defined checkpoints (batch boundaries, pre-completion) with structured context: git range, HOTL contracts, and verification evidence
- The `code-reviewer` agent produces findings with file:line references, severity (BLOCK/WARN/NOTE), and fix direction
- Findings are handled via `receiving-code-review`: verify each claim against the codebase and contracts before acting

**Core rule:** Review feedback is input to evaluate, not instructions to obey. Each finding goes through Verify → Evaluate → Respond → Implement before any change is made.

**Verdict model:**
- Checkpoint reviews: PROCEED / PROCEED WITH WARNINGS / HOLD
- Final reviews: READY / READY WITH WARNINGS / NOT READY

BLOCK issues must be resolved before proceeding past a review checkpoint.

## 7. Verify Before Completion

HOTL does not treat "should work" as done. It requires real evidence:

- Test commands pass
- Lint output is clean
- Verification commands from the workflow succeed
- Success criteria are checked against actual results

No green checkmark without proof.
