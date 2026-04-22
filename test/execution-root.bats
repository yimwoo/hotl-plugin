#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PREPARE_ROOT="$REPO_ROOT/scripts/hotl-prepare-execution-root.sh"
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

@test "prepare-execution-root defaults to an isolated worktree and bootstraps the workflow file" {
    cat > hotl-workflow-sample.md <<'EOF'
---
intent: Sample worktree execution
success_criteria: Workflow exists in isolated checkout
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Do the thing**
action: Echo
loop: false
verify: echo ok
EOF

    run "$PREPARE_ROOT" hotl-workflow-sample.md --executor-mode loop
    [ "$status" -eq 0 ]

    branch="$(echo "$output" | jq -r '.branch')"
    execution_root="$(echo "$output" | jq -r '.execution_root')"
    workflow_path="$(echo "$output" | jq -r '.workflow_path')"
    worktree_path="$(echo "$output" | jq -r '.worktree_path')"

    [ "$branch" = "hotl/sample" ]
    [ -d "$execution_root" ]
    [ "$execution_root" = "$worktree_path" ]
    [ -f "$workflow_path" ]
    [ "$(git -C "$execution_root" branch --show-current)" = "$branch" ]
    cmp -s hotl-workflow-sample.md "$workflow_path"
}

@test "prepare-execution-root honors worktree false as an opt-out" {
    cat > hotl-workflow-sample.md <<'EOF'
---
intent: Shared checkout execution
success_criteria: Workflow stays in repo root
risk_level: low
auto_approve: true
worktree: false
---

## Steps

- [ ] **Step 1: Do the thing**
action: Echo
loop: false
verify: echo ok
EOF

    run "$PREPARE_ROOT" hotl-workflow-sample.md --executor-mode loop
    [ "$status" -eq 0 ]

    execution_root="$(echo "$output" | jq -r '.execution_root')"
    worktree_path="$(echo "$output" | jq -r '.worktree_path')"
    workflow_path="$(echo "$output" | jq -r '.workflow_path')"

    [ "$execution_root" = "$REPO_DIR" ]
    [ "$worktree_path" = "null" ]
    [ "$workflow_path" = "$REPO_DIR/hotl-workflow-sample.md" ]
}

@test "prepare-execution-root blocks on non-HOTL dirty files" {
    cat > hotl-workflow-sample.md <<'EOF'
---
intent: Dirty repo
success_criteria: Dirty files are rejected
risk_level: low
auto_approve: true
worktree: true
---

## Steps

- [ ] **Step 1: Do the thing**
action: Echo
loop: false
verify: echo ok
EOF

    printf '%s\n' 'dirty' > app.txt

    run "$PREPARE_ROOT" hotl-workflow-sample.md --executor-mode loop
    [ "$status" -ne 0 ]
    [[ "$output" == *"Non-HOTL dirty files block execution"* ]]
    [[ "$output" == *"app.txt"* ]]
}
