---
name: code-review
description: Use after completing implementation steps and before merging — reviews against plan and HOTL contracts.
---

# HOTL Code Review

## Checklist

**Plan alignment:**
- [ ] All steps in hotl-workflow.md completed
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

## Severity Levels

- **BLOCK:** Must fix before merge (failing tests, security issues, missing gates on high-risk steps)
- **WARN:** Should fix soon (code quality, missing docs for public APIs)
- **NOTE:** Consider in future (style, minor improvements)

BLOCK issues must be resolved before claiming done.
