#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    CONFORMANCE="$REPO_ROOT/scripts/hotl-conformance.sh"
    EVALUATION_REPORT="$REPO_ROOT/scripts/hotl-evaluation-report.sh"
    SCENARIOS="$REPO_ROOT/test/fixtures/conformance/scenarios.json"
    EVALUATIONS="$REPO_ROOT/test/fixtures/evaluations"
    COMPARISON_FIXTURES="$EVALUATIONS/comparison"
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMP"
}

make_result() {
    local output="$1"
    local profile="$2"
    local scenario="$3"
    local duration_ms="$4"
    local cost_usd="$5"

    jq \
        --arg profile "$profile" \
        --arg scenario "$scenario" \
        --argjson duration "$duration_ms" \
        --argjson cost "$cost_usd" \
        '.profile_id = $profile |
         .scenario_id = $scenario |
         .telemetry.duration_ms = $duration |
         .telemetry.cost = {source:"observed",usd:$cost}' \
        "$COMPARISON_FIXTURES/identity-valid.json" > "$output"
}

make_profile_set() {
    local directory="$1"
    local profile="$2"
    local duration_ms="$3"
    local cost_usd="$4"
    local scenario

    mkdir -p "$directory"
    for scenario in successful-completion retry-then-success report-and-finish; do
        make_result "$directory/${profile}-${scenario}.json" "$profile" "$scenario" "$duration_ms" "$cost_usd"
    done
}

comparison_files() {
    find "$TEST_TMP" -name '*.json' -type f | sort
}

load_comparison_files() {
    FILES=()
    while IFS= read -r file; do
        FILES[${#FILES[@]}]="$file"
    done < <(comparison_files)
}

load_reversed_files() {
    REVERSED_FILES=()
    while IFS= read -r file; do
        REVERSED_FILES[${#REVERSED_FILES[@]}]="$file"
    done < <(comparison_files | sort -r)
}

@test "evaluation identity accepts the legacy result without additive identity fields" {
    run bash "$CONFORMANCE" validate-evaluation "$EVALUATIONS/result-sample.json" "$SCENARIOS"

    [ "$status" -eq 0 ]
}

@test "evaluation identity accepts profile and nullable environment identity" {
    run bash "$CONFORMANCE" validate-evaluation "$COMPARISON_FIXTURES/identity-valid.json" "$SCENARIOS"

    [ "$status" -eq 0 ]
}

@test "evaluation identity rejects an empty profile id" {
    jq '.profile_id = ""' "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/invalid-profile.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/invalid-profile.json" "$SCENARIOS"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation identity rejects a boolean profile id" {
    jq '.profile_id = false' "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/invalid-profile.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/invalid-profile.json" "$SCENARIOS"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation identity rejects a null profile id when the field is present" {
    jq '.profile_id = null' "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/invalid-profile.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/invalid-profile.json" "$SCENARIOS"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation identity rejects malformed environment fields" {
    jq '.environment.host_version = 123' "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/invalid-environment.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/invalid-environment.json" "$SCENARIOS"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation identity rejects a non-object environment" {
    jq '.environment = false' "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/invalid-environment.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/invalid-environment.json" "$SCENARIOS"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation identity keeps unavailable telemetry nullable" {
    jq '.telemetry.tokens = {source:"unavailable",input:null,output:null,cached:null} | .telemetry.cost = {source:"unavailable",usd:null}' \
        "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/unavailable.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/unavailable.json" "$SCENARIOS"

    [ "$status" -eq 0 ]
}

@test "evaluation comparison input rejects an invalid record before aggregation" {
    jq '.profile_id = ""' "$COMPARISON_FIXTURES/identity-valid.json" > "$TEST_TMP/invalid.json"

    run bash "$EVALUATION_REPORT" "$TEST_TMP/invalid.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation comparison input is byte-stable regardless of file order" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    load_comparison_files
    load_reversed_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"
    if [ "$status" -ne 0 ]; then
        echo "$output"
        return 1
    fi
    first="$output"

    run bash "$EVALUATION_REPORT" "${REVERSED_FILES[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
}

@test "evaluation comparison input marks a derived legacy profile identity" {
    run bash "$EVALUATION_REPORT" "$EVALUATIONS/result-sample.json"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.inputs.records[0].profile_identity_source' <<< "$output")" = "derived" ]
    [[ "$(jq -r '.inputs.records[0].profile_id' <<< "$output")" == legacy/* ]]
}

@test "evaluation comparison input separates known environment mismatches" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    for file in "$TEST_TMP"/b/*.json; do
        jq '.environment.host_version = "different-host"' "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    done
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq '.cohorts | length' <<< "$output")" -eq 2 ]
    [ "$(jq '[.cohorts[].profile_count] | max' <<< "$output")" -eq 1 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
}

@test "evaluation comparison input blocks unknown environment identity" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    for file in "$TEST_TMP"/b/*.json; do
        jq '.environment = null' "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    done
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq '[.cohorts[] | select(.environment_status == "unknown")] | length' <<< "$output")" -eq 1 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
    [ "$(jq -r '.recommendation.reason_codes[]' <<< "$output")" = "unknown_environment_identity" ]
}

@test "evaluation comparison requires two profiles and three shared scenarios" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
    [ "$(jq -r '.recommendation.reason_codes[]' <<< "$output")" = "minimum_profiles_not_met" ]

    make_result "$TEST_TMP/beta-one.json" beta successful-completion 1200 0.03
    load_comparison_files
    run bash "$EVALUATION_REPORT" "${FILES[@]}"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
    [ "$(jq -r '.recommendation.reason_codes[]' <<< "$output")" = "minimum_shared_scenarios_not_met" ]
}

@test "evaluation comparison treats a scenario revision mismatch as missing shared coverage" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    jq '.scenario_revision = "2026-06-30"' \
        "$TEST_TMP/b/beta-report-and-finish.json" > "$TEST_TMP/b/beta-report-and-finish.json.tmp"
    mv "$TEST_TMP/b/beta-report-and-finish.json.tmp" "$TEST_TMP/b/beta-report-and-finish.json"
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "collect_more_evidence" ]
    [ "$(jq '.cohorts[0].shared_scenario_count' <<< "$output")" -eq 2 ]
}

@test "evaluation comparison excludes non-shared scenarios from profile metrics" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    make_result "$TEST_TMP/a/alpha-extra.json" alpha failure-and-block 999999 99
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.candidate_profile_id' <<< "$output")" = "alpha" ]
    [ "$(jq '.cohorts[0].profiles[] | select(.profile_id == "alpha") | .scenarios | length' <<< "$output")" -eq 4 ]
    [ "$(jq '.cohorts[0].profiles[] | select(.profile_id == "alpha") | .comparison_scenarios | length' <<< "$output")" -eq 3 ]
    [ "$(jq '.cohorts[0].profiles[] | select(.profile_id == "alpha") | .metrics.duration_ms.mean' <<< "$output")" -eq 1000 ]
}

@test "evaluation comparison normalizes count metrics across repeat samples" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1000 0.02
    for file in "$TEST_TMP"/a/*.json "$TEST_TMP"/b/*.json; do
        jq '.interventions = 1' "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    done
    for file in "$TEST_TMP"/b/*.json; do
        jq '.' "$file" > "$TEST_TMP/b/repeat-$(basename "$file")"
    done
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "human_review_required" ]
    [ "$(jq '.cohorts[0].pareto_frontier | length' <<< "$output")" -eq 2 ]
    [ "$(jq '.cohorts[0].profiles[] | select(.profile_id == "beta") | .metrics.interventions.total' <<< "$output")" -eq 6 ]
    [ "$(jq '.cohorts[0].profiles[] | select(.profile_id == "beta") | .metrics.interventions.mean' <<< "$output")" -eq 1 ]
}

@test "evaluation comparison disqualifies defects and returns the sole reviewable candidate" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    jq '.post_completion_defects = 1' \
        "$TEST_TMP/b/beta-successful-completion.json" > "$TEST_TMP/b/beta-successful-completion.json.tmp"
    mv "$TEST_TMP/b/beta-successful-completion.json.tmp" "$TEST_TMP/b/beta-successful-completion.json"
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.schema' <<< "$output")" = "hotl.evaluation-summary/v1" ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "review_profile_candidate" ]
    [ "$(jq -r '.recommendation.candidate_profile_id' <<< "$output")" = "alpha" ]
    [ "$(jq -r '.cohorts[0].profiles[] | select(.profile_id == "beta") | .safety.eligible' <<< "$output")" = "false" ]
}

@test "evaluation comparison disqualifies contract failures and preserves their ids" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    jq '.contract_failures = ["verification_required"]' \
        "$TEST_TMP/b/beta-successful-completion.json" > "$TEST_TMP/b/beta-successful-completion.json.tmp"
    mv "$TEST_TMP/b/beta-successful-completion.json.tmp" "$TEST_TMP/b/beta-successful-completion.json"
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.candidate_profile_id' <<< "$output")" = "alpha" ]
    [ "$(jq -r '.cohorts[0].profiles[] | select(.profile_id == "beta") | .safety.eligible' <<< "$output")" = "false" ]
    [ "$(jq -r '.cohorts[0].profiles[] | select(.profile_id == "beta") | .safety.contract_failures[]' <<< "$output")" = "verification_required" ]
}

@test "evaluation comparison disqualifies non-completed outcomes" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    jq '.terminal_outcome = "paused"' \
        "$TEST_TMP/b/beta-successful-completion.json" > "$TEST_TMP/b/beta-successful-completion.json.tmp"
    mv "$TEST_TMP/b/beta-successful-completion.json.tmp" "$TEST_TMP/b/beta-successful-completion.json"
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.candidate_profile_id' <<< "$output")" = "alpha" ]
    [ "$(jq -r '.cohorts[0].profiles[] | select(.profile_id == "beta") | .safety.eligible' <<< "$output")" = "false" ]
    [ "$(jq -r '.cohorts[0].profiles[] | select(.profile_id == "beta") | .safety.terminal_outcomes | join(",")' <<< "$output")" = "completed,paused" ]
}

@test "evaluation comparison keeps a Pareto tie under human review" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.03
    make_profile_set "$TEST_TMP/b" beta 1200 0.02
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "human_review_required" ]
    [ "$(jq '.cohorts[0].pareto_frontier | length' <<< "$output")" -eq 2 ]
}

@test "evaluation comparison does not let unknown telemetry improve profile standing" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    for file in "$TEST_TMP"/a/*.json; do
        jq '.telemetry.duration_ms = null | .telemetry.cost = {source:"unavailable",usd:null}' "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    done
    load_comparison_files

    run bash "$EVALUATION_REPORT" "${FILES[@]}"

    [ "$status" -eq 0 ]
    [ "$(jq -r '.recommendation.state' <<< "$output")" = "human_review_required" ]
    [ "$(jq -r '.cohorts[0].profiles[] | select(.profile_id == "alpha") | .metrics.duration_ms.availability' <<< "$output")" = "unavailable" ]
    [ "$(jq '.cohorts[0].pareto_frontier | length' <<< "$output")" -eq 2 ]
}

@test "evaluation text renders a review candidate and mandatory human boundary" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    make_profile_set "$TEST_TMP/b" beta 1200 0.03
    jq '.post_completion_defects = 1' \
        "$TEST_TMP/b/beta-successful-completion.json" > "$TEST_TMP/b/beta-successful-completion.json.tmp"
    mv "$TEST_TMP/b/beta-successful-completion.json.tmp" "$TEST_TMP/b/beta-successful-completion.json"
    load_comparison_files

    run bash "$EVALUATION_REPORT" --format text "${FILES[@]}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Recommendation: review_profile_candidate"* ]]
    [[ "$output" == *"Candidate profile: alpha"* ]]
    [[ "$output" == *"Human review required: yes"* ]]
    [[ "$output" == *"Configuration changes performed: no"* ]]
    [[ "$output" == *"Pareto frontier: alpha"* ]]
    [[ "$output" == *"Metrics: contract_failures=0"* ]]
    [[ "$output" == *"Telemetry: duration_ms=1000 [complete], agent_count=1 [complete]"* ]]
    [[ "$output" == *"Evidence: .hotl/reports/identity-valid.md"* ]]
}

@test "evaluation text renders evidence gaps without inventing a candidate" {
    make_profile_set "$TEST_TMP/a" alpha 1000 0.02
    load_comparison_files

    run bash "$EVALUATION_REPORT" --format text "${FILES[@]}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Recommendation: collect_more_evidence"* ]]
    [[ "$output" == *"Candidate profile: none"* ]]
    [[ "$output" == *"Reasons: minimum_profiles_not_met"* ]]
    [[ "$output" == *"Pareto frontier: none"* ]]
}
