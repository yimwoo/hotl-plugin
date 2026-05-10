---
hotl_managed: true
created_at: 2099-01-01
status: fixture
---

# Fixture: marker via hotl_managed frontmatter

## Intent Contract

intent: prove that `hotl_managed: true` is sufficient to opt a doc into HOTL lint even without a `design_type:` field.
constraints: none.
success_criteria: lint applies HOTL rules; one leakage warning for the deliberate file:line ref; exit 0.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture and confirm one leakage warning + LINT PASSED.

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: testing the `hotl_managed: true` escape hatch as an HOTL marker.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | use hotl_managed instead of design_type | yes | use design_type |

## Surface

This fixture references the file-and-line pattern at the end of this section to trigger one implementation-leakage warning under the HOTL rules: cli.py:55.

## Risks & Open Questions

None.
