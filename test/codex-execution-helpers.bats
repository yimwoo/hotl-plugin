#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    FINALIZE_CODEX="$REPO_ROOT/scripts/finalize-codex-summary.sh"
    SHOW_CODEX_CURRENT="$REPO_ROOT/scripts/show-codex-current-step.sh"
    FIXTURES="$REPO_ROOT/test/fixtures"
    TEST_DIR=$(mktemp -d)
    cp -r "$FIXTURES" "$TEST_DIR/"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "finalize-codex-summary renders a complete compact summary" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    [ -n "$RUN_ID" ]

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    "$HOTL_RT" gate 3 approved --mode human

    run "$FINALIZE_CODEX"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Execution Summary"* ]]
    [[ "$output" == *"Step 1: Run a passing shell verify - Done (1 attempt)"* ]]
    [[ "$output" == *"Step 2: Loop until condition met - Done (1 attempt)"* ]]
    [[ "$output" == *"Step 3: Human gate step - Approved (-)"* ]]
}

@test "show-codex-current-step prints active step metadata" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    [ -n "$RUN_ID" ]

    "$HOTL_RT" step 1 start

    run "$SHOW_CODEX_CURRENT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current step: 1/3"* ]]
    [[ "$output" == *"Name: Run a passing shell verify"* ]]
    [[ "$output" == *"Status: in_progress"* ]]
    [[ "$output" == *"Attempts: 1"* ]]
}

@test "show-codex-current-step falls back to current_step when no step is in progress" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    [ -n "$RUN_ID" ]

    run "$SHOW_CODEX_CURRENT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current step: 1/3"* ]]
    [[ "$output" == *"Name: Run a passing shell verify"* ]]
    [[ "$output" == *"Status: pending"* ]]
    [[ "$output" == *"Attempts: 0"* ]]
}

@test "Codex helpers require an explicit run id when multiple runs exist" {
    RUN_ID_A=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    RUN_ID_B=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    [ -n "$RUN_ID_A" ]
    [ -n "$RUN_ID_B" ]

    run "$SHOW_CODEX_CURRENT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Multiple HOTL runs found"* ]]

    "$HOTL_RT" step 1 start --run-id "$RUN_ID_A"
    run "$SHOW_CODEX_CURRENT" "$RUN_ID_A"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current step: 1/3"* ]]
}

@test "finalize-codex-summary can target a specific run id" {
    RUN_ID_A=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    RUN_ID_B=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)

    "$HOTL_RT" step 1 start --run-id "$RUN_ID_A"
    "$HOTL_RT" step 1 verify --run-id "$RUN_ID_A"
    "$HOTL_RT" step 2 start --run-id "$RUN_ID_A"
    "$HOTL_RT" step 2 verify --run-id "$RUN_ID_A"
    "$HOTL_RT" step 3 start --run-id "$RUN_ID_A"
    "$HOTL_RT" step 3 verify --run-id "$RUN_ID_A"
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID_A"

    run "$FINALIZE_CODEX" "$RUN_ID_A"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Step 1: Run a passing shell verify - Done (1 attempt)"* ]]

    [ "$(jq -r '.status' ".hotl/state/${RUN_ID_A}.json")" = "completed" ]
    [ "$(jq -r '.status' ".hotl/state/${RUN_ID_B}.json")" = "running" ]
}

@test "show-codex-current-step errors when there is no HOTL run" {
    rm -rf .hotl

    run "$SHOW_CODEX_CURRENT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No active HOTL run found"* ]]
}
