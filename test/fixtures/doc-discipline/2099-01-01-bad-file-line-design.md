---
design_type: feature
created_at: 2099-01-01
status: fixture
---

# Fixture: file:line leakage

## Intent Contract

intent: trigger the file:line leakage warning for tests.
constraints: none.
success_criteria: lint emits one implementation-leakage warning.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: testing the file:line pattern.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | trigger pattern | yes | no |

## Surface

This fixture references cli.py:16 in body prose to trigger the file:line implementation-leakage check.

## Risks & Open Questions

None.
