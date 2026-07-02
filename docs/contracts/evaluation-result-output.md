# HOTL Evaluation Result Output Contract

This contract defines a model-neutral record for optional live evaluations of a HOTL conformance scenario. It is observational: evaluation results do not choose a model, alter execution routing, or gate normal CI.

## Required identity

Every result records:

- Schema version and observation timestamp.
- Stable scenario ID and scenario revision.
- Host and execution implementation (`fallback`, `native_adapter`, or `manual`).
- Resolved model, reasoning/effort profile, and adapter version when observable.
- Terminal outcome using the conformance vocabulary.

Records may add a stable `profile_id` for comparison. When present, it is a
lowercase identifier beginning with an alphanumeric character and containing
only lowercase alphanumerics, `.`, `_`, `/`, or `-`. The identifier names the
operator-defined execution profile; it must not be inferred from a marketing
model alias. Legacy records without `profile_id` remain valid, and comparison
tools must visibly mark any derived fallback identity.

Records may also add an `environment` object. When present, it contains the
nullable string fields `repo_revision`, `host_version`, `os`, `arch`, and
`toolchain_fingerprint`. Use explicit JSON `null` for an unavailable value.
Known environment differences form separate comparison cohorts. Missing or
partially unknown environment identity is not evidence of compatibility.

Use JSON `null` when the host does not expose model, effort, adapter,
environment, duration, agent-count, token, or cost information. Do not infer
these values from a product label, plan, rate limit, or elapsed wall-clock
observation unless the result identifies that measurement as observed.

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

Phase 8 collectors add `telemetry_provenance` with normalization version
`hotl.tokens/v1`, provider/source identity, input and cached-counter semantics,
and whether normalization succeeded. Codex cached input is a subset of total
input and is subtracted before storing normalized input. Claude cache reads are
stored as a disjoint counter. Ambiguous counters remain unavailable.

## Evidence

Every result includes at least one evidence reference, such as a HOTL report path, normalized state artifact, review result, or provider run identifier. Evidence may remain local. Publishing an evaluation result does not imply publishing secrets, raw prompts, or full tool output.

## Validation and use

`scripts/hotl-conformance.sh validate-evaluation` validates the record and confirms that its scenario exists in the current conformance manifest. Deterministic contract tests remain the merge gate. Live evaluation results are compared only when scenario revision and relevant environment identity match.

`scripts/hotl-evaluation-report.sh` compares validated records under the
[evaluation summary contract](evaluation-summary-output.md). It performs no
model call, upload, configuration edit, or routing change.
