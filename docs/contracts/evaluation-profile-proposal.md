# HOTL Evaluation Profile Proposal Contract

This contract defines advisory profile-change evidence. A proposal may identify
a profile for human review; it never selects, applies, or emits a command that
changes a model, effort, driver, permission, policy, sandbox, plugin, schedule,
or route.

## Identity and source evidence

The schema identifier is `hotl.evaluation-profile-proposal/v1`. The proposal
records the source history-report schema, SHA-256 hash, recorded-through
timestamp, entry count, and evidence state. Generation is deterministic for
the same report bytes and optional current-profile ID.

Evidence includes campaign/run IDs and status, referenced result paths,
candidate safety records, compatible Phase 7 profile relationships,
regressions, drift, and incompatible or missing evidence codes.
When one comparison has several drift axes, every value in its
`classifications` array remains visible in proposal evidence and gap codes.

## Proposal states

- `collect_more_evidence` — no unique safety-eligible candidate is supported.
- `conflicting_candidates` — different campaign summaries identify different
  candidates.
- `review_candidate` — one safety-eligible candidate exists without recorded
  regression or drift warnings.
- `review_candidate_with_warnings` — one safety-eligible candidate exists, but
  regression, drift, or other evidence gaps require explicit attention.

Candidate safety evidence must exist and every cited candidate record must be
eligible. Otherwise the candidate ID is `null` and the state is
`collect_more_evidence`.

## Confidence and rollback

Every proposal explains that local campaign observations do not establish
statistical significance or broad provider/model superiority. It calls out
host, model, prompt, toolchain, and telemetry drift and preserves unknown
telemetry as unknown.

Rollback guidance requires recording the current profile and rollback
condition, changing at most one reviewed dimension manually, restoring the
previous configuration on safety regression, and appending a repeated campaign
instead of replacing history.

## Mandatory governance fields

Every JSON proposal and human rendering states:

- `human_review_required: true`
- `automatic_selection_performed: false`
- `configuration_changes_performed: false`

The renderer has no apply mode and emits no executable configuration command.
