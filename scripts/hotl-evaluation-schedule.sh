#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CAMPAIGN_HELPER="${HOTL_EVAL_CAMPAIGN_HELPER:-${SCRIPT_DIR}/hotl-evaluation-campaign.sh}"

usage() {
    echo "usage: hotl-evaluation-schedule.sh preflight <campaign.json> --host codex|claude-code --run-label ID"
}

main() {
    [ "$#" -ge 2 ] || {
        usage >&2
        exit 1
    }
    [ "$1" = "preflight" ] || {
        usage >&2
        exit 1
    }
    local campaign="$2"
    shift 2

    local automation_host=""
    local run_label=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --host)
                [ "$#" -ge 2 ] || {
                    echo "ERROR: --host requires codex or claude-code." >&2
                    exit 1
                }
                automation_host="$2"
                shift 2
                ;;
            --run-label)
                [ "$#" -ge 2 ] || {
                    echo "ERROR: --run-label requires a value." >&2
                    exit 1
                }
                run_label="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "ERROR: unknown schedule-preflight option: $1" >&2
                exit 1
                ;;
        esac
    done

    case "$automation_host" in
        codex|claude-code) ;;
        *)
            echo "ERROR: --host must be codex or claude-code." >&2
            exit 1
            ;;
    esac
    [[ "$run_label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
        echo "ERROR: --run-label must use only letters, numbers, dot, underscore, or hyphen." >&2
        exit 1
    }

    bash "$CAMPAIGN_HELPER" validate "$campaign" >/dev/null
    local plan max_cost unsupported_cost_host
    plan="$(bash "$CAMPAIGN_HELPER" plan "$campaign")"
    max_cost="$(jq -c '.budgets.max_cost_usd' "$campaign")"
    if [ "$max_cost" != "null" ]; then
        unsupported_cost_host="$(jq -r '[.profiles[].host | select(. != "claude-code")][0] // ""' "$campaign")"
        if [ -n "$unsupported_cost_host" ]; then
            echo "ERROR: $unsupported_cost_host cannot enforce max_cost_usd before a provider call; scheduled collection is blocked." >&2
            exit 1
        fi
    fi

    local campaign_dir output_relative run_output template
    campaign_dir="$(cd "$(dirname "$campaign")" && pwd -P)"
    campaign="${campaign_dir}/$(basename "$campaign")"
    output_relative="$(jq -r '.output_root' "$campaign")"
    run_output="${campaign_dir}/${output_relative}/${run_label}"
    [ ! -e "$run_output" ] || {
        echo "ERROR: scheduled evaluation output already exists: $run_output" >&2
        exit 1
    }
    template="${REPO_ROOT}/automations/continuous-evaluation/${automation_host}.md"

    jq -cnS \
        --arg automation_host "$automation_host" \
        --arg campaign "$campaign" \
        --arg campaign_id "$(jq -r '.campaign_id' "$campaign")" \
        --arg run_label "$run_label" \
        --arg run_output "$run_output" \
        --arg template "$template" \
        --argjson planned_calls "$(jq '.planned_calls' <<< "$plan")" \
        --argjson budgets "$(jq -c '.budgets' "$campaign")" \
        --argjson capture "$(jq -c '.capture' "$campaign")" '
      {
        schema:"hotl.evaluation-schedule-preflight/v1",
        automation_host:$automation_host,
        native_schedule_kind:(if $automation_host == "codex"
                              then "codex-project-automation"
                              else "claude-desktop-local-task"
                              end),
        campaign_path:$campaign,
        campaign_id:$campaign_id,
        run_label:$run_label,
        run_output:$run_output,
        template_path:$template,
        planned_calls:$planned_calls,
        budgets:$budgets,
        capture:$capture,
        enforcement:{
          max_calls:"hard",
          max_elapsed_minutes:"hard",
          max_cost_usd:(if $budgets.max_cost_usd == null then "unset" else "host-native-hard-limit" end),
          unknown_telemetry:"stop"
        },
        credentials_status:"unverified",
        blocking_reasons:[
          "human_schedule_approval_required",
          "human_live_campaign_approval_required",
          "credentials_unverified"
        ],
        ready_to_enable:false,
        provider_calls_performed:false,
        output_created:false,
        schedule_changes_performed:false,
        configuration_changes_performed:false
      }
    '
}

main "$@"
