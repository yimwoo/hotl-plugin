---
intent: Exercise human-review verification and human gate handling end to end
success_criteria: The runtime pauses for manual review, records approval, passes an explicit human gate, and finalizes cleanly
risk_level: medium
auto_approve: false
---

## Steps

- [ ] **Step 1: Run an automated pre-check**
action: Do a lightweight automated verification before manual review
loop: false
verify: echo "pre-check ok"

- [ ] **Step 2: Pause for manual review**
action: Present the intermediate result for human inspection
loop: false
verify:
  type: human-review
  prompt: Confirm the intermediate output is acceptable before continuing

- [ ] **Step 3: Run a post-review check**
action: Do one more automated check after approval
loop: false
verify: echo "post-review ok"

- [ ] **Step 4: Final human gate**
action: Ask for explicit approval before finalizing the run
loop: false
gate: human
