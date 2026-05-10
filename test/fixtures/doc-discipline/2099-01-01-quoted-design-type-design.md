---
design_type: "feature"
created_at: 2099-01-01
status: fixture
---

# Fixture: design_type with YAML quoted-scalar value

## Intent Contract

intent: prove that `design_type: "feature"` (with quotes) opts the doc into HOTL lint.
constraints: none.
success_criteria: lint applies HOTL rules; LINT PASSED; exit 0.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture and confirm LINT PASSED.

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: testing YAML quoted-scalar handling in the marker check.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | use quoted scalar | yes | unquoted only |

## Surface

The frontmatter uses `design_type: "feature"` with surrounding quotes. After the Phase 1.6 review fix, the marker check strips quotes before comparison so this opts into HOTL lint instead of silently SKIPping.

## Risks & Open Questions

None.
