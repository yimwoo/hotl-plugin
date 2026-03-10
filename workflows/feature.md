---
intent: "[FILL IN: describe the feature to add]"
success_criteria: "[FILL IN: how you know it's done]"
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Write failing tests**
action: Write tests that describe the expected behavior of the feature
loop: false
verify: run your test command and confirm tests FAIL with expected error

- [ ] **Step 2: Implement feature**
action: Write minimal implementation to make the failing tests pass
loop: until tests pass
max_iterations: 5
verify: run your test command

- [ ] **Step 3: Fix any lint issues**
action: Fix all linting errors
loop: until clean
max_iterations: 3
verify: run your lint command

- [ ] **Step 4: Update documentation**
action: Update README or API docs if this adds a public interface
loop: false

- [ ] **Step 5: Final verification**
action: Run full test suite and confirm clean
loop: until clean
max_iterations: 2
verify: run full test suite and lint
gate: human
