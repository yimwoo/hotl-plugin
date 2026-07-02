# HOTL Evaluation Campaign Contract

This contract defines a repeatable, reviewable evaluation campaign. A campaign
describes planned work; validating or planning it performs no provider call,
creates no output directory, enables no schedule, and changes no configuration.

## Identity and artifacts

The schema identifier is `hotl.evaluation-campaign/v1`. Every campaign has a
stable lowercase `campaign_id`, protocol revision, creation timestamp, relative
output root, positive repetition count, profiles, scenarios, budgets, and
capture policy.

Every scenario binds a scenario ID and revision to three relative local
artifacts:

- Prompt and SHA-256 hash
- Structured response schema and SHA-256 hash
- Deterministic assertion and SHA-256 hash

Validation rejects absolute paths, parent traversal, physical or symlink escapes
from the campaign directory, missing artifacts, hash drift, and duplicate
scenario/revision pairs. The assertion artifact is the exact JSON value expected
from the structured response in schema v1. Prompt, schema, and assertion changes
create a new workload identity; they are not silently treated as comparable
history.

## Profiles

Each profile has a stable `profile_id`, host (`codex`, `claude-code`, or
`generic`), requested model and effort when applicable, and adapter version.
Requested values describe campaign intent. Collectors later record resolved
model, effort, binary, host version, and adapter identity as observations.
Requested effort is host-specific. Codex accepts `minimal`, `low`, `medium`,
`high`, or `xhigh`; Claude Code accepts `low`, `medium`, `high`, `xhigh`, or
`max`; and `null` retains the host default. Generic adapters accept the union but
must enforce their own supported subset. Arbitrary host configuration text is
invalid.

Profile IDs are unique within a campaign. Host and model values never grant
permission or weaken a host policy.

## Planned calls and budgets

Planned calls equal profile count multiplied by scenario count multiplied by
repetitions. `budgets.max_calls` must cover that matrix; elapsed minutes must be
positive and cost is either a non-negative observed-provider limit or `null`
when no comparable cost control exists.

The deterministic plan uses schema `hotl.evaluation-campaign-plan/v1` and lists
every call in stable order. It always declares:

- `requires_live_approval: true`
- `live_execution: false`
- `schedule_changes_performed: false`
- `configuration_changes_performed: false`

Planning is a read-only preflight, not authorization to execute the matrix.

## Collection and run identity

`scripts/hotl-evaluation-collect.sh run <campaign> --approve-live` is the only
live collection boundary. The collector records exact host binary/version,
resolved profile observations, validated results, normalized telemetry
provenance, and redacted local evidence beneath `output_root`.

An optional `--run-label` creates a distinct child beneath the output root for
recurring execution without mutating the campaign. Labels are path-safe and
must be unique. Existing output is never overwritten.

Call and elapsed-time budgets are hard limits. A non-null cost budget is
accepted only when every selected adapter can enforce the remaining provider
limit before a call. Unknown cost for a cost-budgeted run stops collection;
HOTL never estimates provider pricing from tokens.

## Capture policy

Raw output is `none` or `local`. Prompt capture is `none`, `hash_only`, or
`local`. Redaction is explicit. Phase 8 collectors must not upload evidence or
capture secrets merely because a provider exposes them.

`none` omits prompt evidence from call metadata, `hash_only` records only the
verified digest, and `local` writes an owner-only prompt copy with the configured
redaction policy. The campaign artifact and its hash remain required
independently of capture mode.

Evidence is local by default. Retention, publication, or removal is an owner
decision; accepted append-only history must never point at silently replaced
bytes. Collector output directories use owner-only access and files use
owner-read/write permissions by default.

## Native schedule preflight

`scripts/hotl-evaluation-schedule.sh preflight` validates a campaign, unique
run label, budgets, capture policy, and output collision without registering a
task or invoking a provider. Its output always preserves human schedule/live
approval and credential-review blockers. Repository templates remain inert
until explicitly created and enabled through a native host surface.

## Human boundary

The campaign/history contracts require human acceptance before live collectors
are implemented. Every live campaign and every schedule enablement requires a
separate human decision. This contract contains no automatic selection or
configuration-write semantics.
