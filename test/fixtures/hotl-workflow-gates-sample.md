---
intent: Sample workflow for testing gate handling and risk-level override
success_criteria: Gate behavior validated correctly
risk_level: high
auto_approve: true
---

## Steps

- [ ] **Step 1: Implement feature**
action: Write the feature code
loop: false
verify: pytest tests/ -v

- [ ] **Step 2: Review auth logic**
action: Review authentication and token handling
loop: false
gate: human

- [ ] **Step 3: Run security scan**
action: Run automated security scan
loop: false
verify: bandit -r src/

- [ ] **Step 4: Final approval**
action: Final human approval before merge
loop: false
gate: human
