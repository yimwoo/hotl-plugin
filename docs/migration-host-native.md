# Host-Native Governance Migration

The preferred new execution entry point is `governed-execution`. Existing `loop-execution`, `executing-plans`, `subagent-execution`, and `resuming` skills—and existing Claude Code commands—remain supported compatibility profiles.

## Compatibility guarantees

- Existing workflow Markdown remains canonical and needs no rewrite.
- Existing state and reports remain readable; new policy fields are additive.
- Generic `hotl-rt` execution remains available when native capability is absent, unknown, disabled, or unsuitable.
- Native drivers are opt-in and never change host permissions or settings.
- Native continuation features provide scheduling and liveness only; HOTL controller ownership, runtime limits, effect reconciliation, and receipts remain authoritative.
- New driver-managed runs require ownership. Existing state remains readable and can be claimed or explicitly taken over during verify-first resume.
- Successful finalization now pauses at `ready_to_finish`; explicit finish disposition is required for `completed`.
- No execution entry point is removed in this roadmap release.

## Adoption

Run `scripts/hotl-adoption-report.sh` inside a project to summarize local driver, executor, and receipt evidence. The command performs no upload. Teams may consider a native default only after representative successful receipts and human review; sparse data keeps fallback as the recommendation.

Recurring Codex automations or Claude plugin monitors remain manually installed and explicitly enabled. Adoption reporting does not create or modify an automation.

## Future deprecation criteria

An entry point can be deprecated only after its behavior is covered by the shared conformance suite, migration documentation exists, local adoption evidence shows a replacement is used successfully, and maintainers approve a release-noted compatibility window. Removal requires a separate human-approved design.

## Memory

`scripts/hotl-memory-proposal.sh <run-id> --fact <text>` produces a review-required proposal linked to receipt evidence. It never writes memory. A human must verify durability, scope, and sensitivity before accepting any proposed fact.
