---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior — before proposing fixes.
---

# Systematic Debugging

## Four Phases

### Phase 1: Reproduce
- Get a minimal, reliable reproduction
- Never fix what you can't reproduce

### Phase 2: Understand
- Read the error message fully — the answer is often there
- Trace the call path from symptom to root cause
- Check: recent changes, environment differences, assumptions about inputs

### Phase 3: Hypothesize
- Form 1-3 specific hypotheses about root cause
- Test each hypothesis with the smallest possible change
- Never change multiple things at once

### Phase 4: Fix and Verify
- Fix the root cause, not the symptom
- Run the reproduction case — confirm fixed
- Run full test suite — confirm no regressions
- Invoke `hotl:verification-before-completion`

## Red Flags

- "Let me try X and see what happens" without a hypothesis
- Changing multiple things before verifying
- Marking done without running full tests
