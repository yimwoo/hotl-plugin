#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    DRIVER="$REPO_ROOT/runtime/drivers/generic.sh"
    TEST_DIR=$(mktemp -d)
    cp -R "$REPO_ROOT/test/fixtures" "$TEST_DIR/fixtures"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# bats test_tags=normalize
@test "normalize emits deterministic portable workflow JSON" {
    first=$("$HOTL_RT" normalize fixtures/hotl-workflow-runtime-sample.md --json)
    second=$("$HOTL_RT" normalize fixtures/hotl-workflow-runtime-sample.md --json)
    [ "$first" = "$second" ]
    [ "$(jq -r '.schema' <<< "$first")" = "hotl.workflow/v1" ]
    [ "$(jq -r '.workflow.total_steps' <<< "$first")" = "3" ]
    [ "$(jq -r '.workflow.steps[1].loop' <<< "$first")" = "until condition met" ]
    [ "$(jq -r '.workflow.steps[2].gate' <<< "$first")" = "human" ]
    [ "$(jq -r '.workflow.steps[0].verify.passed // "absent"' <<< "$first")" = "absent" ]
}

# bats test_tags=normalize
@test "normalize is read-only and supports legacy step headings" {
    before=$(shasum fixtures/hotl-workflow-progress-sample.md)
    run "$HOTL_RT" normalize fixtures/hotl-workflow-progress-sample.md --json
    [ "$status" -eq 0 ]
    [ ! -e .hotl ]
    [ "$before" = "$(shasum fixtures/hotl-workflow-progress-sample.md)" ]
    [ "$(jq -r '.workflow.total_steps' <<< "$output")" -gt 0 ]
}

# bats test_tags=normalize
@test "normalize rejects a workflow without steps" {
    printf '%s\n' '---' 'intent: empty' '---' '# Empty' > empty.md
    run "$HOTL_RT" normalize empty.md --json
    [ "$status" -ne 0 ]
    [[ "$output" == *"No steps found"* ]]
    [ ! -e .hotl ]
}

# bats test_tags=driver
@test "generic driver describes protocol and returns ready preflight" {
    description=$("$DRIVER" describe)
    [ "$(jq -r '.protocol' <<< "$description")" = "hotl.driver/v1" ]
    [ "$(jq -r '.host' <<< "$description")" = "fallback" ]
    preflight=$("$DRIVER" preflight fixtures/hotl-workflow-runtime-sample.md)
    [ "$(jq -r '.ready' <<< "$preflight")" = "true" ]
    [ "$(jq -r '.workflow.schema' <<< "$preflight")" = "hotl.workflow/v1" ]
    [ ! -e .hotl ]
}

# bats test_tags=driver
@test "generic driver delegates launch and status to hotl-rt" {
    run_id=$("$DRIVER" launch fixtures/hotl-workflow-runtime-sample.md)
    status_json=$("$DRIVER" status "$run_id")
    [ "$(jq -r '.run_id' <<< "$status_json")" = "$run_id" ]
    [ "$(jq -r '.executor_mode' <<< "$status_json")" = "generic" ]
    [ -f ".hotl/state/$run_id.json" ]
}

# bats test_tags=receipt
@test "receipt is insufficient before completion and finish" {
    run_id=$("$DRIVER" launch fixtures/hotl-workflow-runtime-sample.md)
    receipt=$("$DRIVER" receipt "$run_id")
    [ "$(jq -r '.schema' <<< "$receipt")" = "hotl.receipt/v1" ]
    [ "$(jq -r '.sufficiency.sufficient' <<< "$receipt")" = "false" ]
    jq -e '.sufficiency.reasons | index("run_not_completed")' <<< "$receipt"
    jq -e '.sufficiency.reasons | index("finish_disposition_missing")' <<< "$receipt"
    [ "$(jq -r '.redaction.stdout_included' <<< "$receipt")" = "false" ]
}

# bats test_tags=receipt
@test "receipt becomes sufficient only after verification gates finalize and finish" {
    run_id=$("$DRIVER" launch fixtures/hotl-workflow-runtime-sample.md)
    "$DRIVER" step 1 start --run-id "$run_id"
    "$DRIVER" step 1 verify --run-id "$run_id"
    "$DRIVER" step 2 start --run-id "$run_id"
    "$DRIVER" step 2 verify --run-id "$run_id"
    "$DRIVER" step 3 start --run-id "$run_id"
    "$DRIVER" step 3 verify --run-id "$run_id"
    "$DRIVER" gate 3 approved --mode human --run-id "$run_id"
    "$DRIVER" finalize --run-id "$run_id" >/dev/null

    receipt=$("$DRIVER" receipt "$run_id")
    [ "$(jq -r '.sufficiency.sufficient' <<< "$receipt")" = "false" ]
    [ "$(jq -r '.sufficiency.reasons[0]' <<< "$receipt")" = "finish_disposition_missing" ]

    "$DRIVER" finish kept --run-id "$run_id" >/dev/null
    receipt=$("$DRIVER" receipt "$run_id")
    [ "$(jq -r '.sufficiency.sufficient' <<< "$receipt")" = "true" ]
    [ "$(jq -r '.finish.disposition' <<< "$receipt")" = "kept" ]
    [ "$(jq -r '[.evidence[] | select(.verification.required and .verification.passed != true)] | length' <<< "$receipt")" = "0" ]
    [ "$(jq -r '[.evidence[] | select(.gate.required and .gate.result != "approved")] | length' <<< "$receipt")" = "0" ]
}

# bats test_tags=receipt
@test "receipt cannot infer success from a completed status without evidence" {
    run_id=$("$DRIVER" launch fixtures/hotl-workflow-runtime-sample.md)
    state=".hotl/state/$run_id.json"
    jq '.status="completed" | .completed_at=.last_update | .finish.disposition="kept"' "$state" > "$state.tmp"
    mv "$state.tmp" "$state"
    receipt=$("$DRIVER" receipt "$run_id")
    [ "$(jq -r '.sufficiency.sufficient' <<< "$receipt")" = "false" ]
    jq -e '.sufficiency.reasons | index("steps_not_done")' <<< "$receipt"
    jq -e '.sufficiency.reasons | index("verification_missing_or_failed")' <<< "$receipt"
    jq -e '.sufficiency.reasons | index("gate_evidence_missing_or_rejected")' <<< "$receipt"
}
