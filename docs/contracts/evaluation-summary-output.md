# HOTL Evaluation Summary Output Contract

This contract defines the deterministic, local comparison of validated HOTL
evaluation results. The summary is advisory evidence for a human decision. It
never selects a model, changes a driver, edits policy, or writes routing
configuration.

## Identity and provenance

The JSON schema identifier is `hotl.evaluation-summary/v1`. A summary records:

- `source: local-evaluation-results`
- The latest `recorded_at` value present in the source records
- Deterministically sorted source paths and normalized result identities
- Fixed comparison requirements: at least two profiles, at least three shared
  scenario/revision pairs, and known matching environment identity

The command validates every source record through
`scripts/hotl-conformance.sh validate-evaluation` before aggregation. Invalid
input stops the report; it is never silently dropped.

## Comparable cohorts

Known environment identity consists of non-null `repo_revision`,
`host_version`, `os`, `arch`, and `toolchain_fingerprint`. Records with equal
known identity form a cohort. Different known identities form separate cohorts.
Any missing environment value makes identity `unknown` and prevents that cohort
from becoming recommendation-eligible.

Scenario coverage uses the pair `scenario_id@scenario_revision`. Only pairs
present for every profile in a cohort count as shared coverage. A revision
mismatch is missing shared coverage, not an equivalent scenario.

Legacy results without `profile_id` receive a deterministic `legacy/...`
identity derived from their observed host, implementation, resolved model,
effort, and adapter values. The summary marks that identity as `derived`, and a
cohort containing it is not recommendation-eligible until the operator supplies
an explicit stable profile identity.

## Profile metrics and safety

Every profile exposes total and comparison sample counts, full and shared
scenario coverage, evidence references, terminal outcomes, stable
contract-failure IDs, post-completion defects, interventions, retries, and
telemetry completeness. Comparison metrics use only records whose
scenario/revision pair is shared by every profile in the cohort; non-shared
evidence remains visible but cannot distort the comparison.

Interventions and retries expose both totals and per-sample means over the
comparison records. Pareto relationships use those means so collecting repeat
samples does not itself make a profile look worse. Duration, agent count, total
tokens, and cost expose:

- `complete` when every sample has an observed value
- `partial` when only some samples have an observed value
- `unavailable` when no sample has an observed value

Only complete optional dimensions receive a comparable mean. Missing or partial
telemetry remains `null`; it is never converted to zero or estimated.

A profile is safety-eligible only when every result completed, no contract
failure is present, and no post-completion defect was found. These are hard
disqualifiers and cannot be offset by speed, token, cost, intervention, or retry
metrics. Safety eligibility considers every supplied record for the profile,
including non-shared scenarios; extra evidence can disqualify a profile but
cannot improve its comparison metrics.

## Pareto relationships

Lower values are preferred for interventions, retries, duration, agent count,
tokens, and cost. A profile dominates another only when:

1. Both profiles are safety-eligible.
2. The candidate observes every dimension available for the other profile.
3. The candidate is no worse on every comparable dimension.
4. The candidate is strictly better on at least one comparable dimension.

This rule prevents missing telemetry from improving a profile's standing. The
Pareto frontier may contain multiple profiles; the report does not collapse
trade-offs into an opaque weighted score.

An ineligible cohort has an empty Pareto frontier. Its profile evidence remains
visible, but sparse, unknown, derived, or otherwise incomparable evidence must
not be presented as a candidate relationship.

## Recommendation states

The summary emits exactly one advisory state:

- `collect_more_evidence` — profile count, shared coverage, environment, or
  explicit identity requirements are not satisfied.
- `human_review_required` — comparable evidence exists, but there is no safe
  candidate, several cohorts are independently comparable, or multiple profiles
  remain on the Pareto frontier.
- `review_profile_candidate` — one safety-eligible profile remains on the
  eligible cohort's Pareto frontier.

Every state sets `human_review_required: true` and
`configuration_changes_performed: false`. Even a single candidate is a proposal
for human review, not an instruction or authorization to change configuration.

## Rendering

JSON is the canonical machine-readable output. Text rendering presents the same
source count, cohorts, evidence gaps, profile safety and metrics, Pareto
frontier, recommendation, and mandatory human boundary. Rendering does not
recalculate or reinterpret comparison semantics.
