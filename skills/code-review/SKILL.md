---
name: code-review
description: Use after completing implementation steps and before merging — reviews against plan and HOTL contracts.
---

# HOTL Code Review

## Review Lifecycle

Code review in HOTL is a governed lifecycle, not a one-shot checklist:

1. **Requesting:** Executors invoke `requesting-code-review` at defined checkpoints to dispatch the `code-reviewer` agent with structured context (git range, contracts, verification evidence)
2. **Reviewing:** The `code-reviewer` agent produces findings with file:line references, severity, and fix direction
3. **Receiving:** Findings are handled via `receiving-code-review` — verify each claim, evaluate against contracts, then implement accepted changes

## Checklist

**Plan alignment:**
- [ ] All steps in the workflow file (`hotl-workflow-*.md`) completed
- [ ] success_criteria from frontmatter met
- [ ] No unplanned scope added (YAGNI)

**Code quality:**
- [ ] Tests exist and pass for all new behavior
- [ ] No code duplication introduced (DRY)
- [ ] Error handling at system boundaries only

**HOTL governance:**
- [ ] risk_level: high steps had human gate approval
- [ ] No sensitive data (secrets, PII) in code, logs, or comments
- [ ] Security-sensitive paths (auth, encryption) have human review documented

## Findings Format

Every finding must include:

```
- [SEVERITY]: file/path:line — description
  Why: [why this matters]
  Fix: [expected remediation direction]
```

For localized issues: file:line is required. For scope-level findings: provide the narrowest evidence available.

## Severity Levels

- **BLOCK:** Must fix before merge (failing tests, security issues, missing gates on high-risk steps)
- **WARN:** Should fix soon (code quality, missing docs for public APIs)
- **NOTE:** Consider in future (style, minor improvements)

## Verdict Model

**Checkpoint reviews:**
- **PROCEED** / **PROCEED WITH WARNINGS** / **HOLD**

**Final reviews (pre-merge):**
- **READY** / **READY WITH WARNINGS** / **NOT READY**

BLOCK issues must be resolved before claiming done.
