---
intent: Sample workflow with branch and worktree fields
success_criteria: Document-lint accepts optional branch and worktree fields
risk_level: low
auto_approve: true
branch: feat/sample-branch
worktree: false
---

## Steps

- [ ] **Step 1: Write tests**
action: Write tests for the feature
loop: false
verify: echo "tests pass"

- [ ] **Step 2: Implement**
action: Implement the feature
loop: until tests pass
max_iterations: 3
verify: echo "tests pass"
