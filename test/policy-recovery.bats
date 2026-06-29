#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    TEST_DIR=$(mktemp -d)
    cp -R "$REPO_ROOT/test/fixtures" "$TEST_DIR/fixtures"
    cd "$TEST_DIR"
    printf '%s\n' \
      '---' 'intent: Test portable budgets' 'success_criteria: Budget states are accurate' \
      'risk_level: low' 'auto_approve: true' 'max_total_attempts: 2' 'max_agents: 2' \
      'max_cost_usd: 1.5' 'max_elapsed_minutes: 10' '---' '' '## Steps' '' \
      '- [ ] **Step 1: Check budget**' 'action: Exercise the runtime' 'loop: false' 'verify: echo pass' > budget-workflow.md
}

teardown() { rm -rf "$TEST_DIR"; }

@test "normalized policy preserves numeric budgets and unknown observations" {
    normalized=$("$HOTL_RT" normalize budget-workflow.md --json)
    [ "$(jq -r '.workflow.policy.profile' <<< "$normalized")" = "standard" ]
    [ "$(jq -r '.workflow.policy.budgets.max_agents' <<< "$normalized")" = "2" ]
    [ "$(jq -r '.workflow.policy.budgets.max_cost_usd' <<< "$normalized")" = "1.5" ]
}

@test "local actions are allowed while sensitive actions pause for human decision" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    local_result=$("$HOTL_RT" action request local_write --target 'edit src/app.ts' --run-id "$run_id")
    [ "$(jq -r '.status' <<< "$local_result")" = "allowed" ]
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "running" ]

    sensitive=$("$HOTL_RT" action request external_write --target 'create pull request for branch hotl/test' --run-id "$run_id")
    action_id=$(jq -r '.id' <<< "$sensitive")
    [ "$(jq -r '.status' <<< "$sensitive")" = "pending" ]
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "paused" ]

    "$HOTL_RT" action decide "$action_id" approved --mode human --run-id "$run_id" >/dev/null
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "running" ]
    [ "$(jq -r '.external_actions[1].status' ".hotl/state/$run_id.json")" = "approved" ]
}

@test "sensitive action rejection blocks and cannot be decided by auto mode" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    action_id=$("$HOTL_RT" action request production_change --target 'deploy release candidate' --run-id "$run_id" | jq -r '.id')
    run "$HOTL_RT" action decide "$action_id" approved --mode auto --run-id "$run_id"
    [ "$status" -ne 0 ]
    "$HOTL_RT" action decide "$action_id" rejected --mode human --run-id "$run_id" >/dev/null
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "blocked" ]
}

@test "sensitive action records reject empty targets and omit environment data" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    run "$HOTL_RT" action request secret_access --target '' --run-id "$run_id"
    [ "$status" -ne 0 ]
    result=$(SECRET_SENTINEL=do-not-record "$HOTL_RT" action request secret_access --target 'read deployment token by reference' --run-id "$run_id")
    [ "$(jq -r '.status' <<< "$result")" = "pending" ]
    ! grep -R 'do-not-record' .hotl
}

@test "budget check distinguishes within unset and unknown telemetry" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    check=$("$HOTL_RT" budget check --run-id "$run_id")
    [ "$(jq -r '.metrics[] | select(.metric=="total_attempts") | .status' <<< "$check")" = "within" ]
    [ "$(jq -r '.metrics[] | select(.metric=="cost_usd") | .status' <<< "$check")" = "unknown" ]
    [ "$(jq -r '.has_unknown' <<< "$check")" = "true" ]
}

@test "known budget exceedance pauses run and makes receipt insufficient" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    check=$("$HOTL_RT" budget record agents 3 --run-id "$run_id")
    [ "$(jq -r '.metrics[] | select(.metric=="agents") | .status' <<< "$check")" = "exceeded" ]
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "paused" ]
    receipt=$("$HOTL_RT" receipt "$run_id")
    jq -e '.sufficiency.reasons | index("budget_exceeded")' <<< "$receipt"
}

@test "reconciliation is read-only and recommends policy decision first" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    "$HOTL_RT" action request external_write --target 'publish release' --run-id "$run_id" >/dev/null
    before=$(shasum ".hotl/state/$run_id.json")
    reconciliation=$("$HOTL_RT" reconcile "$run_id")
    after=$(shasum ".hotl/state/$run_id.json")
    [ "$before" = "$after" ]
    [ "$(jq -r '.next_action' <<< "$reconciliation")" = "await_action_decision" ]
}

@test "reconciliation recommends finish after verified finalized run" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    "$HOTL_RT" step 1 start --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$run_id" >/dev/null
    "$HOTL_RT" finalize --run-id "$run_id" >/dev/null
    reconciliation=$("$HOTL_RT" reconcile "$run_id")
    [ "$(jq -r '.next_action' <<< "$reconciliation")" = "record_finish_disposition" ]
    "$HOTL_RT" finish kept --run-id "$run_id" >/dev/null
    [ "$("$HOTL_RT" reconcile "$run_id" | jq -r '.next_action')" = "complete" ]
}

@test "policy decisions cannot resume a run paused or blocked for another reason" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    "$HOTL_RT" budget record agents 3 --run-id "$run_id" >/dev/null
    action_id=$("$HOTL_RT" action request external_write --target 'publish release' --run-id "$run_id" | jq -r '.id')
    "$HOTL_RT" action decide "$action_id" approved --mode human --run-id "$run_id" >/dev/null
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "paused" ]
    run "$HOTL_RT" step 1 start --run-id "$run_id"
    [ "$status" -ne 0 ]

    blocked_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" step 1 block --reason 'independent blocker' --run-id "$blocked_id" >/dev/null
    "$HOTL_RT" action request production_change --target 'deploy release' --run-id "$blocked_id" >/dev/null
    [ "$(jq -r '.status' ".hotl/state/$blocked_id.json")" = "blocked" ]
    grep -Fq '**Status:** blocked' ".hotl/reports/$blocked_id.md"
}

@test "gate approval cannot bypass a pending sensitive action" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" action request external_write --target 'open pull request' --run-id "$run_id" >/dev/null
    "$HOTL_RT" gate 3 approved --mode human --run-id "$run_id" >/dev/null
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "paused" ]
}

@test "publish and merge finish dispositions require non-finish evidence" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" finalize --run-id "$run_id" >/dev/null
    run "$HOTL_RT" finish published --run-id "$run_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires sufficient completion evidence"* ]]
}

@test "normalization rejects invalid policy numeric and boolean values" {
    sed 's/auto_approve: true/auto_approve: sometimes/' budget-workflow.md > invalid-boolean.md
    run "$HOTL_RT" normalize invalid-boolean.md
    [ "$status" -ne 0 ]
    sed 's/max_agents: 2/max_agents: -1/' budget-workflow.md > invalid-budget.md
    run "$HOTL_RT" normalize invalid-budget.md
    [ "$status" -ne 0 ]
}

@test "high-risk gates reject auto mode and receipts require human mode" {
    sed 's/risk_level: low/risk_level: high/' budget-workflow.md > high-risk.md
    run_id=$("$HOTL_RT" init high-risk.md)
    "$HOTL_RT" step 1 start --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$run_id" >/dev/null
    run "$HOTL_RT" gate 1 approved --mode auto --run-id "$run_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"require human"* ]]
    "$HOTL_RT" gate 1 approved --mode human --run-id "$run_id" >/dev/null
    "$HOTL_RT" finalize --run-id "$run_id" >/dev/null
    "$HOTL_RT" finish kept --run-id "$run_id" >/dev/null
    [ "$("$HOTL_RT" receipt "$run_id" | jq -r '.sufficiency.sufficient')" = "true" ]
}

@test "budget observations cannot decrease and exceedance updates report" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    "$HOTL_RT" budget record cost_usd 2 --run-id "$run_id" >/dev/null
    run "$HOTL_RT" budget record cost_usd 1 --run-id "$run_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot decrease"* ]]
    grep -Fq '**Status:** paused' ".hotl/reports/$run_id.md"
    grep -Fq 'Budget exceeded: cost_usd' ".hotl/reports/$run_id.md"
}
