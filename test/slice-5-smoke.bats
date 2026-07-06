#!/usr/bin/env bats
#
# Slice 5 smoke tests — enforces the setup-project scaffolder contract
# per docs/plans/2026-04-14-slice-5-setup-scaffolder-plan.md §2.1.
# Groups Q/R/S continue the letter sequence from prior slices (A–P).

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOTL_INIT_INITIATIVE="$REPO_ROOT/scripts/hotl-init-initiative.sh"
    HOTL_INSTALL_CODEX_AGENTS="$REPO_ROOT/scripts/hotl-install-codex-agents.sh"
    HOTL_CONFIG_RESOLVE="$REPO_ROOT/scripts/hotl-config-resolve.sh"
    HOTL_RT="$REPO_ROOT/runtime/hotl-rt"
    TMP=$(mktemp -d)
    cd "$TMP"
}

teardown() {
    rm -rf "$TMP"
}

# ── Group Q: hotl-init-initiative.sh scaffolder behavior ───────────────────

@test "Q1: creates .hotl/config.yml with taxonomy: initiative" {
    git init -q
    run bash "$HOTL_INIT_INITIATIVE" --name demo
    [ "$status" -eq 0 ]
    [ -f .hotl/config.yml ]
    grep -qE '^taxonomy:[[:space:]]*initiative\b' .hotl/config.yml
}

@test "Q2: creates the six docs/<tier>/ directories" {
    git init -q
    bash "$HOTL_INIT_INITIATIVE" --name demo
    for dir in \
        docs/designs \
        docs/plans \
        docs/decisions \
        docs/requirements \
        docs/reviews \
        docs/prompts; do
        [ -d "$dir" ] || { echo "FAIL: $dir was not created"; return 1; }
    done
}

@test "Q3: renders four outputs per §1 — generics as-is, per-initiative with substitutions" {
    git init -q
    bash "$HOTL_INIT_INITIATIVE" --name demo

    # Generic references — byte-for-byte identical to source, no substitution.
    diff -q docs/prompts/design-doc-template.md \
            "$REPO_ROOT/adapters/strategic-design.template.md" >/dev/null \
        || { echo "FAIL: design-doc-template.md diverges from source"; return 1; }
    diff -q docs/prompts/plan-template.md \
            "$REPO_ROOT/adapters/tactical-plan.template.md" >/dev/null \
        || { echo "FAIL: plan-template.md diverges from source"; return 1; }

    # Per-initiative instances — filenames include slug, placeholders substituted.
    [ -f docs/prompts/demo-playbook.md ]
    [ -f docs/prompts/demo-operating-model.md ]

    grep -q 'demo' docs/prompts/demo-playbook.md
    grep -q 'demo' docs/prompts/demo-operating-model.md

    # No raw {{INITIATIVE_NAME}} remains.
    ! grep -q '{{INITIATIVE_NAME}}' docs/prompts/demo-playbook.md
    ! grep -q '{{INITIATIVE_NAME}}' docs/prompts/demo-operating-model.md

    # {{DATE}} substitution verified.
    local today
    today=$(date -u +%Y-%m-%d)
    grep -q "$today" docs/prompts/demo-operating-model.md \
        || { echo "FAIL: expected today's date ($today) in demo-operating-model.md"; return 1; }
    ! grep -q '{{DATE}}' docs/prompts/demo-operating-model.md \
        || { echo "FAIL: raw {{DATE}} still present in demo-operating-model.md"; return 1; }

    # None of the FOUR RENDERED OUTPUTS keeps the .template.md suffix.
    # Scoped to the four files we produced — a pre-existing user-owned
    # *.template.md file must not fail this test.
    for f in \
        docs/prompts/design-doc-template.md \
        docs/prompts/plan-template.md \
        docs/prompts/demo-playbook.md \
        docs/prompts/demo-operating-model.md; do
        [ -f "$f" ] || { echo "FAIL: $f missing"; return 1; }
        case "$(basename "$f")" in
            *.template.md)
                echo "FAIL: $f should not use the .template.md suffix after rendering"
                return 1
                ;;
        esac
    done
}

@test "Q4: refuses when .hotl/config.yml already exists — does not silently overwrite" {
    git init -q
    mkdir -p .hotl
    echo "taxonomy: default" > .hotl/config.yml
    local original
    original=$(cat .hotl/config.yml)

    run bash "$HOTL_INIT_INITIATIVE" --name demo
    [ "$status" -ne 0 ]
    [ "$(cat .hotl/config.yml)" = "$original" ]
    echo "$output" | grep -qi 'exists\|already'
}

@test "Q5: idempotent — each of the four target outputs preserved byte-for-byte with SKIP message" {
    git init -q
    mkdir -p docs/prompts
    # Seed all four target outputs with distinct user content so per-file
    # preservation is provable, not just for one file.
    echo "USER EDIT: design-doc"       > docs/prompts/design-doc-template.md
    echo "USER EDIT: plan"             > docs/prompts/plan-template.md
    echo "USER EDIT: playbook"         > docs/prompts/demo-playbook.md
    echo "USER EDIT: operating-model"  > docs/prompts/demo-operating-model.md

    run bash "$HOTL_INIT_INITIATIVE" --name demo
    [ "$status" -eq 0 ]

    [ "$(cat docs/prompts/design-doc-template.md)" = "USER EDIT: design-doc" ]
    [ "$(cat docs/prompts/plan-template.md)" = "USER EDIT: plan" ]
    [ "$(cat docs/prompts/demo-playbook.md)" = "USER EDIT: playbook" ]
    [ "$(cat docs/prompts/demo-operating-model.md)" = "USER EDIT: operating-model" ]

    for f in \
        design-doc-template.md \
        plan-template.md \
        demo-playbook.md \
        demo-operating-model.md; do
        echo "$output" | grep -qiE "skip.*docs/prompts/$f" \
            || { echo "FAIL: no SKIP message for docs/prompts/$f"; return 1; }
    done
}

@test "Q6: required --name argument — scaffolder refuses without a name" {
    git init -q
    run bash "$HOTL_INIT_INITIATIVE"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qiE 'name|required|usage'
    [ ! -e .hotl/config.yml ]
    [ ! -d docs/designs ]
}

@test "Q7: install-path resolution — scaffolder finds adapters/ under HOTL_INSTALL_OVERRIDE" {
    local fake_install
    fake_install=$(mktemp -d)
    mkdir -p "$fake_install/hotl/adapters"
    cp "$REPO_ROOT/adapters"/*.template.md "$fake_install/hotl/adapters/"

    git init -q
    run env HOTL_INSTALL_OVERRIDE="$fake_install" \
        bash "$HOTL_INIT_INITIATIVE" --name demo
    [ "$status" -eq 0 ]

    [ -f docs/prompts/design-doc-template.md ]
    [ -f docs/prompts/plan-template.md ]
    [ -f docs/prompts/demo-playbook.md ]
    [ -f docs/prompts/demo-operating-model.md ]

    rm -rf "$fake_install"
}

# ── Group Q2: Codex custom agent installer behavior ────────────────────────

@test "Q2.0: ships Codex agent templates from tracked adapters" {
    grep -q 'adapters/codex-agents' "$HOTL_INSTALL_CODEX_AGENTS"

    for agent in architect dev pm qa researcher reviewer; do
        [ -f "$REPO_ROOT/adapters/codex-agents/${agent}.toml" ] \
            || { echo "FAIL: missing adapters/codex-agents/${agent}.toml"; return 1; }
        grep -q "name = \"${agent}\"" "$REPO_ROOT/adapters/codex-agents/${agent}.toml"
    done
}

@test "Q2.1: installs HOTL Codex agent templates into project .codex/agents" {
    run bash "$HOTL_INSTALL_CODEX_AGENTS"
    [ "$status" -eq 0 ]

    for agent in architect dev pm qa researcher reviewer; do
        [ -f ".codex/agents/${agent}.toml" ] \
            || { echo "FAIL: missing .codex/agents/${agent}.toml"; return 1; }
        grep -q "name = \"${agent}\"" ".codex/agents/${agent}.toml"
    done

    [[ "$output" == *"Codex agent templates complete: 6 installed, 0 skipped"* ]]
}

@test "Q2.2: preserves existing Codex agent files unless force is explicit" {
    mkdir -p .codex/agents
    printf '%s\n' 'name = "reviewer"' 'description = "custom"' 'developer_instructions = "custom"' > .codex/agents/reviewer.toml

    run bash "$HOTL_INSTALL_CODEX_AGENTS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP: "*".codex/agents/reviewer.toml already exists"* ]]
    grep -q 'description = "custom"' .codex/agents/reviewer.toml

    run bash "$HOTL_INSTALL_CODEX_AGENTS" --force
    [ "$status" -eq 0 ]
    grep -q 'Reviews code for correctness' .codex/agents/reviewer.toml
}

# ── Group R: setup-project SKILL.md content ────────────────────────────────

@test "R1: SKILL documents the opt-in question with 'no' as the default" {
    local skill="$REPO_ROOT/skills/setup-project/SKILL.md"
    grep -qi 'multi-phase initiative\|initiative support' "$skill"
    grep -qiE '(default|prefill)[[:space:]:]+.*no\b' "$skill"
}

@test "R2: SKILL references the scaffolder + documents six-location install-path resolution" {
    local skill="$REPO_ROOT/skills/setup-project/SKILL.md"
    grep -q 'hotl-init-initiative\.sh' "$skill"
    for loc in \
        'scripts/hotl-init-initiative\.sh' \
        '\.codex/hotl/scripts/hotl-init-initiative\.sh' \
        '\.codex/plugins/hotl-source/scripts/hotl-init-initiative\.sh' \
        '\.codex/plugins/cache/codex-plugins/hotl/\*/scripts/hotl-init-initiative\.sh' \
        '\.cline/hotl/scripts/hotl-init-initiative\.sh' \
        '\.claude/plugins/hotl/scripts/hotl-init-initiative\.sh'; do
        grep -qE "$loc" "$skill" \
            || { echo "FAIL: setup-project SKILL missing resolution location matching /$loc/"; return 1; }
    done
}

@test "R3: SKILL gates the scaffolder invocation on a yes/opt-in answer" {
    local skill="$REPO_ROOT/skills/setup-project/SKILL.md"
    grep -qiE 'opt.in|answered yes|if yes|only when.*yes|only if.*yes|only invoke.*yes' "$skill"
}

@test "R4: SKILL documents optional Codex custom agent install helper" {
    local skill="$REPO_ROOT/skills/setup-project/SKILL.md"
    grep -q 'hotl-install-codex-agents\.sh' "$skill"
    grep -q 'adapters/codex-agents/' "$skill"
    grep -q '\.codex/agents/\*\.toml' "$skill"
    grep -qi 'Existing agent files are preserved' "$skill"
}

# ── Group S: small-user safety regression ──────────────────────────────────

@test "S1: command count unchanged and skill count is at least the pre-Slice-5 baseline" {
    local expected_cmds actual_cmds expected_skills actual_skills
    expected_cmds=$(cat "$REPO_ROOT/test/fixtures/pre-slice-5-command-count.txt")
    actual_cmds=$(ls "$REPO_ROOT"/commands/*.md | wc -l | tr -d ' ')
    [ "$actual_cmds" -eq "$expected_cmds" ]

    expected_skills=$(cat "$REPO_ROOT/test/fixtures/pre-slice-5-skill-count.txt")
    actual_skills=$(grep -c '^| `' "$REPO_ROOT/skills/using-hotl/SKILL.md")
    [ "$actual_skills" -ge "$expected_skills" ]
}

@test "S2: non-scaffolder Slice 1–5 surface creates no forbidden artifacts; explicit scaffolder invocation creates the expected artifacts" {
    git init -q

    # Exercise the entire non-scaffolder surface. None should create
    # initiative-support artifacts.
    bash "$HOTL_CONFIG_RESOLVE" get designs_dir --default=docs/designs >/dev/null
    bash "$HOTL_CONFIG_RESOLVE" get workflows_dir --default=. >/dev/null
    bash "$HOTL_RT" log-decision '{"event":"test"}'

    for forbidden in \
        .hotl/config.yml \
        .hotl/decisions.log \
        docs/designs \
        docs/decisions \
        docs/requirements \
        docs/reviews \
        docs/prompts; do
        [ ! -e "$forbidden" ] || { echo "FAIL: $forbidden was created (non-opt-in path)"; return 1; }
    done

    # Explicit scaffolder invocation — artifacts SHOULD appear.
    bash "$HOTL_INIT_INITIATIVE" --name demo
    [ -f .hotl/config.yml ]
    [ -d docs/designs ]
    [ -d docs/prompts ]
    [ -f docs/prompts/demo-playbook.md ]
    [ -f docs/prompts/demo-operating-model.md ]
    [ -f docs/prompts/design-doc-template.md ]
    [ -f docs/prompts/plan-template.md ]
}

@test "S3: all four Slice 3 templates are now consumed — none remain inert" {
    for tmpl_name in \
        strategic-design.template.md \
        tactical-plan.template.md \
        initiative-playbook.template.md \
        initiative-operating-model.template.md; do
        local refs
        refs=$(grep -rl "$tmpl_name" "$REPO_ROOT" 2>/dev/null \
            | grep -vE '^'"$REPO_ROOT"'/(docs/|test/|adapters/|\.git/|CHANGELOG\.md)' \
            || true)
        [ -n "$refs" ] \
            || { echo "FAIL: $tmpl_name has no consumer — remains inert"; return 1; }
    done
}

@test "S4: prior slice smoke suites remain directly discoverable" {
    for suite in \
        test/slice-1-smoke.bats \
        test/slice-2-smoke.bats \
        test/slice-3-smoke.bats \
        test/slice-4-smoke.bats; do
        [ -f "$REPO_ROOT/$suite" ]
    done
}
