---
design_type: contract
status: fixture
---

# Fixture: contract-type doc skipped by feature/phase rules

This fixture is undated and declares `design_type: contract` in frontmatter. It satisfies the pre-existing lint requirements (the three contract sections below) so that the only thing under test is whether the NEW structure/leakage rules correctly skip contract-type docs.

The lint must emit no `category=structure` or `category=implementation-leakage` warnings on this file, even though it deliberately contains all three leakage patterns and lacks the four feature/phase design slots (Scope, Decisions, Surface, Risks & Open Questions).

## Intent Contract

intent: prove the new feature/phase rules skip contract-type docs.
constraints: none beyond fixture role.
success_criteria: lint emits zero `category=structure` and zero `category=implementation-leakage` lines.
risk_level: low

## Verification Contract

verify_steps:
- run document-lint on this file and confirm no new warnings

## Governance Contract

approval_gates: none.
rollback: delete fixture.
ownership: test fixture.

## Intentional leakage patterns (must be ignored for contract type)

A file:line reference: cli.py:16

A long fenced code block:

```
one
two
three
four
five
six
seven
eight
nine
ten
eleven
twelve
```

A dense flag line: docker run --network=none --cap-drop=ALL --read-only --tmpfs /tmp --tmpfs /run --tmpfs /opt --label x=y image.

## Why

Contract / architecture / initiative / reference docs are durable references and may legitimately include deeper technical shape. The Phase 1 lint defers any rules for them.
