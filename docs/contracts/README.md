# HOTL Contracts

This directory contains HOTL's canonical output, execution, and governance
contracts. Output contracts define what an artifact contains and means;
execution and governance contracts define portable behavior that every driver
must preserve. Platform-specific rendering lives in platform docs or skill
files unless a contract explicitly defines a required cross-platform view.

## Vocabularies

HOTL uses distinct vocabularies across its contracts. Do not conflate them.

**Severity** (for findings in reviews):
`BLOCK | WARN | NOTE` — the only finding-severity system in user-facing text. No other severity labels (P1/P2, priority numbers) may appear in prose.

**Verdict** (for task-specific outcomes — defined per contract):
- Review verdicts: `READY | READY WITH WARNINGS | NOT READY`, `PROCEED | PROCEED WITH WARNINGS | HOLD`, `APPROVE | REQUEST_CHANGES | COMMENT`
- Each contract specifies which verdict set applies to its context.

**Run status:**
`running | paused | blocked | completed`

**Step status:**
`pending | in_progress | done | failed | blocked`

**Gate and sensitive-action decisions:**
`approved | rejected` are persisted human/gate decisions. Sensitive-action
requests use `allowed | host_authority | pending | approved | rejected`.
`Auto-approved` and `Approved` may also appear as human-readable report labels;
they are not finding severities.

**Budget evaluation:**
`unset | unknown | within | exceeded` — unavailable telemetry for a configured
budget is `unknown`, never implicitly `within`.

## Conventions

Apply each convention only to the contract family named below.

1. **Portable semantics and behavior — all contracts.** Contracts define the
   portable meaning or invariant. Platform-specific presentation and host wiring
   live in platform docs (`docs/README.codex.md`, `cline/rules/`, etc.).
   Exception: final-artifact rendering tables belong in an output contract when
   they define required views of the same durable artifact.

2. **Severity vocabulary — review contracts.** `BLOCK | WARN | NOTE` is the only
   finding-severity system.

3. **Section ordering — structured output contracts.** A contract may define a
   fixed section order. When it does, every declared section is present, even
   when empty or clean.

4. **Clean-report requirement — review/report contracts.** When a declared
   section has no findings or issues, state what was checked and what was not
   covered. Do not silently omit it.

## Contracts

| Contract | Type | Purpose |
|----------|------|---------|
| [pr-review-output.md](pr-review-output.md) | Output schema (9 sections) | PR review metadata, dimension verdicts, and consolidated findings |
| [code-review-output.md](code-review-output.md) | Output schema (6 sections) | Code review scope, dimensions, findings, coverage gaps, and verdict |
| [execution-report-output.md](execution-report-output.md) | Output schema (5 sections) | Execution metadata, summary table, event log, final summary, and verification |
| [driver-conformance.md](driver-conformance.md) | Execution behavior | Portable workflow invariants and deterministic evidence required from execution drivers |
| [evaluation-result-output.md](evaluation-result-output.md) | Output schema | Optional model-neutral evaluation identity, quality measurements, telemetry, and evidence |
| [portable-workflow-and-receipt.md](portable-workflow-and-receipt.md) | JSON and protocol contracts | Normalized workflow, driver protocol, and state-derived completion receipt |
| [policy-budget-recovery.md](policy-budget-recovery.md) | Governance behavior | Sensitive-action decisions, observed budgets, and verify-first reconciliation |
