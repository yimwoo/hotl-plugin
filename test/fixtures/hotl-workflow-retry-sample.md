---
intent: Sample workflow for testing retry and max-iterations stop behavior
success_criteria: Retry logic validated correctly
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Write failing tests**
action: Write tests that will initially fail
loop: false
verify: pytest tests/ -v

- [ ] **Step 2: Implement until tests pass**
action: Write implementation to make tests pass
loop: until tests pass
max_iterations: 3
verify: pytest tests/ -v

- [ ] **Step 3: Fix lint errors**
action: Fix all lint issues
loop: until clean
max_iterations: 5
verify: ruff check .
