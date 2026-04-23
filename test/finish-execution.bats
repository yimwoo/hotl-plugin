#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    PREPARE_ROOT="$REPO_ROOT/scripts/hotl-prepare-execution-root.sh"
    FINISH_EXEC="$REPO_ROOT/scripts/hotl-finish-execution.sh"

    TEST_DIR="$(mktemp -d)"
    REPO_DIR="$TEST_DIR/repo"
    mkdir -p "$REPO_DIR/docs/plans"
    cd "$REPO_DIR"
    git init -b main >/dev/null
    git config user.name "HOTL Test"
    git config user.email "hotl@example.com"
    printf '%s\n' '# repo' > README.md
    git add README.md
    git commit -m "init" >/dev/null
    git switch -c feature/authoring >/dev/null
}

teardown() {
    rm -rf "$TEST_DIR"
}

prepare_completed_isolated_run() {
    WORKFLOW_PATH="$REPO_DIR/docs/plans/2026-04-22-sample-workflow.md"
    cat > "$WORKFLOW_PATH" <<'EOF'
---
intent: Sample execution lifecycle
success_criteria: Feature marker exists
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Write feature marker**
action: Create feature marker file
loop: false
verify: test -f feature.txt
EOF

    PREP_JSON="$("$PREPARE_ROOT" "$WORKFLOW_PATH" --executor-mode loop)"
    BRANCH="$(echo "$PREP_JSON" | jq -r '.branch')"
    EXEC_ROOT="$(echo "$PREP_JSON" | jq -r '.execution_root')"
    WORKTREE_PATH="$(echo "$PREP_JSON" | jq -r '.worktree_path // empty')"
    WORKFLOW_IN_EXEC="$(echo "$PREP_JSON" | jq -r '.workflow_path')"
    SOURCE_HEAD="$(git -C "$REPO_DIR" rev-parse HEAD)"

    RUN_ID="$(
        cd "$EXEC_ROOT" &&
        "$HOTL_RT" init "$WORKFLOW_IN_EXEC" \
            --executor-mode loop \
            --repo-root "$REPO_DIR" \
            --execution-root "$EXEC_ROOT" \
            --source-workflow-path "$WORKFLOW_PATH" \
            --source-branch "feature/authoring" \
            --source-head "$SOURCE_HEAD" \
            --worktree-path "$WORKTREE_PATH" \
            --branch "$BRANCH"
    )"

    printf '%s\n' 'feature marker' > "$EXEC_ROOT/feature.txt"
    git -C "$EXEC_ROOT" add feature.txt
    git -C "$EXEC_ROOT" commit -m "add feature marker" >/dev/null

    (
        cd "$EXEC_ROOT"
        "$HOTL_RT" step 1 start --run-id "$RUN_ID" >/dev/null
        "$HOTL_RT" step 1 verify --run-id "$RUN_ID" >/dev/null
        "$HOTL_RT" finalize --json --run-id "$RUN_ID" >/dev/null
    )
}

@test "finish merge defaults back to source branch, preserves artifacts, and cleans isolated branch/worktree" {
    prepare_completed_isolated_run

    run "$FINISH_EXEC" --run-id "$RUN_ID" --mode merge
    [ "$status" -eq 0 ]

    [ "$(git -C "$REPO_DIR" branch --show-current)" = "feature/authoring" ]
    [ -f "$REPO_DIR/feature.txt" ]
    [ ! -d "$WORKTREE_PATH" ]
    ! git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"

    STATE="$REPO_DIR/.hotl/state/${RUN_ID}.json"
    REPORT="$REPO_DIR/.hotl/reports/${RUN_ID}.md"
    REPORT_CANONICAL="$(cd "$(dirname "$REPORT")" && pwd -P)/$(basename "$REPORT")"
    [ -f "$STATE" ]
    [ -f "$REPORT" ]
    [ "$(jq -r '.finish.disposition' "$STATE")" = "merged" ]
    [ "$(jq -r '.finish.target_branch' "$STATE")" = "feature/authoring" ]
    [ "$(jq -r '.finish.worktree_action' "$STATE")" = "removed" ]
    [ "$(jq -r '.report_path' "$STATE")" = "$REPORT_CANONICAL" ]
}

@test "finish discard requires confirmation, then removes isolated branch/worktree and preserves artifacts" {
    prepare_completed_isolated_run

    run "$FINISH_EXEC" --run-id "$RUN_ID" --mode discard
    [ "$status" -ne 0 ]
    [[ "$output" == *"--confirm discard"* ]]

    run "$FINISH_EXEC" --run-id "$RUN_ID" --mode discard --confirm discard
    [ "$status" -eq 0 ]

    [ ! -d "$WORKTREE_PATH" ]
    ! git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"
    [ ! -f "$REPO_DIR/feature.txt" ]

    STATE="$REPO_DIR/.hotl/state/${RUN_ID}.json"
    [ -f "$STATE" ]
    [ "$(jq -r '.finish.disposition' "$STATE")" = "discarded" ]
    [ "$(jq -r '.finish.branch_action' "$STATE")" = "deleted" ]
}

@test "finish publish pushes the execution branch and keeps the isolated worktree" {
    prepare_completed_isolated_run

    REMOTE_DIR="$TEST_DIR/remote.git"
    git init --bare "$REMOTE_DIR" >/dev/null
    git -C "$REPO_DIR" remote add origin "$REMOTE_DIR"

    run "$FINISH_EXEC" --run-id "$RUN_ID" --mode publish --remote origin
    [ "$status" -eq 0 ]

    git -C "$REMOTE_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"
    [ -d "$WORKTREE_PATH" ]

    STATE="$EXEC_ROOT/.hotl/state/${RUN_ID}.json"
    [ -f "$STATE" ]
    [ "$(jq -r '.finish.disposition' "$STATE")" = "published" ]
    [ "$(jq -r '.finish.remote' "$STATE")" = "origin" ]
    [ "$(jq -r '.finish.worktree_action' "$STATE")" = "kept" ]
}
