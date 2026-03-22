#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    RENDERER="$REPO_ROOT/scripts/render-execution-summary.sh"
    SUMMARY_FIXTURES="$REPO_ROOT/test/fixtures/summary"
}

render_and_compare() {
    local fixture="$1"
    local platform="$2"
    local expected_ext="$3"
    local expected_file="$SUMMARY_FIXTURES/${fixture}.${expected_ext}"

    run "$RENDERER" --platform "$platform" "$SUMMARY_FIXTURES/${fixture}.json"
    [ "$status" -eq 0 ]
    diff -u "$expected_file" <(printf '%s\n' "$output")
}

@test "codex renderer matches happy gate fixture" {
    render_and_compare "happy-gate" "codex" "codex.txt"
}

@test "codex renderer preserves auto-approved gate status" {
    render_and_compare "auto-gate" "codex" "codex.txt"
}

@test "codex renderer matches retry fixture" {
    render_and_compare "retry-pass" "codex" "codex.txt"
}

@test "codex renderer matches mixed outcomes fixture" {
    render_and_compare "mixed-outcomes" "codex" "codex.txt"
}

@test "claude renderer matches table fixture" {
    render_and_compare "happy-gate" "claude" "table.txt"
}

@test "cline renderer matches table fixture" {
    render_and_compare "mixed-outcomes" "cline" "table.txt"
}

@test "table renderer escapes markdown delimiters in step names" {
    render_and_compare "escaped-name" "claude" "table.txt"
}
