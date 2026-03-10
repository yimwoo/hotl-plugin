---
intent: Sample workflow for testing checkbox-style step parsing
success_criteria: All steps parsed correctly by document-lint.sh
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Write failing tests**
action: Write tests that describe the expected behavior
loop: false
verify: pytest tests/ -v

- [ ] **Step 2: Implement feature**
action: Write minimal implementation to make tests pass
loop: until tests pass
max_iterations: 3
verify: pytest tests/ -v

- [ ] **Step 3: Run full test suite**
action: Verify no regressions
loop: false
verify: pytest -v
