---
design_type: feature
created_at: 2099-01-01
status: fixture
---

# Fixture: code-block-too-long leakage

## Intent Contract

intent: trigger the long-code-block leakage warning.
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

In: testing the long-code-block pattern.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | trigger pattern | yes | no |

## Surface

The fixture below contains a fenced code block with twelve content lines.

```
line one
line two
line three
line four
line five
line six
line seven
line eight
line nine
line ten
line eleven
line twelve
```

## Risks & Open Questions

None.
