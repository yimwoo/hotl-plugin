---
name: verification-before-completion
description: Use before claiming any work is complete, fixed, or passing — runs verification commands and confirms output before making success claims.
---

# Verification Before Completion

## Rule

Never claim "done", "fixed", or "passing" without running verification commands and showing the output.

Evidence before assertions. Always.

## Checklist

Before claiming complete:

- [ ] Run the test suite: show the output
- [ ] Run the linter/formatter: show the output
- [ ] Confirm the specific behavior that was requested works
- [ ] No regressions in previously passing tests

## What to Show

```
Tests: pytest output (N passed, 0 failed)
Lint: ruff/eslint output (clean)
Behavior: [description of manual or automated check]
```

If anything fails: report it honestly. Do not claim partial success as full success.
