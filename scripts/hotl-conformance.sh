#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_SCENARIOS="${REPO_ROOT}/test/fixtures/conformance/scenarios.json"

usage() {
    printf '%s\n' \
        "usage: hotl-conformance.sh validate [scenarios.json]" \
        "       hotl-conformance.sh validate-evaluation <result.json>"
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required for HOTL conformance operations." >&2
        exit 1
    fi
}

validate_manifest_shape() {
    local manifest="$1"
    jq -e '
      def nonempty_string: type == "string" and length > 0;
      def valid_date: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
      def allowed_status: . as $status | ["completed", "blocked", "paused", "running", "mixed", "paused_or_blocked"] | index($status) != null;
      .schema_version == 1 and
      (.verified_at | valid_date) and
      (.scenarios | type == "array" and length > 0) and
      (all(.scenarios[];
        (.id | nonempty_string) and
        (.title | nonempty_string) and
        (.invariant | nonempty_string) and
        (.expected_terminal_status | allowed_status) and
        (.gap | type == "boolean") and
        ((.gap == false and .gap_reason == null and (.evidence | type == "array" and length > 0)) or
         (.gap == true and (.gap_reason | nonempty_string) and (.evidence | type == "array"))) and
        (all(.evidence[]; (.file | nonempty_string) and (.test | nonempty_string)))
      )) and
      (([.scenarios[].id] | length) == ([.scenarios[].id] | unique | length))
    ' "$manifest" >/dev/null
}

validate_evidence_references() {
    local manifest="$1"
    local failed=0

    while IFS=$'\t' read -r scenario_id evidence_file evidence_test; do
        local absolute_file="${REPO_ROOT}/${evidence_file}"
        if [ ! -f "$absolute_file" ]; then
            echo "ERROR: conformance scenario ${scenario_id} references missing file: ${evidence_file}" >&2
            failed=1
            continue
        fi
        if ! grep -Fq "@test \"${evidence_test}\"" "$absolute_file"; then
            echo "ERROR: conformance scenario ${scenario_id} references missing test: ${evidence_file} :: ${evidence_test}" >&2
            failed=1
        fi
    done < <(jq -r '.scenarios[] | select(.gap == false) | .id as $id | .evidence[] | [$id, .file, .test] | @tsv' "$manifest")

    [ "$failed" -eq 0 ]
}

validate_manifest() {
    local manifest="$1"
    if [ ! -f "$manifest" ]; then
        echo "ERROR: conformance manifest not found: $manifest" >&2
        return 1
    fi
    validate_manifest_shape "$manifest" || {
        echo "ERROR: invalid HOTL conformance manifest: $manifest" >&2
        return 1
    }
    validate_evidence_references "$manifest"
}

validate_evaluation() {
    local result="$1"
    local manifest="${2:-$DEFAULT_SCENARIOS}"

    if [ ! -f "$result" ]; then
        echo "ERROR: evaluation result not found: $result" >&2
        return 1
    fi
    validate_manifest "$manifest" >/dev/null

    jq -e '
      def nonempty_string: type == "string" and length > 0;
      def nullable_string: . == null or nonempty_string;
      def nonnegative_integer: type == "number" and floor == . and . >= 0;
      def nullable_nonnegative_integer: . == null or nonnegative_integer;
      def valid_timestamp: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
      def valid_date: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
      def valid_profile_id: nonempty_string and test("^[a-z0-9][a-z0-9._/-]*$");
      def allowed($values): . as $value | $values | index($value) != null;
      def observed_number($source; $value):
        if $source == "observed" then ($value | type == "number" and . >= 0)
        elif $source == "unavailable" then $value == null
        else false
        end;
      .schema_version == 1 and
      (.recorded_at | valid_timestamp) and
      (.scenario_id | nonempty_string) and
      (.scenario_revision | valid_date) and
      ((has("profile_id") | not) or (.profile_id | valid_profile_id)) and
      (.host | nonempty_string) and
      (.execution_implementation | allowed(["fallback", "native_adapter", "manual"])) and
      (.resolved_model | nullable_string) and
      (.effort_profile | nullable_string) and
      (.adapter_version | nullable_string) and
      (.environment as $environment |
        $environment == null or
        ($environment | type == "object" and
          has("repo_revision") and
          has("host_version") and
          has("os") and
          has("arch") and
          has("toolchain_fingerprint") and
          (.repo_revision | nullable_string) and
          (.host_version | nullable_string) and
          (.os | nullable_string) and
          (.arch | nullable_string) and
          (.toolchain_fingerprint | nullable_string))) and
      (.terminal_outcome | allowed(["completed", "blocked", "paused", "running"])) and
      (.contract_failures | type == "array" and all(.[]; nonempty_string)) and
      (.post_completion_defects | nonnegative_integer) and
      (.interventions | nonnegative_integer) and
      (.retries | nonnegative_integer) and
      (.telemetry | type == "object") and
      (.telemetry.duration_ms | nullable_nonnegative_integer) and
      (.telemetry.agent_count | nullable_nonnegative_integer) and
      (.telemetry.tokens.source | allowed(["observed", "unavailable"])) and
      observed_number(.telemetry.tokens.source; .telemetry.tokens.input) and
      observed_number(.telemetry.tokens.source; .telemetry.tokens.output) and
      observed_number(.telemetry.tokens.source; .telemetry.tokens.cached) and
      (.telemetry.cost.source | allowed(["observed", "unavailable"])) and
      observed_number(.telemetry.cost.source; .telemetry.cost.usd) and
      (.evidence_refs | type == "array" and length > 0 and all(.[]; nonempty_string)) and
      (.notes | nullable_string)
    ' "$result" >/dev/null || {
        echo "ERROR: invalid HOTL evaluation result: $result" >&2
        return 1
    }

    local scenario_id
    scenario_id="$(jq -r '.scenario_id' "$result")"
    if ! jq -e --arg id "$scenario_id" 'any(.scenarios[]; .id == $id)' "$manifest" >/dev/null; then
        echo "ERROR: evaluation result references unknown scenario: $scenario_id" >&2
        return 1
    fi
}

main() {
    require_jq
    local command_name="${1:-}"

    case "$command_name" in
        validate)
            local manifest="${2:-$DEFAULT_SCENARIOS}"
            validate_manifest "$manifest"
            echo "Conformance manifest valid: $manifest"
            ;;
        validate-evaluation)
            if [ $# -lt 2 ]; then
                echo "ERROR: validate-evaluation requires a result file." >&2
                usage >&2
                exit 1
            fi
            validate_evaluation "$2" "${3:-$DEFAULT_SCENARIOS}"
            echo "Evaluation result valid: $2"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
