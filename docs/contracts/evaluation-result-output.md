# HOTL Evaluation Result Output Contract

This contract defines a model-neutral record for optional live evaluations of a HOTL conformance scenario. It is observational: Phase 1 evaluation results do not choose a model, alter execution routing, or gate normal CI.

## Required identity

Every result records:

- Schema version and observation timestamp.
- Stable scenario ID and scenario revision.
- Host and execution implementation (`fallback`, `native_adapter`, or `manual`).
- Resolved model, reasoning/effort profile, and adapter version when observable.
- Terminal outcome using the conformance vocabulary.

Use JSON `null` when the host does not expose model, effort, adapter, duration, agent-count, token, or cost information. Do not infer these values from a product label, plan, rate limit, or elapsed wall-clock observation unless the result identifies that measurement as observed.

## Quality measurements

The result contains non-negative counts for:

- Contract failures.
- Post-completion defects found by later review or testing.
- Human interventions required to continue.
- Verification or execution retries.

Contract failures are stored as stable strings naming the violated invariant. An empty array means the evaluated run met the checked contract; it does not claim that unmeasured quality dimensions passed.

## Telemetry

Duration and agent count are nullable non-negative integers. Token and cost telemetry use explicit source states:

- `observed`: the provider or execution surface returned the value; numeric values are required.
- `unavailable`: the surface did not expose the value; corresponding values must be JSON `null`.

Zero is a measurement, not a missing-value placeholder. A result cannot label telemetry unavailable while storing zero.

Token telemetry separates input, output, and cached tokens. Cost telemetry records US dollars when observed. The contract does not normalize provider pricing or estimate cost from tokens.

## Evidence

Every result includes at least one evidence reference, such as a HOTL report path, normalized state artifact, review result, or provider run identifier. Evidence may remain local. Publishing an evaluation result does not imply publishing secrets, raw prompts, or full tool output.

## Validation and use

`scripts/hotl-conformance.sh validate-evaluation` validates the record and confirms that its scenario exists in the current conformance manifest. Deterministic contract tests remain the merge gate. Live evaluation results are compared only when scenario revision and relevant environment identity match.
