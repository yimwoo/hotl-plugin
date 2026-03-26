## HOTL Systematic Debugging

**When to use:** When encountering any bug, test failure, or unexpected behavior.

**Full skill:** Read `__HOTL_HOME__/skills/systematic-debugging/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY RULE

**NEVER guess at fixes.** Follow the 4 phases below in order. Do NOT skip to "Fix" without completing Reproduce, Understand, and Hypothesize first.

### Phase 1: Reproduce

- Create a minimal, reliable way to trigger the bug
- Run it and confirm you see the exact same error
- **NEVER fix what you cannot reproduce**
- Document: exact steps, inputs, expected output, actual output

### Phase 2: Understand

- Read the FULL error message — every line, including stack traces
- Trace the call path from the error back to the entry point
- Check recent changes: `git log --oneline -10`, `git diff`
- Read the relevant source code around the error location

**DO NOT propose fixes yet. You are still gathering information.**

### Phase 3: Hypothesize

- Form 1-3 specific hypotheses about the root cause
- For each hypothesis, describe what test would confirm or rule it out
- Test each hypothesis independently with the smallest possible change
- **DO NOT change multiple things at once** — one change per test

### Phase 4: Fix and Verify

- Fix the ROOT CAUSE, not the symptom
- Run the reproduction case — confirm the bug is gone
- Run the full test suite — check for regressions
- Show the actual test output as evidence

### What You MUST NOT Do

- NEVER try random fixes without a hypothesis — stop and think
- NEVER change multiple things at once — isolate each change
- NEVER claim "fixed" without running the reproduction AND the test suite
- NEVER summarize test output — show the actual output
