## HOTL Code Review

**When to use:** After completing implementation, before merging or claiming done. Also triggered automatically at executor review checkpoints.

**Full skill:** Read `~/.cline/hotl/skills/code-review/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### Review Lifecycle

Code review in HOTL is a governed lifecycle embedded in execution:

1. **Requesting:** Executors invoke `requesting-code-review` at checkpoints to dispatch the reviewer with git range, contracts, and verification evidence
2. **Reviewing:** The reviewer produces findings with file:line references, severity (BLOCK/WARN/NOTE), and fix direction
3. **Receiving:** Handle findings via `receiving-code-review` — verify each claim against the codebase and HOTL contracts before acting

### MANDATORY RULE

**NEVER claim work is complete without running the review checklist below.** Every section MUST be checked. Report findings honestly — do not hide issues.

### Checklist (check ALL sections)

**1. Plan Alignment**
- [ ] All planned steps from the workflow file are completed
- [ ] Success criteria from the intent contract are met
- [ ] No scope creep — only what was planned was implemented
- [ ] If anything was skipped, explain why

**2. Code Quality**
- [ ] Tests exist for new/changed behavior
- [ ] No code duplication introduced
- [ ] Error handling at system boundaries (user input, external APIs)
- [ ] No hardcoded secrets, credentials, or PII in code

**3. HOTL Governance**
- [ ] `risk_level: high` steps had human approval before execution
- [ ] Security-sensitive paths (auth, encryption, billing) were reviewed
- [ ] Verification commands from the workflow ran and passed

**4. Final Verification**
- [ ] Run the test suite — show actual output
- [ ] Run the linter — show actual output
- [ ] Confirm the specific requested behavior works — show evidence
- [ ] Check for regressions — existing tests still pass

### Findings Format

Every finding must include:

```
- [SEVERITY]: file/path:line — description
  Why: [why this matters]
  Fix: [expected remediation direction]
```

### Receiving Review Feedback

When review findings arrive, follow the `receiving-code-review` protocol:

1. **Verify** — check each finding against the current code
2. **Evaluate** — does acting on it violate intent, expand scope, or change risk?
3. **Respond** — classify as accept/reject/defer with evidence
4. **Implement** — only accepted findings, BLOCK first, verify after each change

### Verdict Model

**Checkpoint reviews:** PROCEED | PROCEED WITH WARNINGS | HOLD

**Final reviews (pre-merge):** READY | READY WITH WARNINGS | NOT READY

### What You MUST NOT Do

- NEVER claim "all tests pass" without actually running them and showing output
- NEVER skip the governance check — especially for high-risk changes
- NEVER hide issues — report everything you find, even if uncomfortable
- NEVER mark review as "passed" if any BLOCK issues exist
- NEVER implement review feedback without verifying the claim first
