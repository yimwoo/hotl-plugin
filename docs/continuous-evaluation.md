# Continuous Evaluation and Drift Detection

HOTL can collect the same governed scenarios through Codex, Claude Code, and a
generic fallback; preserve validated results in append-only local history; and
surface drift, regressions, and profile candidates for human review.

This feature is opt-in. Normal installation performs no provider call, creates
no schedule, and changes no model, effort, driver, permission, sandbox, policy,
plugin, or routing configuration.

## Safety boundary

- Campaign validation and planning are read-only.
- Collection requires `--approve-live` and enforces call and elapsed-time
  budgets. A provider cost budget is accepted only when the host adapter can
  enforce it before the call.
- Raw evidence stays local with owner-only permissions by default. Capture and
  redaction are explicit campaign policy.
- History is append-only and hash-verified under stable run-ID-derived keys; a
  run ID cannot be replaced.
- Drift is classified before trends are interpreted.
- Profile proposals are advisory, require human review, and contain no
  configuration-changing command.
- Native scheduling templates are inert until a human creates and enables a
  task in Codex or Claude Desktop.

## 1. Define and preview a campaign

A `hotl.evaluation-campaign/v1` JSON file binds profiles and scenario revisions
to hashed prompts, response schemas, assertions, budgets, and capture policy.
Artifact paths and `output_root` are relative to the campaign file and must stay
inside its physical directory; symlink escapes are rejected. Requested effort is
host-specific: Codex accepts `minimal`, `low`, `medium`, `high`, or `xhigh`;
Claude Code accepts `low`, `medium`, `high`, `xhigh`, or `max`; and `null` keeps
the host default.

```json
{
  "schema": "hotl.evaluation-campaign/v1",
  "campaign_id": "weekly-governance-baseline",
  "protocol_revision": "2026-07-01",
  "created_at": "2026-07-01T16:00:00Z",
  "output_root": ".hotl/evaluations/weekly-governance-baseline",
  "repetitions": 1,
  "profiles": [
    {
      "profile_id": "codex-low",
      "host": "codex",
      "requested_model": "reviewed-model-id",
      "requested_effort": "low",
      "adapter_version": "reviewed-local-version"
    }
  ],
  "scenarios": [
    {
      "scenario_id": "successful-completion",
      "scenario_revision": "2026-06-29",
      "prompt_path": "scenarios/successful-completion.txt",
      "prompt_sha256": "<64-lowercase-hex>",
      "response_schema_path": "scenarios/response-schema.json",
      "response_schema_sha256": "<64-lowercase-hex>",
      "assertion_path": "scenarios/successful-completion-assertion.json",
      "assertion_sha256": "<64-lowercase-hex>"
    }
  ],
  "budgets": {
    "max_calls": 1,
    "max_elapsed_minutes": 10,
    "max_cost_usd": null
  },
  "capture": {
    "raw_output": "local",
    "prompts": "hash_only",
    "redact": true
  }
}
```

Replace every hash with the digest of its local artifact. Validate and preview
the complete call matrix without invoking a host:

```bash
bash scripts/hotl-evaluation-campaign.sh validate campaign.json
bash scripts/hotl-evaluation-campaign.sh plan campaign.json
```

The plan declares `live_execution: false`,
`schedule_changes_performed: false`, and
`configuration_changes_performed: false`.

## 2. Run an explicitly approved collection

Review the profiles, scenarios, calls, time/cost limits, and capture policy.
Then make the live boundary explicit:

```bash
bash scripts/hotl-evaluation-collect.sh run campaign.json \
  --approve-live \
  --call-timeout-seconds 300
```

The collector resolves and records the exact host binary and version, uses a
read-only Codex sandbox or tool-disabled Claude Code print session, validates
structured output, and writes only beneath the campaign output root. Override
host binaries deliberately with `HOTL_EVAL_CODEX_BIN`,
`HOTL_EVAL_CLAUDE_BIN`, or `HOTL_EVAL_GENERIC_BIN`.

For recurring runs of the same immutable campaign, add a unique run label:

```bash
bash scripts/hotl-evaluation-collect.sh run campaign.json \
  --approve-live \
  --run-label scheduled-20260701t160000z
```

Each run contains `campaign-run.json`, validated `results/`, and redacted
`evidence/`. Interrupted, timed-out, malformed, over-budget, and
telemetry-unknown runs remain `incomplete`; the collector does not silently
retry or increase a budget.

Prompt capture follows the campaign exactly: `none` stores no prompt evidence,
`hash_only` stores only the verified SHA-256 in call metadata, and `local` writes
an owner-only prompt copy beside the call evidence, applying the campaign's
redaction setting.

`max_cost_usd` must be `null` for profiles whose adapters cannot enforce a
pre-call provider limit. The current Claude Code adapter passes its remaining
limit to the host. Codex and generic profiles reject a non-null cost budget
instead of treating post-call or missing cost as hard enforcement.

## 3. Append history and inspect drift

Append every validated result from a completed or interrupted campaign run:

```bash
bash scripts/hotl-evaluation-history.sh append-run \
  .hotl/evaluation-history \
  campaign.json \
  .hotl/evaluations/weekly-governance-baseline/campaign-run.json
```

Re-running `append-run` is recovery-safe: already stored run IDs are skipped,
while newly available validated results are appended. This is the normal path
because it derives workload hashes from the validated campaign. Direct entry
validation and append are trusted, advanced ingestion operations: the caller is
responsible for the supplied prompt/schema/assertion attestations.

```bash
bash scripts/hotl-evaluation-history.sh validate-entry entry.json
bash scripts/hotl-evaluation-history.sh append .hotl/evaluation-history entry.json
```

Generate a deterministic report:

```bash
bash scripts/hotl-evaluation-history.sh report .hotl/evaluation-history \
  > .hotl/evaluation-history-report.json
```

The report separates `compatible`, workload, prompt/schema, host,
adapter/model, toolchain, and telemetry drift from incomplete campaigns and
quality regressions. `classification` retains the primary class for compatibility
and `classifications` lists every simultaneous drift axis. Compatible
single-campaign profile relationships retain the Phase 7 safety,
telemetry-completeness, and Pareto semantics. A Phase 8 workload projection lets
Codex, Claude Code, and fallback profiles share a cohort while host/version/model
remain visible observations; conflicting prompt/schema/assertion hashes block the
comparison. A logical profile whose observed host, version, model, effort, or
adapter changes inside the campaign is also ineligible until evidence is
recollected under stable profile identities.

## 4. Render a profile proposal

Profile proposals cite the history report hash, campaign runs, result paths,
safety evidence, regressions, drift, measured trade-offs, confidence limits,
and rollback guidance:

```bash
bash scripts/hotl-evaluation-proposal.sh \
  --format text \
  --current-profile codex-current \
  .hotl/evaluation-history-report.json
```

`review_candidate` and `review_candidate_with_warnings` mean only “inspect this
evidence.” An unsafe or missing candidate becomes `collect_more_evidence`.
Every output says `human_review_required: true`,
`automatic_selection_performed: false`, and
`configuration_changes_performed: false`.

## 5. Optional native scheduling

Preview one scheduled run without registering a task:

```bash
bash scripts/hotl-evaluation-schedule.sh preflight campaign.json \
  --host codex \
  --run-label scheduled-20260701t160000z
```

Preflight always returns `ready_to_enable: false` with human-approval and
credential-review blockers. It creates no output and performs no provider or
schedule call.

After manual testing and review, use the inert templates under
[`automations/continuous-evaluation/`](../automations/continuous-evaluation/):

- Codex: create a standalone project automation in the Codex app.
- Claude Code: create a Claude Desktop **Local** scheduled task so local
  binaries and append-only evidence remain available.

Creating and enabling the native task is the human approval for the pinned
campaign, cadence, and limits represented by that schedule. It grants no
authority to run a different campaign, increase budgets, or change profiles.

## Telemetry normalization

Codex cached input is normalized as a subset of total input: normalized input
equals total input minus cached input. Claude cache-read tokens are retained as
a disjoint counter. Generic observed telemetry must declare its counter
semantics; otherwise it remains unavailable. Every history entry records
`hotl.tokens/v1` provenance. Missing cost or token data stays `null`, never
zero or an estimate.

## Retention and redaction

Keep `.hotl` evidence local and ignored unless an owner adopts a reviewed
storage policy. Prefer `prompts: hash_only`, `raw_output: none` for sensitive
work, and `redact: true`. Local raw capture is useful for debugging but may
contain repository content or provider output; review it before sharing and
remove it only under an explicit retention decision. Never rewrite an accepted
history entry or the bytes referenced by its stored hash. To correct evidence,
append a new run with clear provenance.

## Contracts

- [Evaluation campaign](contracts/evaluation-campaign.md)
- [Evaluation result](contracts/evaluation-result-output.md)
- [Evaluation summary](contracts/evaluation-summary-output.md)
- [Evaluation history and drift](contracts/evaluation-history-and-drift.md)
- [Evaluation profile proposal](contracts/evaluation-profile-proposal.md)
