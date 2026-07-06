#!/usr/bin/env bats
#
# Slice 4 smoke tests — enforces the brainstorming scope-question contract
# per docs/plans/2026-04-14-slice-4-brainstorming-scope-plan.md §2.1.
# Groups M/N/O/P continue the letter sequence from prior slices (A–L).

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_CONFIG_SH="$REPO_ROOT/scripts/hotl-config.sh"
    HOTL_CONFIG_RESOLVE="$REPO_ROOT/scripts/hotl-config-resolve.sh"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    TMP=$(mktemp -d)
    cd "$TMP"
}

teardown() {
    rm -rf "$TMP"
}

# ── Group M: SKILL.md scope question and path routing ──────────────────────

@test "M1: brainstorming SKILL.md documents the three-choice scope question with feature as default" {
    local skill="$REPO_ROOT/skills/brainstorming/SKILL.md"

    # Whole-word matches via -w (POSIX-portable).
    grep -qw feature "$skill"
    grep -qw phase "$skill"
    grep -qw initiative "$skill"

    # "Scope" is called out as a question or step.
    grep -qi 'scope.*question\|scope.*(feature.*phase.*initiative)\|ask.*scope' "$skill"

    # feature is the default — documented as such.
    grep -qiE '(default|prefill)[[:space:]:]+.*feature' "$skill"
}

@test "M2: initiative scope routes output to docs/designs/<topic>.md (undated, durable)" {
    local skill="$REPO_ROOT/skills/brainstorming/SKILL.md"

    grep -qE 'initiative.*docs/designs/<topic>\.md|initiative.*<designs_dir>/<topic>\.md' "$skill"
}

@test "M3: feature/phase scope routes output to dated docs/designs design docs" {
    local skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
    grep -qE 'feature.*docs/designs/YYYY-MM-DD-<slug>-design\.md' "$skill"
    grep -qE 'phase.*docs/designs/YYYY-MM-DD-phase-N-<slug>-design\.md' "$skill"
}

@test "M4: cline/rules/hotl-brainstorming.md mirror carries the scope question" {
    local mirror="$REPO_ROOT/cline/rules/hotl-brainstorming.md"
    grep -qw feature "$mirror"
    grep -qw phase "$mirror"
    grep -qw initiative "$mirror"
    grep -qi 'scope' "$mirror"
    grep -qE 'docs/designs/<topic>\.md|<designs_dir>/<topic>\.md' "$mirror"
    grep -qE 'docs/designs/YYYY-MM-DD-<slug>-design\.md' "$mirror"
    grep -qE 'docs/designs/YYYY-MM-DD-phase-N-<slug>-design\.md' "$mirror"
}

# ── Group N: strategic-design template install-path resolution ─────────────

@test "N1: brainstorming SKILL.md documents the six-location resolution for strategic-design.template.md" {
    local skill="$REPO_ROOT/skills/brainstorming/SKILL.md"

    # Canonical in-repo form is `adapters/strategic-design.template.md`.
    # Relative-path variants like scripts/../adapters/... are NOT accepted.
    for loc in \
        'adapters/strategic-design\.template\.md' \
        '\.codex/hotl/adapters/strategic-design\.template\.md' \
        '\.codex/plugins/hotl-source/adapters/strategic-design\.template\.md' \
        '\.codex/plugins/cache/codex-plugins/hotl/\*/adapters/strategic-design\.template\.md' \
        '\.cline/hotl/adapters/strategic-design\.template\.md' \
        '\.claude/plugins/hotl/adapters/strategic-design\.template\.md'; do
        grep -qE "$loc" "$skill" \
            || { echo "FAIL: brainstorming SKILL missing resolution location matching /$loc/"; return 1; }
    done
}

@test "N2: doc-parity — install roots match document-lint.sh's resolution list in order" {
    local skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
    local dr="$REPO_ROOT/skills/document-review/SKILL.md"

    # Allow optional leading whitespace — brainstorming's numbered list is
    # nested under a step and indented. document-review's list is at column 0.
    local lint_roots tmpl_roots
    lint_roots=$(grep -E '^[[:space:]]*[0-9]+\. ' "$dr" \
        | grep -Eo '`[^`]*document-lint\.sh`' \
        | sed 's|^`||; s|`$||' \
        | sed -E 's|(.*/)?scripts/document-lint\.sh$|\1|' \
        | sed 's|^$|<in-repo>|')
    tmpl_roots=$(grep -E '^[[:space:]]*[0-9]+\. ' "$skill" \
        | grep -Eo '`[^`]*strategic-design\.template\.md`' \
        | sed 's|^`||; s|`$||' \
        | sed -E 's|(.*/)?adapters/strategic-design\.template\.md$|\1|' \
        | sed 's|^$|<in-repo>|')

    [ -n "$lint_roots" ]
    [ -n "$tmpl_roots" ]

    local lint_count tmpl_count
    lint_count=$(printf '%s\n' "$lint_roots" | wc -l | tr -d ' ')
    tmpl_count=$(printf '%s\n' "$tmpl_roots" | wc -l | tr -d ' ')
    [ "$lint_count" -eq 6 ]
    [ "$tmpl_count" -eq 6 ]

    [ "$lint_roots" = "$tmpl_roots" ]
}

# ── Group O: designs_dir config consumption ────────────────────────────────

@test "O1: hotl-config-resolve.sh get designs_dir returns default when config absent" {
    run bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs
    [ "$status" -eq 0 ]
    [ "$output" = "docs/designs" ]
}

@test "O2: hotl-config-resolve.sh get designs_dir returns configured value when set" {
    mkdir -p .hotl
    echo "designs_dir: docs/strategy" > .hotl/config.yml
    run bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs
    [ "$status" -eq 0 ]
    [ "$output" = "docs/strategy" ]
}

@test "O3: brainstorming SKILL.md instructs the agent to resolve designs_dir via hotl-config-resolve.sh" {
    local skill="$REPO_ROOT/skills/brainstorming/SKILL.md"
    grep -q 'hotl-config-resolve\.sh' "$skill"
    grep -q 'designs_dir' "$skill"
    grep -q -- '--default=docs/designs' "$skill"
}

# ── Group P: small-user safety regression ──────────────────────────────────

@test "P1: command count unchanged and skill count is at least the pre-Slice-4 baseline" {
    local expected_cmds actual_cmds expected_skills actual_skills
    expected_cmds=$(cat "$REPO_ROOT/test/fixtures/pre-slice-4-command-count.txt")
    actual_cmds=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$actual_cmds" -eq "$expected_cmds" ]

    expected_skills=$(cat "$REPO_ROOT/test/fixtures/pre-slice-4-skill-count.txt")
    actual_skills=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$actual_skills" -ge "$expected_skills" ]
}

@test "P2: Slice 4 surface in a clean repo creates no forbidden initiative-support artifacts" {
    git init -q

    bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs >/dev/null
    bash "$HOTL_RT" log-decision '{"event":"test"}'

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
}

@test "P3: strategic-design template is consumed by brainstorming (Slice 4's new wiring)" {
    # NOTE: P3 originally also asserted the other three Slice 3 templates
    # remained inert after Slice 4. Slice 5 legitimately consumed them via
    # hotl-init-initiative.sh, so the "remain inert" half of P3 no longer
    # applies. The "all four consumed" invariant is enforced by
    # slice-5-smoke.bats S3. P3 is narrowed to its still-meaningful half:
    # Slice 4's wiring of strategic-design into brainstorming.
    grep -q 'strategic-design\.template\.md' \
        "$REPO_ROOT/skills/brainstorming/SKILL.md"
}

@test "P4: prior slice smoke suites remain directly discoverable" {
    for suite in test/slice-1-smoke.bats test/slice-2-smoke.bats test/slice-3-smoke.bats; do
        [ -f "$REPO_ROOT/$suite" ]
    done
}
