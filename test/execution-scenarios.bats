#!/usr/bin/env bats

# HOTL Execution Scenario Tests
# Validates execution behavior through fixtures, skill content, and behavioral specs.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    LOOP_SKILL="$REPO_ROOT/skills/loop-execution/SKILL.md"
    EXEC_SKILL="$REPO_ROOT/skills/executing-plans/SKILL.md"
    SUBAGENT_SKILL="$REPO_ROOT/skills/subagent-execution/SKILL.md"
    FIXTURES="$REPO_ROOT/test/fixtures"
    SCENARIOS="$REPO_ROOT/test/scenarios"
}

# ── Scenario 1: Retry and max-iterations stop ───────────────────────────────

@test "scenario 01: retry fixture passes lint" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$FIXTURES/hotl-workflow-retry-sample.md"
    [ "$status" -eq 0 ]
}

@test "scenario 01: loop-execution describes retry with attempt logging" {
    grep -qi "retry\|retrying" "$LOOP_SKILL"
    grep -qi "max_iterations\|max iterations" "$LOOP_SKILL"
}

@test "scenario 01: loop-execution describes stop after max iterations" {
    grep -qi "reached max iterations\|max_iterations.*STOP\|iterations = max_iterations" "$LOOP_SKILL"
}

@test "scenario 01: behavioral spec exists" {
    [ -f "$SCENARIOS/01-retry-stop.md" ]
}

# ── Scenario 2: Gate handling ────────────────────────────────────────────────

@test "scenario 02: gates fixture passes lint" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$FIXTURES/hotl-workflow-gates-sample.md"
    [ "$status" -eq 0 ]
}

@test "scenario 02: loop-execution describes human gate pause" {
    grep -qi "gate.*human.*PAUSE\|PAUSE.*gate\|gate: human" "$LOOP_SKILL"
}

@test "scenario 02: loop-execution describes auto-approve path" {
    grep -qi "auto.approve\|Auto-approved" "$LOOP_SKILL"
}

@test "scenario 02: behavioral spec exists" {
    [ -f "$SCENARIOS/02-gate-handling.md" ]
}

# ── Scenario 3: Risk level overrides auto-approve ────────────────────────────

@test "scenario 03: loop-execution states high risk forces human gates" {
    grep -qi "risk_level.*high.*always\|high.*forces.*human\|risk_level: high.*always" "$LOOP_SKILL"
}

@test "scenario 03: loop-execution lists security-sensitive keywords" {
    grep -qi "auth.*encrypt\|secret.*password\|token.*billing\|security-sensitive" "$LOOP_SKILL"
}

@test "scenario 03: behavioral spec exists" {
    [ -f "$SCENARIOS/03-risk-override.md" ]
}

# ── Scenario 4: Final summary reporting contract ────────────────────────────

@test "scenario 04: loop-execution defines Status column values" {
    grep -q "✓ Done" "$LOOP_SKILL"
    grep -q "⚡ Auto-approved" "$LOOP_SKILL"
    grep -q "✗ Failed" "$LOOP_SKILL"
    grep -q "✗ Blocked" "$LOOP_SKILL"
}

@test "scenario 04: loop-execution defines Iterations as attempt count only" {
    grep -qi "attempt count.*only\|number only\|count only" "$LOOP_SKILL"
}

@test "scenario 04: loop-execution states test counts go in Status not Iterations" {
    grep -qi "Never.*test counts.*Iterations\|test counts.*Status\|Never put test counts" "$LOOP_SKILL"
}

@test "scenario 04: loop-execution prefers compact list chat output for Codex" {
    grep -qi "Codex.*compact list\|compact list.*Codex\|wide markdown table" "$LOOP_SKILL"
}

@test "scenario 04: compact Codex list keeps status and iterations inline" {
    grep -qi "status and iteration semantics.*inline\|status and iteration count inline" "$LOOP_SKILL"
    grep -Fq "Done (1 attempt)" "$LOOP_SKILL"
    grep -Fq "Done (3 attempts)" "$LOOP_SKILL"
    grep -Fq "Approved (1 attempt)" "$LOOP_SKILL"
}

@test "scenario 04: loop-execution describes Codex native progress as additive only" {
    grep -qi "Codex app.*native plan\|native plan/progress UI\|built-in progress card" "$LOOP_SKILL"
    grep -qi "additive\|do not remove.*chat logs\|platforms without a native progress UI" "$LOOP_SKILL"
}

@test "scenario 04: behavioral spec exists" {
    [ -f "$SCENARIOS/04-summary-columns.md" ]
}

# ── Scenario 5: Verbose progress precedence ──────────────────────────────────

@test "scenario 05: progress fixture passes lint" {
    run bash "$REPO_ROOT/scripts/document-lint.sh" "$FIXTURES/hotl-workflow-progress-sample.md"
    [ "$status" -eq 0 ]
}

@test "scenario 05: loop-execution defines verbose precedence" {
    grep -qi "invocation.*override\|override.*frontmatter\|frontmatter.*default" "$LOOP_SKILL"
}

@test "scenario 05: loop-execution defines verbose symbols" {
    grep -q "✓" "$LOOP_SKILL"
    grep -q "→" "$LOOP_SKILL"
    grep -q "·" "$LOOP_SKILL"
}

@test "scenario 05: loop-execution states verbose prints at step transitions only" {
    grep -qi "step transition\|before starting.*after.*complete" "$LOOP_SKILL"
}

@test "scenario 05: behavioral spec exists" {
    [ -f "$SCENARIOS/05-verbose-precedence.md" ]
}

# ── Executor inheritance ─────────────────────────────────────────────────────

@test "executing-plans references canonical reporting contract from loop-execution" {
    grep -qi "Reporting.*loop-execution\|canonical.*Reporting\|loop-execution.*reporting" "$EXEC_SKILL"
}

@test "subagent-execution references canonical reporting contract from loop-execution" {
    grep -qi "Reporting.*loop-execution\|canonical.*Reporting\|loop-execution.*reporting" "$SUBAGENT_SKILL"
}

# ── Durable execution report ────────────────────────────────────────────────

@test "loop-execution defines Execution Report section" {
    grep -q "## Execution Report" "$LOOP_SKILL"
}

@test "loop-execution describes report lifecycle and .hotl/reports/ path" {
    grep -q ".hotl/reports/" "$LOOP_SKILL"
    grep -q "report_path" "$LOOP_SKILL"
}

@test "loop-execution requires persistence before visible progress updates" {
    grep -q "Persist step start before any user-facing progress update" "$LOOP_SKILL"
    grep -q "persist completion before announcing" "$LOOP_SKILL"
    grep -q "Native progress UI is advisory only" "$LOOP_SKILL"
}

@test "loop-execution describes report format (table + event log)" {
    grep -qi "Summary table\|summary table" "$LOOP_SKILL"
    grep -qi "Event Log\|event log" "$LOOP_SKILL"
}

@test "loop-execution describes verify output policy (failures vs full)" {
    grep -qi "report_detail.*full\|report_detail: full" "$LOOP_SKILL"
}

@test "resuming references report_path from sidecar" {
    grep -q "report_path" "$REPO_ROOT/skills/resuming/SKILL.md"
}
