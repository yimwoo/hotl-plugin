---
intent: Sample workflow for testing verbose progress view
success_criteria: Progress rendering validated correctly
risk_level: low
auto_approve: true
progress: verbose
---

## Steps

- [ ] **Step 1: Write tests**
action: Write unit tests
loop: false
verify: pytest tests/ -v

- [ ] **Step 2: Implement feature**
action: Write implementation
loop: until tests pass
max_iterations: 3
verify: pytest tests/ -v

- [ ] **Step 3: Run full suite**
action: Run complete test suite
loop: false
verify: pytest -v
