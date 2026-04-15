# {{INITIATIVE_NAME}} — Strategic Design

**Status:** Draft | Accepted | Superseded by {{path-to-successor}}
**Date:** {{DATE}}
**Owner:** {{one human owner, not a team}}
**Co-authors:** {{agent roles that contributed — e.g., @architect, @pm}}
**Related:** {{prior design docs or decision records that constrain this initiative}}

This is a strategic / multi-phase initiative design. It lives in `docs/designs/` because it defines the **parent direction** — what are we building overall, why, across what phases, and what is explicitly out of scope. Child tactical plans live in `docs/plans/YYYY-MM-DD-<topic>-plan.md` and reference this document.

Design docs are durable. Rewrite rather than patch when direction changes meaningfully; supersede rather than edit when an initiative ends.

---

## 1. Problem statement

Two paragraphs maximum. Concrete, not aspirational.

**Who is hurt today?** {{named roles — QA leads, developers, operators — and the specific tasks they cannot do or do painfully today}}

**What evidence do we have?** {{metrics, incidents, user quotes. If "we think users want this" is the strongest evidence, the initiative is not ready.}}

---

## 2. Vision / intent

One paragraph describing what the world looks like when this initiative ships, written as if it is already done.

> {{Example format: "When this ships, a {{role}} can {{do task X}} in under {{target duration}}, with every {{artifact}} carrying {{expected metadata}}. {{Measurable outcome}} improves by {{threshold}} within {{time window}}."}}

If you cannot write this sentence, the scope is not yet clear.

---

## 3. Non-goals

Explicit list of what this initiative is **not** about. This is the most important section for preventing scope creep — revisit it whenever a phase plan tries to expand into one of these areas.

Good non-goals (specific):

- {{Not replacing {{existing tool}}; it remains the authority for {{domain}}}}
- {{Not integrating with {{external system}} beyond the subset already in use}}
- {{Not targeting {{environment}} in v1}}

Bad non-goals (too vague — do not use): "not adding complexity", "not breaking anything".

---

## 4. Stakeholders

| Role | Interest | Interface |
|---|---|---|
| Primary users | {{who benefits daily once this ships}} | {{UI page, CLI, API — where they interact}} |
| Operators | {{who runs this in production}} | {{metrics dashboard, runbook, on-call}} |
| Reviewers / approvers | {{who signs off at phase boundaries}} | {{review memo, PR, gate}} |
| Blocked parties | {{who is waiting on this initiative to start their own work}} | {{contract, dependency}} |

---

## 5. Architecture / module-level changes

High-level architecture diagram or description. Name every module that is **new**, **extended**, or **left untouched**. The principle: the parent design says what-and-where; tactical plans say how-and-when.

```
{{ASCII diagram or short prose describing the new layer and where it sits
   relative to existing modules. Keep it under 20 lines — deep detail
   belongs in the child plan.}}
```

**Key invariant:** {{one sentence describing the architectural invariant this initiative must never break — e.g., "the new layer sits above existing domain modules and never bypasses them."}}

---

## 6. Maturity stages

Optional section — include when the initiative rolls out in graduated stages. Each stage gates on concrete exit criteria before promoting.

| Stage | Description | Effort level | Exit criteria for next stage |
|---|---|---|---|
| **L1** | {{baseline manual state}} | {{≈ effort}} | {{concrete threshold: metric X < value Y over Z weeks}} |
| **L2** | {{partial automation, human-confirms}} | {{≈ effort}} | {{…}} |
| **L3** | {{automated, human-reviews}} | {{≈ effort}} | {{…}} |
| **L4** | {{sampled review, autonomous}} | {{≈ effort}} | {{continuous; revisit quarterly}} |

**Current state:** {{which stage you are in today}}.
**Target for next {{N}} phases:** {{which stage to reach}}.

---

## 7. Phase breakdown

Each phase is a child tactical plan in `docs/plans/`. One line of intent per phase.

| Phase | Intent (one sentence) | Dated plan filename |
|---|---|---|
| Phase 1 | {{what ships in this phase}} | `docs/plans/YYYY-MM-DD-phase-1-{{slug}}-plan.md` |
| Phase 2 | {{…}} | `docs/plans/YYYY-MM-DD-phase-2-{{slug}}-plan.md` |
| Phase 3 | {{…}} | `docs/plans/YYYY-MM-DD-phase-3-{{slug}}-plan.md` |

Phases ship sequentially by default. Parallel execution only when the design explicitly allows it and the phases share no mutable state.

---

## 8. Quality attributes

| Attribute | Goal / measurement |
|---|---|
| Performance | {{target latency / throughput / cost}} |
| Security | {{threat model note — injection, auth, data handling}} |
| Observability | {{metrics, logs, traces that must exist}} |
| Cost | {{upper bound on operational / LLM / storage cost}} |
| Backwards compatibility | {{what existing users / projects must see unchanged}} |

---

## 9. Risks and open questions

**Risk: {{short name}}.** {{one-paragraph description}}. Mitigation: {{how you plan to reduce likelihood or impact}}.

**Risk: {{…}}.** {{…}}

**Open question:** {{what is not yet decided; deferred to which phase; who decides}}.

**Open question:** {{…}}

---

## 10. Verification

This design is considered accepted when:

- {{reviewer confirms the problem statement and vision are coherent and evidence-backed}}
- {{non-goals are specific, not vague}}
- {{phase breakdown is sequential and each phase has a clear exit criterion}}
- {{at least one named stakeholder approves in writing (comment on the PR, review memo, or sign-off)}}

---

## 11. References

- {{prior designs that constrain this initiative}}
- {{ADRs or decision records that apply}}
- {{external specs, research papers, vendor docs}}
