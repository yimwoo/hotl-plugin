---
intent: Sample workflow for testing multi-check verify item ordering
success_criteria: List-form verify parsing works regardless of key order
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Multi-check with type first**
action: Validate the baseline multi-check form
loop: false
verify:
  - type: shell
    command: test -f artifacts/output.txt
  - type: artifact
    path: artifacts/output.txt
    assert:
      kind: contains
      value: "render ok"

- [ ] **Step 2: Multi-check with command before type**
action: Validate list items when type is not the first key
loop: false
verify:
  - command: test -f artifacts/output.txt
    type: shell
  - path: artifacts/output.txt
    type: artifact
    assert:
      kind: contains
      value: "render ok"
