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
    mkdir -p docs/plans
    cat > docs/plans/2026-04-22-sample-workflow.md <<'EOF'
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

    run "$PREPARE_ROOT" docs/plans/2026-04-22-sample-workflow.md --executor-mode loop
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
    cmp -s docs/plans/2026-04-22-sample-workflow.md "$workflow_path"
}

@test "prepare-execution-root honors worktree false as an opt-out" {
    mkdir -p docs/plans
    cat > docs/plans/2026-04-22-sample-workflow.md <<'EOF'
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

    run "$PREPARE_ROOT" docs/plans/2026-04-22-sample-workflow.md --executor-mode loop
    [ "$status" -eq 0 ]

    execution_root="$(echo "$output" | jq -r '.execution_root')"
    worktree_path="$(echo "$output" | jq -r '.worktree_path')"
    workflow_path="$(echo "$output" | jq -r '.workflow_path')"

    [ "$execution_root" = "$REPO_DIR" ]
    [ "$worktree_path" = "null" ]
    [ "$workflow_path" = "$REPO_DIR/docs/plans/2026-04-22-sample-workflow.md" ]
}

@test "prepare-execution-root reports source branch and source head metadata" {
    mkdir -p docs/plans
    cat > docs/plans/2026-04-22-sample-workflow.md <<'EOF'
---
intent: Metadata capture
success_criteria: Source branch and head are recorded
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Do the thing**
action: Echo
loop: false
verify: echo ok
EOF

    run "$PREPARE_ROOT" docs/plans/2026-04-22-sample-workflow.md --executor-mode loop
    [ "$status" -eq 0 ]

    [ "$(echo "$output" | jq -r '.source_branch')" = "main" ]
    [ -n "$(echo "$output" | jq -r '.source_head')" ]
}

@test "prepare-execution-root blocks same-branch worktree execution with clear guidance" {
    git switch -c feature/demo >/dev/null
    mkdir -p docs/plans
    cat > docs/plans/2026-04-22-sample-workflow.md <<'EOF'
---
intent: Same branch conflict
success_criteria: Guard catches current-branch worktree conflict
risk_level: low
auto_approve: true
branch: feature/demo
---

## Steps

- [ ] **Step 1: Do the thing**
action: Echo
loop: false
verify: echo ok
EOF

    run "$PREPARE_ROOT" docs/plans/2026-04-22-sample-workflow.md --executor-mode loop
    [ "$status" -ne 0 ]
    [[ "$output" == *"already checked out in the current checkout"* ]]
    [[ "$output" == *"worktree: false"* ]]
}

@test "prepare-execution-root blocks on non-HOTL dirty files" {
    mkdir -p docs/plans
    cat > docs/plans/2026-04-22-sample-workflow.md <<'EOF'
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

    run "$PREPARE_ROOT" docs/plans/2026-04-22-sample-workflow.md --executor-mode loop
    [ "$status" -ne 0 ]
    [[ "$output" == *"Non-HOTL dirty files block execution"* ]]
    [[ "$output" == *"app.txt"* ]]
}

@test "prepare-execution-root ignores canonical HOTL artifacts in dirty check" {
    mkdir -p docs/plans docs/designs
    cat > docs/plans/2026-04-22-sample-workflow.md <<'EOF'
---
intent: HOTL-owned dirty files are allowed
success_criteria: Canonical HOTL files do not block execution
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Do the thing**
action: Echo
loop: false
verify: echo ok
EOF

    printf '%s\n' '# canonical design' > docs/designs/2026-04-22-sample-design.md

    run "$PREPARE_ROOT" docs/plans/2026-04-22-sample-workflow.md --executor-mode loop
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.branch')" = "hotl/sample" ]
}
