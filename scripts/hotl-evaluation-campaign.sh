#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf '%s\n' \
        "usage: hotl-evaluation-campaign.sh validate <campaign.json>" \
        "       hotl-evaluation-campaign.sh plan <campaign.json>"
}

require_jq() {
    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq is required for HOTL evaluation campaigns." >&2
        exit 1
    }
}

sha256_file() {
    local file="$1"

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        echo "ERROR: shasum or sha256sum is required." >&2
        return 1
    fi
}

assert_path_within_campaign() {
    local campaign_dir="$1"
    local path="$2"
    local label="$3"
    local physical_parent

    if [ -L "$path" ]; then
        echo "ERROR: campaign $label escapes campaign directory through a symlink: $path" >&2
        return 1
    fi
    physical_parent="$(cd "$(dirname "$path")" && pwd -P)" || {
        echo "ERROR: unable to resolve campaign $label parent: $path" >&2
        return 1
    }
    case "$physical_parent" in
        "$campaign_dir"|"$campaign_dir"/*) ;;
        *)
            echo "ERROR: campaign $label escapes campaign directory: $path" >&2
            return 1
            ;;
    esac
}

assert_future_path_within_campaign() {
    local campaign_dir="$1"
    local path="$2"
    local label="$3"
    local existing="$path"
    local physical_existing

    while [ ! -e "$existing" ] && [ ! -L "$existing" ]; do
        [ "$existing" != "/" ] || break
        existing="$(dirname "$existing")"
    done
    if [ -L "$existing" ] && [ ! -d "$existing" ]; then
        echo "ERROR: campaign $label escapes campaign directory through a symlink: $path" >&2
        return 1
    fi
    if [ -d "$existing" ]; then
        physical_existing="$(cd "$existing" && pwd -P)" || return 1
    else
        physical_existing="$(cd "$(dirname "$existing")" && pwd -P)/$(basename "$existing")" || return 1
    fi
    case "$physical_existing" in
        "$campaign_dir"|"$campaign_dir"/*) ;;
        *)
            echo "ERROR: campaign $label escapes campaign directory: $path" >&2
            return 1
            ;;
    esac
}

validate_campaign() {
    local campaign="$1"

    [ -f "$campaign" ] || {
        echo "ERROR: evaluation campaign not found: $campaign" >&2
        return 1
    }

    jq -e '
      def nonempty_string: type == "string" and length > 0;
      def nullable_string: . == null or nonempty_string;
      def positive_integer: type == "number" and floor == . and . > 0;
      def nonnegative_number: type == "number" and . >= 0;
      def valid_timestamp: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
      def valid_date: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
      def valid_id: nonempty_string and test("^[a-z0-9][a-z0-9._/-]*$");
      def valid_hash: nonempty_string and test("^[a-f0-9]{64}$");
      def safe_path:
        nonempty_string and
        test("^[A-Za-z0-9._/-]+$") and
        (startswith("/") | not) and
        (split("/") | all(.[]; . != ".." and length > 0));
      def allowed($values): . as $value | $values | index($value) != null;
      .schema == "hotl.evaluation-campaign/v1" and
      (.campaign_id | valid_id) and
      (.protocol_revision | valid_date) and
      (.created_at | valid_timestamp) and
      (.output_root | safe_path) and
      (.repetitions | positive_integer) and
      (.profiles | type == "array" and length > 0) and
      (all(.profiles[];
        (.profile_id | valid_id) and
        (.host | allowed(["codex", "claude-code", "generic"])) and
        (.requested_model | nullable_string) and
        (.requested_effort == null or
         (if .host == "codex" then
            (.requested_effort | allowed(["minimal", "low", "medium", "high", "xhigh"]))
          elif .host == "claude-code" then
            (.requested_effort | allowed(["low", "medium", "high", "xhigh", "max"]))
          else
            (.requested_effort | allowed(["minimal", "low", "medium", "high", "xhigh", "max"]))
          end)) and
        (.adapter_version | nullable_string))) and
      ((.profiles | map(.profile_id) | unique | length) == (.profiles | length)) and
      (.scenarios | type == "array" and length > 0) and
      (all(.scenarios[];
        (.scenario_id | valid_id) and
        (.scenario_revision | valid_date) and
        (.prompt_path | safe_path) and
        (.prompt_sha256 | valid_hash) and
        (.response_schema_path | safe_path) and
        (.response_schema_sha256 | valid_hash) and
        (.assertion_path | safe_path) and
        (.assertion_sha256 | valid_hash))) and
      ((.scenarios | map(.scenario_id + "@" + .scenario_revision) | unique | length) == (.scenarios | length)) and
      (.budgets | type == "object") and
      (.budgets.max_calls | positive_integer) and
      (.budgets.max_elapsed_minutes | positive_integer) and
      (.budgets.max_cost_usd == null or (.budgets.max_cost_usd | nonnegative_number)) and
      (.capture.raw_output | allowed(["none", "local"])) and
      (.capture.prompts | allowed(["none", "hash_only", "local"])) and
      (.capture.redact | type == "boolean")
    ' "$campaign" >/dev/null || {
        echo "ERROR: invalid HOTL evaluation campaign: $campaign" >&2
        return 1
    }

    local planned_calls max_calls
    planned_calls="$(jq '(.profiles | length) * (.scenarios | length) * .repetitions' "$campaign")"
    max_calls="$(jq '.budgets.max_calls' "$campaign")"
    if [ "$planned_calls" -gt "$max_calls" ]; then
        echo "ERROR: planned call count $planned_calls exceeds max_calls $max_calls" >&2
        return 1
    fi

    local campaign_dir
    campaign_dir="$(cd "$(dirname "$campaign")" && pwd -P)"
    local output_relative
    output_relative="$(jq -r '.output_root' "$campaign")"
    assert_future_path_within_campaign "$campaign_dir" "${campaign_dir}/${output_relative}" "output_root"
    local relative_path expected_hash actual_hash full_path label
    while IFS=$'\t' read -r label relative_path expected_hash; do
        full_path="${campaign_dir}/${relative_path}"
        [ -f "$full_path" ] || {
            echo "ERROR: campaign $label artifact not found: $relative_path" >&2
            return 1
        }
        assert_path_within_campaign "$campaign_dir" "$full_path" "$label artifact"
        actual_hash="$(sha256_file "$full_path")"
        [ "$actual_hash" = "$expected_hash" ] || {
            echo "ERROR: campaign $label hash mismatch: $relative_path" >&2
            return 1
        }
    done < <(jq -r '.scenarios[] |
      ["prompt", .prompt_path, .prompt_sha256],
      ["response_schema", .response_schema_path, .response_schema_sha256],
      ["assertion", .assertion_path, .assertion_sha256] | @tsv' "$campaign")

    echo "Evaluation campaign valid: $campaign"
}

plan_campaign() {
    local campaign="$1"

    validate_campaign "$campaign" >/dev/null
    jq -cS '
      . as $campaign |
      ([
        $campaign.profiles[] as $profile |
        $campaign.scenarios[] as $scenario |
        range(1; $campaign.repetitions + 1) as $repetition |
        {
          call_id:(
            $campaign.campaign_id + "/" +
            $profile.profile_id + "/" +
            $scenario.scenario_id + "@" + $scenario.scenario_revision + "/" +
            ($repetition | tostring)
          ),
          profile_id:$profile.profile_id,
          host:$profile.host,
          scenario_id:$scenario.scenario_id,
          scenario_revision:$scenario.scenario_revision,
          repetition:$repetition
        }
      ] | sort_by(.call_id)) as $calls |
      {
        schema:"hotl.evaluation-campaign-plan/v1",
        campaign_id:$campaign.campaign_id,
        protocol_revision:$campaign.protocol_revision,
        output_root:$campaign.output_root,
        planned_calls:($calls | length),
        budgets:$campaign.budgets,
        calls:$calls,
        requires_live_approval:true,
        live_execution:false,
        schedule_changes_performed:false,
        configuration_changes_performed:false
      }
    ' "$campaign"
}

main() {
    require_jq
    [ "$#" -eq 2 ] || {
        usage >&2
        exit 1
    }

    case "$1" in
        validate)
            validate_campaign "$2"
            ;;
        plan)
            plan_campaign "$2"
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
