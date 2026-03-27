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
    status)
        if [ "${1:-}" = "--short" ] || [ "${1:-}" = "--porcelain" ]; then
            if [ -f "$dirty_file" ]; then
                printf ' M README.md\n'
            fi
            if [ "${2:-}" = "--branch" ] || [ "${3:-}" = "--branch" ]; then
                printf '## %s\n' "$(cat "$branch_file")"
            fi
            exit 0
        fi
        ;;
    diff)
        if [ "${1:-}" = "--quiet" ] || { [ "${1:-}" = "--cached" ] && [ "${2:-}" = "--quiet" ]; }; then
            [ ! -f "$dirty_file" ]
            exit $?
        fi
        ;;
    fetch)
        echo "fetch $repo ${1:-} ${2:-}" >> "$LOG_FILE"
        exit 0
        ;;
    pull)
        echo "pull $repo" >> "$LOG_FILE"
        exit 0
        ;;
    reset)
        if [ "${1:-}" = "--hard" ]; then
            rm -f "$dirty_file"
            echo "reset $repo ${2:-}" >> "$LOG_FILE"
            exit 0
        fi
        ;;
    clean)
        echo "clean $repo $*" >> "$LOG_FILE"
        exit 0
        ;;
    switch)
        target_branch="${1:-}"
        [ -n "$target_branch" ] || {
            echo "Missing branch name for fake git switch" >&2
            exit 1
        }
        printf '%s\n' "$target_branch" > "$branch_file"
        echo "switch $repo $target_branch" >> "$LOG_FILE"
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

make_fake_codex_plugin_source() {
    local home_dir="$1"
    local source_dir="$home_dir/.codex/plugins/hotl-source"

    mkdir -p "$source_dir/.git" "$source_dir/runtime" "$source_dir/skills"
    printf 'main\n' > "$source_dir/.fake_branch"
    printf 'source runtime\n' > "$source_dir/runtime/hotl-rt"
    printf 'source skill\n' > "$source_dir/skills/sample.txt"
    printf '9.9.9\n' > "$source_dir/VERSION"
}

mark_fake_codex_dirty() {
    local target_dir="$1"

    : > "$target_dir/.fake_dirty"
    printf 'local change\n' > "$target_dir/README.md"
}

assert_codex_prompt_resolves() {
    local prompt="$1"
    local skill_name
    local skill_path

    if [[ "$prompt" =~ \$((hotl:)?[a-z-]+) ]]; then
        skill_name="${BASH_REMATCH[1]#hotl:}"
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
    grep -q 'hotl:pr-reviewing' "$REPO_ROOT/skills/using-hotl/SKILL.md" || {
        echo "using-hotl index missing pr-reviewing entry"
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
    output=$("$REPO_ROOT/hooks/session-start")
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'additional_context' in data, 'missing additional_context field'
assert len(data['additional_context']) > 0, 'additional_context is empty'
" <<< "$output"
}

@test "check-update refreshes a fresh cache entry when cached latest is older than installed" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    installed_version="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"

    mkdir -p "$fake_bin" "$tmp_home/.cache/hotl"

    cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat <<'JSON'
{"tag_name":"v9.9.9","html_url":"https://example.com/releases/v9.9.9"}
JSON
EOF
    chmod +x "$fake_bin/curl"

    cat > "$tmp_home/.cache/hotl/update-check.json" <<'EOF'
{
  "latest_version": "2.0.0",
  "checked_at": "2099-01-01T00:00:00Z",
  "source": "github-api",
  "release_url": "https://example.com/releases/v2.0.0"
}
EOF

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" bash "$REPO_ROOT/scripts/check-update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"HOTL update available: ${installed_version} → 9.9.9"* ]]
    grep -q '"latest_version": "9.9.9"' "$tmp_home/.cache/hotl/update-check.json"
}

@test "session-start does not expose unsupported sessionStartNotice metadata" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"

    mkdir -p "$fake_bin" "$tmp_home/.cache/hotl"

    cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat <<'JSON'
{"tag_name":"v9.9.9","html_url":"https://example.com/releases/v9.9.9"}
JSON
EOF
    chmod +x "$fake_bin/curl"

    output=$(env HOME="$tmp_home" PATH="$fake_bin:$PATH" "$REPO_ROOT/hooks/session-start" 2>/dev/null)
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'HOTL update available:' not in data['additional_context']
assert 'sessionStartNotice' not in data.get('hookSpecificOutput', {})
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

# ── output contracts ──────────────────────────────────────────────────────────

@test "pr-review output contract contains all 9 required sections" {
    contract="$REPO_ROOT/docs/contracts/pr-review-output.md"
    [ -f "$contract" ] || { echo "Contract file missing: $contract"; return 1; }
    grep -q "PR Metadata" "$contract"
    grep -q "Description Verdict" "$contract"
    grep -q "Ticket Alignment Verdict" "$contract"
    grep -q "Code Changes Verdict" "$contract"
    grep -q "Code Scan Verdict" "$contract"
    grep -q "Unit Tests Verdict" "$contract"
    grep -q "Overall Verdict" "$contract"
    grep -q "Consolidated Findings" "$contract"
    grep -q "Verification Notes" "$contract"
}

@test "pr-reviewing skill references the output contract" {
    grep -q "docs/contracts/pr-review-output.md" "$REPO_ROOT/skills/pr-reviewing/SKILL.md"
}

# ── version parity ───────────────────────────────────────────────────────────

@test "VERSION file matches all manifest versions" {
    local ver
    ver=$(cat "$REPO_ROOT/VERSION" | tr -d '[:space:]')
    [ -n "$ver" ] || { echo "VERSION file is empty"; return 1; }

    local claude_ver cursor_ver market_ver codex_ver
    claude_ver=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.claude-plugin/plugin.json'))['version'])")
    cursor_ver=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.cursor-plugin/plugin.json'))['version'])")
    market_ver=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.claude-plugin/marketplace.json'))['plugins'][0]['version'])")
    codex_ver=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.codex-plugin/plugin.json'))['version'])")

    [ "$ver" = "$claude_ver" ] || { echo "VERSION ($ver) != .claude-plugin/plugin.json ($claude_ver)"; return 1; }
    [ "$ver" = "$cursor_ver" ] || { echo "VERSION ($ver) != .cursor-plugin/plugin.json ($cursor_ver)"; return 1; }
    [ "$ver" = "$market_ver" ] || { echo "VERSION ($ver) != .claude-plugin/marketplace.json ($market_ver)"; return 1; }
    [ "$ver" = "$codex_ver" ] || { echo "VERSION ($ver) != .codex-plugin/plugin.json ($codex_ver)"; return 1; }
}

@test ".codex-plugin/marketplace.json does not exist (installer generates entries)" {
    [ ! -f "$REPO_ROOT/.codex-plugin/marketplace.json" ]
}

# ── command/skill name collision guard ────────────────────────────────────────

@test "no command shares a name with a skill directory (prevents Skill tool loop)" {
    # Commands and skills must use different names. If a command and skill share
    # a name, the Skill tool either loops (without disable-model-invocation) or
    # blocks (with it). Convention: command=short name, skill=longer variant
    # (e.g. command brainstorm → skill brainstorming).
    collisions=()
    for cmd_file in "$REPO_ROOT"/commands/*.md; do
        cmd_name="$(basename "$cmd_file" .md)"
        if [ -d "$REPO_ROOT/skills/$cmd_name" ]; then
            collisions+=("$cmd_name")
        fi
    done
    if [ "${#collisions[@]}" -gt 0 ]; then
        echo "Command/skill name collision(s) found: ${collisions[*]}"
        echo "Rename the skill directory so it differs from the command name."
        echo "Convention: command=short (e.g. pr-review), skill=longer (e.g. pr-reviewing)"
        return 1
    fi
}

# ── resumable execution ──────────────────────────────────────────────────────

@test "resume command exists and invokes hotl:resuming" {
    [ -f "$REPO_ROOT/commands/resume.md" ]
    grep -q "hotl:resuming" "$REPO_ROOT/commands/resume.md"
}

@test "resuming skill exists with verify-first and sidecar state" {
    [ -f "$REPO_ROOT/skills/resuming/SKILL.md" ]
    grep -q "verify-first" "$REPO_ROOT/skills/resuming/SKILL.md"
    grep -q ".hotl/state" "$REPO_ROOT/skills/resuming/SKILL.md"
}

@test "using-hotl skill index lists hotl:resuming" {
    grep -q "hotl:resuming" "$REPO_ROOT/skills/using-hotl/SKILL.md"
}

# ── run-hook.cmd ──────────────────────────────────────────────────────────────

@test "hooks/run-hook.cmd is executable" {
    [ -x "$REPO_ROOT/hooks/run-hook.cmd" ]
}

@test "document-lint accepts checkbox-style workflow steps" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/hotl-workflow-checkbox-sample.md"
    [ "$status" -eq 0 ]
}

@test "document-lint accepts demo simulation workflow fixture" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/demo-simulation-workflow.md"
    [ "$status" -eq 0 ]
}

# ── execution reporting ──────────────────────────────────────────────────────

@test "workflow-format.md documents progress field" {
    grep -q '| `progress`' "$REPO_ROOT/docs/workflow-format.md"
    grep -q 'verbose' "$REPO_ROOT/docs/workflow-format.md"
}

@test "workflow-format.md documents report_detail field" {
    grep -q '| `report_detail`' "$REPO_ROOT/docs/workflow-format.md"
}

@test "workflow-format.md documents dirty_worktree field" {
    grep -q '| `dirty_worktree`' "$REPO_ROOT/docs/workflow-format.md"
}

@test "loop-execution references execution report contract and defines live behavior" {
    grep -q "execution-report-output.md" "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q "Live Step Visibility" "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q "verbose" "$REPO_ROOT/skills/loop-execution/SKILL.md"
    test -f "$REPO_ROOT/docs/contracts/execution-report-output.md"
    grep -q "Iterations" "$REPO_ROOT/docs/contracts/execution-report-output.md"
}

# ── typed verification ───────────────────────────────────────────────────────

@test "document-lint accepts typed verification workflow" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/hotl-workflow-typed-verify-sample.md"
    [ "$status" -eq 0 ]
}

@test "workflow-format.md documents all 4 verification types" {
    grep -q 'type: shell' "$REPO_ROOT/docs/workflow-format.md"
    grep -q 'type: browser' "$REPO_ROOT/docs/workflow-format.md"
    grep -q 'type: human-review' "$REPO_ROOT/docs/workflow-format.md"
    grep -q 'type: artifact' "$REPO_ROOT/docs/workflow-format.md"
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

@test "loop-execution and executing-plans contain identical Branch/Worktree Preflight section" {
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
    [ -n "$loop" ] || { echo "loop-execution missing preflight section"; return 1; }
    [ "$loop" = "$exec_plans" ] || { echo "loop-execution and executing-plans preflight sections differ"; return 1; }
}

@test "subagent-execution references the canonical execution state machine" {
    grep -q "Execution State Machine" "$REPO_ROOT/skills/subagent-execution/SKILL.md"
    grep -q "Critical Invariants" "$REPO_ROOT/skills/subagent-execution/SKILL.md"
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
    grep -q '\$brainstorming' "$REPO_ROOT/README.md"
    grep -q '\$brainstorming' "$REPO_ROOT/docs/README.codex.md"
    grep -q 'describe the task in natural language' "$REPO_ROOT/README.md"
    grep -q 'Describe the task in natural language' "$REPO_ROOT/docs/README.codex.md"
}

@test "Codex docs explain the stable channel and HOTL skill discovery path" {
    grep -q 'stable channel' "$REPO_ROOT/README.md"
    grep -q '~/.agents/skills/hotl' "$REPO_ROOT/README.md"
    grep -q 'stable channel' "$REPO_ROOT/docs/README.codex.md"
    grep -q '~/.agents/skills/hotl' "$REPO_ROOT/docs/README.codex.md"
    grep -q 'stable channel' "$REPO_ROOT/.codex/INSTALL.md"
    grep -q '~/.agents/skills/hotl' "$REPO_ROOT/.codex/INSTALL.md"
}

@test "Codex prompt examples resolve to installed HOTL skills locally" {
    assert_codex_prompt_resolves 'Use $brainstorming to design this feature before writing code.'
    assert_codex_prompt_resolves 'Use $writing-plans to create a hotl-workflow file for adding OAuth login.'
    assert_codex_prompt_resolves 'Use $pr-reviewing to review https://github.com/org/repo/pull/123.'
    assert_codex_prompt_resolves 'Use HOTL for this task and choose the correct skill automatically.'
}

@test "install.sh succeeds on a fresh HOME without pre-existing plugin directories" {
    tmp_home="$(mktemp -d)"

    run env HOME="$tmp_home" bash "$REPO_ROOT/install.sh"

    [ "$status" -eq 0 ]
    [ -d "$tmp_home/.claude/plugins/hotl" ]
    [ -f "$tmp_home/.claude/plugins/hotl/update.sh" ]
    [ -d "$tmp_home/.claude/plugins/hotl/skills" ]
}

@test "docs/README.codex.md prompt examples resolve to installed HOTL skills locally" {
    assert_codex_prompt_resolves 'Use $brainstorming to compare OAuth and API-key auth before writing code.'
    assert_codex_prompt_resolves 'Use $writing-plans to create hotl-workflow-add-rate-limiting.md.'
    assert_codex_prompt_resolves 'Review hotl-workflow-add-rate-limiting.md with HOTL and tell me if it is ready to execute.'
    assert_codex_prompt_resolves 'Use $subagent-execution to execute hotl-workflow-add-rate-limiting.md in this session.'
    assert_codex_prompt_resolves 'Before you say this task is done, use $verification-before-completion.'
    assert_codex_prompt_resolves 'Use HOTL for this task and choose the most appropriate skill automatically.'
}

@test "docs/README.cline.md documents the current global rule set" {
    rule_count=$(find "$REPO_ROOT/cline/rules" -maxdepth 1 -name 'hotl-*.md' | wc -l | tr -d ' ')
    grep -q "HOTL installs ${rule_count} rule files" "$REPO_ROOT/docs/README.cline.md"
    grep -q 'hotl-document-review.md' "$REPO_ROOT/docs/README.cline.md"
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
    [[ "$output" == *"Updating Codex native-skills install at ${tmp_home}/.codex/hotl..."* ]]
    [[ "$output" == *"Codex native-skills install updated."* ]]
    grep -q "fetch ${tmp_home}/.codex/hotl origin main" "$fake_log"
    grep -q "reset ${tmp_home}/.codex/hotl origin/main" "$fake_log"
}

@test "update.sh switches Codex back to main on a clean non-main branch" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "feature/hotl-test"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Codex install is on branch feature/hotl-test; switching back to stable branch main."* ]]
    [[ "$output" == *"Updating Codex native-skills install at ${tmp_home}/.codex/hotl..."* ]]
    grep -q "switch ${tmp_home}/.codex/hotl main" "$fake_log"
    grep -q "fetch ${tmp_home}/.codex/hotl origin main" "$fake_log"
    grep -q "reset ${tmp_home}/.codex/hotl origin/main" "$fake_log"
}

@test "update.sh backs up dirty Codex installs before resetting to stable main" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "main"
    mark_fake_codex_dirty "$codex_target"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Codex native-skills install has local changes; backed them up to ${tmp_home}/.codex/backups/hotl/"* ]]
    [[ "$output" == *"Updating Codex native-skills install at ${tmp_home}/.codex/hotl..."* ]]
    grep -q "fetch ${tmp_home}/.codex/hotl origin main" "$fake_log"
    grep -q "reset ${tmp_home}/.codex/hotl origin/main" "$fake_log"
    [ -d "$tmp_home/.codex/backups/hotl" ]
    [ "$(find "$tmp_home/.codex/backups/hotl" -path '*/worktree/README.md' | wc -l | tr -d ' ')" -ge 1 ]
}

@test "update.sh --force-codex resets dirty Codex installs without creating a backup" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "feature/hotl-test"
    mark_fake_codex_dirty "$codex_target"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh" --force-codex

    [ "$status" -eq 0 ]
    [[ "$output" == *"--force-codex set, skipping backup and resetting to origin/main."* ]]
    [[ "$output" == *"switching back to stable branch main."* ]]
    grep -q "switch ${tmp_home}/.codex/hotl main" "$fake_log"
    grep -q "fetch ${tmp_home}/.codex/hotl origin main" "$fake_log"
    grep -q "reset ${tmp_home}/.codex/hotl origin/main" "$fake_log"
    [ ! -d "$tmp_home/.codex/backups/hotl" ]
}

@test "update.sh reminds users to restart after an update" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    codex_target="$tmp_home/codex-worktree"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_install "$tmp_home" "$codex_target" "main"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Restart"* ]]
}

@test "install.sh --codex-plugin --local seeds Codex plugin cache" {
    tmp_home="$(mktemp -d)"
    cache_dir="$tmp_home/.codex/plugins/cache/codex-plugins/hotl/local"

    run env HOME="$tmp_home" bash "$REPO_ROOT/install.sh" --codex-plugin --local

    [ "$status" -eq 0 ]
    [[ "$output" == *"Seeding Codex plugin cache at ${cache_dir}..."* ]]
    [[ "$output" == *"Codex plugin cache refreshed."* ]]
    [ -f "$cache_dir/.codex-plugin/plugin.json" ]
    [ -f "$cache_dir/runtime/hotl-rt" ]
}

@test "update.sh --codex-plugin refreshes Codex plugin cache from source checkout" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    cache_dir="$tmp_home/.codex/plugins/cache/codex-plugins/hotl/local"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_plugin_source "$tmp_home"
    mkdir -p "$cache_dir/runtime"
    printf 'stale runtime\n' > "$cache_dir/runtime/hotl-rt"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh" --codex-plugin

    [ "$status" -eq 0 ]
    [[ "$output" == *"Refreshing Codex plugin cache at ${cache_dir}/..."* ]]
    [[ "$output" == *"Codex plugin cache refreshed."* ]]
    grep -q "fetch ${tmp_home}/.codex/plugins/hotl-source origin main" "$fake_log"
    grep -q "reset ${tmp_home}/.codex/plugins/hotl-source origin/main" "$fake_log"
    [ "$(cat "$cache_dir/runtime/hotl-rt")" = "source runtime" ]
}
