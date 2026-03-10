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
