# HOTL PR Review — Cline Rendering Guidance

When executing the `hotl:pr-reviewing` skill:

1. Follow the canonical output schema in `docs/contracts/pr-review-output.md`
2. Render all 9 required sections in order, even when the overall verdict is REQUEST_CHANGES
3. Use markdown tables where supported for the verdict summary
4. Include file:line references in findings where available
5. Derive the overall verdict from dimension-level verdicts, not individual findings
