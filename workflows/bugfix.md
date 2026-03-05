---
intent: "[FILL IN: describe the bug to fix]"
success_criteria: "[FILL IN: reproduction case no longer triggers the bug]"
risk_level: low
auto_approve: true
---

## Steps

### 1. Write reproduction test
action: Write a test that reproduces the bug and currently fails
loop: false
verify: run your test command — confirm test FAILS with the bug's error

### 2. Fix the root cause
action: Fix the bug — do not fix symptoms, fix the root cause
loop: until tests pass
max_iterations: 5
verify: run your test command

### 3. Confirm no regressions
action: Run full test suite
loop: false
verify: run full test suite

### 4. Final check
action: Lint and format
loop: until clean
max_iterations: 2
verify: run your lint command
