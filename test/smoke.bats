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

    mkdir -p "$source_dir/.git" "$source_dir/runtime" "$source_dir/skills" "$source_dir/scripts"
    printf 'main\n' > "$source_dir/.fake_branch"
    printf 'source runtime\n' > "$source_dir/runtime/hotl-rt"
    printf 'source document lint\n' > "$source_dir/scripts/document-lint.sh"
    printf 'source renderer\n' > "$source_dir/scripts/render-execution-summary.sh"
    printf 'source finalize\n' > "$source_dir/scripts/finalize-codex-summary.sh"
    printf 'source current step\n' > "$source_dir/scripts/show-codex-current-step.sh"
    printf 'source run locator\n' > "$source_dir/scripts/hotl-locate-run.sh"
    printf 'source update check\n' > "$source_dir/scripts/check-update.sh"
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
    grep -q 'hotl:finishing-a-development-branch' "$REPO_ROOT/skills/using-hotl/SKILL.md" || {
        echo "using-hotl index missing finishing-a-development-branch entry"
        return 1
    }
}

# ── JSON validity ─────────────────────────────────────────────────────────────

@test "plugin.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/.claude-plugin/plugin.json" > /dev/null
}

@test "Codex plugin manifest points skills at plugin-root-relative path" {
    skills_path=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.codex-plugin/plugin.json'))['skills'])")

    [ "$skills_path" = "./skills/" ] || {
        echo "Expected .codex-plugin/plugin.json skills path to be ./skills/, got: $skills_path"
        return 1
    }
}

@test "hooks/hooks.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/hooks/hooks.json" > /dev/null
}

@test "hooks/hooks-cursor.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/hooks/hooks-cursor.json" > /dev/null
}

@test "marketplace.json is valid JSON" {
    python3 -m json.tool "$REPO_ROOT/.claude-plugin/marketplace.json" > /dev/null
}

# ── session-start hook output ─────────────────────────────────────────────────

@test "session-start outputs valid JSON with SDK additionalContext by default" {
    output=$("$REPO_ROOT/hooks/session-start")
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'additionalContext' in data, 'missing additionalContext field'
assert 'additional_context' not in data, 'unexpected Cursor additional_context field'
assert 'hookSpecificOutput' not in data, 'unexpected Claude hookSpecificOutput field'
assert len(data['additionalContext']) > 0, 'additionalContext is empty'
" <<< "$output"
}

@test "session-start emits Claude Code hook shape only when CLAUDE_PLUGIN_ROOT is set" {
    output=$(env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start")
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'hookSpecificOutput' in data, 'missing hookSpecificOutput'
assert data['hookSpecificOutput']['hookEventName'] == 'SessionStart'
assert len(data['hookSpecificOutput']['additionalContext']) > 0
assert 'additional_context' not in data, 'unexpected duplicate Cursor field'
assert 'additionalContext' not in data, 'unexpected duplicate SDK field'
" <<< "$output"
}

@test "session-start emits Cursor hook shape only when CURSOR_PLUGIN_ROOT is set" {
    output=$(env CURSOR_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start")
    python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'additional_context' in data, 'missing Cursor additional_context field'
assert len(data['additional_context']) > 0
assert 'hookSpecificOutput' not in data, 'unexpected Claude hookSpecificOutput field'
assert 'additionalContext' not in data, 'unexpected SDK additionalContext field'
" <<< "$output"
}

@test "Claude hook config skips resume and uses double-quoted command path" {
    python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
entry = data['hooks']['SessionStart'][0]
assert entry['matcher'] == 'startup|clear|compact'
command = entry['hooks'][0]['command']
assert command.startswith('\"'), command
assert \"'\" not in command, command
" "$REPO_ROOT/hooks/hooks.json"
}

@test "Cursor plugin manifest uses Cursor-specific hook config" {
    hooks_path=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.cursor-plugin/plugin.json'))['hooks'])")
    [ "$hooks_path" = "./hooks/hooks-cursor.json" ]
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
context = data.get('additionalContext') or data.get('additional_context') or data.get('hookSpecificOutput', {}).get('additionalContext', '')
assert 'HOTL update available:' not in context
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

@test "version bump tooling reports declared versions in sync" {
    [ -x "$REPO_ROOT/scripts/bump-version.sh" ]
    [ -f "$REPO_ROOT/.version-bump.json" ]

    run bash "$REPO_ROOT/scripts/bump-version.sh" --check

    [ "$status" -eq 0 ]
    [[ "$output" == *"All declared files are in sync"* ]]
}

@test "version bump audit ignores local generated registries" {
    run bash "$REPO_ROOT/scripts/bump-version.sh" --audit

    [ "$status" -eq 0 ]
    [[ "$output" == *"No undeclared files contain the version string."* ]]
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

@test "skill-authoring skill is indexed and documented" {
    [ -s "$REPO_ROOT/skills/skill-authoring/SKILL.md" ]
    grep -q "name: skill-authoring" "$REPO_ROOT/skills/skill-authoring/SKILL.md"
    grep -q "hotl:skill-authoring" "$REPO_ROOT/skills/using-hotl/SKILL.md"
    grep -q "skill-authoring" "$REPO_ROOT/docs/skills.md"
    grep -q "skill-authoring" "$REPO_ROOT/README.md"
}

@test "document-review checks Codex install paths for document-lint" {
    grep -q '~/.codex/hotl/scripts/document-lint.sh' "$REPO_ROOT/skills/document-review/SKILL.md"
    grep -q '~/.codex/plugins/hotl-source/scripts/document-lint.sh' "$REPO_ROOT/skills/document-review/SKILL.md"
    grep -q '~/.codex/plugins/cache/codex-plugins/hotl/.*/scripts/document-lint.sh' "$REPO_ROOT/skills/document-review/SKILL.md"
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

@test "loop-execution path resolution covers Codex plugin installs" {
    grep -q '~/.codex/plugins/hotl-source/runtime/hotl-rt' "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q '~/.codex/plugins/cache/codex-plugins/hotl/.*/runtime/hotl-rt' "$REPO_ROOT/skills/loop-execution/SKILL.md"
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

@test "subagent-execution defines delegated worker statuses" {
    grep -q "DONE_WITH_CONCERNS" "$REPO_ROOT/skills/subagent-execution/SKILL.md"
    grep -q "NEEDS_CONTEXT" "$REPO_ROOT/skills/subagent-execution/SKILL.md"
    grep -q "BLOCKED" "$REPO_ROOT/skills/subagent-execution/SKILL.md"
    grep -q "Never mark a delegated step complete from the worker report alone" "$REPO_ROOT/skills/subagent-execution/SKILL.md"
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

@test "writing-plans documents default branch derivation and warns against brittle branch-name verifies" {
    grep -q 'Default branch derivation: `hotl/<slug>`' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q "Avoid brittle verify steps such as \`git branch --show-current" "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q 'copies the workflow into that worktree at the same relative path' "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q 'set both `branch: <current-branch>` and `worktree: false`' "$REPO_ROOT/skills/writing-plans/SKILL.md"
}

@test "writing-plans rejects placeholder-heavy workflow steps" {
    grep -q "No Placeholders" "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q "TBD" "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q "similar to Step N" "$REPO_ROOT/skills/writing-plans/SKILL.md"
    grep -q "undefined references" "$REPO_ROOT/skills/writing-plans/SKILL.md"
}

@test "workflow-format describes worktree isolation modes" {
    grep -q '`false` uses the current checkout and may create/switch to the target branch' "$REPO_ROOT/docs/workflow-format.md"
    grep -q '`host` uses the current feature branch' "$REPO_ROOT/docs/workflow-format.md"
    grep -q 'Uses host mode automatically' "$REPO_ROOT/docs/workflow-format.md"
}

@test "execution docs describe continuity chooser and source metadata" {
    grep -q 'source_branch' "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q 'source_head' "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q 'Continue on the current branch in this checkout' "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q 'interactive reuse/recreate is not implemented yet' "$REPO_ROOT/docs/workflow-format.md"
}

@test "execution root helper script exists" {
    [ -x "$REPO_ROOT/scripts/hotl-prepare-execution-root.sh" ]
}

@test "resume run locator script exists and execution docs use it before preflight" {
    [ -x "$REPO_ROOT/scripts/hotl-locate-run.sh" ]
    grep -q 'hotl-locate-run.sh --workflow' "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q 'hotl-locate-run.sh --workflow' "$REPO_ROOT/skills/resuming/SKILL.md"
    grep -q 'Branch/Worktree Preflight' "$REPO_ROOT/skills/loop-execution/SKILL.md"
}

@test "execution docs describe explicit run-id pinning" {
    grep -q -- '--run-id <run-id>' "$REPO_ROOT/skills/loop-execution/SKILL.md"
    grep -q -- '--run-id <run-id>' "$REPO_ROOT/docs/workflow-format.md"
}

@test "Claude Code execution commands delegate to canonical execution skills" {
    grep -q 'Invoke the hotl:loop-execution skill' "$REPO_ROOT/commands/loop.md"
    grep -q 'Invoke the hotl:executing-plans skill' "$REPO_ROOT/commands/execute-plan.md"
    grep -q 'Invoke the hotl:subagent-execution skill' "$REPO_ROOT/commands/subagent-execute.md"
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
    grep -q '\$hotl:brainstorming' "$REPO_ROOT/README.md"
    grep -q '\$hotl:brainstorming' "$REPO_ROOT/docs/README.codex.md"
    grep -q '@hotl' "$REPO_ROOT/docs/README.codex.md"
    grep -q 'describe the task in natural language' "$REPO_ROOT/README.md"
    grep -q 'describe the task in natural language' "$REPO_ROOT/docs/README.codex.md"
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
    assert_codex_prompt_resolves 'Use $hotl:brainstorming to design this feature before writing code.'
    assert_codex_prompt_resolves 'Use $hotl:writing-plans to create docs/plans/2026-04-22-add-oauth-login-workflow.md.'
    assert_codex_prompt_resolves 'Use $hotl:finishing-a-development-branch for run add-oauth-login-20260422T010203Z.'
    assert_codex_prompt_resolves 'Use $hotl:pr-reviewing to review https://github.com/org/repo/pull/123.'
    assert_codex_prompt_resolves 'Use HOTL for this task and choose the correct skill automatically.'
    assert_codex_prompt_resolves 'Use $hotl:skill-authoring before editing a HOTL skill.'
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
    assert_codex_prompt_resolves 'Use @hotl to compare OAuth and API-key auth before writing code.'
    assert_codex_prompt_resolves 'Use $hotl:writing-plans to create docs/plans/2026-04-22-add-rate-limiting-workflow.md.'
    assert_codex_prompt_resolves 'Review docs/plans/2026-04-22-add-rate-limiting-workflow.md with HOTL and tell me if it is ready to execute.'
    assert_codex_prompt_resolves 'Use $hotl:subagent-execution to execute docs/plans/2026-04-22-add-rate-limiting-workflow.md in this session.'
    assert_codex_prompt_resolves 'After execution finishes, use $hotl:finishing-a-development-branch for the run id.'
    assert_codex_prompt_resolves 'Before you say this task is done, use $hotl:verification-before-completion.'
    assert_codex_prompt_resolves 'Use HOTL for this task and choose the most appropriate skill automatically.'
}

@test "execution lifecycle docs mention finishing-a-development-branch" {
    grep -q 'finishing-a-development-branch' "$REPO_ROOT/README.md"
    grep -q 'finishing-a-development-branch' "$REPO_ROOT/.codex/INSTALL.md"
    grep -q 'finishing-a-development-branch' "$REPO_ROOT/docs/README.codex.md"
    grep -q 'finishing-a-development-branch' "$REPO_ROOT/docs/skills.md"
    grep -q '## Finish Outcome' "$REPO_ROOT/docs/contracts/execution-report-output.md"
}

@test "Codex docs describe canonical design and workflow artifact locations" {
    grep -q 'docs/designs/' "$REPO_ROOT/README.md"
    grep -q 'docs/plans/YYYY-MM-DD-<slug>-workflow.md' "$REPO_ROOT/README.md"
    grep -q 'docs/plans/YYYY-MM-DD-<slug>-workflow.md' "$REPO_ROOT/.codex/INSTALL.md"
    grep -q 'docs/plans/2026-04-22-add-rate-limiting-workflow.md' "$REPO_ROOT/docs/README.codex.md"
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
    [ -f "$cache_dir/scripts/document-lint.sh" ]
    [ -f "$cache_dir/scripts/render-execution-summary.sh" ]
    [ -f "$cache_dir/scripts/finalize-codex-summary.sh" ]
    [ -f "$cache_dir/scripts/show-codex-current-step.sh" ]
    [ -f "$cache_dir/scripts/hotl-locate-run.sh" ]
    [ -f "$cache_dir/scripts/check-update.sh" ]
}

@test "update.sh --codex-plugin refreshes Codex plugin cache from source checkout" {
    tmp_home="$(mktemp -d)"
    fake_bin="$tmp_home/bin"
    fake_log="$tmp_home/git.log"
    cache_dir="$tmp_home/.codex/plugins/cache/codex-plugins/hotl/local"

    : > "$fake_log"
    make_fake_git "$fake_bin" "$fake_log"
    make_fake_codex_plugin_source "$tmp_home"
    mkdir -p "$cache_dir/runtime" "$cache_dir/scripts"
    printf 'stale runtime\n' > "$cache_dir/runtime/hotl-rt"
    printf 'stale renderer\n' > "$cache_dir/scripts/render-execution-summary.sh"

    run env HOME="$tmp_home" PATH="$fake_bin:$PATH" FAKE_GIT_LOG="$fake_log" bash "$REPO_ROOT/update.sh" --codex-plugin

    [ "$status" -eq 0 ]
    [[ "$output" == *"Refreshing Codex plugin cache at ${cache_dir}/..."* ]]
    [[ "$output" == *"Codex plugin cache refreshed."* ]]
    grep -q "fetch ${tmp_home}/.codex/plugins/hotl-source origin main" "$fake_log"
    grep -q "reset ${tmp_home}/.codex/plugins/hotl-source origin/main" "$fake_log"
    [ "$(cat "$cache_dir/runtime/hotl-rt")" = "source runtime" ]
    [ "$(cat "$cache_dir/scripts/document-lint.sh")" = "source document lint" ]
    [ "$(cat "$cache_dir/scripts/render-execution-summary.sh")" = "source renderer" ]
    [ "$(cat "$cache_dir/scripts/finalize-codex-summary.sh")" = "source finalize" ]
    [ "$(cat "$cache_dir/scripts/show-codex-current-step.sh")" = "source current step" ]
    [ "$(cat "$cache_dir/scripts/hotl-locate-run.sh")" = "source run locator" ]
    [ "$(cat "$cache_dir/scripts/check-update.sh")" = "source update check" ]
}

# ── design document lint warnings ────────────────────────────────────────────

@test "design lint warns on file:line refs in feature design" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-bad-file-line-design.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "category=implementation-leakage"
    echo "$output" | grep -q "cli.py:16"
}

@test "design lint warns on code blocks over 10 lines in feature design" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-bad-code-block-design.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "category=implementation-leakage"
    echo "$output" | grep -q "code block"
}

@test "design lint warns on dense flag lines in feature design" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-bad-flag-line-design.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "category=implementation-leakage"
    echo "$output" | grep -q "dense flag"
}

@test "design lint warns on missing required section in feature design" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-bad-missing-section-design.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "category=structure"
    echo "$output" | grep -q "Decisions"
}

@test "design lint emits no structure or leakage warnings on contract-type doc" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/ok-architecture-contract-design.md"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "category=structure"
    ! echo "$output" | grep -q "category=implementation-leakage"
    echo "$output" | grep -q "LINT PASSED"
}

@test "design lint resolves phase from phase-N filename slug" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-phase-7-bad-file-line-design.md"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "category=implementation-leakage"
    echo "$output" | grep -q "design_type=phase"
    echo "$output" | grep -q "cli.py:42"
}

@test "design lint skips frontmatter-less feature-design doc post-opt-in" {
    # Post-Phase-1.6: a *-design.md file with no frontmatter has no HOTL marker
    # and SKIPs at the opt-in gate. The Phase 1.5 body-extraction fix that this
    # test originally guarded is unreachable through the gate; coverage overlaps
    # with test 78 but is kept as a regression guard against gate weakening.
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-no-frontmatter-feature-design.md" 2>&1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SKIP:"
    echo "$output" | grep -q "not a HOTL-managed"
    ! echo "$output" | grep -q "category=structure"
    ! echo "$output" | grep -q "category=implementation-leakage"
}

@test "design lint does not flag wide markdown table rows" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-table-not-flag-design.md"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "category=implementation-leakage"
    ! echo "$output" | grep -q "category=structure"
    echo "$output" | grep -q "LINT PASSED:"
}

@test "design lint skips unmarked undated design-folder docs" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/unmarked-architecture-no-frontmatter-design.md" 2>&1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SKIP:"
    echo "$output" | grep -q "not a HOTL-managed"
    ! echo "$output" | grep -q "category=structure"
    ! echo "$output" | grep -q "category=implementation-leakage"
}

@test "design lint skips dated *-design.md without HOTL marker" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-unmarked-no-frontmatter-design.md" 2>&1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SKIP:"
    echo "$output" | grep -q "not a HOTL-managed"
    ! echo "$output" | grep -q "category=structure"
    ! echo "$output" | grep -q "category=implementation-leakage"
}

@test "design lint applies HOTL rules to docs marked via hotl_managed frontmatter" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-marked-via-hotl-managed-design.md" 2>&1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "category=implementation-leakage"
    echo "$output" | grep -q "cli.py:55"
    echo "$output" | grep -q "LINT PASSED:"
}

@test "design lint accepts quoted YAML scalar for design_type marker" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$REPO_ROOT/test/fixtures/doc-discipline/2099-01-01-quoted-design-type-design.md" 2>&1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "LINT PASSED:"
    ! echo "$output" | grep -q "SKIP:"
}
