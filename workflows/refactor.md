---
intent: "[FILL IN: describe what is being refactored and why]"
success_criteria: "All existing tests pass, no behavior changes, code is simpler"
risk_level: medium
auto_approve: true
---

## Steps

### 1. Confirm test coverage baseline
action: Run full test suite and record pass count — do not proceed if tests are failing
loop: false
verify: run full test suite — note the number of passing tests

### 2. Refactor incrementally
action: Make one refactor change at a time, keeping tests green throughout
loop: until refactor complete
max_iterations: 10
verify: run full test suite

### 3. Check for regressions
action: Run full test suite — must match baseline pass count
loop: false
verify: run full test suite

### 4. Lint
action: Fix any lint issues introduced
loop: until clean
verify: run your lint command

### 5. Human review of structural changes
action: Summary of what changed structurally
loop: false
gate: human
