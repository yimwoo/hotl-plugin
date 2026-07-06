# Portable Workflow and Evidence Receipt Contract

HOTL keeps workflow Markdown as the authoring source and derives two versioned JSON documents for drivers and audits.

## Normalized workflow (`hotl.workflow/v1`)

Run `runtime/hotl-rt normalize <workflow> --json`. The command is read-only and emits source identity, portable workflow metadata, and ordered step contracts. Runtime result fields such as attempts and pass/fail state are never included. Consumers must ignore unknown fields and reject unknown major schema versions.

## Driver protocol (`hotl.driver/v1`)

A driver exposes `describe`, `preflight`, `launch`, `owner`, `step`, `gate`, `action`, `budget`, `status`, `receipt`, `reconcile`, `finalize`, and `finish`. Drivers may schedule work differently, but only HOTL ownership, ordered transitions, bounded budgets, effect evidence, verification, and finish state determine governed completion. A driver must not weaken the host sandbox, permissions, or managed policy. Missing capability must produce an explicit fallback or non-ready preflight result.

The generic implementation is `runtime/drivers/generic.sh`; it delegates lifecycle mutations to `hotl-rt` and is the conformance reference.

## Evidence receipt (`hotl.receipt/v1`)

Run `runtime/hotl-rt receipt <run-id> --json`. Receipts are derived from state rather than chat. `sufficiency.sufficient` is true only when the run is completed, all steps are done, all required verification passed, all required gates are approved, sensitive effects have terminal evidence, budgets are not exceeded, and a finish disposition is recorded. High-risk workflows require human gate evidence for every step. `ready_to_finish` is intentionally insufficient until disposition.

Receipts exclude verification stdout, stderr, and environment values by default. The state and human-readable report retain their existing behavior; the receipt is a redacted audit projection, not a replacement state format.
