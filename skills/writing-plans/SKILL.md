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
---

## Steps

- [ ] **Step N: [Step name]**
action: [what to do]
loop: false | until [condition]
max_iterations: [number, default 3]
verify: [command to run]
gate: human | auto   # optional
```

## Step Granularity

Break work into atomic steps:
- "Write failing test for X" (loop: false)
- "Implement X" (loop: until tests pass, verify: pytest)
- "Fix lint errors" (loop: until clean, verify: ruff check .)
- "Human review of security logic" (loop: false, gate: human — REQUIRED for risk_level: high)

## risk_level Guidelines

- **low:** UI changes, new endpoints, non-critical features
- **medium:** Schema changes, refactors, performance work
- **high:** Auth/authz, encryption, privacy logic, billing, multi-tenant isolation

`risk_level: high` **always** generates `gate: human` on security-sensitive steps, regardless of `auto_approve`.

## After Saving

Offer execution options:

**"Plan saved to `hotl-workflow-<slug>.md`. Before execution, run `hotl:document-review` on the workflow file. Then choose one of three options:**
1. **Loop execution (this session)** — `/hotl:loop` runs steps autonomously with auto-approve
2. **Manual execution** — `/hotl:execute-plan` for linear execution with explicit checkpoints
3. **Subagent execution (this session)** — `/hotl:subagent-execute` delegates implementation-friendly steps to fresh subagents while the controller keeps gates and verification

Which approach?"

*(Always tell the user the exact filename so they can pass it to the execution command if multiple workflow files exist.)*
