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
    for step in 1 2 3; do
        "$HOTL_RT" step "$step" start --run-id "$run_id" >/dev/null
        "$HOTL_RT" step "$step" verify --run-id "$run_id" >/dev/null
    done
    "$HOTL_RT" action request external_write --target 'open pull request' --run-id "$run_id" >/dev/null
    "$HOTL_RT" gate 3 approved --mode human --run-id "$run_id" >/dev/null
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "paused" ]
}

@test "publish and merge finish dispositions require non-finish evidence" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    for step in 1 2 3; do
        "$HOTL_RT" step "$step" start --run-id "$run_id" >/dev/null
        "$HOTL_RT" step "$step" verify --run-id "$run_id" >/dev/null
    done
    state=".hotl/state/$run_id.json"
    jq '.status = "ready_to_finish" | .finalized_at = .last_update' "$state" > "$state.fixture"
    mv "$state.fixture" "$state"
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

@test "simultaneous action requests preserve every unique record" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    pids=()
    for index in 1 2 3 4 5 6; do
        "$HOTL_RT" action request local_write --target "edit file $index" --run-id "$run_id" > "action-$index.out" 2> "action-$index.err" &
        pids+=("$!")
    done

    failures=0
    for pid in "${pids[@]}"; do
        wait "$pid" || failures=$((failures + 1))
    done

    [ "$failures" -eq 0 ]
    [ "$(jq '.external_actions | length' ".hotl/state/$run_id.json")" -eq 6 ]
    [ "$(jq '[.external_actions[].id] | unique | length' ".hotl/state/$run_id.json")" -eq 6 ]
}

@test "step transitions enforce aggregate attempt budgets without a separate check" {
    cat > aggregate-budget-workflow.md <<'EOF'
---
intent: Enforce aggregate attempts
success_criteria: Third attempt is rejected
risk_level: low
auto_approve: true
max_total_attempts: 2
---

## Steps

- [ ] **Step 1: First attempt**
action: Pass
loop: false
verify: true

- [ ] **Step 2: Second attempt**
action: Pass
loop: false
verify: true

- [ ] **Step 3: Over budget**
action: Must not start
loop: false
verify: true
EOF
    run_id=$("$HOTL_RT" init aggregate-budget-workflow.md)
    "$HOTL_RT" step 1 start --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 2 start --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 2 verify --run-id "$run_id" >/dev/null

    run "$HOTL_RT" step 3 start --run-id "$run_id"

    [ "$status" -ne 0 ]
    [[ "$output" == *"total_attempts"*"exceeded"* ]]
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "paused" ]
}

@test "step transitions enforce elapsed budgets without a separate check" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    state=".hotl/state/$run_id.json"
    jq '.started_at = "2000-01-01T00:00:00+00:00"' "$state" > "$state.fixture"
    mv "$state.fixture" "$state"

    run "$HOTL_RT" step 1 start --run-id "$run_id"

    [ "$status" -ne 0 ]
    [[ "$output" == *"elapsed_minutes"*"exceeded"* ]]
    [ "$(jq -r '.status' "$state")" = "paused" ]
}

@test "controller ownership supports claim heartbeat release and conflict rejection" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)

    claim=$("$HOTL_RT" owner claim --owner controller-a --lease-seconds 60 --run-id "$run_id")
    token=$(jq -r '.token' <<< "$claim")
    [ "$(jq -r '.status' <<< "$claim")" = "active" ]
    [ -n "$token" ]
    ! grep -Fq "$token" ".hotl/state/$run_id.json"

    run "$HOTL_RT" owner claim --owner controller-b --lease-seconds 60 --run-id "$run_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"active controller"* ]]

    before=$(jq -r '.revision' ".hotl/state/$run_id.json")
    HOTL_OWNER_TOKEN="$token" "$HOTL_RT" owner heartbeat --lease-seconds 60 --run-id "$run_id" >/dev/null
    [ "$(jq -r '.revision' ".hotl/state/$run_id.json")" -gt "$before" ]
    HOTL_OWNER_TOKEN="$token" "$HOTL_RT" owner release --run-id "$run_id" >/dev/null
    [ "$("$HOTL_RT" owner status --run-id "$run_id" | jq -r '.status')" = "released" ]

    replacement=$("$HOTL_RT" owner claim --owner controller-b --lease-seconds 60 --run-id "$run_id")
    [ "$(jq -r '.owner_id' <<< "$replacement")" = "controller-b" ]
}

@test "controller tokens are generated from operating-system entropy" {
    grep -Eq 'openssl rand|/dev/urandom' "$HOTL_RT"
}

@test "controller takeover is explicit and audit recorded" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    "$HOTL_RT" owner claim --owner controller-a --lease-seconds 60 --run-id "$run_id" >/dev/null

    run "$HOTL_RT" owner takeover --owner controller-b --reason 'resume elsewhere' --run-id "$run_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lease is still active"* ]]

    state=".hotl/state/$run_id.json"
    jq '.controller.lease_expires_epoch = 0' "$state" > "$state.fixture"
    mv "$state.fixture" "$state"
    takeover=$("$HOTL_RT" owner takeover --owner controller-b --reason 'expired controller' --run-id "$run_id")

    [ "$(jq -r '.owner_id' <<< "$takeover")" = "controller-b" ]
    [ "$(jq -r '.ownership_history[-1].event' "$state")" = "takeover" ]
    [ "$(jq -r '.ownership_history[-1].reason' "$state")" = "expired controller" ]
}

@test "claimed runs reject mutations from controllers without the lease token" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    claim=$("$HOTL_RT" owner claim --owner controller-a --lease-seconds 60 --run-id "$run_id")
    token=$(jq -r '.token' <<< "$claim")

    run "$HOTL_RT" step 1 start --run-id "$run_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"controller ownership token"* ]]

    HOTL_OWNER_TOKEN="$token" "$HOTL_RT" step 1 start --run-id "$run_id" >/dev/null
    [ "$(jq -r '.steps[0].status' ".hotl/state/$run_id.json")" = "in_progress" ]
}

@test "sensitive effects persist intent idempotency and reconciled outcome" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    requested=$("$HOTL_RT" action request external_write --target 'create pull request' --idempotency-key pr-release-1 --run-id "$run_id")
    action_id=$(jq -r '.id' <<< "$requested")
    [ "$(jq -r '.idempotency_key' <<< "$requested")" = "pr-release-1" ]
    "$HOTL_RT" action decide "$action_id" approved --mode human --run-id "$run_id" >/dev/null

    receipt=$("$HOTL_RT" receipt "$run_id")
    jq -e '.sufficiency.reasons | index("sensitive_action_effect_unresolved")' <<< "$receipt" >/dev/null

    begun=$("$HOTL_RT" action begin "$action_id" --idempotency-key pr-release-1 --run-id "$run_id")
    [ "$(jq -r '.effect_status' <<< "$begun")" = "in_progress" ]
    jq -e --arg id "$action_id" '.external_actions[] | select(.id==$id and .effect.intent_recorded_at != null)' ".hotl/state/$run_id.json" >/dev/null
    [ "$("$HOTL_RT" reconcile "$run_id" | jq -r '.next_action')" = "reconcile_action_effect" ]

    "$HOTL_RT" action complete "$action_id" uncertain --evidence-ref 'provider-timeout' --run-id "$run_id" >/dev/null
    [ "$("$HOTL_RT" reconcile "$run_id" | jq -r '.next_action')" = "reconcile_action_effect" ]
    run "$HOTL_RT" action begin "$action_id" --idempotency-key pr-release-1 --run-id "$run_id"
    [ "$status" -ne 0 ]

    "$HOTL_RT" action reconcile "$action_id" succeeded --evidence-ref 'pr:https://example.test/1' --run-id "$run_id" >/dev/null
    receipt=$("$HOTL_RT" receipt "$run_id")
    [ "$(jq '[.sufficiency.reasons[] | select(.=="sensitive_action_effect_unresolved")] | length' <<< "$receipt")" -eq 0 ]
}

@test "duplicate sensitive idempotency keys reuse one action record" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    first=$("$HOTL_RT" action request external_write --target 'publish release' --idempotency-key release-42 --run-id "$run_id")
    second=$("$HOTL_RT" action request external_write --target 'publish release' --idempotency-key release-42 --run-id "$run_id")

    [ "$(jq -r '.id' <<< "$first")" = "$(jq -r '.id' <<< "$second")" ]
    [ "$(jq '.external_actions | length' ".hotl/state/$run_id.json")" -eq 1 ]
}

@test "legacy approved sensitive actions without effect evidence stay conservative" {
    run_id=$("$HOTL_RT" init fixtures/hotl-workflow-runtime-sample.md)
    action_id=$("$HOTL_RT" action request external_write --target 'legacy publish' --run-id "$run_id" | jq -r '.id')
    "$HOTL_RT" action decide "$action_id" approved --mode human --run-id "$run_id" >/dev/null
    state=".hotl/state/$run_id.json"
    jq '(.external_actions[] | select(.id=="action-1")) |= del(.effect, .idempotency_key, .effect_required)' "$state" > "$state.fixture"
    mv "$state.fixture" "$state"

    receipt=$("$HOTL_RT" receipt "$run_id")

    jq -e '.sufficiency.reasons | index("sensitive_action_effect_evidence_missing")' <<< "$receipt" >/dev/null

    "$HOTL_RT" action reconcile "$action_id" succeeded \
        --evidence-ref 'legacy-inspection:published' --run-id "$run_id" >/dev/null
    receipt=$("$HOTL_RT" receipt "$run_id")
    [ "$(jq '[.sufficiency.reasons[] | select(startswith("sensitive_action_effect"))] | length' <<< "$receipt")" -eq 0 ]
    [ "$(jq -r --arg id "$action_id" '.external_actions[] | select(.id==$id) | .effect.status' ".hotl/state/$run_id.json")" = "succeeded" ]
}

@test "finish cannot complete a ready run with post-finalize unresolved effects" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    "$HOTL_RT" step 1 start --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$run_id" >/dev/null
    "$HOTL_RT" finalize --run-id "$run_id" >/dev/null
    action_id=$("$HOTL_RT" action request external_write --target 'publish after finalize' --idempotency-key post-finalize-publish --run-id "$run_id" | jq -r '.id')
    "$HOTL_RT" action decide "$action_id" approved --mode human --run-id "$run_id" >/dev/null

    run "$HOTL_RT" finish kept --run-id "$run_id"

    [ "$status" -ne 0 ]
    [[ "$output" == *"sufficient completion evidence"* ]]
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" = "ready_to_finish" ]
    [ "$(jq -r '.finish.disposition' ".hotl/state/$run_id.json")" = "null" ]
}

@test "finalize rejects approved sensitive actions without terminal effect evidence" {
    run_id=$("$HOTL_RT" init budget-workflow.md)
    action_id=$("$HOTL_RT" action request external_write --target 'publish release' --run-id "$run_id" | jq -r '.id')
    "$HOTL_RT" action decide "$action_id" approved --mode human --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 1 start --run-id "$run_id" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$run_id" >/dev/null

    run "$HOTL_RT" finalize --run-id "$run_id"

    [ "$status" -ne 0 ]
    [[ "$output" == *"effect evidence"* ]]
    [ "$(jq -r '.status' ".hotl/state/$run_id.json")" != "completed" ]
    [ "$("$HOTL_RT" reconcile "$run_id" | jq -r '.next_action')" = "execute_approved_action" ]
}

@test "failed and cancelled sensitive effects produce distinct conservative outcomes" {
    failed_run=$("$HOTL_RT" init budget-workflow.md)
    failed_request=$("$HOTL_RT" action request production_change --target 'deploy release' --idempotency-key deploy-1 --run-id "$failed_run")
    failed_id=$(jq -r '.id' <<< "$failed_request")
    "$HOTL_RT" action decide "$failed_id" approved --mode human --run-id "$failed_run" >/dev/null
    "$HOTL_RT" action begin "$failed_id" --idempotency-key deploy-1 --run-id "$failed_run" >/dev/null
    "$HOTL_RT" action complete "$failed_id" failed --evidence-ref 'deployment:error-42' --run-id "$failed_run" >/dev/null

    [ "$(jq -r '.status' ".hotl/state/$failed_run.json")" = "blocked" ]
    jq -e '.sufficiency.reasons | index("sensitive_action_effect_failed")' <<< "$("$HOTL_RT" receipt "$failed_run")" >/dev/null

    cancelled_run=$("$HOTL_RT" init budget-workflow.md)
    cancelled_request=$("$HOTL_RT" action request external_write --target 'create release' --idempotency-key release-cancelled --run-id "$cancelled_run")
    cancelled_id=$(jq -r '.id' <<< "$cancelled_request")
    "$HOTL_RT" action decide "$cancelled_id" approved --mode human --run-id "$cancelled_run" >/dev/null
    "$HOTL_RT" action begin "$cancelled_id" --idempotency-key release-cancelled --run-id "$cancelled_run" >/dev/null
    "$HOTL_RT" action complete "$cancelled_id" cancelled --evidence-ref 'human:cancelled-before-write' --run-id "$cancelled_run" >/dev/null

    [ "$(jq -r '.status' ".hotl/state/$cancelled_run.json")" = "running" ]
    receipt=$("$HOTL_RT" receipt "$cancelled_run")
    [ "$(jq '[.sufficiency.reasons[] | select(startswith("sensitive_action_effect"))] | length' <<< "$receipt")" -eq 0 ]
}
