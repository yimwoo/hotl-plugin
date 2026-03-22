#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: render-execution-summary.sh --platform <codex|claude|cline> <summary-json>" >&2
    exit 1
}

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not found." >&2
    exit 1
fi

if [ "${1:-}" != "--platform" ]; then
    usage
fi

platform="${2:-}"
summary_json="${3:-}"

[ -n "$platform" ] || usage
[ -n "$summary_json" ] || usage
[ -f "$summary_json" ] || {
    echo "ERROR: Summary JSON not found: $summary_json" >&2
    exit 1
}

normalize_status() {
    local step_json="$1"
    local gate_result gate_mode status
    gate_result=$(echo "$step_json" | jq -r '.gate_result // "null"')
    gate_mode=$(echo "$step_json" | jq -r '.gate_mode // "null"')
    status=$(echo "$step_json" | jq -r '.status // "pending"')

    case "$gate_result" in
        approved)
            if [ "$gate_mode" = "auto" ]; then
                echo "Auto-approved"
            else
                echo "Approved"
            fi
            ;;
        rejected) echo "Rejected" ;;
        *)
            case "$status" in
                blocked) echo "Blocked" ;;
                failed) echo "Failed" ;;
                done) echo "Done" ;;
                in_progress) echo "Running" ;;
                pending) echo "Pending" ;;
                *) echo "$status" ;;
            esac
            ;;
    esac
}

status_symbol() {
    local normalized_status="$1"
    case "$normalized_status" in
        Approved|Done) echo "✓" ;;
        Auto-approved) echo "⚡" ;;
        Rejected|Failed|Blocked) echo "✗" ;;
        Running) echo "→" ;;
        Pending) echo "·" ;;
        *) echo "·" ;;
    esac
}

attempt_text() {
    local step_json="$1"
    local gate_result attempts
    gate_result=$(echo "$step_json" | jq -r '.gate_result // "null"')
    attempts=$(echo "$step_json" | jq -r '.attempts // 0')

    if [ "$gate_result" != "null" ]; then
        echo "-"
        return
    fi

    if [ "$attempts" = "1" ]; then
        echo "1 attempt"
        return
    fi

    echo "${attempts} attempts"
}

table_iterations() {
    local step_json="$1"
    local gate_result attempts
    gate_result=$(echo "$step_json" | jq -r '.gate_result // "null"')
    attempts=$(echo "$step_json" | jq -r '.attempts // 0')

    if [ "$gate_result" != "null" ]; then
        echo "-"
        return
    fi

    echo "$attempts"
}

sanitize_inline_text() {
    printf '%s' "$1" | tr '\n' ' '
}

sanitize_table_cell() {
    sanitize_inline_text "$1" | sed 's/\\/\\\\/g; s/|/\\|/g'
}

emit_codex() {
    echo "Execution Summary"
    echo ""

    while IFS= read -r step_json; do
        local number name normalized symbol attempts
        number=$(echo "$step_json" | jq -r '.number')
        name=$(echo "$step_json" | jq -r '.name')
        name=$(sanitize_inline_text "$name")
        normalized=$(normalize_status "$step_json")
        symbol=$(status_symbol "$normalized")
        attempts=$(attempt_text "$step_json")

        printf "%s Step %s: %s - %s (%s)\n" "$symbol" "$number" "$name" "$normalized" "$attempts"
    done < <(jq -c '.steps[]' "$summary_json")
}

emit_table() {
    echo "| Step | Name | Status | Iterations |"
    echo "|------|------|--------|------------|"

    while IFS= read -r step_json; do
        local number name normalized symbol iterations
        number=$(echo "$step_json" | jq -r '.number')
        name=$(echo "$step_json" | jq -r '.name')
        name=$(sanitize_table_cell "$name")
        normalized=$(normalize_status "$step_json")
        symbol=$(status_symbol "$normalized")
        iterations=$(table_iterations "$step_json")

        printf "| %s | %s | %s %s | %s |\n" "$number" "$name" "$symbol" "$normalized" "$iterations"
    done < <(jq -c '.steps[]' "$summary_json")
}

case "$platform" in
    codex) emit_codex ;;
    claude|cline) emit_table ;;
    *)
        echo "ERROR: Unsupported platform: $platform" >&2
        exit 1
        ;;
esac
