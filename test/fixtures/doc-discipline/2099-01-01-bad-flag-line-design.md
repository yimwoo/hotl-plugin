---
created_at: 2099-01-01
status: fixture
---

# Fixture: dense flag line leakage

## Intent Contract

intent: trigger the dense-flag-line leakage warning.
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

In: testing the dense-flag-line pattern.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | trigger pattern | yes | no |

## Surface

Argv example: docker run --network=none --cap-drop=ALL --read-only --tmpfs /tmp --tmpfs /run --tmpfs /opt --label trustTier=sandboxed image.

## Risks & Open Questions

None.
