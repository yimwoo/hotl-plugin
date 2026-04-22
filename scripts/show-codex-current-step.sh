#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOTL_RT="$REPO_ROOT/runtime/hotl-rt"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not found." >&2
    exit 1
fi

run_id="${1:-${HOTL_RUN_ID:-}}"
state_dir=".hotl/state"

if [ -n "$run_id" ]; then
    state_file="${state_dir}/${run_id}.json"
    if [ ! -f "$state_file" ]; then
        echo "ERROR: No HOTL run found for run_id: ${run_id}" >&2
        exit 1
    fi
else
    shopt -s nullglob
    state_files=("${state_dir}"/*.json)
    shopt -u nullglob
    if [ "${#state_files[@]}" -eq 0 ]; then
        echo "ERROR: No active HOTL run found in .hotl/state/" >&2
        exit 1
    fi
    if [ "${#state_files[@]}" -gt 1 ]; then
        echo "ERROR: Multiple HOTL runs found. Pass a run id or set HOTL_RUN_ID." >&2
        exit 1
    fi
    state_file="${state_files[0]}"
fi

run_id="$(jq -r '.run_id' "$state_file")"
summary_json="$("$HOTL_RT" summary "$run_id" --json)"
state_current_step="$(jq -r '.current_step // 1' "$state_file")"
current_index="$(echo "$summary_json" | jq -r '
    .steps
    | map(select(.status == "in_progress"))[0].number // empty
')"
if [ -z "$current_index" ]; then
    current_index="$state_current_step"
fi
step_total="$(echo "$summary_json" | jq -r '.total_steps')"
step_name="$(echo "$summary_json" | jq -r --argjson idx "$current_index" '.steps[$idx - 1].name')"
step_status="$(echo "$summary_json" | jq -r --argjson idx "$current_index" '.steps[$idx - 1].status')"
step_attempts="$(echo "$summary_json" | jq -r --argjson idx "$current_index" '.steps[$idx - 1].attempts')"

cat <<EOF
Current step: ${current_index}/${step_total}
Name: ${step_name}
Status: ${step_status}
Attempts: ${step_attempts}
EOF
