#!/usr/bin/env bats
#
# Slice 1 smoke tests — enforces the exit contract, install-path resolution,
# opt-in decision-log behavior, and small-user safety regression from
# docs/designs/slice-1-config-reader-plan.md §2.1.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_CONFIG_SH="$REPO_ROOT/scripts/hotl-config.sh"
    HOTL_CONFIG_RESOLVE="$REPO_ROOT/scripts/hotl-config-resolve.sh"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    FIXTURES="$REPO_ROOT/test/fixtures"
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Group A: hotl-config.sh exit contract ───────────────────────────────────

@test "A1: field absent, no default → empty stdout, exit 0" {
    run bash "$HOTL_CONFIG_SH" get plans_dir
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "A2: field absent, default provided → default on stdout, exit 0" {
    run bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans
    [ "$status" -eq 0 ]
    [ "$output" = "docs/plans" ]
}

@test "A3: field present in config → value on stdout, exit 0" {
    mkdir -p .hotl
    echo "plans_dir: custom/plans" > .hotl/config.yml
    run bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans
    [ "$status" -eq 0 ]
    [ "$output" = "custom/plans" ]
}

@test "A4: malformed config → non-zero exit, stderr explains" {
    mkdir -p .hotl
    printf "plans_dir: [unterminated\n" > .hotl/config.yml
    run bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "config"
}

@test "A5: unknown subcommand → non-zero exit, usage on stderr" {
    run bash "$HOTL_CONFIG_SH" foo
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "usage"
}

# ── Group B: install-path resolution ────────────────────────────────────────

@test "B1: doc-parity between document-lint.sh and hotl-config.sh resolution blocks" {
    local skill="$REPO_ROOT/skills/document-review/SKILL.md"
    [ -f "$skill" ]

    # Each resolution block is a numbered list (1. … 6.) of backticked paths.
    # Extract only numbered-list lines, pull the backticked path token, and
    # normalize the script name to CANONICAL so the two lists should be equal.
    LINT_PATHS=$(grep -E '^[0-9]+\. ' "$skill" \
        | grep -Eo '`[^`]*document-lint\.sh`' \
        | sed 's|document-lint\.sh|CANONICAL|')
    CFG_PATHS=$(grep -E '^[0-9]+\. ' "$skill" \
        | grep -Eo '`[^`]*hotl-config\.sh`' \
        | sed 's|hotl-config\.sh|CANONICAL|')

    [ -n "$LINT_PATHS" ]
    [ -n "$CFG_PATHS" ]

    # Exactly six locations per block.
    LINT_COUNT=$(printf '%s\n' "$LINT_PATHS" | wc -l | tr -d ' ')
    CFG_COUNT=$(printf '%s\n' "$CFG_PATHS" | wc -l | tr -d ' ')
    [ "$LINT_COUNT" -eq 6 ]
    [ "$CFG_COUNT" -eq 6 ]

    # Shape parity: the six locations must match in order.
    [ "$LINT_PATHS" = "$CFG_PATHS" ]
}

@test "B2: synthetic install resolves and forwards" {
    FAKE_ROOT=$(mktemp -d)
    mkdir -p "$FAKE_ROOT/hotl/scripts"
    cp "$HOTL_CONFIG_SH" "$FAKE_ROOT/hotl/scripts/"

    # Resolver should locate via HOTL_INSTALL_OVERRIDE and forward argv.
    run env HOTL_INSTALL_OVERRIDE="$FAKE_ROOT" bash "$HOTL_CONFIG_RESOLVE" get plans_dir --default=docs/plans
    [ "$status" -eq 0 ]
    [ "$output" = "docs/plans" ]

    rm -rf "$FAKE_ROOT"
}

# ── Group C: decision log opt-in contract ───────────────────────────────────

@test "C1: no config → log-decision is a no-op (no file created)" {
    run bash "$HOTL_RT" log-decision '{"event":"test"}'
    [ "$status" -eq 0 ]
    [ ! -e .hotl ]
    [ ! -e .hotl/decisions.log ]
    # Defensive: no decisions.log anywhere under cwd.
    run find . -name 'decisions.log'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "C2: decision_log_path set → writes JSON line to that path" {
    mkdir -p .hotl
    echo "decision_log_path: .hotl/decisions.log" > .hotl/config.yml
    run bash "$HOTL_RT" log-decision '{"event":"approved","risk":"low"}'
    [ "$status" -eq 0 ]
    [ -f .hotl/decisions.log ]
    grep -q '"event":"approved"' .hotl/decisions.log
}

@test "C3: decision_log_path points to new directory → directory is created" {
    mkdir -p .hotl
    echo "decision_log_path: docs/decisions/log.md" > .hotl/config.yml
    run bash "$HOTL_RT" log-decision '{"event":"approved"}'
    [ "$status" -eq 0 ]
    [ -f docs/decisions/log.md ]
}

@test "C4: append-only semantics — multiple invocations accumulate" {
    mkdir -p .hotl
    echo "decision_log_path: .hotl/decisions.log" > .hotl/config.yml
    bash "$HOTL_RT" log-decision '{"event":"first"}'
    bash "$HOTL_RT" log-decision '{"event":"second"}'
    LINES=$(wc -l < .hotl/decisions.log | tr -d ' ')
    [ "$LINES" -eq 2 ]
    grep -q '"event":"first"' .hotl/decisions.log
    grep -q '"event":"second"' .hotl/decisions.log
}

# ── Group D: small-user safety regression ───────────────────────────────────
#
# Scoped to the Slice 1 surface (hotl-config.sh, hotl-config-resolve.sh,
# hotl-rt log-decision). Existing higher-level flows are not invoked here —
# baseline runtime behavior is covered by D1b's call to runtime-integration.bats.

@test "D1: Slice 1 surface in clean repo creates no forbidden initiative-support artifacts" {
    git init -q

    # Invoke every Slice 1 surface that could create files.
    bash "$HOTL_RT" log-decision '{"event":"test"}'
    bash "$HOTL_CONFIG_SH" get plans_dir --default=docs/plans >/dev/null
    bash "$HOTL_CONFIG_SH" get decision_log_path >/dev/null
    bash "$HOTL_CONFIG_RESOLVE" get plans_dir --default=docs/plans >/dev/null

    # None of the forbidden initiative-support artifacts (design §9) exist.
    for forbidden in \
        .hotl/config.yml \
        .hotl/decisions.log \
        docs/designs \
        docs/decisions \
        docs/requirements \
        docs/reviews \
        docs/prompts; do
        [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden was created"; return 1; }
    done

    # Baseline .hotl/state and .hotl/reports may exist when other commands
    # run, but Slice 1's log-decision must not create them as a side effect.
    [ ! -d .hotl/state ]
    [ ! -d .hotl/reports ]
}

@test "D1b: existing runtime-integration.bats remains green after Slice 1" {
    # Baseline hotl-rt behavior must be unchanged. This proves the new
    # log-decision subcommand and dispatcher edits did not regress existing
    # runtime commands. NOT a substitute for end-to-end coverage of higher-
    # level skills — that is covered by manual verification.
    run bats "$REPO_ROOT/test/runtime-integration.bats"
    [ "$status" -eq 0 ]
}

@test "D2: command count unchanged from pre-Slice-1 baseline" {
    EXPECTED=$(cat "$REPO_ROOT/test/fixtures/pre-slice-1-command-count.txt")
    ACTUAL=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$ACTUAL" -eq "$EXPECTED" ]
}

@test "D3: using-hotl skill-table length unchanged from pre-Slice-1 baseline" {
    EXPECTED=$(cat "$REPO_ROOT/test/fixtures/pre-slice-1-skill-count.txt")
    ACTUAL=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$ACTUAL" -eq "$EXPECTED" ]
}
