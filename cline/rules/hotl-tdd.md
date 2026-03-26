## HOTL Test-Driven Development

**When to use:** Before writing any implementation code.

**Full skill:** Read `__HOTL_HOME__/skills/tdd/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY RULE

**NEVER write implementation code before a failing test exists.** This is not optional. If you catch yourself writing code first, STOP and write the test.

### The Cycle: RED then GREEN then REFACTOR

You MUST follow this exact order. Do NOT skip or reorder steps.

**1. RED — Write a failing test**
- Write the test FIRST
- Run it — it MUST fail
- Confirm the failure message matches what you expect
- If the test passes immediately, the test is wrong — fix it

**2. GREEN — Write minimal code to pass**
- Write ONLY the code needed to make the failing test pass
- Do NOT add extra features, handle edge cases, or "improve" the code
- Run the test — it MUST pass now

**3. REFACTOR — Clean up**
- Improve code structure without changing behavior
- Run tests again — they MUST still pass
- If they fail, you changed behavior — undo and try again

**4. COMMIT — Small atomic commit after each cycle**

### What You MUST NOT Do

- NEVER write implementation code before the failing test — this is the #1 rule
- NEVER skip running the test at each phase — no guessing
- NEVER write a test that passes immediately — that's a false green, fix the test
- NEVER test private implementation details — test public behavior
- NEVER write one giant test for everything — small, focused tests
- NEVER skip the refactor phase — this is where code quality happens
