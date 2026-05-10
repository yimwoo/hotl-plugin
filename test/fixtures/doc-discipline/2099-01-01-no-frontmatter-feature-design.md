# Fixture: no YAML frontmatter, body still has all 7 sections

This fixture deliberately has NO frontmatter at all. After the body-extraction fix lands, the lint must collect line 1 onward as body, find all 7 required sections, and emit ONLY one implementation-leakage warning for the file-and-line reference embedded in the Surface section.

## Intent Contract

intent: prove the no-frontmatter body-extraction fix works.
constraints: none.
success_criteria: zero structure warnings; one leakage warning; exit 0.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this fixture; check stdout

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Scope

In: regression coverage for frontmatter-less feature designs.
Out: anything else.

## Decisions

| # | Decision | Choice | Rejected |
|---|---|---|---|
| 1 | omit frontmatter | yes | no |

## Surface

This fixture references cli.py:99 in body prose to trigger one file:line leakage warning. The leakage is the only finding the lint should emit on this fixture after the fix lands.

## Risks & Open Questions

None.
