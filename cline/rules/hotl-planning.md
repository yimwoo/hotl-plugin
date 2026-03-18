## HOTL Planning

**When to use:** After design approval. Create an implementation plan before coding.

**Full skill:** Read `~/.cline/hotl/skills/writing-plans/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY — DO NOT SKIP

You MUST create a `hotl-workflow-<slug>.md` file before writing any implementation code. Do NOT start coding without a plan file.

### Output

Save to project root as `hotl-workflow-<slug>.md` where `<slug>` is a short kebab-case name from the intent (e.g., `hotl-workflow-add-auth.md`).

### Format (follow exactly)

```markdown
---
intent: [from design's intent contract]
success_criteria: [from design's intent contract]
risk_level: low | medium | high
auto_approve: true | false
---

## Steps

- [ ] **Step N: [Step name]**
action: [what to do]
loop: false | until [condition]
max_iterations: [number, default 3]
verify: [command to run]
gate: human | auto
```

### Step Rules

Break work into atomic steps (2-5 minutes each). Each step MUST have:
- A clear action
- A verify command that confirms success
- A loop condition (false for one-shot, or "until [condition]" for retry)

Examples:
- "Write failing test for X" (loop: false, verify: test runner shows 1 failure)
- "Implement X" (loop: until tests pass, verify: pytest, max_iterations: 3)
- "Fix lint errors" (loop: until clean, verify: linter command)
- "Human review of security logic" (loop: false, gate: human)

### Risk Level Rules

- **low:** UI changes, new endpoints → auto-approve OK
- **medium:** Schema changes, refactors → proceed with caution
- **high:** Auth, encryption, privacy, billing → ALWAYS add `gate: human` on sensitive steps

### Self-Check Loop

After saving the workflow file, run a self-check before offering execution options. Review the plan for:
- **Step sizing** — each step should be 2-5 minutes of atomic work
- **Verify coverage** — every looped step has a verify command
- **Gate placement** — risky steps have `gate: human`
- **Loop safety** — `max_iterations` is reasonable
- **Ordering** — logical dependencies respected

If issues are found, fix them and re-check until clean. This is an internal quality pass — do not ask the user to review.

### After Saving the Plan

Offer loop, manual, or subagent execution. Do NOT auto-execute. Wait for explicit approval.
