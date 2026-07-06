#!/usr/bin/env bats

# HOTL Runtime Integration Tests
# Simulates full agent call sequences against the runtime.
# These are the agent conformance spec — if an agent follows this sequence,
# the artifacts will be correct.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    FINALIZE_CODEX="$REPO_ROOT/scripts/finalize-codex-summary.sh"
    FIXTURES="$REPO_ROOT/test/fixtures"
    TEST_DIR=$(mktemp -d)
    cp -r "$FIXTURES" "$TEST_DIR/"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Happy path: init → steps → finalize → finish ────────────────────────────

@test "happy path: all steps done, run completed" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    # Step 1: start → verify (passes: echo command)
    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    [ "$(jq -r '.steps[0].status' "$STATE")" = "done" ]

    # Step 2: start → verify (passes: echo command)
    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    [ "$(jq -r '.steps[1].status' "$STATE")" = "done" ]

    # Step 3: start → verify (no verify command — auto-pass)
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    [ "$(jq -r '.steps[2].status' "$STATE")" = "done" ]

    "$HOTL_RT" gate 3 approved --mode human >/dev/null

    # Finalize establishes readiness; finish disposition establishes completion.
    SUMMARY=$("$HOTL_RT" finalize --json)
    [ "$(echo "$SUMMARY" | jq -r '.status')" = "ready_to_finish" ]
    [ "$(echo "$SUMMARY" | jq -r '.completed_steps')" = "3" ]
    [ "$(echo "$SUMMARY" | jq -r '.failed_steps')" = "0" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "0" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].status')" = "done" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].attempts')" = "1" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[2].attempts')" = "1" ]

    SUMMARY=$("$HOTL_RT" finish kept --run-id "$RUN_ID")
    [ "$(echo "$SUMMARY" | jq -r '.status')" = "completed" ]

    # Report should be completed only after disposition.
    grep -Fq '**Status:** completed' "$REPORT"
    grep -q '✓ Done' "$REPORT"
    grep -q 'Run finalized: ready_to_finish' "$REPORT"
}

@test "demo simulation flow renders report and compact Codex summary" {
    RUN_ID=$("$HOTL_RT" init fixtures/demo-simulation-workflow.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    "$HOTL_RT" step 1 start
    mkdir -p .hotl-demo/simulation
    "$HOTL_RT" step 1 verify

    "$HOTL_RT" step 2 start
    printf '%s\n' '# Demo Note' '' 'This file was created by a throwaway HOTL loop-execution simulation.' > .hotl-demo/simulation/demo-note.md
    "$HOTL_RT" step 2 verify

    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    "$HOTL_RT" gate 3 approved --mode auto

    run "$FINALIZE_CODEX"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Execution Summary"* ]]
    [[ "$output" == *"Step 1: Create demo workspace - Done (1 attempt)"* ]]
    [[ "$output" == *"Step 2: Write demo note - Done (1 attempt)"* ]]
    [[ "$output" == *"Step 3: Demo review gate - Auto-approved (-)"* ]]

    [ "$(jq -r '.status' "$STATE")" = "ready_to_finish" ]
    [ "$(jq -r '.steps[2].gate_result' "$STATE")" = "approved" ]
    [ "$(jq -r '.steps[2].gate_mode' "$STATE")" = "auto" ]
    [ -f .hotl-demo/simulation/demo-note.md ]
    grep -Fq '**Status:** ready_to_finish' "$REPORT"
    grep -q '⚡ Auto-approved' "$REPORT"
    grep -q 'Run finalized: ready_to_finish' "$REPORT"
}

@test "human-review pause plus explicit human gate flow completes end to end" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-human-review-e2e.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify

    "$HOTL_RT" step 2 start
    run "$HOTL_RT" step 2 verify
    [ "$status" -ne 0 ]
    [[ "$output" == *"human review required"* ]]
    [ "$(jq -r '.status' "$STATE")" = "paused" ]
    [ "$(jq -r '.steps[1].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[1].block_reason' "$STATE")" = "human review required: Confirm the intermediate output is acceptable before continuing" ]
    grep -Fq '**Status:** paused' "$REPORT"

    "$HOTL_RT" gate 2 approved --mode human
    [ "$(jq -r '.status' "$STATE")" = "running" ]
    [ "$(jq -r '.steps[1].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[1].gate_result' "$STATE")" = "approved" ]

    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify

    "$HOTL_RT" step 4 start
    "$HOTL_RT" step 4 verify
    "$HOTL_RT" gate 4 approved --mode human

    run "$FINALIZE_CODEX"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Execution Summary"* ]]
    [[ "$output" == *"Step 1: Run an automated pre-check - Done (1 attempt)"* ]]
    [[ "$output" == *"Step 2: Pause for manual review - Approved (-)"* ]]
    [[ "$output" == *"Step 3: Run a post-review check - Done (1 attempt)"* ]]
    [[ "$output" == *"Step 4: Final human gate - Approved (-)"* ]]

    [ "$(jq -r '.status' "$STATE")" = "ready_to_finish" ]
    [ "$(jq -r '[.steps[] | select(.status == "blocked")] | length' "$STATE")" = "0" ]
    grep -Fq '**Status:** ready_to_finish' "$REPORT"
    grep -q 'Human review for Step 2: approved (human)' "$REPORT"
    grep -q 'Gate Step 4: approved (human)' "$REPORT"
}

# ── Failure path: verify fails ──────────────────────────────────────────────

@test "failure path: step verify fails, run not auto-completed" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-retry-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify  # pytest not available — fails
    [ "$status" -ne 0 ]

    [ "$(jq -r '.steps[0].status' "$STATE")" = "failed" ]
    [ "$(jq -r '.steps[0].verify.passed' "$STATE")" = "false" ]
    # Run is still "running" — not auto-finalized
    [ "$(jq -r '.status' "$STATE")" = "running" ]
}

# ── Block path: agent blocks step before verify ─────────────────────────────

@test "block path: step blocked with reason" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 block --reason "agent could not edit file"

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "agent could not edit file" ]

    # Finalize should mark as blocked
    SUMMARY=$("$HOTL_RT" finalize --json)
    [ "$(echo "$SUMMARY" | jq -r '.status')" = "blocked" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "1" ]
}

# ── Gate path: gate recorded alongside step completion ──────────────────────

@test "gate path: approved gate recorded in artifacts" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    "$HOTL_RT" gate 1 approved --mode auto

    [ "$(jq -r '.steps[0].gate_result' "$STATE")" = "approved" ]
    [ "$(jq -r '.steps[0].gate_mode' "$STATE")" = "auto" ]
    grep -q 'Gate Step 1: approved' "$REPORT"

    # Complete remaining steps and finalize
    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    "$HOTL_RT" gate 3 approved --mode auto
    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "ready_to_finish" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].status')" = "done" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].attempts')" = "1" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].gate_result')" = "approved" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].gate_mode')" = "auto" ]
}

# ── Summary mid-run: read-only query during execution ───────────────────────

@test "summary mid-run: returns running status" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)

    "$HOTL_RT" step 1 start
    SUMMARY=$("$HOTL_RT" summary "$RUN_ID" --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "running" ]
    [ "$(echo "$SUMMARY" | jq -r '.run_id')" = "$RUN_ID" ]
    [ "$(echo "$SUMMARY" | jq -r '.total_steps')" = "3" ]
    # Only step 1 should show as in_progress
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].status')" = "in_progress" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[1].status')" = "pending" ]
}

# ── Retry path: fail → retry → pass ────────────────────────────────────────

@test "retry path: fail then retry then pass" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    # Temporarily make step 1 use a failing verify command
    jq '.steps[0].verify.command = "false"' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"

    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]
    [ "$(jq -r '.steps[0].status' "$STATE")" = "failed" ]

    # Retry — fix the verify command to pass
    "$HOTL_RT" step 1 retry
    jq '.steps[0].verify.command = "true"' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify
    [ "$(jq -r '.steps[0].status' "$STATE")" = "done" ]
    [ "$(jq -r '.steps[0].attempts' "$STATE")" = "2" ]

    "$HOTL_RT" step 2 start
    "$HOTL_RT" step 2 verify
    "$HOTL_RT" step 3 start
    "$HOTL_RT" step 3 verify
    "$HOTL_RT" gate 3 approved --mode human >/dev/null
    SUMMARY=$("$HOTL_RT" finalize --json)
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].status')" = "done" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].attempts')" = "2" ]

    # Report should show the retry history
    grep -q '↻' "$REPORT"
    grep -q '✓ Done' "$REPORT"
}

# ── Mixed outcomes in summary payload ──────────────────────────────────────

@test "finalize summary preserves failed and pending step outcomes" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    STATE=".hotl/state/${RUN_ID}.json"

    "$HOTL_RT" step 1 start
    "$HOTL_RT" step 1 verify

    jq '.steps[1].verify.command = "false"' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
    "$HOTL_RT" step 2 start
    run "$HOTL_RT" step 2 verify
    [ "$status" -ne 0 ]

    SUMMARY=$("$HOTL_RT" finalize --json)

    [ "$(echo "$SUMMARY" | jq -r '.status')" = "blocked" ]
    [ "$(echo "$SUMMARY" | jq -r '.completed_steps')" = "1" ]
    [ "$(echo "$SUMMARY" | jq -r '.failed_steps')" = "1" ]
    [ "$(echo "$SUMMARY" | jq -r '.blocked_steps')" = "0" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[0].status')" = "done" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[1].status')" = "failed" ]
    [ "$(echo "$SUMMARY" | jq -r '.steps[2].status')" = "pending" ]
}

# ── Report incremental updates: report is always current ────────────────────

@test "report is updated incrementally at each transition" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    REPORT=".hotl/reports/${RUN_ID}.md"

    # After init: all pending
    PENDING=$(grep -c '· Pending' "$REPORT")
    [ "$PENDING" -eq 3 ]

    # After step 1 start: one running
    "$HOTL_RT" step 1 start
    grep -q '→ Running' "$REPORT"

    # After step 1 verify: one done
    "$HOTL_RT" step 1 verify
    grep -q '✓ Done' "$REPORT"

    # Event log should have entries
    EVENT_COUNT=$(grep -c '^\*\*\[' "$REPORT")
    [ "$EVENT_COUNT" -ge 2 ]
}

# ── Browser verify fallback and unsupported verify types ────────────────────

@test "browser verify downgrades to human-review pause" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-browser-verify.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]

    [ "$(jq -r '.status' "$STATE")" = "paused" ]
    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    [ "$(jq -r '.steps[0].block_reason' "$STATE")" = "human review required: browser verify requested for http://localhost:3000 - page renders correctly" ]

    grep -q '✗ Blocked' "$REPORT"
    grep -q 'browser verify requested for http://localhost:3000 - page renders correctly' "$REPORT"
}

@test "unsupported verify type blocks with clear reason" {
    RUN_ID=$("$HOTL_RT" init fixtures/hotl-workflow-unsupported-verify.md)
    STATE=".hotl/state/${RUN_ID}.json"
    REPORT=".hotl/reports/${RUN_ID}.md"

    "$HOTL_RT" step 1 start
    run "$HOTL_RT" step 1 verify
    [ "$status" -ne 0 ]

    [ "$(jq -r '.steps[0].status' "$STATE")" = "blocked" ]
    jq -r '.steps[0].block_reason' "$STATE" | grep -q 'unsupported verify type: unsupported-tool'

    grep -q '✗ Blocked' "$REPORT"
    grep -q 'unsupported verify type: unsupported-tool' "$REPORT"
}
