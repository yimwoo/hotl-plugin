---
name: writing-plans
description: Use after design approval to create a hotl-workflow.md implementation plan with bite-sized tasks, exact file paths, and loop/gate definitions.
---

# Writing HOTL Plans

## Overview

Produce a `hotl-workflow.md` file that `loop-execution` can execute. Each step should be 2-5 minutes of work. Include loop conditions and gates from the design's governance contract.

**Announce:** "I'm using the writing-plans skill to create the implementation plan."

## Output: hotl-workflow.md

Save to project root. Format:

```markdown
---
intent: [from design's intent contract]
success_criteria: [from design's intent contract]
risk_level: low | medium | high
auto_approve: true | false
---

## Steps

### N. [Step name]
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

**"Plan saved to `hotl-workflow.md`. Two options:**
1. **Loop execution (this session)** — `/hotl:loop` runs steps autonomously with auto-approve
2. **Manual execution** — `/hotl:execute-plan` for linear execution with explicit checkpoints

Which approach?"
