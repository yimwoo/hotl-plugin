---
design_type: feature
created_at: 2099-01-01
status: fixture
---

# Fixture: missing required section

## Intent Contract

intent: trigger the missing-required-section structure warning.
constraints: none.
success_criteria: lint emits one structure warning naming the missing section.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: testing the missing-section structure check.
Out: anything else.

## Surface

Six of the seven required sections are present. The Decisions section is intentionally absent so the structure check warns once.

## Risks & Open Questions

None.
