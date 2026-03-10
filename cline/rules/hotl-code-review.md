## HOTL Code Review

**When to use:** After completing implementation, before merging or claiming done.

**Full skill:** Read `~/.cline/hotl/skills/code-review/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

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

### Severity Levels

When reporting issues, use these levels:

- **BLOCK** — Must fix before merge. Broken functionality, security issues, missing tests for critical paths.
- **WARN** — Should fix soon. Code smells, missing edge case handling, unclear naming.
- **NOTE** — Consider later. Style preferences, minor improvements.

### What You MUST NOT Do

- NEVER claim "all tests pass" without actually running them and showing output
- NEVER skip the governance check — especially for high-risk changes
- NEVER hide issues — report everything you find, even if uncomfortable
- NEVER mark review as "passed" if any BLOCK issues exist
