#!/usr/bin/env bats

# HOTL Runtime Unit Tests
# Tests each hotl-rt subcommand against fixture workflows.
# Uses field-level assertions with jq — no golden file diffs.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    FIXTURES="$REPO_ROOT/test/fixtures"
    TEST_DIR=$(mktemp -d)
    cp -r "$FIXTURES" "$TEST_DIR/"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── init ────────────────────────────────────────────────────────────────────

@test "init creates state JSON with correct step count" {
    run "$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    RUN_ID="$output"
    STEP_COUNT=$(jq '.steps | length' ".hotl/state/${RUN_ID}.json")
    [ "$STEP_COUNT" -eq 3 ]
}

@test "init creates state JSON with correct fields" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.status' "$STATE")" = "running" ]
    [ "$(jq -r '.current_step' "$STATE")" = "1" ]
    [ "$(jq -r '.total_steps' "$STATE")" = "3" ]
    [ "$(jq -r '.risk_level' "$STATE")" = "low" ]
    [ "$(jq -r '.auto_approve' "$STATE")" = "true" ]

    # Timestamps are ISO 8601 format
    jq -r '.started_at' "$STATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'
}

@test "init creates report with metadata header" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    REPORT=".hotl/reports/${RUN_ID}.md"

    [ -f "$REPORT" ]
    grep -q "Execution Report: ${RUN_ID}" "$REPORT"
    grep -Fq "**Workflow:**" "$REPORT"
    grep -Fq "**Intent:**" "$REPORT"
    grep -Fq "**Status:** running" "$REPORT"
    grep -q "## Event Log" "$REPORT"
}

@test "init creates report with all steps as pending" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    REPORT=".hotl/reports/${RUN_ID}.md"

    PENDING_COUNT=$(grep -c '· Pending' "$REPORT")
    [ "$PENDING_COUNT" -eq 3 ]
}

@test "init parses all steps pending with zero attempts" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    for i in 0 1 2; do
        [ "$(jq -r ".steps[$i].status" "$STATE")" = "pending" ]
        [ "$(jq -r ".steps[$i].attempts" "$STATE")" = "0" ]
    done
}

@test "init parses verify command from scalar form" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].verify.command' "$STATE")" = 'echo "hello from verify"' ]
    [ "$(jq -r '.steps[0].verify.type' "$STATE")" = "shell" ]
}

@test "init parses step with gate field" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[2].gate' "$STATE")" = "human" ]
    [ "$(jq -r '.steps[0].gate' "$STATE")" = "null" ]
}

@test "init parses retry workflow with max_iterations" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[1].max_iterations' "$STATE")" = "3" ]
    [ "$(jq -r '.steps[2].max_iterations' "$STATE")" = "5" ]
}

@test "init fails on missing workflow file" {
    run "$HOTL_RT" init nonexistent.md
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "init prints run_id to stdout" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    # Run ID format: <slug>-<YYYYMMDDTHHMMSSZ>
    echo "$RUN_ID" | grep -qE '^runtime-sample-[0-9]{8}T[0-9]{6}Z$'
}

# ── step start ──────────────────────────────────────────────────────────────

@test "step start sets status to in_progress" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "in_progress" ]
}

@test "step start increments attempts" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].attempts' "$STATE")" = "1" ]
}

@test "step start sets started_at timestamp" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    STATE=".hotl/state/${RUN_ID}.json"

    jq -r '.steps[0].started_at' "$STATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'
}

@test "step start updates report to Running" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -q '→ Running' "$REPORT"
}

@test "step start appends event to report log" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -q '→ Step 1:' "$REPORT"
}

# ── step verify ─────────────────────────────────────────────────────────────

@test "step verify transitions to done on passing command" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "true" ]
}

@test "step verify captures stdout on pass" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    STATE=".hotl/state/${RUN_ID}.json"

    jq -r '.steps[0].verify.stdout' "$STATE" | grep -q 'hello from verify'
}

@test "step verify transitions to failed on failing command" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "failed" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "false" ]
}

@test "step verify sets completed_at on pass" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    STATE=".hotl/state/${RUN_ID}.json"

    jq -r '.steps[0].completed_at' "$STATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'
}

@test "step verify blocks on unsupported type" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-unsupported-verify.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    jq -r '.steps[0].block_reason' "$STATE" | grep -q 'unsupported verify type'
}

@test "step verify blocks with human-review prompt" {
    RUN_ID=$("$HOTL_RT" init fixtures/human-review-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "human review required: Confirm the output looks correct" ]
}

@test "step verify updates report to Done on pass" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -q '✓ Done' "$REPORT"
}

@test "step verify passes artifact exists check" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-artifact-verify-sample.md)
    mkdir -p artifacts/reports
    echo "render ok" > artifacts/output.txt
    echo "# report" > artifacts/reports/summary.md

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "true" ]
}

@test "step verify passes artifact matches-glob check" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-artifact-verify-sample.md)
    mkdir -p artifacts/reports
    echo "render ok" > artifacts/output.txt
    echo "# report" > artifacts/reports/summary.md

    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[2].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[2].verify.passed' "$STATE")" = "true" ]
}

@test "step verify runs all checks in list form" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-artifact-verify-sample.md)
    mkdir -p artifacts/reports
    echo "render ok" > artifacts/output.txt
    echo "# report" > artifacts/reports/summary.md

    "$HOTL_RT" step 4 start
    "$HOTL_RT" step 4 verify
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[3].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[3].verify.passed' "$STATE")" = "true" ]
}

@test "init preserves multi-check verify items when type is not the first key" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-verify-order-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq '.steps[1].verify.checks | length' "$STATE")" = "2" ]
    [ "$(jq -r '.steps[1].verify.checks[0].type' "$STATE")" = "shell" ]
    [ "$(jq -r '.steps[1].verify.checks[1].type' "$STATE")" = "artifact" ]
}

@test "step verify blocks artifact contains without assert value" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-artifact-verify-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    mkdir -p artifacts/reports
    echo "render ok" > artifacts/output.txt
    echo "# report" > artifacts/reports/summary.md

    jq '.steps[1].verify.assert.value = null' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"

    "$HOTL_RT" step 2 start
    run "$HOTL_RT" step 2 verify
    [ "$status" -ne 0 ]
    [ "$(jq -r '.steps[1].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[1].block_reason' "$STATE")" = "artifact assert kind contains requires value" ]
}

@test "step verify blocks artifact matches-glob without assert value" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-artifact-verify-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    mkdir -p artifacts/reports
    echo "render ok" > artifacts/output.txt
    echo "# report" > artifacts/reports/summary.md

    jq '.steps[2].verify.assert.value = null' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"

    "$HOTL_RT" step 3 start
    run "$HOTL_RT" step 3 verify
    [ "$status" -ne 0 ]
    [ "$(jq -r '.steps[2].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[2].block_reason' "$STATE")" = "artifact assert kind matches-glob requires value" ]
}

# ── step retry ──────────────────────────────────────────────────────────────

@test "step retry resets failed step to in_progress" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify  # will fail — no pytest tests
    "$HOTL_RT" step 1 retry
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "in_progress" ]
}

@test "step retry clears previous verify results" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    "$HOTL_RT" step 1 retry
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "null" ]
    [ "$(jq -r '.steps[0].verify.stdout' "$STATE")" = "null" ]
}

@test "step retry appends retrying event to report" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    "$HOTL_RT" step 1 retry
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -q '↻' "$REPORT"
}

@test "step retry fails on non-failed step" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 retry
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

# ── step block ──────────────────────────────────────────────────────────────

@test "step block records reason" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 block --reason "test block reason"
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "test block reason" ]
}

@test "step block updates report" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 block --reason "test block reason"
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -q '✗ Blocked' "$REPORT"
    grep -q 'test block reason' "$REPORT"
}

@test "step block requires --reason" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 block
    [ "$status" -ne 0 ]
    [[ "$output" == *"--reason is required"* ]]
}

# ── gate ────────────────────────────────────────────────────────────────────

@test "gate records approved decision" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" gate 1 approved
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].gate_result' "$STATE")" = "approved" ]
}

@test "gate records auto approval mode" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" gate 1 approved --mode auto
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].gate_mode' "$STATE")" = "auto" ]
}

@test "gate records rejected decision" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" gate 1 rejected
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].gate_result' "$STATE")" = "rejected" ]
}

@test "gate rejects invalid decision" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    run "$HOTL_RT" gate 1 maybe
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "gate updates report" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" gate 1 approved
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -q 'Gate Step 1: approved' "$REPORT"
}

@test "gate approved clears blocked human-review step" {
    RUN_ID=$("$HOTL_RT" init fixtures/human-review-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]

    "$HOTL_RT" gate 1 approved
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "true" ]
    [ "$(jq -r '.steps[0].gate_result' "$STATE")" = "approved" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "null" ]
}

@test "gate rejected keeps human-review step blocked" {
    RUN_ID=$("$HOTL_RT" init fixtures/human-review-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]

    "$HOTL_RT" gate 1 rejected
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "false" ]
    [ "$(jq -r '.steps[0].gate_result' "$STATE")" = "rejected" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "human review rejected" ]
}

# ── finalize ────────────────────────────────────────────────────────────────

@test "finalize produces valid JSON summary" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    SUMMARY=$("$HOTL_RT" finalize --json)

    echo "$SUMMARY" | jq -r '.run_id' | grep -q "$RUN_ID"
    echo "$SUMMARY" | jq -r '.status' | grep -qE '^(completed|failed)$'
    echo "$SUMMARY" | jq -r '.total_steps' | grep -q '3'
}

@test "finalize sets completed status when all done" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "completed" ]
    [ "$(echo "$SUMMARY" | jq -r '.completed_steps')" = "3" ]
}

@test "finalize sets failed status when steps failed" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 block --reason "test"
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "failed" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "1" ]
}

@test "finalize updates report status" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" finalize --json > /dev/null
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -Fq '**Status:** completed' "$REPORT" || grep -Fq '**Status:** failed' "$REPORT"
}

@test "finalize completes after approved human-review step" {
    RUN_ID=$("$HOTL_RT" init fixtures/human-review-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    "$HOTL_RT" gate 1 approved
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "completed" ]
    [ "$(echo "$SUMMARY" | jq -r '.completed_steps')" = "1" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "0" ]
}

# ── summary ─────────────────────────────────────────────────────────────────

@test "summary returns current state for in-progress run" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    SUMMARY=$("$HOTL_RT" summary "$RUN_ID" --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "running" ]
    [ "$(echo "$SUMMARY" | jq -r '.run_id')" = "$RUN_ID" ]
}

@test "summary returns completed state" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" finalize --json > /dev/null
    SUMMARY=$("$HOTL_RT" summary "$RUN_ID" --json)

    echo "$SUMMARY" | jq -r '.status' | grep -qE '^(completed|failed)$'
}

@test "summary fails for unknown run-id" {
    mkdir -p .hotl/state
    run "$HOTL_RT" summary "nonexistent-run" --json
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}
