---
design_type: phase
---

# {{INITIATIVE_NAME}} — Phase {{PHASE_ID}} Design

**Status:** Proposed — for review
**Date:** {{DATE}}
**Depends on:** {{list prior phases, design docs, or workflows this phase builds on}}
**Strategy reference:** {{path to the parent strategic design in docs/designs/}}

This is a tactical phase design. Despite this template's compatibility-oriented filename, the accepted artifact is a design doc: save it in `docs/designs/YYYY-MM-DD-phase-{{PHASE_ID}}-<slug>-design.md`, then use `writing-plans` to turn it into an executable workflow in `docs/plans/YYYY-MM-DD-<slug>-workflow.md`.

---

## 1. Intent contract

**What this phase is for.** {{one-paragraph description of the phase's purpose in plain language — if you cannot state it in three sentences the scope is too big}}

**What this phase is NOT for.** {{explicit non-goals — list here to kill scope creep before it starts}}

**Primary audience / user story.** {{who benefits when this phase ships; what do they do differently?}}

**Contract fields.** These lines are parsed by `document-lint.sh`. Keep the key names; replace the bracketed values.

- intent: {{one-sentence goal}}
- constraints: {{limits, dependencies, non-goals}}
- success_criteria: {{how you know the phase is done — testable, observable}}
- risk_level: medium  # REVIEW BEFORE APPROVAL: confirm low | medium | high based on scope

---

## 2. Verification contract

**Definition of done.** Concrete, testable criteria. A reviewer must be able to read this list and verify each item by observation. Examples of good criteria:

- {{command X produces output Y when run against fixture Z}}
- {{route /foo/{id} returns HTTP 200 with expected fields for id=123}}
- {{full test suite passes: `bats test/`}}

Examples of bad criteria — reject these: "code quality is good", "users are happy", "architecture is clean".

**Verification plan.** Step-by-step checklist the reviewer will run:

1. {{run test command Z, confirm exit 0}}
2. {{check artifact X exists and is non-empty}}
3. {{manually verify behavior W}}

**Regression surface.** {{which existing modules / tests could break; where to look}}

---

## 3. Governance contract

**Approvers.** {{who signs off before execution begins — typically: product manager, architect, optionally QA or security}}

**Review gates.** {{list of explicit checkpoints between "design accepted" and "phase done"}}

- approval_gates:
  - {{design review → workflow creation}}
  - {{workflow creation → implementation}}
  - {{implementation → code review}}
  - {{code review → pre-merge verification}}

**Exit criteria.** {{what must be true to close this phase — usually matches the definition-of-done from §2, plus any operational criteria}}

**Rollback plan.**

- rollback: {{how to reverse this phase's changes if something goes wrong — explicit for schema / migration / data-mutating work; "revert the commit" for pure-additive changes}}

---

## 4. Scope

### In scope (ships in this phase)

1. {{numbered list of deliverables}}
2. {{…}}

### Out of scope (deferred to later phases)

- {{items explicitly deferred}}
- {{…}}

---

## 5. Module-level changes

| File | Change |
|---|---|
| {{path/to/file}} | {{what changes}} |
| {{…}} | {{…}} |

No other files change. Confirm via `git diff --name-only main...HEAD` before the review gate.

---

## 6. Task breakdown

1. {{step 1 — must be the first commit if it captures baseline state}}
2. {{step 2}}
3. {{…}}
4. Run full test suite — must be green.
5. Update `CHANGELOG.md`.

---

## 7. Open questions

1. {{question 1 — record assumptions and the leaning answer; if any remain open at review time, surface them}}
2. {{question 2 — remove this section if no open questions remain}}
