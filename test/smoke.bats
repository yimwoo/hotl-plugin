#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

make_fake_git() {
    local bin_dir="$1"
    local log_file="$2"

    mkdir -p "$bin_dir"
    cat > "$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${FAKE_GIT_LOG:?}"
repo=""
if [ "${1:-}" = "-C" ]; then
    repo="$2"
    shift 2
fi

cmd="${1:-}"
shift || true

branch_file="${repo}/.fake_branch"
dirty_file="${repo}/.fake_dirty"

case "$cmd" in
    rev-parse)
        if [ "${1:-}" = "--is-inside-work-tree" ]; then
            [ -d "$repo" ] || exit 1
            echo "true"
            exit 0
        fi
        ;;
    branch)
        if [ "${1:-}" = "--show-current" ]; then
            cat "$branch_file"
            exit 0
        fi
        ;;
    diff)
        if [ "${1:-}" = "--quiet" ] || { [ "${1:-}" = "--cached" ] && [ "${2:-}" = "--quiet" ]; }; then
            [ ! -f "$dirty_file" ]
            exit $?
        fi
        ;;
    pull)
        echo "pull $repo" >> "$LOG_FILE"
        exit 0
        ;;
esac

echo "Unexpected fake git invocation: $repo $cmd $*" >&2
exit 1
EOF
    chmod +x "$bin_dir/git"
}

make_fake_codex_install() {
    local home_dir="$1"
    local target_dir="$2"
    local branch_name="$3"

    mkdir -p "$target_dir/skills" "$home_dir/.codex" "$home_dir/.agents/skills"
    printf '%s\n' "$branch_name" > "$target_dir/.fake_branch"
    ln -s "$target_dir" "$home_dir/.codex/hotl"
    ln -s "$home_dir/.codex/hotl/skills" "$home_dir/.agents/skills/hotl"
}

assert_codex_prompt_resolves() {
    local prompt="$1"
    local skill_name
    local skill_path

    if [[ "$prompt" =~ hotl:[a-z-]+ ]]; then
        skill_name="${BASH_REMATCH[0]#hotl:}"
        skill_path="$REPO_ROOT/skills/$skill_name/SKILL.md"
        [ -f "$skill_path" ] || {
            echo "Missing skill for prompt: $prompt ($skill_path)"
            return 1
        }
        grep -q "name: $skill_name" "$skill_path" || {
            echo "Skill frontmatter mismatch for prompt: $prompt"
            return 1
        }
        return 0
    fi

    grep -q 'name: using-hotl' "$REPO_ROOT/skills/using-hotl/SKILL.md" || {
        echo "using-hotl dispatcher skill missing"
        return 1
    }
    grep -q 'hotl:brainstorming' "$REPO_ROOT/skills/using-hotl/SKILL.md" || {
        echo "using-hotl index missing brainstorming entry"
        return 1
    }
    grep -q 'hotl:writing-plans' "$REPO_ROOT/skills/using-hotl/SKILL.md" || {
        echo "using-hotl index missing writing-plans entry"
        return 1
    }
    grep -q 'hotl:pr-review' "$REPO_ROOT/skills/using-hotl/SKILL.md" || {
        echo "using-hotl index missing pr-review entry"
        return 1
    }
}

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

@test "Codex install docs consistently use ~/.codex/hotl" {
    grep -q '~/.codex/hotl' "$REPO_ROOT/README.md"
    grep -q '~/.codex/hotl' "$REPO_ROOT/.codex/INSTALL.md"
    grep -q '~/.codex/hotl' "$REPO_ROOT/docs/README.codex.md"
    ! grep -q '~/.codex/hotl-plugin' "$REPO_ROOT/README.md"
    ! grep -q '~/.codex/hotl-plugin' "$REPO_ROOT/.codex/INSTALL.md"
    ! grep -q '~/.codex/hotl-plugin' "$REPO_ROOT/docs/README.codex.md"
}

@test "Codex docs explain restart after updating skills" {
    grep -q 'Restart Codex' "$REPO_ROOT/docs/README.codex.md"
    grep -q 'Restart Codex' "$REPO_ROOT/README.md"
}

@test "Codex docs explain skill invocation without slash commands" {
    grep -q 'There is no `/hotl:' "$REPO_ROOT/README.md"
    grep -q 'There is no `/hotl:' "$REPO_ROOT/docs/README.codex.md"
    grep -q 'Ask Codex to use `hotl:brainstorming`' "$REPO_ROOT/README.md"
    grep -q 'Ask Codex to use `hotl:brainstorming`' "$REPO_ROOT/docs/README.codex.md"
}

@test "Codex prompt examples resolve to installed HOTL skills locally" {
    assert_codex_prompt_resolves 'Use hotl:brainstorming to design this feature before writing code.'
    assert_codex_prompt_resolves 'Use hotl:writing-plans to create a hotl-workflow file for adding OAuth login.'
    assert_codex_prompt_resolves 'Use hotl:pr-review to review https://github.com/org/repo/pull/123.'
    assert_codex_prompt_resolves 'Use HOTL for this task and choose the correct skill automatically.'
}

@test "update.sh updates Codex when ~/.codex/hotl is a symlink to a clean main worktree" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "main"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Updating Codex plugin at ${tmp_home}/.codex/hotl..."* ]]
    [[ "$output" == *"Codex plugin updated."* ]]
    grep -q "pull ${tmp_home}/.codex/hotl" "$fake_log"
}

@test "update.sh skips Codex on non-main branch unless forced" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "feature/hotl-test"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Codex install is on branch feature/hotl-test; skipping to avoid mutating a feature branch."* ]]
    [[ "$output" == *"--force-codex"* ]]
    [ ! -f "$fake_log" ] || ! grep -q "pull ${tmp_home}/.codex/hotl" "$fake_log"
}

@test "update.sh force-updates Codex on non-main branch with --force-codex" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "feature/hotl-test"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh" --force-codex

    [ "$status" -eq 0 ]
    [[ "$output" == *"Updating Codex plugin at ${tmp_home}/.codex/hotl..."* ]]
    grep -q "pull ${tmp_home}/.codex/hotl" "$fake_log"
}

@test "update.sh reminds Codex users to restart after an update" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "main"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Restart Codex"* ]]
}
