---
intent: Sample workflow for testing human-review verification handling
success_criteria: Human review approvals can complete a blocked verify step
risk_level: low
auto_approve: false
---

## Steps

- [ ] **Step 1: Human review verification**
action: Present the change for manual review
loop: false
verify:
  type: human-review
  prompt: Confirm the output looks correct
