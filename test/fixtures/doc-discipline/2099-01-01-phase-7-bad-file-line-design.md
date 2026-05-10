---
created_at: 2099-01-01
status: fixture
---

# Fixture: phase-N filename slug resolves to design_type=phase

## Intent Contract

intent: trigger one leakage warning under design_type=phase via filename pattern.
constraints: none.
success_criteria: lint emits one implementation-leakage warning with `design_type=phase`.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture and confirm design_type=phase

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: testing the phase resolution path.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | trigger pattern | yes | no |

## Surface

This fixture references cli.py:42 in body prose to trigger the file:line check while resolving as phase via the `phase-7` slug component.

## Risks & Open Questions

None.
