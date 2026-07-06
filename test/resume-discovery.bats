#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PREPARE_ROOT="$REPO_ROOT/scripts/hotl-prepare-execution-root.sh"
    LOCATE_RUN="$REPO_ROOT/scripts/hotl-locate-run.sh"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    TEST_DIR="$(mktemp -d)"
    REPO_DIR="$TEST_DIR/repo"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    REPO_DIR="$(pwd -P)"
    git init -b main >/dev/null
    git config user.name "HOTL Test"
    git config user.email "hotl@example.com"
    printf '%s\n' '# repo' > README.md
    git add README.md
    git commit -m "init" >/dev/null
}

teardown() {
    rm -rf "$TEST_DIR"
}

write_workflow() {
    mkdir -p docs/plans
    cat > docs/plans/2026-05-09-long-workflow.md <<'EOF'
---
intent: Reproduce interrupted isolated worktree resume discovery
success_criteria: Interrupted state can be found from the authoring checkout
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: First step**
action: Do first step
loop: false
verify: echo first

- [ ] **Step 2: Second step**
action: Do second step
loop: false
verify: echo second
EOF
    git add docs/plans/2026-05-09-long-workflow.md
    git commit -m "add workflow" >/dev/null
}

prepare_and_init_run() {
    local preflight
    preflight=$("$PREPARE_ROOT" docs/plans/2026-05-09-long-workflow.md --executor-mode loop)

    EXECUTION_ROOT="$(echo "$preflight" | jq -r '.execution_root')"
    WORKFLOW_PATH="$(echo "$preflight" | jq -r '.workflow_path')"
    SOURCE_WORKFLOW_PATH="$(echo "$preflight" | jq -r '.source_workflow_path')"
    WORKTREE_PATH="$(echo "$preflight" | jq -r '.worktree_path')"
    BRANCH="$(echo "$preflight" | jq -r '.branch')"

    cd "$EXECUTION_ROOT"
    RUN_ID=$("$HOTL_RT" init "$WORKFLOW_PATH" \
        --executor-mode loop \
        --repo-root "$REPO_DIR" \
        --execution-root "$EXECUTION_ROOT" \
        --source-workflow-path "$SOURCE_WORKFLOW_PATH" \
        --worktree-path "$WORKTREE_PATH" \
        --branch "$BRANCH")
}

@test "locator finds interrupted isolated-worktree run from authoring checkout by workflow" {
    write_workflow
    prepare_and_init_run

    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    cd "$REPO_DIR"

    [ ! -d "$REPO_DIR/.hotl/state" ]
    [ -f "$EXECUTION_ROOT/.hotl/state/${RUN_ID}.json" ]

    run "$LOCATE_RUN" --workflow docs/plans/2026-05-09-long-workflow.md
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" = "1" ]
    [ "$(echo "$output" | jq -r '.[0].run_id')" = "$RUN_ID" ]
    [ "$(echo "$output" | jq -r '.[0].run_root')" = "$EXECUTION_ROOT" ]
    [ "$(echo "$output" | jq -r '.[0].execution_root')" = "$EXECUTION_ROOT" ]
    [ "$(echo "$output" | jq -r '.[0].source_workflow_path')" = "$REPO_DIR/docs/plans/2026-05-09-long-workflow.md" ]
}

@test "locator finds interrupted isolated-worktree run from authoring checkout by run id" {
    write_workflow
    prepare_and_init_run

    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    cd "$REPO_DIR"

    run "$LOCATE_RUN" --run-id "$RUN_ID"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" = "1" ]
    [ "$(echo "$output" | jq -r '.[0].run_id')" = "$RUN_ID" ]
    [ "$(echo "$output" | jq -r '.[0].state_file')" = "$EXECUTION_ROOT/.hotl/state/${RUN_ID}.json" ]
}

@test "locator excludes completed runs by default but can include all runs" {
    write_workflow
    prepare_and_init_run

    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 2 start --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 2 verify --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finish kept --run-id "$RUN_ID" >/dev/null
    cd "$REPO_DIR"

    run "$LOCATE_RUN" --workflow docs/plans/2026-05-09-long-workflow.md
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" = "0" ]

    run "$LOCATE_RUN" --workflow docs/plans/2026-05-09-long-workflow.md --all
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" = "1" ]
    [ "$(echo "$output" | jq -r '.[0].status')" = "completed" ]
}

@test "locator includes ready-to-finish runs so disposition can resume" {
    write_workflow
    prepare_and_init_run

    "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 1 verify --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 2 start --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" step 2 verify --run-id "$RUN_ID" >/dev/null
    "$HOTL_RT" finalize --run-id "$RUN_ID" >/dev/null
    cd "$REPO_DIR"

    run "$LOCATE_RUN" --workflow docs/plans/2026-05-09-long-workflow.md
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" = "1" ]
    [ "$(echo "$output" | jq -r '.[0].status')" = "ready_to_finish" ]
}
