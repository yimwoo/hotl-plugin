---
intent: Sample workflow for testing typed verification parsing
success_criteria: All verify types parsed correctly by document-lint.sh
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Scalar shorthand verify**
action: Test backward-compatible scalar verify
loop: false
verify: pytest tests/ -v

- [ ] **Step 2: Typed shell verify**
action: Test structured shell verify block
loop: until tests pass
max_iterations: 3
verify:
  type: shell
  command: pytest tests/test_auth.py -v

- [ ] **Step 3: Browser verify**
action: Test browser verification type
loop: false
verify:
  type: browser
  url: http://localhost:3000/dashboard
  check: priority badge is visible

- [ ] **Step 4: Human review verify**
action: Test human-review verification type
loop: false
verify:
  type: human-review
  prompt: Check priority colors match the approved spec

- [ ] **Step 5: Artifact verify**
action: Test artifact verification type
loop: false
verify:
  type: artifact
  path: migrations
  assert:
    kind: matches-glob
    value: "*.sql"

- [ ] **Step 6: Multiple verify checks**
action: Test list form with multiple verify blocks
loop: false
verify:
  - type: shell
    command: npm test
  - type: artifact
    path: coverage/lcov.info
    assert:
      kind: exists
