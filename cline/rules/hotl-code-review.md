## HOTL Code Review

**When to use:** After completing implementation, before merging or claiming done. Also triggered automatically at executor review checkpoints.

**Full skill:** Read `__HOTL_HOME__/skills/code-review/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### How It Works

Cline runs the inline review path (subagent dispatch is not available). The inline review uses the same output contract as the full `code-reviewer` agent — identical dimensions, findings format, and verdict model.

### Context Gathering

Before reviewing, gather:

1. **Base branch** (fallback ladder): PR base → `origin/HEAD` → `main` → `master`
2. **Review scope**: committed branch diff plus staged/unstaged changes on feature branches; staged/unstaged/`HEAD~1` on base branch
3. **Workflow file**: first look for canonical `docs/plans/*-workflow.md`; if none exists, fall back to the most recently modified legacy `hotl-workflow-*.md`
4. **Contracts**: from workflow frontmatter if available
5. **Verification evidence**: `.hotl/state/*.json` and `.hotl/reports/*.md` if present; otherwise report "not available"

### Review Dimensions (check ALL)

**1. Plan Alignment** (skip if no workflow)
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

### Verdict Model

**Direct and final reviews:** READY | READY WITH WARNINGS | NOT READY

**Checkpoint reviews:** PROCEED | PROCEED WITH WARNINGS | HOLD

### Post-Review

Return findings + verdict only. Do NOT automatically fix findings.

If the user asks to fix them, follow the `receiving-code-review` protocol:

1. **Verify** — check each finding against the current code
2. **Evaluate** — does acting on it violate intent, expand scope, or change risk?
3. **Respond** — classify as accept/reject/defer with evidence
4. **Implement** — only accepted findings, BLOCK first, verify after each change

### Review Lifecycle

```
code-review              = user-facing entry point (this rule)
requesting-code-review   = internal executor/orchestration entry point
receiving-code-review    = follow-up handler for acting on findings
```

### What You MUST NOT Do

- NEVER claim "all tests pass" without actually running them and showing output
- NEVER skip the governance check — especially for high-risk changes
- NEVER hide issues — report everything you find, even if uncomfortable
- NEVER mark review as "passed" if any BLOCK issues exist
- NEVER implement review feedback without verifying the claim first
- NEVER auto-fix findings unless the user explicitly asks
