---
created_at: 2099-01-01
status: fixture
---

# Fixture: wide markdown tables must not trigger dense-flag warnings

## Intent Contract

intent: prove that 6+-column Markdown table separator rows are NOT counted as dense flag lines after the Step 3 regex refinement.
constraints: none.
success_criteria: zero leakage warnings; exit 0.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture; assert no warnings

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: regression coverage for the markdown-table false-positive bug.
Out: anything else.

## Decisions

The decisions table below has six columns; its separator row contains six `---` segments. Before the Step 3 fix, this row triggered a false dense-flag warning (six `--` substrings counted as flag tokens). After the fix, the lint must require a letter after each `--`, so this separator row produces zero matches.

| # | Decision | Choice | Rejected | Owner | Risk |
|---|---|---|---|---|---|
| 1 | wide table | yes | no | tests | low |
| 2 | second row | demo | n/a | tests | low |

## Surface

The fixture's body contains a 6-column Markdown table (above) whose separator row would have tripped the original `--` counting heuristic. With the Step 3 regex refinement (require a letter after `--`), this row now produces zero matches.

## Risks & Open Questions

None.
