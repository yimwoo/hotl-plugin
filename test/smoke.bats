#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ── JSON validity ─────────────────────────────────────────────────────────────

@test "plugin.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/.claude-plugin/plugin.json" > /dev/null
}

@test "hooks/hooks.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/hooks/hooks.json" > /dev/null
}

@test "marketplace.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/.claude-plugin/marketplace.json" > /dev/null
}

# ── session-start hook output ─────────────────────────────────────────────────

@test "session-start outputs valid JSON with additional_context field" {
    output=$("$REPO_ROOT/hooks/session-start" 2>&1)
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'additional_context' in data, 'missing additional_context field'
assert len(data['additional_context']) > 0, 'additional_context is empty'
" <<< "$output"
}

# ── skill files ───────────────────────────────────────────────────────────────

@test "all SKILL.md files exist and are non-empty" {
    skills_dir="$REPO_ROOT/skills"
    found=0
    while IFS= read -r -d '' skill_file; do
        found=$((found + 1))
        [ -s "$skill_file" ] || { echo "Empty or missing: $skill_file"; exit 1; }
    done < <(find "$skills_dir" -name "SKILL.md" -print0)
    [ "$found" -gt 0 ] || { echo "No SKILL.md files found under $skills_dir"; exit 1; }
}

# ── command files ─────────────────────────────────────────────────────────────

@test "all command .md files exist and are non-empty" {
    commands_dir="$REPO_ROOT/commands"
    found=0
    while IFS= read -r -d '' cmd_file; do
        found=$((found + 1))
        [ -s "$cmd_file" ] || { echo "Empty or missing: $cmd_file"; exit 1; }
    done < <(find "$commands_dir" -name "*.md" -print0)
    [ "$found" -gt 0 ] || { echo "No .md files found under $commands_dir"; exit 1; }
}

# ── run-hook.cmd ──────────────────────────────────────────────────────────────

@test "hooks/run-hook.cmd is executable" {
    [ -x "$REPO_ROOT/hooks/run-hook.cmd" ]
}

@test "document-lint accepts checkbox-style workflow steps" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/hotl-workflow-checkbox-sample.md"
    [ "$status" -eq 0 ]
}

# ── branch/worktree preflight ────────────────────────────────────────────────

@test "document-lint accepts workflow with branch and worktree fields" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/hotl-workflow-branch-sample.md"
    [ "$status" -eq 0 ]
}

@test "workflow-format.md documents branch and worktree fields" {
    grep -q '| `branch`' "$REPO_ROOT/docs/workflow-format.md"
    grep -q '| `worktree`' "$REPO_ROOT/docs/workflow-format.md"
}

@test "all three execution skills contain identical Branch/Worktree Preflight section" {
    extract() {
        python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
match = re.search(r'(## Branch/Worktree Preflight\n.*?)(?=\n## )', content, re.DOTALL)
print(match.group(1) if match else '')
" "$1"
    }
    loop=$(extract "$REPO_ROOT/skills/loop-execution/SKILL.md")
    exec_plans=$(extract "$REPO_ROOT/skills/executing-plans/SKILL.md")
    subagent=$(extract "$REPO_ROOT/skills/subagent-execution/SKILL.md")
    [ -n "$loop" ] || { echo "loop-execution missing preflight section"; return 1; }
    [ "$loop" = "$exec_plans" ] || { echo "loop-execution and executing-plans preflight sections differ"; return 1; }
    [ "$loop" = "$subagent" ] || { echo "loop-execution and subagent-execution preflight sections differ"; return 1; }
}

@test "workflow templates do not contain branch or worktree fields" {
    ! grep -q 'branch:' "$REPO_ROOT/workflows/feature.md"
    ! grep -q 'branch:' "$REPO_ROOT/workflows/bugfix.md"
    ! grep -q 'branch:' "$REPO_ROOT/workflows/refactor.md"
    ! grep -q 'worktree:' "$REPO_ROOT/workflows/feature.md"
    ! grep -q 'worktree:' "$REPO_ROOT/workflows/bugfix.md"
    ! grep -q 'worktree:' "$REPO_ROOT/workflows/refactor.md"
}

@test "writing-plans SKILL.md mentions branch and worktree as optional" {
    grep -q 'branch:' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q 'worktree:' "$REPO_ROOT/skills/writing-plans/SKILL.md"
}
