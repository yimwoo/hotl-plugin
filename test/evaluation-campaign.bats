#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    CAMPAIGN_SCRIPT="$REPO_ROOT/scripts/hotl-evaluation-campaign.sh"
    COLLECTOR_SCRIPT="$REPO_ROOT/scripts/hotl-evaluation-collect.sh"
    HISTORY_SCRIPT="$REPO_ROOT/scripts/hotl-evaluation-history.sh"
    PROPOSAL_SCRIPT="$REPO_ROOT/scripts/hotl-evaluation-proposal.sh"
    SCHEDULE_SCRIPT="$REPO_ROOT/scripts/hotl-evaluation-schedule.sh"
    TEST_TMP="$(mktemp -d)"
    cp -R "$REPO_ROOT/test/fixtures/evaluation-campaign" "$TEST_TMP/campaign"
    CAMPAIGN="$TEST_TMP/campaign/valid-campaign.json"
    HISTORY_ENTRY="$TEST_TMP/campaign/valid-history-entry.json"
    FAKE_BIN="$REPO_ROOT/test/fixtures/evaluation-campaign/bin"
    CALL_LOG="$TEST_TMP/host-calls.log"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "evaluation contract accepts a complete campaign" {
    run bash "$CAMPAIGN_SCRIPT" validate "$CAMPAIGN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evaluation campaign valid"* ]]
}

@test "evaluation contract rejects duplicate profile identities" {
    jq '.profiles[1].profile_id = .profiles[0].profile_id' "$CAMPAIGN" > "$TEST_TMP/invalid.json"

    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation campaign"* ]]
}

@test "evaluation contract rejects duplicate scenario revisions" {
    jq '.scenarios += [.scenarios[0]]' "$CAMPAIGN" > "$TEST_TMP/invalid.json"

    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation campaign"* ]]
}

@test "evaluation contract rejects a call budget below the planned matrix" {
    jq '.budgets.max_calls = 3' "$CAMPAIGN" > "$TEST_TMP/invalid.json"

    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"planned call count 4 exceeds max_calls 3"* ]]
}

@test "evaluation contract rejects artifact hash drift" {
    jq '.scenarios[0].prompt_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
        "$CAMPAIGN" > "$TEST_TMP/campaign/invalid.json"

    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/campaign/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"hash mismatch"* ]]
}

@test "evaluation contract rejects effort configuration injection" {
    jq '.profiles[0].requested_effort = "low\"\nsandbox=\"danger-full-access"' \
        "$CAMPAIGN" > "$TEST_TMP/campaign/invalid.json"

    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/campaign/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation campaign"* ]]
}

@test "evaluation contract validates effort levels per host" {
    jq '(.profiles[] | select(.host == "codex") | .requested_effort) = "minimal" |
        (.profiles[] | select(.host == "claude-code") | .requested_effort) = "max"' \
        "$CAMPAIGN" > "$TEST_TMP/campaign/supported.json"
    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/campaign/supported.json"
    [ "$status" -eq 0 ]

    jq '(.profiles[] | select(.host == "codex") | .requested_effort) = "max"' \
        "$CAMPAIGN" > "$TEST_TMP/campaign/invalid-codex.json"
    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/campaign/invalid-codex.json"
    [ "$status" -ne 0 ]

    jq '(.profiles[] | select(.host == "claude-code") | .requested_effort) = "minimal"' \
        "$CAMPAIGN" > "$TEST_TMP/campaign/invalid-claude.json"
    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/campaign/invalid-claude.json"
    [ "$status" -ne 0 ]
}

@test "evaluation contract rejects an artifact symlink outside the campaign" {
    prompt_relative="$(jq -r '.scenarios[0].prompt_path' "$CAMPAIGN")"
    cp "$TEST_TMP/campaign/$prompt_relative" "$TEST_TMP/outside-prompt.txt"
    rm "$TEST_TMP/campaign/$prompt_relative"
    ln -s "$TEST_TMP/outside-prompt.txt" "$TEST_TMP/campaign/$prompt_relative"

    run bash "$CAMPAIGN_SCRIPT" validate "$CAMPAIGN"

    [ "$status" -ne 0 ]
    [[ "$output" == *"escapes campaign directory"* ]]
}

@test "evaluation contract rejects an output parent symlink outside the campaign" {
    mkdir -p "$TEST_TMP/outside-output"
    ln -s "$TEST_TMP/outside-output" "$TEST_TMP/campaign/escaped-output"
    jq '.output_root = "escaped-output/run"' "$CAMPAIGN" > "$TEST_TMP/campaign/invalid.json"

    run bash "$CAMPAIGN_SCRIPT" validate "$TEST_TMP/campaign/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"output_root escapes campaign directory"* ]]
}

@test "evaluation contract planning is deterministic and read-only" {
    run bash "$CAMPAIGN_SCRIPT" plan "$CAMPAIGN"
    [ "$status" -eq 0 ]
    first="$output"

    run bash "$CAMPAIGN_SCRIPT" plan "$CAMPAIGN"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
    [ "$(jq -r '.schema' <<< "$output")" = "hotl.evaluation-campaign-plan/v1" ]
    [ "$(jq '.planned_calls' <<< "$output")" -eq 4 ]
    [ "$(jq -r '.live_execution' <<< "$output")" = "false" ]
    [ "$(jq -r '.configuration_changes_performed' <<< "$output")" = "false" ]
    [ ! -e "$REPO_ROOT/.hotl/test-campaign-contract-output" ]
}

@test "evaluation contract accepts a complete history entry" {
    run bash "$HISTORY_SCRIPT" validate-entry "$HISTORY_ENTRY"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Evaluation history entry valid"* ]]
}

@test "evaluation contract rejects a history content hash mismatch" {
    jq '.result_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
        "$HISTORY_ENTRY" > "$TEST_TMP/invalid-history.json"

    run bash "$HISTORY_SCRIPT" validate-entry "$TEST_TMP/invalid-history.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"result hash mismatch"* ]]
}

@test "evaluation contract rejects ambiguous observed token provenance" {
    jq '.telemetry_provenance.tokens.normalized = false' \
        "$HISTORY_ENTRY" > "$TEST_TMP/invalid-history.json"

    run bash "$HISTORY_SCRIPT" validate-entry "$TEST_TMP/invalid-history.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation history entry"* ]]
}

@test "evaluation contract rejects a history result symlink outside the repository" {
    prepare_history_repo
    outside_result="$TEST_TMP/outside-result.json"
    cp "$REPO_ROOT/test/fixtures/evaluations/comparison/identity-valid.json" "$outside_result"
    ln -s "$outside_result" "$HISTORY_REPO_ROOT/results/escaped.json"
    result_hash="$(shasum -a 256 "$outside_result" | awk '{print $1}')"
    jq --arg result_hash "$result_hash" \
        '.result_path = "results/escaped.json" | .result_sha256 = $result_hash' \
        "$HISTORY_ENTRY" > "$TEST_TMP/escaped-history.json"

    run history_env bash "$HISTORY_SCRIPT" validate-entry "$TEST_TMP/escaped-history.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"outside the declared repository root"* ]]
}

make_profile_campaign() {
    local host="$1"
    local profile_id="$2"
    local output_name="$3"
    local repetitions="${4:-1}"
    local max_calls="${5:-$repetitions}"
    local max_cost="${6:-null}"

    jq \
        --arg host "$host" \
        --arg profile_id "$profile_id" \
        --arg output_root "runs/$output_name" \
        --argjson repetitions "$repetitions" \
        --argjson max_calls "$max_calls" \
        --argjson max_cost "$max_cost" \
        '.profiles = [{
            profile_id:$profile_id,
            host:$host,
            requested_model:(if $host == "generic" then null else "fixture-model" end),
            requested_effort:(if $host == "generic" then null else "low" end),
            adapter_version:"phase8-test"
         }] |
         .repetitions = $repetitions |
         .budgets.max_calls = $max_calls |
         .budgets.max_cost_usd = $max_cost |
         .output_root = $output_root' \
        "$CAMPAIGN" > "$TEST_TMP/campaign/$output_name.json"
    printf '%s\n' "$TEST_TMP/campaign/$output_name.json"
}

collector_env() {
    env \
        HOTL_EVAL_CODEX_BIN="$FAKE_BIN/codex" \
        HOTL_EVAL_CLAUDE_BIN="$FAKE_BIN/claude" \
        HOTL_EVAL_GENERIC_BIN="$FAKE_BIN/generic" \
        HOTL_EVAL_CALL_LOG="$CALL_LOG" \
        HOTL_EVAL_REPO_REVISION="fixture-revision" \
        HOTL_EVAL_OS="fixture-os" \
        HOTL_EVAL_ARCH="fixture-arch" \
        HOTL_EVAL_TOOLCHAIN_FINGERPRINT="fixture-toolchain" \
        HOTL_EVAL_RECORDED_AT="2026-06-30T20:00:00Z" \
        "$@"
}

single_result() {
    find "$1/results" -type f -name '*.json' -print -quit
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

@test "evaluation collector requires explicit live approval without side effects" {
    campaign="$(make_profile_campaign codex codex-low no-approval)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign"

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [[ "$output" == *"explicit live approval"* ]]
    [ ! -e "$TEST_TMP/campaign/runs/no-approval" ]
    [ ! -e "$CALL_LOG" ]
}

@test "evaluation collector normalizes Codex cached input as a subset" {
    campaign="$(make_profile_campaign codex codex-low codex-valid)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    result="$(single_result "$TEST_TMP/campaign/runs/codex-valid")"
    [ -f "$result" ]
    [ "$(jq '.telemetry.tokens.input' "$result")" -eq 100 ]
    [ "$(jq '.telemetry.tokens.cached' "$result")" -eq 20 ]
    [ "$(jq -r '.telemetry_provenance.tokens.input_semantics' "$result")" = "uncached_input" ]
    [ "$(jq -r '.telemetry_provenance.tokens.cached_semantics' "$result")" = "separate_subset" ]
    evidence="$(find "$TEST_TMP/campaign/runs/codex-valid/evidence" -type f -name '*.json' ! -name '*.response.json' -print -quit)"
    [ "$(jq -r '.host_binary' "$evidence")" = "$FAKE_BIN/codex" ]
    [ "$(jq -r '.prompt_capture.mode' "$evidence")" = "hash_only" ]
    [ "$(jq -r '.prompt_capture.local_path' "$evidence")" = "null" ]
    [ "$(jq -r '.prompt_capture.sha256' "$evidence")" = "$(jq -r '.scenarios[0].prompt_sha256' "$campaign")" ]
    [ -z "$(find "$TEST_TMP/campaign/runs/codex-valid/evidence" -type f -name '*.prompt.txt' -print -quit)" ]
    [ "$(jq -r '.configuration_changes_performed' "$evidence")" = "false" ]
    [ "$(jq -r '.configuration_changes_performed' "$TEST_TMP/campaign/runs/codex-valid/campaign-run.json")" = "false" ]
    run bash "$REPO_ROOT/scripts/hotl-conformance.sh" validate-evaluation "$result"
    [ "$status" -eq 0 ]
}

@test "evaluation collector normalizes Claude cache reads as disjoint counters" {
    campaign="$(make_profile_campaign claude-code claude-low claude-valid 1 1 1)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    result="$(single_result "$TEST_TMP/campaign/runs/claude-valid")"
    [ "$(jq '.telemetry.tokens.input' "$result")" -eq 80 ]
    [ "$(jq '.telemetry.tokens.cached' "$result")" -eq 30 ]
    [ "$(jq '.telemetry.cost.usd' "$result")" = "0.02" ]
    [ "$(jq -r '.telemetry_provenance.tokens.input_semantics' "$result")" = "disjoint_counters" ]
    [ "$(jq -r '.telemetry_provenance.tokens.cached_semantics' "$result")" = "disjoint_counter" ]
}

@test "evaluation collector preserves unavailable fallback telemetry as null" {
    campaign="$(make_profile_campaign generic generic-safe generic-valid)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    result="$(single_result "$TEST_TMP/campaign/runs/generic-valid")"
    [ "$(jq -r '.execution_implementation' "$result")" = "fallback" ]
    [ "$(jq -r '.telemetry.tokens.source' "$result")" = "unavailable" ]
    [ "$(jq '.telemetry.tokens.input' "$result")" = "null" ]
    [ "$(jq -r '.telemetry_provenance.tokens.input_semantics' "$result")" = "unavailable" ]
}

@test "evaluation collector refuses an invalid call budget before invoking a host" {
    campaign="$(make_profile_campaign codex codex-low invalid-call-budget 2 1)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [[ "$output" == *"planned call count 2 exceeds max_calls 1"* ]]
    [ ! -e "$CALL_LOG" ]
    [ ! -e "$TEST_TMP/campaign/runs/invalid-call-budget" ]
}

@test "evaluation collector stops after a cost budget is exceeded" {
    campaign="$(make_profile_campaign claude-code claude-low cost-budget 2 2 0.01)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [ "$(wc -l < "$CALL_LOG" | tr -d ' ')" -eq 1 ]
    [ "$(jq -r '.status' "$TEST_TMP/campaign/runs/cost-budget/campaign-run.json")" = "incomplete" ]
    [ "$(jq -r '.stop_reason' "$TEST_TMP/campaign/runs/cost-budget/campaign-run.json")" = "cost_budget_exceeded" ]
}

@test "evaluation collector refuses a cost budget that its host cannot enforce" {
    campaign="$(make_profile_campaign codex codex-low unknown-cost 2 2 1)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot enforce max_cost_usd"* ]]
    [ ! -e "$CALL_LOG" ]
    [ ! -e "$TEST_TMP/campaign/runs/unknown-cost" ]
}

@test "evaluation collector enforces a per-call timeout" {
    campaign="$(make_profile_campaign codex codex-low timeout)"

    FAKE_EVAL_MODE=sleep run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 1

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [ "$(jq -r '.status' "$TEST_TMP/campaign/runs/timeout/campaign-run.json")" = "incomplete" ]
    [ "$(jq -r '.stop_reason' "$TEST_TMP/campaign/runs/timeout/campaign-run.json")" = "timeout" ]
}

@test "evaluation collector rejects malformed structured output" {
    campaign="$(make_profile_campaign codex codex-low malformed)"

    FAKE_EVAL_MODE=malformed run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [ "$(jq -r '.stop_reason' "$TEST_TMP/campaign/runs/malformed/campaign-run.json")" = "malformed_response" ]
    [ ! -d "$TEST_TMP/campaign/runs/malformed/results" ] || [ -z "$(find "$TEST_TMP/campaign/runs/malformed/results" -type f -name '*.json' -print -quit)" ]
}

@test "evaluation collector preserves completed evidence when interrupted" {
    campaign="$(make_profile_campaign generic generic-safe interrupted 2 2)"

    FAKE_EVAL_INTERRUPT_ON_CALL=2 run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [ "$(jq -r '.status' "$TEST_TMP/campaign/runs/interrupted/campaign-run.json")" = "incomplete" ]
    [ "$(jq -r '.stop_reason' "$TEST_TMP/campaign/runs/interrupted/campaign-run.json")" = "interrupted" ]
    [ "$(find "$TEST_TMP/campaign/runs/interrupted/results" -type f -name '*.json' | wc -l | tr -d ' ')" -eq 1 ]
}

@test "evaluation collector redacts captured host secrets" {
    campaign="$(make_profile_campaign codex codex-low redacted)"

    FAKE_EVAL_MODE=secret run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    ! rg -q 'FAKE_SECRET_VALUE' "$TEST_TMP/campaign/runs/redacted"
    rg -q '\[REDACTED\]' "$TEST_TMP/campaign/runs/redacted/evidence"
}

@test "evaluation collector keeps local evidence private by default" {
    campaign="$(make_profile_campaign codex codex-low private-evidence)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    output_root="$TEST_TMP/campaign/runs/private-evidence"
    evidence_file="$(find "$output_root/evidence" -type f -print -quit)"
    [ "$(file_mode "$output_root")" = "700" ]
    [ "$(file_mode "$output_root/campaign-run.json")" = "600" ]
    [ "$(file_mode "$evidence_file")" = "600" ]
}

@test "evaluation collector honors explicit local prompt capture and redaction" {
    campaign="$(make_profile_campaign codex codex-low local-prompt)"
    printf 'Return the fixture response. api_key=FAKE_PROMPT_SECRET\n' > "$TEST_TMP/campaign/local-prompt-source.txt"
    prompt_hash="$(shasum -a 256 "$TEST_TMP/campaign/local-prompt-source.txt" | awk '{print $1}')"
    jq --arg prompt_hash "$prompt_hash" \
        '.capture.prompts = "local" |
         .scenarios[0].prompt_path = "local-prompt-source.txt" |
         .scenarios[0].prompt_sha256 = $prompt_hash' \
        "$campaign" > "$TEST_TMP/campaign/local-prompt-updated.json"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$TEST_TMP/campaign/local-prompt-updated.json" \
        --approve-live --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    output_root="$TEST_TMP/campaign/runs/local-prompt"
    prompt_evidence="$(find "$output_root/evidence" -type f -name '*.prompt.txt' -print -quit)"
    prompt_evidence_physical="$(cd "$(dirname "$prompt_evidence")" && pwd -P)/$(basename "$prompt_evidence")"
    metadata="$(find "$output_root/evidence" -type f -name '*.json' ! -name '*.response.json' -print -quit)"
    [ -f "$prompt_evidence" ]
    ! rg -q 'FAKE_PROMPT_SECRET' "$prompt_evidence"
    rg -q '\[REDACTED\]' "$prompt_evidence"
    [ "$(jq -r '.prompt_capture.mode' "$metadata")" = "local" ]
    [ "$(jq -r '.prompt_capture.local_path' "$metadata")" = "$prompt_evidence_physical" ]
    [ "$(file_mode "$prompt_evidence")" = "600" ]
}

prepare_history_repo() {
    HISTORY_REPO_ROOT="$TEST_TMP/history-repo"
    HISTORY_REGISTRY="$TEST_TMP/history-registry"
    mkdir -p "$HISTORY_REPO_ROOT/results"
}

history_env() {
    env HOTL_EVAL_REPO_ROOT="$HISTORY_REPO_ROOT" "$@"
}

append_history_record() {
    local record_id="$1"
    local profile_id="$2"
    local recorded_at="$3"
    local result_filter="${4:-.}"
    local entry_filter="${5:-.}"
    local result_file="$HISTORY_REPO_ROOT/results/$record_id.json"
    local base_result="$REPO_ROOT/test/fixtures/evaluations/comparison/identity-valid.json"
    local staged_result="$TEST_TMP/$record_id-result.json"
    local staged_entry="$TEST_TMP/$record_id-entry-base.json"
    local entry_file="$TEST_TMP/$record_id-entry.json"

    jq --arg profile_id "$profile_id" --arg recorded_at "$recorded_at" \
        '.profile_id = $profile_id | .recorded_at = $recorded_at' \
        "$base_result" > "$staged_result"
    jq "$result_filter" "$staged_result" > "$result_file"

    result_hash="$(shasum -a 256 "$result_file" | awk '{print $1}')"
    jq \
        --arg run_id "$record_id" \
        --arg recorded_at "$recorded_at" \
        --arg result_path "results/$record_id.json" \
        --arg result_hash "$result_hash" \
        --slurpfile result "$result_file" '
      $result[0] as $result |
      .run_id = $run_id |
      .recorded_at = $recorded_at |
      .result_path = $result_path |
      .result_sha256 = $result_hash |
      .campaign_status = "completed" |
      .campaign_run_id = "fixture-campaign-run" |
      .workload_identity.repo_revision = $result.environment.repo_revision |
      .workload_identity.scenario_id = $result.scenario_id |
      .workload_identity.scenario_revision = $result.scenario_revision |
      .workload_identity.os = $result.environment.os |
      .workload_identity.arch = $result.environment.arch |
      .workload_identity.toolchain_fingerprint = $result.environment.toolchain_fingerprint |
      .profile_observation.profile_id = $result.profile_id |
      .profile_observation.host = $result.host |
      .profile_observation.host_version = $result.environment.host_version |
      .profile_observation.resolved_model = $result.resolved_model |
      .profile_observation.effort_profile = $result.effort_profile |
      .profile_observation.adapter_version = $result.adapter_version |
      .telemetry_provenance.cost.source = $result.telemetry.cost.source
    ' "$REPO_ROOT/test/fixtures/evaluation-campaign/valid-history-entry.json" > "$staged_entry"
    jq "$entry_filter" "$staged_entry" > "$entry_file"

    history_env bash "$HISTORY_SCRIPT" append "$HISTORY_REGISTRY" "$entry_file" >/dev/null
    LAST_HISTORY_ENTRY="$entry_file"
}

append_history_pair() {
    local prefix="$1"
    local current_result_filter="${2:-.}"
    local current_entry_filter="${3:-.}"

    append_history_record "$prefix-base" "$prefix" "2026-06-30T20:00:00Z"
    append_history_record "$prefix-current" "$prefix" "2026-06-30T21:00:00Z" \
        "$current_result_filter" "$current_entry_filter"
}

@test "evaluation history append is immutable and duplicate protected" {
    prepare_history_repo
    append_history_record duplicate-run duplicate-profile "2026-06-30T20:00:00Z"
    before="$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' -exec shasum -a 256 {} \;)"

    run history_env bash "$HISTORY_SCRIPT" append "$HISTORY_REGISTRY" "$LAST_HISTORY_ENTRY"

    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate history run_id"* ]]
    after="$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' -exec shasum -a 256 {} \;)"
    [ "$after" = "$before" ]
    [ "$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' | wc -l | tr -d ' ')" -eq 1 ]
    stored_entry="$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' -print -quit)"
    [ "$(file_mode "$HISTORY_REGISTRY")" = "700" ]
    [ "$(file_mode "$stored_entry")" = "600" ]
}

@test "evaluation history recovers completed evidence from an interrupted campaign" {
    campaign="$(make_profile_campaign generic generic-safe interrupted-history 2 2)"
    FAKE_EVAL_INTERRUPT_ON_CALL=2 run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live --call-timeout-seconds 5
    [ "$status" -ne 0 ]
    manifest="$TEST_TMP/campaign/runs/interrupted-history/campaign-run.json"
    HISTORY_REPO_ROOT="$TEST_TMP/campaign"
    HISTORY_REGISTRY="$TEST_TMP/interrupted-history-registry"

    run history_env bash "$HISTORY_SCRIPT" append-run "$HISTORY_REGISTRY" "$campaign" "$manifest"

    [ "$status" -eq 0 ]
    [ "$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' | wc -l | tr -d ' ')" -eq 1 ]
    run history_env bash "$HISTORY_SCRIPT" append-run "$HISTORY_REGISTRY" "$campaign" "$manifest"
    [ "$status" -eq 0 ]
    [[ "$output" == *"appended=0 skipped=1"* ]]
    [ "$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' | wc -l | tr -d ' ')" -eq 1 ]
    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.campaigns[0].status' <<< "$output")" = "incomplete" ]
    jq -e '.comparisons | length == 0' <<< "$output"
}

@test "evaluation drift report is deterministic and separates drift classes" {
    prepare_history_repo
    append_history_pair compatible
    append_history_pair prompt-drift . '.workload_identity.prompt_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
    append_history_pair workload-drift '.environment.repo_revision = "changed-revision"'
    append_history_pair toolchain-drift '.environment.toolchain_fingerprint = "changed-toolchain"'
    append_history_pair host-drift '.host = "claude-code" | .environment.host_version = "claude-v2"'
    append_history_pair model-drift '.resolved_model = "changed-model" | .adapter_version = "changed-adapter"'
    append_history_pair telemetry-drift . '.telemetry_provenance.tokens.source = "changed-provider-json"'
    append_history_pair quality-regression '.retries = 1'
    append_history_pair incomplete-campaign . '.campaign_status = "incomplete"'

    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"
    [ "$status" -eq 0 ]
    first="$output"
    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]

    classifications="$(jq -c '[.comparisons[].classification] | unique' <<< "$output")"
    for expected in compatible prompt_or_schema_drift workload_drift toolchain_drift host_drift adapter_or_model_drift telemetry_drift quality_regression incomplete_campaign; do
        jq -e --arg expected "$expected" 'index($expected) != null' <<< "$classifications" >/dev/null
    done
    [ "$(jq -r '.human_review_required' <<< "$output")" = "true" ]
    [ "$(jq -r '.configuration_changes_performed' <<< "$output")" = "false" ]
    [ "$(jq '.regression_count' <<< "$output")" -eq 1 ]
    jq -e '.profile_comparisons | length == 1' <<< "$output"
    jq -e 'all(.profile_comparisons[]; .summary.recommendation.human_review_required == true and .summary.recommendation.configuration_changes_performed == false)' <<< "$output"
}

@test "evaluation drift report exposes every simultaneous drift axis" {
    prepare_history_repo
    append_history_pair multi-axis \
        '.host = "claude-code" | .environment.host_version = "claude-v2" | .resolved_model = "changed-model"' \
        '.workload_identity.prompt_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'

    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"

    [ "$status" -eq 0 ]
    jq -e '.comparisons | length == 1' <<< "$output"
    [ "$(jq -r '.comparisons[0].classification' <<< "$output")" = "prompt_or_schema_drift" ]
    jq -e '.comparisons[0].classifications == ["prompt_or_schema_drift", "host_drift", "adapter_or_model_drift"]' <<< "$output"
    [ "$(jq '.drift_count' <<< "$output")" -eq 1 ]
}

@test "evaluation history compares Codex and Claude profiles on one shared workload" {
    prepare_history_repo
    for scenario in successful-completion retry-then-success report-and-finish; do
        append_history_record "codex-$scenario" codex-profile "2026-06-30T20:00:00Z" \
            ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\" | .host = \"codex\" | .environment.host_version = \"codex-v1\" | .telemetry.duration_ms = 1000"
        append_history_record "claude-$scenario" claude-profile "2026-06-30T20:00:00Z" \
            ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\" | .host = \"claude-code\" | .environment.host_version = \"claude-v1\" | .telemetry.duration_ms = 2000"
    done

    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"

    [ "$status" -eq 0 ]
    jq -e '.profile_comparisons | length == 1' <<< "$output"
    jq -e '.profile_comparisons[0].comparison_status == "eligible"' <<< "$output"
    jq -e '.profile_comparisons[0].summary.cohorts | length == 1' <<< "$output"
    jq -e '.profile_comparisons[0].summary.cohorts[0].eligibility.eligible == true' <<< "$output"
    jq -e '.profile_comparisons[0].summary.cohorts[0].shared_scenario_count == 3' <<< "$output"
    [ "$(jq -r '.profile_comparisons[0].summary.recommendation.candidate_profile_id' <<< "$output")" = "codex-profile" ]
    jq -e '.profile_comparisons[0].observed_profiles[] | select(.profile_id == "codex-profile") | .hosts == ["codex"] and .host_versions == ["codex-v1"]' <<< "$output"
    jq -e '.profile_comparisons[0].observed_profiles[] | select(.profile_id == "claude-profile") | .hosts == ["claude-code"] and .host_versions == ["claude-v1"]' <<< "$output"
}

@test "evaluation history blocks a profile comparison when workload hashes conflict" {
    prepare_history_repo
    for scenario in successful-completion retry-then-success report-and-finish; do
        append_history_record "safe-$scenario" safe-profile "2026-06-30T20:00:00Z" \
            ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\""
        if [ "$scenario" = "retry-then-success" ]; then
            append_history_record "drifted-$scenario" drifted-profile "2026-06-30T20:00:00Z" \
                ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\"" \
                '.workload_identity.prompt_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
        else
            append_history_record "drifted-$scenario" drifted-profile "2026-06-30T20:00:00Z" \
                ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\""
        fi
    done

    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.profile_comparisons[0].comparison_status' <<< "$output")" = "incompatible_workload" ]
    [ "$(jq -r '.profile_comparisons[0].summary.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
    jq -e '.profile_comparisons[0].summary.recommendation.reason_codes | index("phase8_workload_identity_mismatch") != null' <<< "$output"
    jq -e 'all(.profile_comparisons[0].summary.cohorts[]; .eligibility.eligible == false)' <<< "$output"
}

@test "evaluation history blocks a profile whose observations change inside one campaign" {
    prepare_history_repo
    for scenario in successful-completion retry-then-success report-and-finish; do
        append_history_record "stable-$scenario" stable-profile "2026-06-30T20:00:00Z" \
            ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\" | .environment.host_version = \"stable-v1\""
        changing_version="changing-v1"
        [ "$scenario" != "report-and-finish" ] || changing_version="changing-v2"
        append_history_record "changing-$scenario" changing-profile "2026-06-30T20:00:00Z" \
            ".scenario_id = \"$scenario\" | .scenario_revision = \"2026-06-29\" | .environment.host_version = \"$changing_version\""
    done

    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.profile_comparisons[0].comparison_status' <<< "$output")" = "incompatible_profile_observation" ]
    [ "$(jq -r '.profile_comparisons[0].summary.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
    jq -e '.profile_comparisons[0].summary.recommendation.reason_codes | index("phase8_profile_observation_inconsistent") != null' <<< "$output"
    jq -e '.profile_comparisons[0].observed_profiles[] | select(.profile_id == "changing-profile") | .host_versions == ["changing-v1", "changing-v2"]' <<< "$output"
}

@test "evaluation drift report rejects registry evidence that changed in place" {
    prepare_history_repo
    append_history_record immutable-entry immutable-profile "2026-06-30T20:00:00Z"
    stored_entry="$(find "$HISTORY_REGISTRY/entries" -type f -name '*.json' -print -quit)"
    jq '.result_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
        "$stored_entry" > "$TEST_TMP/tampered.json"
    cp "$TEST_TMP/tampered.json" "$stored_entry"

    run history_env bash "$HISTORY_SCRIPT" report "$HISTORY_REGISTRY"

    [ "$status" -ne 0 ]
    [[ "$output" == *"result hash mismatch"* ]]
}

@test "evaluation schedule preflight is deterministic and read-only" {
    campaign="$(make_profile_campaign generic generic-safe schedule-preflight)"

    run bash "$SCHEDULE_SCRIPT" preflight "$campaign" --host codex --run-label scheduled-20260630t220000z
    [ "$status" -eq 0 ]
    first="$output"
    run bash "$SCHEDULE_SCRIPT" preflight "$campaign" --host codex --run-label scheduled-20260630t220000z
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
    [ "$(jq -r '.schema' <<< "$output")" = "hotl.evaluation-schedule-preflight/v1" ]
    [ "$(jq '.planned_calls' <<< "$output")" -eq 1 ]
    [ "$(jq -r '.credentials_status' <<< "$output")" = "unverified" ]
    [ "$(jq -r '.ready_to_enable' <<< "$output")" = "false" ]
    [ "$(jq -r '.schedule_changes_performed' <<< "$output")" = "false" ]
    [ "$(jq -r '.configuration_changes_performed' <<< "$output")" = "false" ]
    jq -e '.blocking_reasons | index("human_schedule_approval_required") != null' <<< "$output"
    jq -e '.blocking_reasons | index("credentials_unverified") != null' <<< "$output"
    [ ! -e "$TEST_TMP/campaign/runs/schedule-preflight" ]
    [ ! -e "$CALL_LOG" ]
}

@test "evaluation schedule preflight blocks an unenforceable provider cost budget" {
    campaign="$(make_profile_campaign codex codex-low schedule-cost 1 1 1)"

    run bash "$SCHEDULE_SCRIPT" preflight "$campaign" --host codex --run-label scheduled-cost

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot enforce max_cost_usd"* ]]
    [ ! -e "$CALL_LOG" ]
    [ ! -e "$TEST_TMP/campaign/runs/schedule-cost" ]
}

@test "evaluation schedule run labels isolate repeated campaign output" {
    campaign="$(make_profile_campaign generic generic-safe scheduled-output)"

    run collector_env bash "$COLLECTOR_SCRIPT" run "$campaign" --approve-live \
        --run-label scheduled-20260630t220000z --call-timeout-seconds 5

    [ "$status" -eq 0 ]
    manifest="$TEST_TMP/campaign/runs/scheduled-output/scheduled-20260630t220000z/campaign-run.json"
    [ -f "$manifest" ]
    [ "$(jq -r '.schedule_changes_performed' "$manifest")" = "false" ]
    [ "$(jq -r '.configuration_changes_performed' "$manifest")" = "false" ]
}

@test "evaluation schedule templates are inert and require native host enablement" {
    root="$REPO_ROOT/automations/continuous-evaluation"
    [ -f "$root/prompt.md" ]
    [ -f "$root/codex.md" ]
    [ -f "$root/claude-code.md" ]
    ! find "$root" -type f -name 'automation.toml' | grep -q .
    grep -q '^template_status: inert$' "$root/codex.md"
    grep -q '^template_status: inert$' "$root/claude-code.md"
    grep -q 'explicit human enablement' "$root/prompt.md"
    grep -q -- '--approve-live' "$root/prompt.md"
    grep -q 'append-run' "$root/prompt.md"
    ! rg -n '\.codex/automations|CronCreate' "$REPO_ROOT/install.sh" "$REPO_ROOT/update.sh"
}

@test "evaluation proposal renders an evidence-linked human review candidate" {
    report="$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json"

    run bash "$PROPOSAL_SCRIPT" --format json --current-profile codex-high "$report"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.schema' <<< "$output")" = "hotl.evaluation-profile-proposal/v1" ]
    [ "$(jq -r '.proposal.state' <<< "$output")" = "review_candidate" ]
    [ "$(jq -r '.proposal.current_profile_id' <<< "$output")" = "codex-high" ]
    [ "$(jq -r '.proposal.candidate_profile_id' <<< "$output")" = "codex-low" ]
    [ "$(jq -r '.proposal.human_review_required' <<< "$output")" = "true" ]
    [ "$(jq -r '.proposal.configuration_changes_performed' <<< "$output")" = "false" ]
    jq -e '.evidence.campaign_run_ids | index("candidate-campaign-run") != null' <<< "$output"
    jq -e '.evidence.candidate_safety | all(.[]; .eligible == true)' <<< "$output"
    jq -e '.confidence.limitations | length >= 3' <<< "$output"
    jq -e '.rollback.guidance | length >= 3' <<< "$output"
}

@test "evaluation proposal retains a candidate but exposes regression warnings" {
    report="$TEST_TMP/history-warning.json"
    jq '.regression_count = 1 |
        .comparisons += [{profile_id:"codex-low",scenario_id:"successful-completion",previous_run_id:"old",current_run_id:"new",classification:"quality_regression"}]' \
        "$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json" > "$report"

    run bash "$PROPOSAL_SCRIPT" --format json --current-profile codex-high "$report"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.proposal.state' <<< "$output")" = "review_candidate_with_warnings" ]
    jq -e '.evidence.regressions | length == 1' <<< "$output"
    jq -e '.evidence.incompatible_or_missing | index("quality_regression") != null' <<< "$output"
}

@test "evaluation proposal preserves every classification from multi-axis drift" {
    report="$TEST_TMP/history-multi-axis.json"
    jq '.drift_count = 1 |
        .comparisons += [{
          profile_id:"codex-low",
          scenario_id:"successful-completion",
          previous_run_id:"old",
          current_run_id:"new",
          classification:"prompt_or_schema_drift",
          classifications:["prompt_or_schema_drift", "host_drift", "adapter_or_model_drift"]
        }]' "$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json" > "$report"

    run bash "$PROPOSAL_SCRIPT" --format json --current-profile codex-high "$report"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.proposal.state' <<< "$output")" = "review_candidate_with_warnings" ]
    for expected in prompt_or_schema_drift host_drift adapter_or_model_drift; do
        jq -e --arg expected "$expected" '.evidence.incompatible_or_missing | index($expected) != null' <<< "$output"
    done
    jq -e '.evidence.drift[0].classifications | length == 3' <<< "$output"
}

@test "evaluation proposal asks for more evidence when no candidate exists" {
    report="$TEST_TMP/history-no-candidate.json"
    jq '.profile_comparisons[0].summary.recommendation = {
          state:"collect_more_evidence",
          candidate_profile_id:null,
          reason_codes:["minimum_shared_scenarios_not_met"],
          human_review_required:true,
          configuration_changes_performed:false
        }' "$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json" > "$report"

    run bash "$PROPOSAL_SCRIPT" --format json --current-profile codex-high "$report"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.proposal.state' <<< "$output")" = "collect_more_evidence" ]
    [ "$(jq '.proposal.candidate_profile_id' <<< "$output")" = "null" ]
    jq -e '.evidence.incompatible_or_missing | index("minimum_shared_scenarios_not_met") != null' <<< "$output"
}

@test "evaluation proposal refuses a candidate without safety eligibility" {
    report="$TEST_TMP/history-unsafe-candidate.json"
    jq '(.profile_comparisons[0].summary.cohorts[0].profiles[] |
         select(.profile_id == "codex-low") | .safety) = {
           eligible:false,
           disqualifiers:["contract_failure"],
           terminal_outcomes:["completed"],
           contract_failures:["fixture-failure"]
         }' "$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json" > "$report"

    run bash "$PROPOSAL_SCRIPT" --format json --current-profile codex-high "$report"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.proposal.state' <<< "$output")" = "collect_more_evidence" ]
    [ "$(jq '.proposal.candidate_profile_id' <<< "$output")" = "null" ]
    jq -e '.evidence.incompatible_or_missing | index("candidate_not_safety_eligible") != null' <<< "$output"
}

@test "evaluation proposal is deterministic and emits no configuration command" {
    report="$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json"

    run bash "$PROPOSAL_SCRIPT" --format text --current-profile codex-high "$report"
    [ "$status" -eq 0 ]
    first="$output"
    run bash "$PROPOSAL_SCRIPT" --format text --current-profile codex-high "$report"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
    [[ "$output" == *"Human review required: yes"* ]]
    [[ "$output" == *"Configuration changes performed: no"* ]]
    ! grep -Eq '(^|[[:space:]])(codex|claude)[[:space:]].*--(model|effort)|config(uration)?[[:space:]]+(set|write)|export[[:space:]]' <<< "$output"
}

@test "evaluation proposal rejects a source that claims configuration mutation" {
    report="$TEST_TMP/history-mutating.json"
    jq '.configuration_changes_performed = true' \
        "$REPO_ROOT/test/fixtures/evaluation-campaign/history-report-candidate.json" > "$report"

    run bash "$PROPOSAL_SCRIPT" --format json "$report"

    [ "$status" -ne 127 ]
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation history report"* ]]
}
