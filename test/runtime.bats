#!/usr/bin/env bats

# HOTL Runtime Unit Tests
# Tests each hotl-rt subcommand against fixture workflows.
# Uses field-level assertions with jq — no golden file diffs.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    FIXTURES="$REPO_ROOT/test/fixtures"
    TEST_DIR=$(mktemp -d)
    TEST_ROOT="$(cd "$TEST_DIR" && pwd -P)"
    cp -r "$FIXTURES" "$TEST_DIR/"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

complete_steps_through() {
    local run_id="$1"
    local final_step="$2"
    local step
    for ((step = 1; step <= final_step; step++)); do
        "$HOTL_RT" step "$step" start --run-id "$run_id" >/dev/null
        "$HOTL_RT" step "$step" verify --run-id "$run_id" >/dev/null
    done
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
    [ "$(jq -r '.workflow_slug' "$STATE")" = "runtime-sample" ]
    [ "$(jq -r '.executor_mode' "$STATE")" = "loop" ]
    [ "$(jq -r '.repo_root' "$STATE")" = "$TEST_ROOT" ]
    [ "$(jq -r '.execution_root' "$STATE")" = "$TEST_ROOT" ]
    [ "$(jq -r '.worktree_path' "$STATE")" = "null" ]
    [ "$(jq -r '.last_update' "$STATE")" = "$(jq -r '.started_at' "$STATE")" ]

    # Timestamps are ISO 8601 format
    jq -r '.started_at' "$STATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'
}

@test "init accepts execution metadata overrides" {
    custom_execution_root="$TEST_ROOT"
    custom_source="$TEST_ROOT/source/hotl-workflow-runtime-sample.md"
    custom_worktree="$TEST_ROOT/custom-worktree"
    mkdir -p "$TEST_ROOT/source"
    cp fixtures/hotl-workflow-runtime-sample.md "$custom_source"

    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md \
        --executor-mode subagent \
        --repo-root "$TEST_ROOT/repo-root" \
        --execution-root "$custom_execution_root" \
        --source-workflow-path "$custom_source" \
        --worktree-path "$custom_worktree" \
        --branch "feat/runtime-override")
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.executor_mode' "$STATE")" = "subagent" ]
    [ "$(jq -r '.repo_root' "$STATE")" = "$TEST_ROOT/repo-root" ]
    [ "$(jq -r '.execution_root' "$STATE")" = "$custom_execution_root" ]
    [ "$(jq -r '.source_workflow_path' "$STATE")" = "$custom_source" ]
    [ "$(jq -r '.worktree_path' "$STATE")" = "$custom_worktree" ]
    [ "$(jq -r '.branch' "$STATE")" = "feat/runtime-override" ]
    [ "$(jq -r '.report_path' "$STATE")" = "$custom_execution_root/.hotl/reports/${RUN_ID}.md" ]
}

@test "init creates report with metadata header" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    REPORT=".hotl/reports/${RUN_ID}.md"

    [ -f "$REPORT" ]
    grep -q "Execution Report: ${RUN_ID}" "$REPORT"
    grep -Fq "**Workflow:**" "$REPORT"
    grep -Fq "**Source Workflow:**" "$REPORT"
    grep -Fq "**Intent:**" "$REPORT"
    grep -Fq "**Execution Root:**" "$REPORT"
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

@test "step commands require explicit run id when multiple runs exist" {
    RUN_ID_A=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    RUN_ID_B=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)

    run "$HOTL_RT" step 1 start
    [ "$status" -ne 0 ]
    [[ "$output" == *"Multiple HOTL runs found"* ]]

    "$HOTL_RT" step 1 start --run-id "$RUN_ID_A"
    [ "$(jq -r '.steps[0].status' ".hotl/state/${RUN_ID_A}.json")" = "in_progress" ]
    [ "$(jq -r '.steps[0].status' ".hotl/state/${RUN_ID_B}.json")" = "pending" ]
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

@test "step verify persists commands that exit explicitly" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    jq '.steps[0].verify.command = "exit 0"' "$STATE" > "$STATE.tmp"
    mv "$STATE.tmp" "$STATE"
    "$HOTL_RT" step 1 start

    run "$HOTL_RT" step 1 verify

    [ "$status" -eq 0 ]
    [ "$output" = "pass" ]
    [ "$(jq -r '.steps[0].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "true" ]
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
    REPORT=".hotl/reports/${RUN_ID}.md"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "human review required: Confirm the output looks correct" ]
    [ "$(jq -r '.status' "$STATE")" = "paused" ]
    grep -Fq '**Status:** paused' "$REPORT"
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

    complete_steps_through "$RUN_ID" 2
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

    complete_steps_through "$RUN_ID" 3
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

    complete_steps_through "$RUN_ID" 1
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

    complete_steps_through "$RUN_ID" 2
    "$HOTL_RT" step 3 start
    run "$HOTL_RT" step 3 verify
    [ "$status" -ne 0 ]
    [ "$(jq -r '.steps[2].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[2].block_reason' "$STATE")" = "artifact assert kind matches-glob requires value" ]
}

@test "step verify blocks artifact matches-glob when value includes a path segment" {
    cat > invalid-glob-workflow.md <<'EOF'
---
intent: Invalid artifact glob
success_criteria: Runtime blocks invalid glob shape
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Invalid glob**
action: Confirm invalid glob is rejected
loop: false
verify:
  type: artifact
  path: .
  assert:
    kind: matches-glob
    value: "artifacts/*"
EOF

    RUN_ID=$("$HOTL_RT" init invalid-glob-workflow.md)
    STATE=".hotl/state/${RUN_ID}.json"
    mkdir -p artifacts
    echo "render ok" > artifacts/output.txt

    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "artifact assert kind matches-glob expects a filename glob; put the directory in path" ]
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

@test "step block accepts explicit run id when multiple runs exist" {
    RUN_ID_A=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    RUN_ID_B=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)

    run "$HOTL_RT" step 1 block --reason "targeted block"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Multiple HOTL runs found"* ]]

    "$HOTL_RT" step 1 block --reason "targeted block" --run-id "$RUN_ID_A"

    [ "$(jq -r '.status' ".hotl/state/${RUN_ID_A}.json")" = "blocked" ]
    [ "$(jq -r '.steps[0].status' ".hotl/state/${RUN_ID_A}.json")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' ".hotl/state/${RUN_ID_A}.json")" = "targeted block" ]
    [ "$(jq -r '.status' ".hotl/state/${RUN_ID_B}.json")" = "running" ]
    [ "$(jq -r '.steps[0].status' ".hotl/state/${RUN_ID_B}.json")" = "pending" ]
}

# ── gate ────────────────────────────────────────────────────────────────────

@test "gate records approved decision" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 1
    "$HOTL_RT" gate 1 approved
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].gate_result' "$STATE")" = "approved" ]
}

@test "gate records auto approval mode" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 1
    "$HOTL_RT" gate 1 approved --mode auto
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.steps[0].gate_mode' "$STATE")" = "auto" ]
}

@test "gate records rejected decision" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 1
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

@test "gate rejects invalid or unfinished step targets" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)

    run "$HOTL_RT" gate 0 approved --mode human --run-id "$RUN_ID"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid step number"* ]]

    run "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID"
    [ "$status" -ne 0 ]
    [[ "$output" == *"must be done before its gate"* ]]
    [ "$(jq -r '.steps[2].gate_result' ".hotl/state/${RUN_ID}.json")" = "null" ]
}

@test "gate updates report" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 1
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
    [ "$(jq -r '.status' "$STATE")" = "running" ]
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
    [ "$(jq -r '.status' "$STATE")" = "blocked" ]
}

# ── finalize ────────────────────────────────────────────────────────────────

@test "finalize produces valid JSON summary" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 3
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    SUMMARY=$("$HOTL_RT" finalize --json)

    echo "$SUMMARY" | jq -r '.run_id' | grep -q "$RUN_ID"
    echo "$SUMMARY" | jq -r '.status' | grep -qE '^(ready_to_finish|blocked)$'
    echo "$SUMMARY" | jq -r '.total_steps' | grep -q '3'
}

@test "finalize sets ready_to_finish until disposition is recorded" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "ready_to_finish" ]
    [ "$(echo "$SUMMARY" | jq -r '.completed_steps')" = "3" ]
    [ "$(jq -r '.completed_at' ".hotl/state/${RUN_ID}.json")" = "null" ]
}

@test "finalize sets blocked status when steps failed" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 block --reason "test"
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "blocked" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "1" ]
}

@test "finalize updates report status" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 3
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --json > /dev/null
    REPORT=".hotl/reports/${RUN_ID}.md"

    grep -Fq '**Status:** ready_to_finish' "$REPORT" || grep -Fq '**Status:** blocked' "$REPORT"
}

@test "finalize completes after approved human-review step" {
    RUN_ID=$("$HOTL_RT" init fixtures/human-review-runtime-sample.md)
    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    "$HOTL_RT" gate 1 approved
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "ready_to_finish" ]
    [ "$(echo "$SUMMARY" | jq -r '.completed_steps')" = "1" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "0" ]
}

@test "finish records a kept outcome in state, summary, and report" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --json > /dev/null

    SUMMARY=$("$HOTL_RT" finish kept --run-id "$RUN_ID" --branch-action kept --worktree-action kept --notes "Keep for follow-up")
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    [ "$(jq -r '.finish.disposition' "$STATE")" = "kept" ]
    [ "$(jq -r '.finish.branch_action' "$STATE")" = "kept" ]
    [ "$(jq -r '.finish.worktree_action' "$STATE")" = "kept" ]
    [ "$(jq -r '.finish.notes' "$STATE")" = "Keep for follow-up" ]
    [ "$(echo "$SUMMARY" | jq -r '.finish.disposition')" = "kept" ]
    grep -q '## Finish Outcome' "$REPORT"
    grep -Fq '**Disposition:** kept' "$REPORT"
    grep -Fq '**Branch Action:** kept' "$REPORT"
}

@test "finalize is idempotent after finish and cannot regress completed state" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 3
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --json --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finish kept --run-id "$RUN_ID" >/dev/null

    SUMMARY=$("$HOTL_RT" finalize --json --run-id "$RUN_ID")
    STATE=".hotl/state/${RUN_ID}.json"

    [ "$(jq -r '.status' <<< "$SUMMARY")" = "completed" ]
    [ "$(jq -r '.status' "$STATE")" = "completed" ]
    [ "$(jq -r '.finish.disposition' "$STATE")" = "kept" ]
}

@test "finish rejects published disposition for blocked runs" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 block --reason "stop"
    "$HOTL_RT" finalize --json > /dev/null

    run "$HOTL_RT" finish published --run-id "$RUN_ID" --remote origin
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a completed run"* ]]
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
    complete_steps_through "$RUN_ID" 3
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --json > /dev/null
    "$HOTL_RT" finish kept --run-id "$RUN_ID" >/dev/null
    SUMMARY=$("$HOTL_RT" summary "$RUN_ID" --json)

    echo "$SUMMARY" | jq -r '.status' | grep -qE '^(completed|blocked)$'
}

@test "summary fails for unknown run-id" {
    mkdir -p .hotl/state
    run "$HOTL_RT" summary "nonexistent-run" --json
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

# ── long-running execution invariants ──────────────────────────────────────

@test "run ids remain unique when initializations share one timestamp" {
    pids=()
    for index in 1 2 3; do
        "$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md > "run-$index.out" 2> "run-$index.err" &
        pids+=("$!")
    done

    failures=0
    for pid in "${pids[@]}"; do
        wait "$pid" || failures=$((failures + 1))
    done

    [ "$failures" -eq 0 ]
    [ "$(sort -u run-*.out | wc -l | tr -d ' ')" -eq 3 ]
    [ "$(find .hotl/state -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')" -eq 3 ]
}

@test "explicit run ids reject path traversal" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    cp ".hotl/state/${RUN_ID}.json" victim.json

    run "$HOTL_RT" summary "../../victim" --json

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid run id"* ]]
}

@test "state revision increases after every successful mutation" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    initial_revision=$(jq -r '.revision' "$STATE")

    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    started_revision=$(jq -r '.revision' "$STATE")
    "$HOTL_RT" step 1 verify --run-id "$RUN_ID" >/dev/null
    verified_revision=$(jq -r '.revision' "$STATE")

    [[ "$initial_revision" =~ ^[0-9]+$ ]]
    [ "$started_revision" -gt "$initial_revision" ]
    [ "$verified_revision" -gt "$started_revision" ]
}

@test "step start rejects out-of-order execution" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)

    run "$HOTL_RT" step 2 start --run-id "$RUN_ID"

    [ "$status" -ne 0 ]
    [[ "$output" == *"step 1"*"must be done"* ]]
    [ "$(jq -r '.steps[1].status' ".hotl/state/${RUN_ID}.json")" = "pending" ]
}

@test "step retry rejects attempts at the declared max iterations" {
    cat > bounded-retry-workflow.md <<'EOF'
---
intent: Bound runtime retries
success_criteria: Retry stops at the declared maximum
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Fail twice**
action: Exercise retry bounds
loop: until pass
max_iterations: 2
verify: false
EOF
    RUN_ID=$("$HOTL_RT" init bounded-retry-workflow.md)

    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    run "$HOTL_RT" step 1 verify --run-id "$RUN_ID"
    [ "$status" -ne 0 ]
    "$HOTL_RT" step 1 retry --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    run "$HOTL_RT" step 1 verify --run-id "$RUN_ID"
    [ "$status" -ne 0 ]

    run "$HOTL_RT" step 1 retry --run-id "$RUN_ID"

    [ "$status" -ne 0 ]
    [[ "$output" == *"maximum iterations (2)"* ]]
    [ "$(jq -r '.steps[0].attempts' ".hotl/state/${RUN_ID}.json")" -eq 2 ]
}

@test "finalize rejects a run with unfinished steps" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)

    run "$HOTL_RT" finalize --json --run-id "$RUN_ID"

    [ "$status" -ne 0 ]
    [[ "$output" == *"unfinished steps"* ]]
    [ "$(jq -r '.status' ".hotl/state/${RUN_ID}.json")" != "completed" ]
}

@test "a mutation repairs a missing report from authoritative state" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    REPORT=".hotl/reports/${RUN_ID}.md"
    rm "$REPORT"

    run "$HOTL_RT" step 1 start --run-id "$RUN_ID"

    [ "$status" -eq 0 ]
    grep -Fq "# Execution Report: ${RUN_ID}" "$REPORT"
    grep -Fq '→ Running' "$REPORT"
}

@test "report repair reconstructs completed status and finish disposition" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 3
    "$HOTL_RT" gate 3 approved --mode human --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --json --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finish kept --run-id "$RUN_ID" >/dev/null
    REPORT=".hotl/reports/${RUN_ID}.md"
    rm "$REPORT"

    "$HOTL_RT" budget check --run-id "$RUN_ID" >/dev/null

    grep -Fq '**Status:** completed' "$REPORT"
    grep -Fq '## Finish Outcome' "$REPORT"
    grep -Fq '**Disposition:** kept' "$REPORT"
}

@test "finalize rejects missing configured gate evidence" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    complete_steps_through "$RUN_ID" 3

    run "$HOTL_RT" finalize --json --run-id "$RUN_ID"

    [ "$status" -ne 0 ]
    [[ "$output" == *"gate evidence"* ]]
    [ "$(jq -r '.status' ".hotl/state/${RUN_ID}.json")" = "running" ]
}

@test "require-owner initialization blocks mutation until controller claim" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md --require-owner)

    run "$HOTL_RT" step 1 start --run-id "$RUN_ID"
    [ "$status" -ne 0 ]
    [[ "$output" == *"claim controller ownership"* ]]

    claim=$("$HOTL_RT" owner claim --owner controller-a --run-id "$RUN_ID")
    HOTL_OWNER_TOKEN=$(jq -r '.token' <<< "$claim") "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    [ "$(jq -r '.steps[0].status' ".hotl/state/${RUN_ID}.json")" = "in_progress" ]
}
