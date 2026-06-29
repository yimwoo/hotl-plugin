#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CAPABILITIES="$REPO_ROOT/scripts/hotl-capabilities.sh"
CATALOG="$REPO_ROOT/runtime/capabilities/catalog.json"
CONFORMANCE="$REPO_ROOT/scripts/hotl-conformance.sh"
SCENARIOS="$REPO_ROOT/test/fixtures/conformance/scenarios.json"
EVALUATION="$REPO_ROOT/test/fixtures/evaluations/result-sample.json"

setup() {
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMP"
}

copy_catalog() {
    local destination="$1"
    cp "$CATALOG" "$destination"
}

@test "capability catalog validates canonical catalog" {
    run bash "$CAPABILITIES" validate "$CATALOG"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Capability catalog valid"* ]]
}

@test "capability catalog rejects duplicate identities" {
    local fixture="$TEST_TMP/catalog.json"
    copy_catalog "$fixture"
    jq '.capabilities += [.capabilities[0]]' "$fixture" > "$TEST_TMP/changed.json"

    run bash "$CAPABILITIES" validate "$TEST_TMP/changed.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL capability catalog"* ]]
}

@test "capability catalog rejects invalid vocabulary" {
    local fixture="$TEST_TMP/catalog.json"
    copy_catalog "$fixture"
    jq '.capabilities[0].provider_maturity = "latest"' "$fixture" > "$TEST_TMP/changed.json"

    run bash "$CAPABILITIES" validate "$TEST_TMP/changed.json"
    [ "$status" -ne 0 ]
}

@test "capability catalog rejects missing provenance" {
    local fixture="$TEST_TMP/catalog.json"
    copy_catalog "$fixture"
    jq '.capabilities[0].sources = []' "$fixture" > "$TEST_TMP/changed.json"

    run bash "$CAPABILITIES" validate "$TEST_TMP/changed.json"
    [ "$status" -ne 0 ]
}

@test "capability catalog rejects non-official provenance domains" {
    local fixture="$TEST_TMP/catalog.json"
    copy_catalog "$fixture"
    jq '.capabilities[0].sources = ["https://example.com/codex"]' "$fixture" > "$TEST_TMP/changed.json"

    run bash "$CAPABILITIES" validate "$TEST_TMP/changed.json"
    [ "$status" -ne 0 ]
}

@test "capability matrix renderer is deterministic" {
    run bash "$CAPABILITIES" render "$CATALOG"
    [ "$status" -eq 0 ]
    first="$output"

    run bash "$CAPABILITIES" render "$CATALOG"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
}

@test "capability matrix matches checked-in documentation" {
    run bash -c 'bash "$1" render "$2" | diff -u "$3" -' _ "$CAPABILITIES" "$CATALOG" "$REPO_ROOT/docs/host-capabilities.md"
    [ "$status" -eq 0 ]
}

@test "capability matrix includes security and verification provenance" {
    run bash "$CAPABILITIES" render "$CATALOG"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Security boundary"* ]]
    [[ "$output" == *"Verified"* ]]
    [[ "$output" == *"HOTL support states"* ]]
}

@test "capability probe reports installed hosts with unknown capability entitlement" {
    local fake_codex="$TEST_TMP/codex"
    local fake_claude="$TEST_TMP/claude"
    printf '#!/usr/bin/env bash\necho "codex-cli 9.9.9"\n' > "$fake_codex"
    printf '#!/usr/bin/env bash\necho "9.9.9 (Claude Code)"\n' > "$fake_claude"
    chmod +x "$fake_codex" "$fake_claude"

    run env HOTL_CODEX_BIN="$fake_codex" HOTL_CLAUDE_BIN="$fake_claude" bash "$CAPABILITIES" probe "$CATALOG"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hosts[] | select(.host == "codex" and .state == "unknown")' >/dev/null
    echo "$output" | jq -e '.hosts[] | select(.host == "claude-code" and .state == "unknown")' >/dev/null
    echo "$output" | jq -e '[.capabilities[] | select(.host == "codex" and .state != "unknown")] | length == 0' >/dev/null
}

@test "capability probe reports unavailable missing hosts" {
    run env HOTL_CODEX_BIN="$TEST_TMP/missing-codex" HOTL_CLAUDE_BIN="$TEST_TMP/missing-claude" bash "$CAPABILITIES" probe "$CATALOG"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hosts[] | select(.host == "codex" and .state == "unavailable")' >/dev/null
    echo "$output" | jq -e '.hosts[] | select(.host == "claude-code" and .state == "unavailable")' >/dev/null
}

@test "capability probe makes no filesystem mutations" {
    local empty_dir="$TEST_TMP/empty"
    mkdir -p "$empty_dir"

    run bash -c 'cd "$1" && HOTL_CODEX_BIN="$1/missing-codex" HOTL_CLAUDE_BIN="$1/missing-claude" bash "$2" probe "$3" >/dev/null' _ "$empty_dir" "$CAPABILITIES" "$CATALOG"
    [ "$status" -eq 0 ]
    [ -z "$(find "$empty_dir" -mindepth 1 -print -quit)" ]
}

@test "conformance manifest validates the baseline scenario corpus" {
    run bash "$CONFORMANCE" validate "$SCENARIOS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Conformance manifest valid"* ]]
}

@test "conformance manifest rejects duplicate scenario identities" {
    jq '.scenarios += [.scenarios[0]]' "$SCENARIOS" > "$TEST_TMP/scenarios.json"

    run bash "$CONFORMANCE" validate "$TEST_TMP/scenarios.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL conformance manifest"* ]]
}

@test "conformance manifest rejects missing evidence files" {
    jq '.scenarios[0].evidence[0].file = "test/missing.bats"' "$SCENARIOS" > "$TEST_TMP/scenarios.json"

    run bash "$CONFORMANCE" validate "$TEST_TMP/scenarios.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"references missing file"* ]]
}

@test "conformance manifest rejects missing evidence tests" {
    jq '.scenarios[0].evidence[0].test = "missing test name"' "$SCENARIOS" > "$TEST_TMP/scenarios.json"

    run bash "$CONFORMANCE" validate "$TEST_TMP/scenarios.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"references missing test"* ]]
}

@test "conformance manifest accepts an explicit reviewed gap" {
    jq '.scenarios[0].gap = true | .scenarios[0].gap_reason = "coverage deferred to a named later phase" | .scenarios[0].evidence = []' "$SCENARIOS" > "$TEST_TMP/scenarios.json"

    run bash "$CONFORMANCE" validate "$TEST_TMP/scenarios.json"
    [ "$status" -eq 0 ]
}

@test "evaluation result validates the model-neutral sample" {
    run bash "$CONFORMANCE" validate-evaluation "$EVALUATION" "$SCENARIOS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Evaluation result valid"* ]]
}

@test "evaluation result rejects unknown scenario identity" {
    jq '.scenario_id = "unknown-scenario"' "$EVALUATION" > "$TEST_TMP/result.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/result.json" "$SCENARIOS"
    [ "$status" -ne 0 ]
    [[ "$output" == *"references unknown scenario"* ]]
}

@test "evaluation result rejects unavailable token telemetry encoded as zero" {
    jq '.telemetry.tokens.input = 0' "$EVALUATION" > "$TEST_TMP/result.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/result.json" "$SCENARIOS"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid HOTL evaluation result"* ]]
}

@test "evaluation result requires non-empty evidence references" {
    jq '.evidence_refs = []' "$EVALUATION" > "$TEST_TMP/result.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/result.json" "$SCENARIOS"
    [ "$status" -ne 0 ]
}

@test "evaluation result accepts observed telemetry" {
    jq '.telemetry.tokens = {source: "observed", input: 100, output: 25, cached: 50} | .telemetry.cost = {source: "observed", usd: 0.01}' "$EVALUATION" > "$TEST_TMP/result.json"

    run bash "$CONFORMANCE" validate-evaluation "$TEST_TMP/result.json" "$SCENARIOS"
    [ "$status" -eq 0 ]
}

@test "baseline documentation links the generated capability matrix and no-routing boundary" {
    grep -q 'Host Capability Baseline' "$REPO_ROOT/README.md"
    grep -q 'docs/host-capabilities.md' "$REPO_ROOT/README.md"
    grep -q 'choose an execution' "$REPO_ROOT/README.md"
}

@test "baseline documentation describes the read-only tri-state probe" {
    grep -q 'scripts/hotl-capabilities.sh probe' "$REPO_ROOT/docs/how-it-works.md"
    grep -q 'available.*,.*unavailable.*,.*unknown' "$REPO_ROOT/docs/how-it-works.md"
    grep -q 'edit configuration' "$REPO_ROOT/docs/how-it-works.md"
}

@test "baseline documentation indexes both new output contracts" {
    grep -q 'driver-conformance.md' "$REPO_ROOT/docs/contracts/README.md"
    grep -q 'evaluation-result-output.md' "$REPO_ROOT/docs/contracts/README.md"
}

@test "baseline documentation records the Phase 1 additions in the changelog" {
    grep -q 'host capability catalog' "$REPO_ROOT/CHANGELOG.md"
    grep -q 'does not route execution' "$REPO_ROOT/CHANGELOG.md"
}
