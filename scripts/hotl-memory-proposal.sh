#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOTL_RT="${HOTL_RT:-$SCRIPT_DIR/../runtime/hotl-rt}"

[ $# -ge 1 ] || { echo "usage: hotl-memory-proposal.sh <run-id> [--fact <text>] [--scope <scope>]" >&2; exit 1; }
run_id="$1"; shift
fact=""; scope="project"
while [ $# -gt 0 ]; do
    case "$1" in --fact) fact="$2"; shift 2 ;; --scope) scope="$2"; shift 2 ;; *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;; esac
done

receipt=$("$HOTL_RT" receipt "$run_id" --json)
if [ -n "$fact" ]; then
    facts=$(jq -cn --arg fact "$fact" --arg scope "$scope" '[{text:$fact,scope:$scope,status:"proposed"}]')
else
    facts='[]'
fi

jq -cn --argjson receipt "$receipt" --argjson facts "$facts" '{
  schema:"hotl.memory-proposal/v1",
  status:"needs-human-review",
  source_run:$receipt.run.id,
  receipt_sufficient:$receipt.sufficiency.sufficient,
  proposed_facts:$facts,
  evidence_refs:[{run_id:$receipt.run.id,workflow:$receipt.run.workflow_path,finish:$receipt.finish.disposition}],
  writes_performed:false,
  instructions:"Review each proposed fact for durability, scope, and sensitivity before writing it to project memory."
}'
