---
name: writing-plans
description: Use after design approval to create a hotl-workflow-<slug>.md implementation plan with bite-sized tasks, exact file paths, and loop/gate definitions.
---

# Writing HOTL Plans

## Overview

Produce a `hotl-workflow-<slug>.md` file that `loop-execution` can execute. The `<slug>` is a short kebab-case name from the intent (e.g., `hotl-workflow-add-rate-limiting.md`). Each step should be 2-5 minutes of work. Include loop conditions and gates from the design's governance contract.

**Announce:** "I'm using the writing-plans skill to create the implementation plan."

## Output Filename

Save to project root as `hotl-workflow-<slug>.md`, where `<slug>` is a short kebab-case slug derived from the intent (e.g., `hotl-workflow-add-user-auth.md`, `hotl-workflow-refactor-api.md`). This prevents conflicts when multiple agents work on the same project simultaneously.

Format:

```markdown
---
intent: [from design's intent contract]
success_criteria: [from design's intent contract]
risk_level: low | medium | high
auto_approve: true | false
# branch: custom/branch-name   # optional — execution derives hotl/<slug> if absent
# worktree: true                # optional — default false, creates git worktree instead of branch checkout
# dirty_worktree: allow         # optional — proceed even if non-HOTL files are uncommitted
---

## Steps

- [ ] **Step N: [Step name]**
action: [what to do]
loop: false | until [condition]
max_iterations: [number, default 3]
verify: [scalar command OR typed block]
gate: human | auto   # optional
```

## Typed Verification

Choose the appropriate verify type for each step:

- **shell** — for test suites, linters, build commands (default; scalar shorthand accepted)
- **browser** — for UI work requiring visual inspection (capability-gated; falls back to human-review)
- **human-review** — for subjective quality checks with no automated signal
- **artifact** — for verifying files/outputs exist and meet criteria

```yaml
# Scalar shorthand (type: shell)
verify: pytest tests/ -v

# Structured
verify:
  type: browser
  url: http://localhost:3000/dashboard
  check: priority badge renders with correct color

# Artifact with structured assert
verify:
  type: artifact
  path: migrations
  assert:
    kind: matches-glob
    value: "*.sql"

# Multiple checks per step
verify:
  - type: shell
    command: npm test
  - type: artifact
    path: coverage/lcov.info
    assert:
      kind: exists
```

## Step Granularity

Break work into atomic steps:
- "Write failing test for X" (loop: false, verify: pytest)
- "Implement X" (loop: until tests pass, verify: pytest)
- "Fix lint errors" (loop: until clean, verify: ruff check .)
- "Verify UI renders correctly" (loop: false, verify: type: browser)
- "Human review of security logic" (loop: false, gate: human — REQUIRED for risk_level: high)

## risk_level Guidelines

- **low:** UI changes, new endpoints, non-critical features
- **medium:** Schema changes, refactors, performance work
- **high:** Auth/authz, encryption, privacy logic, billing, multi-tenant isolation

`risk_level: high` **always** generates `gate: human` on security-sensitive steps, regardless of `auto_approve`.

## Self-Check Loop

After saving the workflow file, run a self-check before offering execution options. Review the plan for:

- **Step sizing** — each step should be 2-5 minutes of atomic work
- **Verify coverage** — every looped step has a verify command that tests what the step claims
- **Gate placement** — risky steps (auth, encryption, billing, secrets) have `gate: human`
- **Loop safety** — `max_iterations` is reasonable (typically 3-5)
- **Ordering** — logical dependencies between steps are respected

If issues are found, fix them in the workflow file and re-check until clean. Do not ask the user to review — this is an internal quality pass.

## After Saving

Once the self-check passes, offer execution options:

**"Plan saved to `hotl-workflow-<slug>.md`. How would you like to execute?"**
1. **Loop execution (this session)** — `/hotl:loop` runs steps autonomously with auto-approve
2. **Manual execution** — `/hotl:execute-plan` for linear execution with explicit checkpoints
3. **Subagent execution (this session)** — `/hotl:subagent-execute` delegates implementation-friendly steps to fresh subagents while the controller keeps gates and verification

If a previous run was interrupted, use `/hotl:resume` to continue from where it left off.

*(Always tell the user the exact filename so they can pass it to the execution command if multiple workflow files exist.)*
