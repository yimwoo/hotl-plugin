# {{INITIATIVE_NAME}} — Operating Model

**Status:** Proposed — tune over the first 2–3 phases, tighten once calibrated.
**Date:** {{DATE}}
**Purpose.** Define how agent roles, human checkpoints, escalations, and decision logging interact so the human stays **on** the loop, not **in** every loop.

---

## 1. Intent

Multi-phase initiatives involve many agent sessions across weeks or months. If every artifact needs human sign-off, the human becomes the bottleneck. If no artifact needs sign-off, decisions drift from the human's intent.

This operating model resolves that by making the human responsible for **strategy, checkpoints, and exceptions** — not every intermediate artifact. Agents resolve requirements, plans, ADRs, code, and reviews among themselves; the human audits the decision log and intervenes only when a tripwire fires or a checkpoint arrives.

**Non-goal.** Replacing the human. The human makes every load-bearing decision. The agents stop asking about every trivially-reversible one.

---

## 2. Roles

The generic HOTL role vocabulary. These are **roles** (who owns an artifact) not **skills** (the workflow that produces it). A session uses one role and one or more skills — they are orthogonal.

| Role | Primary artifact | Typical skills invoked |
|---|---|---|
| `@pm` | Requirements / acceptance criteria in `docs/requirements/` | (prompt-driven; no skill) |
| `@architect` | Strategic and tactical designs in `docs/designs/`, workflows in `docs/plans/`, ADRs in `docs/decisions/` | `brainstorming`, `writing-plans` |
| `@dev` | Source code and tests in `src/`, `tests/` | `executing-plans`, `loop-execution`, `tdd` |
| `@qa` | Test plans, regression suites, strategies in `docs/strategies/` | `tdd`, `test-driven-development` |
| `@reviewer` | Review memos in `docs/reviews/`, PR reviews | `code-review`, `pr-reviewing`, `document-review` |
| `@researcher` | Research notes in `docs/research/` | (prompt-driven; no skill) |

Every playbook prompt is dispatched to exactly one role. One session → one artifact → one role.

---

## 3. Decision-rights matrix

What each role decides autonomously vs. what must escalate. Start conservative. Loosen over time as calibration improves.

| Role | Decides autonomously | Must escalate to human |
|---|---|---|
| `@pm` | Acceptance-criteria wording, user-story granularity, UX copy, non-goals within the phase | Exit-gate changes that expand or contract phase scope; cross-phase dependencies not previously agreed |
| `@architect` | Module boundaries within a phase; data-model details within an ADR's constraints; naming | Any new ADR (cross-phase or expensive to reverse); any change that contradicts an accepted ADR; any change to a design doc in `docs/designs/` |
| `@dev` | Library choice within stated constraints; local refactors; test scaffolding for the change | Schema migration; public API change; PR touching more than {{N}} files (tunable, start at 10); dependency additions; any change in `docs/` |
| `@qa` | Test cases within the scenario contract; fixture shape; coverage targets within plan | Promotion to `tests/generated/`; relaxation of an existing assertion; negative-control removal |
| `@reviewer` | Accept or request-changes on any agent artifact | Two back-to-back rejections on the same artifact; security-impacting findings; cost-impacting findings |
| `@researcher` | Which sources to read; how to summarize; follow-up reads | When findings suggest a scope change or new ADR |

### Interpreting the matrix

- **"Autonomously"** means the role writes the artifact and commits it (optionally after `@reviewer` passes) without human sign-off.
- **"Escalate"** means the role pauses, appends the decision question to `docs/decisions/log.md`, and pings the human via the configured notification channel.
- **Ambiguous cases escalate.** When a role cannot confidently classify a decision as autonomous, the default is to escalate. This bias is intentional early on and should be loosened deliberately, not drifted.

### Phase-specific overrides

Any workflow document (`docs/plans/*-workflow.md`) may **tighten — but not loosen —** these rights for the duration of one phase. Example: a phase touching destructive operations might add `@dev must escalate on any change to <module>`. The override lives in the workflow's governance/gate structure and expires when the phase closes. Legacy `docs/plans/*-plan.md` files remain readable during migration but are no longer the canonical artifact.

---

## 4. Escalation tripwires

Conditions that force the human into the loop regardless of decision rights. Tripwires are implemented in the agent harness and listed here for transparency.

### 4.1 Decision coherence

- **New ADR.** Any role proposing a new architecture decision.
- **Contradiction with existing ADR.** Any role producing an artifact that conflicts with an accepted ADR.
- **Scope creep.** Any step attempting work explicitly listed as a non-goal in the relevant design.

### 4.2 Risk / safety

- **Security keywords in a high-risk step.** A workflow step whose content mentions auth, encryption, secrets, billing, or permissions AND whose `risk_level: high` must have `gate: human`.
- **Schema migration or destructive data operation.** Always human-gated.
- **Public API change.** Always human-gated.

### 4.3 Cost / budget

- **LLM spend crosses {{BUDGET_USD}}/day.** Dispatcher pauses; human reviews.
- **Kill-switch env var** (`{{KILL_SWITCH_ENV_VAR}}=1`) forces all dispatches to no-op.

### 4.4 Review churn

- **Two consecutive rejections on the same artifact.** Signal that agent-to-agent resolution is not converging.
- **Cross-role disagreement** (e.g., `@architect` and `@qa` disagree on test coverage). Human breaks the tie.

---

## 5. Decision log

Every autonomous decision appends one JSON line to `docs/decisions/log.md`. Format:

```json
{
  "timestamp": "YYYY-MM-DDTHH:MM:SSZ",
  "role": "@architect",
  "phase": "phase-2",
  "decision": "chose library X over Y",
  "rationale": "X has fewer dependencies and aligns with ADR-003",
  "artifact": "docs/plans/2026-MM-DD-<slug>-workflow.md",
  "reversible": true
}
```

The log is append-only. Humans scan the log at weekly digest time (see playbook §6.1).

To enable the log, set `decision_log_path: docs/decisions/log.md` in `.hotl/config.yml`. Absence of that setting disables logging entirely (opt-in per the HOTL plugin's safety contract).

---

## 6. Human checkpoints

Mandatory human involvement happens only at these moments:

| Checkpoint | Trigger | Human output |
|---|---|---|
| **Initiative kickoff** | Before Phase 1 begins | Design doc signed off; operating model signed off |
| **Phase design review** | Before each phase's `writing-plans` session | Design approved / revise / reject |
| **Tripwire firing** | See §4 | Decision or unblocking action |
| **Weekly digest** | Configured cadence | Acknowledge or redirect |
| **Initiative exit** | Final phase merged | Sign-off and post-mortem notes |

Anything outside this list that requires a human is a **bug in the operating model** — fix the matrix, don't add checkpoints.

---

## 7. Metrics — how do we know the model is working?

Review these metrics at the initiative-exit checkpoint (see playbook §6.2):

- **Escalation rate** — fraction of decisions that escalated vs. auto-resolved. Target: decreasing over phases.
- **Rejection rate** — fraction of reviewer verdicts that were request-changes. Target: below {{REJECTION_RATE_TARGET}}%.
- **Cycle time per phase** — kickoff to merge. Target: flat or decreasing.
- **Tripwire fires** — count and distribution. Unexpected spikes indicate a rule needs tightening or loosening.

---

## 8. Amending this model

Changes to this operating model are **expensive to reverse** because they affect every future session. Amendments require:

1. A written proposal in `docs/reviews/operating-model-amendment-YYYY-MM-DD.md`.
2. Human approval.
3. Migration of any in-progress phase to the new rights matrix before the next session is dispatched.

Do not drift. The whole point of an operating model is that it is explicit.
