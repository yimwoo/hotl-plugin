# HOTL Evaluation History and Drift Contract

This contract defines immutable evidence entries and the deterministic report
that Phase 8 history and drift reporting consume.

## Entry identity

The schema identifier is `hotl.evaluation-history-entry/v1`. An entry records a
campaign ID, globally stable run ID, observation timestamp, status, repository-
relative evaluation-result path, and SHA-256 content hash. The referenced
result must pass the existing evaluation-result validator and match its stored
hash.

History is append-only. A run ID may be written once. Corrections create a new
run/entry with explicit provenance; they never replace bytes behind an accepted
hash.

`scripts/hotl-evaluation-history.sh append` stores one validated entry under a
stable SHA-256 key derived from its run ID, verifies the referenced result hash,
and rejects duplicate run IDs. `append-run` is the normal ingestion path: it
recovers every completed validated result from completed or interrupted campaign
evidence and derives workload hashes from the validated campaign. A repeat
invocation skips existing run IDs and appends only newly available records.
Direct `append` is a trusted, advanced path because a standalone result cannot
independently reconstruct its prompt, response-schema, or assertion bytes.

## Workload identity

Comparable workload identity contains:

- Repository revision and protocol revision
- Scenario ID and scenario revision
- Prompt, response-schema, and assertion hashes
- Operating system, architecture, and toolchain fingerprint

These values describe the workload. A change is visible workload or environment
drift and must not silently join an earlier compatible cohort.

## Profile observation

Profile observation contains logical profile ID plus host, host version,
resolved model, effort, and adapter version. Unlike Phase 7 environment
identity, host/version/model are observed profile variables in a Phase 8
campaign. Trend logic may compare hosts only when workload identity matches and
must still display every observed profile difference.

## Telemetry normalization provenance

Every entry names normalization version `hotl.tokens/v1`. Observed token data
must state source, input semantics, cached semantics, and
`normalized: true`. Supported input semantics distinguish uncached input,
provider totals without cache, and already disjoint counters. Cached semantics
distinguish a separately extracted subset, a disjoint counter, or no cache.

When tokens are unavailable, both semantics are `unavailable`. Cost provenance
is independently `observed` or `unavailable`. Missing or ambiguous provider
counters never become zero and never become comparable by inference.

## Deterministic history report

`scripts/hotl-evaluation-history.sh report` validates every stored entry and
its referenced result before reporting. The
`hotl.evaluation-history-report/v1` output contains campaign status, workload
cohorts, chronological per-profile/scenario comparisons, Phase 7 profile
relationship summaries, regression/drift counts, source horizon, and mandatory
human/configuration boundaries.

For a single campaign relationship, the report creates a deterministic Phase 8
workload projection before reusing Phase 7 comparison semantics. Repository,
operating-system, architecture, and toolchain dimensions remain cohort identity;
host version is replaced only in the projection by the campaign workload-set
hash. Actual host, host version, resolved model, effort, and adapter remain in
`observed_profiles`. Conflicting prompt, schema, or assertion hashes for the same
scenario revision produce `incompatible_workload` and no candidate. If one
logical profile ID resolves to changing host, version, model, effort, or adapter
observations inside a campaign relationship, it produces
`incompatible_profile_observation` and no candidate.

## Drift and regression vocabulary

Future trend reports classify at least:

- `compatible`
- `workload_drift`
- `prompt_or_schema_drift`
- `host_drift`
- `adapter_or_model_drift`
- `toolchain_drift`
- `telemetry_drift`
- `incomplete_campaign`
- `quality_regression`
- `insufficient_evidence`

Each chronological comparison keeps a primary `classification` for compatibility
and a deterministic `classifications` array containing every applicable axis.
Drift classification precedes performance comparison. A regression or profile
proposal is advisory evidence and always retains human review. Compatible
single-campaign profile relationships reuse the Phase 7 safety,
telemetry-completeness, and Pareto report semantics.

## Configuration boundary

History validation, append, trend, drift, and proposal surfaces perform no
model, effort, driver, permission, policy, sandbox, plugin, schedule, or routing
configuration change.
