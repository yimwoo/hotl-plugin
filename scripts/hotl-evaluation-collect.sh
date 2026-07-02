#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CAMPAIGN_HELPER="${HOTL_EVAL_CAMPAIGN_HELPER:-${SCRIPT_DIR}/hotl-evaluation-campaign.sh}"
CONFORMANCE="${HOTL_CONFORMANCE:-${SCRIPT_DIR}/hotl-conformance.sh}"
CLEANUP_ROOT=""

cleanup() {
    [ -z "$CLEANUP_ROOT" ] || rm -rf "$CLEANUP_ROOT"
}

usage() {
    printf '%s\n' \
        "usage: hotl-evaluation-collect.sh run <campaign.json> --approve-live [--run-label ID] [--call-timeout-seconds N]" \
        "" \
        "Live execution is opt-in. The collector writes only beneath the campaign output_root" \
        "and never changes HOTL or host configuration."
}

require_tools() {
    local tool
    for tool in jq sed awk; do
        command -v "$tool" >/dev/null 2>&1 || {
            echo "ERROR: $tool is required for HOTL evaluation collection." >&2
            return 1
        }
    done
}

positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

sha256_file() {
    local file="$1"

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        echo "ERROR: shasum or sha256sum is required for evaluation evidence." >&2
        return 1
    fi
}

resolve_binary() {
    local candidate="$1"
    local resolved

    if [[ "$candidate" == */* ]]; then
        [ -x "$candidate" ] || return 1
        resolved="$(cd "$(dirname "$candidate")" && pwd -P)/$(basename "$candidate")"
    else
        resolved="$(command -v "$candidate" 2>/dev/null || true)"
        [ -n "$resolved" ] && [ -x "$resolved" ] || return 1
    fi
    printf '%s\n' "$resolved"
}

binary_for_host() {
    case "$1" in
        codex)
            resolve_binary "${HOTL_EVAL_CODEX_BIN:-codex}"
            ;;
        claude-code)
            resolve_binary "${HOTL_EVAL_CLAUDE_BIN:-claude}"
            ;;
        generic)
            [ -n "${HOTL_EVAL_GENERIC_BIN:-}" ] || {
                echo "ERROR: generic evaluation requires HOTL_EVAL_GENERIC_BIN." >&2
                return 1
            }
            resolve_binary "$HOTL_EVAL_GENERIC_BIN"
            ;;
        *)
            echo "ERROR: unsupported evaluation host: $1" >&2
            return 1
            ;;
    esac
}

host_version() {
    local binary="$1"
    local version

    version="$("$binary" --version 2>&1)" || {
        echo "ERROR: unable to query evaluation host version: $binary" >&2
        return 1
    }
    printf '%s\n' "$version" | awk 'NF { print; exit }'
}

run_with_timeout() {
    local timeout_seconds="$1"
    local stdin_file="$2"
    local stdout_file="$3"
    local stderr_file="$4"
    shift 4

    ("$@" < "$stdin_file" > "$stdout_file" 2> "$stderr_file") &
    local command_pid=$!
    local started_at=$SECONDS

    while kill -0 "$command_pid" 2>/dev/null; do
        if [ "$((SECONDS - started_at))" -ge "$timeout_seconds" ]; then
            kill -TERM "$command_pid" 2>/dev/null || true
            sleep 0.1
            kill -KILL "$command_pid" 2>/dev/null || true
            wait "$command_pid" 2>/dev/null || true
            return 124
        fi
        sleep 0.1
    done

    if wait "$command_pid"; then
        return 0
    else
        return $?
    fi
}

redact_text_file() {
    local source_file="$1"
    local destination_file="$2"
    local redact="$3"

    if [ "$redact" = "true" ]; then
        sed -E \
            -e 's/([Aa]uthorization[[:space:]]*:[[:space:]]*[Bb]earer[[:space:]]+)[^[:space:]",}]+/\1[REDACTED]/g' \
            -e 's/("?(authorization|api[_-]?key|access[_-]?token|token|secret|password)"?[[:space:]]*[:=][[:space:]]*"?)[^[:space:]",}]+/\1[REDACTED]/g' \
            "$source_file" > "$destination_file"
    else
        cp "$source_file" "$destination_file"
    fi
}

redact_json_file() {
    local source_file="$1"
    local destination_file="$2"
    local redact="$3"

    if [ "$redact" = "true" ]; then
        jq -cS '
          walk(
            if type == "object" then
              with_entries(
                if (.key | test("authorization|api[_-]?key|access[_-]?token|secret|password"; "i"))
                then .value = "[REDACTED]"
                else .
                end)
            else .
            end)
        ' "$source_file" > "$destination_file"
    else
        jq -cS . "$source_file" > "$destination_file"
    fi
}

validate_structured_response() {
    local response_file="$1"
    local schema_file="$2"

    jq -e --slurpfile schema "$schema_file" '
      def matches_type($value; $expected):
        if $expected == null then true
        elif $expected == "integer" then ($value | type == "number" and floor == .)
        elif $expected == "number" then ($value | type == "number")
        else ($value | type == $expected)
        end;
      . as $response |
      $schema[0] as $definition |
      matches_type($response; $definition.type) and
      (if $definition.type == "object" then
         all(($definition.required // [])[]; . as $key | $response | has($key)) and
         all((($definition.properties // {}) | to_entries)[];
             . as $property |
             (($response | has($property.key)) | not) or
             matches_type($response[$property.key]; $property.value.type)) and
         (if $definition.additionalProperties == false then
            (($response | keys_unsorted) - (($definition.properties // {}) | keys_unsorted) | length) == 0
          else true
          end)
       else true
       end)
    ' "$response_file" >/dev/null
}

normalize_codex() {
    local raw_file="$1"
    local response_file="$2"
    local requested_model="$3"
    local requested_effort="$4"
    local duration_ms="$5"

    jq -e . "$response_file" >/dev/null
    jq -s -e 'length > 0 and all(.[]; type == "object")' "$raw_file" >/dev/null
    jq -cn \
        --arg requested_model "$requested_model" \
        --arg requested_effort "$requested_effort" \
        --argjson duration_ms "$duration_ms" \
        --slurpfile response "$response_file" \
        --slurpfile events "$raw_file" '
      ($events | map(select(.type == "turn.completed")) | last // {}) as $turn |
      ($turn.usage // {}) as $usage |
      ($usage.input_tokens // null) as $input_total |
      ($usage.cached_input_tokens // 0) as $cached |
      ($usage.output_tokens // null) as $output |
      (($input_total | type) == "number" and
       ($cached | type) == "number" and
       ($output | type) == "number" and
       $input_total >= $cached and $cached >= 0 and $output >= 0) as $tokens_observed |
      {
        structured_output:$response[0],
        resolved_model:($turn.model // (if $requested_model == "" then null else $requested_model end)),
        effort_profile:(if $requested_effort == "" then null else $requested_effort end),
        duration_ms:$duration_ms,
        tokens:(if $tokens_observed then
                  {source:"observed",input:($input_total - $cached),output:$output,cached:$cached}
                else
                  {source:"unavailable",input:null,output:null,cached:null}
                end),
        cost:{source:"unavailable",usd:null},
        telemetry_provenance:{
          normalization_version:"hotl.tokens/v1",
          tokens:(if $tokens_observed then
                    {source:"codex-json",input_semantics:"uncached_input",cached_semantics:"separate_subset",normalized:true}
                  else
                    {source:"codex-json",input_semantics:"unavailable",cached_semantics:"unavailable",normalized:false}
                  end),
          cost:{source:"unavailable"}
        }
      }
    '
}

normalize_claude() {
    local raw_file="$1"
    local requested_model="$2"
    local requested_effort="$3"
    local measured_duration_ms="$4"

    jq -e '.type == "result" and (.structured_output | type != "null")' "$raw_file" >/dev/null
    jq -c \
        --arg requested_model "$requested_model" \
        --arg requested_effort "$requested_effort" \
        --argjson measured_duration_ms "$measured_duration_ms" '
      . as $result |
      ($result.usage // {}) as $usage |
      ($usage.input_tokens // null) as $input |
      ($usage.output_tokens // null) as $output |
      ($usage.cache_read_input_tokens // 0) as $cached |
      (($input | type) == "number" and
       ($output | type) == "number" and
       ($cached | type) == "number" and
       $input >= 0 and $output >= 0 and $cached >= 0) as $tokens_observed |
      (($result.total_cost_usd | type) == "number" and $result.total_cost_usd >= 0) as $cost_observed |
      {
        structured_output:$result.structured_output,
        resolved_model:(
          $result.model //
          (($result.modelUsage // {}) | keys_unsorted | first) //
          (if $requested_model == "" then null else $requested_model end)
        ),
        effort_profile:(if $requested_effort == "" then null else $requested_effort end),
        duration_ms:($result.duration_ms // $measured_duration_ms),
        tokens:(if $tokens_observed then
                  {source:"observed",input:$input,output:$output,cached:$cached}
                else
                  {source:"unavailable",input:null,output:null,cached:null}
                end),
        cost:(if $cost_observed then
               {source:"observed",usd:$result.total_cost_usd}
             else
               {source:"unavailable",usd:null}
             end),
        telemetry_provenance:{
          normalization_version:"hotl.tokens/v1",
          tokens:(if $tokens_observed then
                    {source:"claude-json",input_semantics:"disjoint_counters",cached_semantics:"disjoint_counter",normalized:true}
                  else
                    {source:"claude-json",input_semantics:"unavailable",cached_semantics:"unavailable",normalized:false}
                  end),
          cost:{source:(if $cost_observed then "observed" else "unavailable" end)}
        }
      }
    ' "$raw_file"
}

normalize_generic() {
    local raw_file="$1"
    local requested_model="$2"
    local requested_effort="$3"
    local measured_duration_ms="$4"

    jq -e '
      def nonnegative_number: type == "number" and . >= 0;
      .schema == "hotl.evaluation-adapter-result/v1" and
      (.structured_output | type != "null") and
      (.tokens.source == "unavailable" or
       (.tokens.source == "observed" and
        (.tokens.input | nonnegative_number) and
        (.tokens.output | nonnegative_number) and
        (.tokens.cached | nonnegative_number) and
        (.telemetry_provenance.tokens.input_semantics | type == "string") and
        (.telemetry_provenance.tokens.cached_semantics | type == "string"))) and
      (.cost.source == "unavailable" or
       (.cost.source == "observed" and (.cost.usd | nonnegative_number)))
    ' "$raw_file" >/dev/null
    jq -c \
        --arg requested_model "$requested_model" \
        --arg requested_effort "$requested_effort" \
        --argjson measured_duration_ms "$measured_duration_ms" '
      . as $result |
      ($result.tokens.source == "observed") as $tokens_observed |
      ($result.cost.source == "observed") as $cost_observed |
      {
        structured_output:$result.structured_output,
        resolved_model:($result.resolved_model // (if $requested_model == "" then null else $requested_model end)),
        effort_profile:($result.effort_profile // (if $requested_effort == "" then null else $requested_effort end)),
        duration_ms:($result.duration_ms // $measured_duration_ms),
        tokens:(if $tokens_observed then $result.tokens else {source:"unavailable",input:null,output:null,cached:null} end),
        cost:(if $cost_observed then $result.cost else {source:"unavailable",usd:null} end),
        telemetry_provenance:{
          normalization_version:"hotl.tokens/v1",
          tokens:(if $tokens_observed then
                    {source:"generic-adapter",
                     input_semantics:$result.telemetry_provenance.tokens.input_semantics,
                     cached_semantics:$result.telemetry_provenance.tokens.cached_semantics,
                     normalized:true}
                  else
                    {source:"generic-adapter",input_semantics:"unavailable",cached_semantics:"unavailable",normalized:false}
                  end),
          cost:{source:(if $cost_observed then "observed" else "unavailable" end)}
        }
      }
    ' "$raw_file"
}

run_host() {
    local host="$1"
    local binary="$2"
    local prompt_file="$3"
    local schema_file="$4"
    local requested_model="$5"
    local requested_effort="$6"
    local remaining_cost="$7"
    local timeout_seconds="$8"
    local raw_file="$9"
    local error_file="${10}"
    local response_file="${11}"
    local -a arguments

    case "$host" in
        codex)
            arguments=(exec --ephemeral --skip-git-repo-check --sandbox read-only -C "$REPO_ROOT" --output-schema "$schema_file" --json -o "$response_file")
            [ -z "$requested_model" ] || arguments+=(-m "$requested_model")
            [ -z "$requested_effort" ] || arguments+=(-c "model_reasoning_effort=\"$requested_effort\"")
            arguments+=(-)
            run_with_timeout "$timeout_seconds" "$prompt_file" "$raw_file" "$error_file" "$binary" "${arguments[@]}"
            ;;
        claude-code)
            arguments=(--print --output-format json --json-schema "$(jq -c . "$schema_file")" --no-session-persistence --tools "" --permission-mode dontAsk)
            [ -z "$requested_model" ] || arguments+=(--model "$requested_model")
            [ -z "$requested_effort" ] || arguments+=(--effort "$requested_effort")
            [ "$remaining_cost" = "null" ] || arguments+=(--max-budget-usd "$remaining_cost")
            run_with_timeout "$timeout_seconds" "$prompt_file" "$raw_file" "$error_file" "$binary" "${arguments[@]}"
            ;;
        generic)
            arguments=(--prompt-file "$prompt_file" --response-schema "$schema_file")
            [ -z "$requested_model" ] || arguments+=(--model "$requested_model")
            [ -z "$requested_effort" ] || arguments+=(--effort "$requested_effort")
            run_with_timeout "$timeout_seconds" "$prompt_file" "$raw_file" "$error_file" "$binary" "${arguments[@]}"
            ;;
    esac
}

collect_campaign() {
    local campaign="$1"
    local approved_live="$2"
    local call_timeout_seconds="$3"
    local run_label="$4"

    [ "$approved_live" = "true" ] || {
        echo "ERROR: evaluation collection requires explicit live approval via --approve-live." >&2
        return 1
    }

    bash "$CAMPAIGN_HELPER" validate "$campaign" >/dev/null

    local campaign_dir output_relative output_root
    campaign_dir="$(cd "$(dirname "$campaign")" && pwd -P)"
    campaign="${campaign_dir}/$(basename "$campaign")"
    output_relative="$(jq -r '.output_root' "$campaign")"
    output_root="${campaign_dir}/${output_relative}"
    [ -z "$run_label" ] || output_root="${output_root}/${run_label}"
    [ ! -e "$output_root" ] || {
        echo "ERROR: evaluation output_root already exists: $output_root" >&2
        return 1
    }

    local host binary
    while IFS= read -r host; do
        binary="$(binary_for_host "$host")" || {
            echo "ERROR: evaluation host binary unavailable for $host." >&2
            return 1
        }
        host_version "$binary" >/dev/null
    done < <(jq -r '.profiles[].host' "$campaign" | sort -u)

    local plan planned_calls max_elapsed_minutes max_elapsed_seconds max_cost
    plan="$(bash "$CAMPAIGN_HELPER" plan "$campaign")"
    planned_calls="$(jq '.planned_calls' <<< "$plan")"
    max_elapsed_minutes="$(jq '.budgets.max_elapsed_minutes' "$campaign")"
    max_elapsed_seconds="$((max_elapsed_minutes * 60))"
    max_cost="$(jq -c '.budgets.max_cost_usd' "$campaign")"

    if [ "$max_cost" != "null" ]; then
        local unsupported_cost_host
        unsupported_cost_host="$(jq -r '[.profiles[].host | select(. != "claude-code")][0] // ""' "$campaign")"
        if [ -n "$unsupported_cost_host" ]; then
            echo "ERROR: $unsupported_cost_host cannot enforce max_cost_usd before a provider call; use null or a host-native hard budget." >&2
            return 1
        fi
    fi

    mkdir -p "$output_root/.tmp" "$output_root/evidence"
    local temporary_root="$output_root/.tmp"
    CLEANUP_ROOT="$temporary_root"
    trap cleanup EXIT

    local campaign_id protocol_revision campaign_sha256 recorded_at run_timestamp run_id
    campaign_id="$(jq -r '.campaign_id' "$campaign")"
    protocol_revision="$(jq -r '.protocol_revision' "$campaign")"
    campaign_sha256="$(sha256_file "$campaign")"
    recorded_at="${HOTL_EVAL_RECORDED_AT:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}"
    run_timestamp="$(printf '%s' "$recorded_at" | tr -d ':-')"
    run_id="${campaign_id}-${run_timestamp}"
    [ -z "$run_label" ] || run_id="${campaign_id}/${run_label}"

    local calls_completed=0 calls_failed=0 observed_cost="0" result_paths='[]'
    local manifest="$output_root/campaign-run.json"
    write_manifest() {
        local status="$1"
        local stop_reason="$2"
        local manifest_tmp="$temporary_root/campaign-run.json"
        jq -nS \
            --arg campaign_id "$campaign_id" \
            --arg campaign_path "$campaign" \
            --arg campaign_sha256 "$campaign_sha256" \
            --arg protocol_revision "$protocol_revision" \
            --arg run_label "$run_label" \
            --arg run_id "$run_id" \
            --arg recorded_at "$recorded_at" \
            --arg status "$status" \
            --arg stop_reason "$stop_reason" \
            --argjson planned_calls "$planned_calls" \
            --argjson calls_completed "$calls_completed" \
            --argjson calls_failed "$calls_failed" \
            --argjson observed_cost "$observed_cost" \
            --argjson results "$result_paths" '
          {
            schema:"hotl.evaluation-campaign-run/v1",
            campaign_id:$campaign_id,
            campaign_path:$campaign_path,
            campaign_sha256:$campaign_sha256,
            protocol_revision:$protocol_revision,
            run_label:(if $run_label == "" then null else $run_label end),
            run_id:$run_id,
            recorded_at:$recorded_at,
            status:$status,
            stop_reason:(if $stop_reason == "" then null else $stop_reason end),
            planned_calls:$planned_calls,
            calls_completed:$calls_completed,
            calls_failed:$calls_failed,
            observed_cost_usd:$observed_cost,
            results:$results,
            live_approval_observed:true,
            schedule_changes_performed:false,
            configuration_changes_performed:false
          }
        ' > "$manifest_tmp"
        mv "$manifest_tmp" "$manifest"
    }
    write_manifest running ""

    local capture_raw capture_prompts capture_redact
    capture_raw="$(jq -r '.capture.raw_output' "$campaign")"
    capture_prompts="$(jq -r '.capture.prompts' "$campaign")"
    capture_redact="$(jq -r '.capture.redact' "$campaign")"

    local repo_revision os_name architecture toolchain_fingerprint
    repo_revision="${HOTL_EVAL_REPO_REVISION:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf unknown)}"
    os_name="${HOTL_EVAL_OS:-$(uname -s)-$(uname -r)}"
    architecture="${HOTL_EVAL_ARCH:-$(uname -m)}"
    toolchain_fingerprint="${HOTL_EVAL_TOOLCHAIN_FINGERPRINT:-hotl-evaluation-collector-v1_jq-$(jq --version)}"

    local campaign_started=$SECONDS call
    while IFS= read -r call; do
        local elapsed remaining_elapsed effective_timeout
        elapsed="$((SECONDS - campaign_started))"
        remaining_elapsed="$((max_elapsed_seconds - elapsed))"
        if [ "$remaining_elapsed" -le 0 ]; then
            write_manifest incomplete elapsed_budget_exceeded
            echo "ERROR: evaluation elapsed-time budget exceeded before the next call." >&2
            return 1
        fi
        effective_timeout="$call_timeout_seconds"
        [ "$effective_timeout" -le "$remaining_elapsed" ] || effective_timeout="$remaining_elapsed"

        if [ "$max_cost" != "null" ] && [ "$calls_completed" -gt 0 ] &&
           jq -en --argjson observed "$observed_cost" --argjson maximum "$max_cost" '$observed >= $maximum' >/dev/null; then
            write_manifest incomplete cost_budget_exhausted
            echo "ERROR: evaluation cost budget is exhausted before the next call." >&2
            return 1
        fi

        local call_id profile_id scenario_id scenario_revision
        call_id="$(jq -r '.call_id' <<< "$call")"
        profile_id="$(jq -r '.profile_id' <<< "$call")"
        host="$(jq -r '.host' <<< "$call")"
        scenario_id="$(jq -r '.scenario_id' <<< "$call")"
        scenario_revision="$(jq -r '.scenario_revision' <<< "$call")"

        local profile scenario requested_model requested_effort adapter_version
        profile="$(jq -c --arg id "$profile_id" '.profiles[] | select(.profile_id == $id)' "$campaign")"
        scenario="$(jq -c --arg id "$scenario_id" --arg revision "$scenario_revision" \
            '.scenarios[] | select(.scenario_id == $id and .scenario_revision == $revision)' "$campaign")"
        requested_model="$(jq -r '.requested_model // ""' <<< "$profile")"
        requested_effort="$(jq -r '.requested_effort // ""' <<< "$profile")"
        adapter_version="$(jq -r '.adapter_version // empty' <<< "$profile")"

        local prompt_file schema_file assertion_file
        prompt_file="${campaign_dir}/$(jq -r '.prompt_path' <<< "$scenario")"
        schema_file="${campaign_dir}/$(jq -r '.response_schema_path' <<< "$scenario")"
        assertion_file="${campaign_dir}/$(jq -r '.assertion_path' <<< "$scenario")"

        local slug raw_file error_file response_file normalized_file
        slug="${call_id//\//--}"
        raw_file="$temporary_root/${slug}.stdout"
        error_file="$temporary_root/${slug}.stderr"
        response_file="$temporary_root/${slug}.response.json"
        normalized_file="$temporary_root/${slug}.normalized.json"

        local prompt_capture_hash="" prompt_capture_path=""
        if [ "$capture_prompts" != "none" ]; then
            prompt_capture_hash="$(sha256_file "$prompt_file")"
        fi
        if [ "$capture_prompts" = "local" ]; then
            prompt_capture_path="$output_root/evidence/${slug}.prompt.txt"
            redact_text_file "$prompt_file" "$prompt_capture_path" "$capture_redact"
        fi

        binary="$(binary_for_host "$host")"
        local version
        version="$(host_version "$binary")"

        local remaining_cost="null"
        if [ "$max_cost" != "null" ]; then
            remaining_cost="$(jq -cn --argjson maximum "$max_cost" --argjson observed "$observed_cost" '$maximum - $observed')"
        fi

        local call_started=$SECONDS command_status
        if run_host "$host" "$binary" "$prompt_file" "$schema_file" "$requested_model" "$requested_effort" \
            "$remaining_cost" "$effective_timeout" "$raw_file" "$error_file" "$response_file"; then
            command_status=0
        else
            command_status=$?
        fi
        local measured_duration_ms="$(((SECONDS - call_started) * 1000))"

        local evidence_stdout="" evidence_stderr=""
        if [ "$capture_raw" = "local" ]; then
            evidence_stdout="$output_root/evidence/${slug}.stdout"
            evidence_stderr="$output_root/evidence/${slug}.stderr"
            redact_text_file "$raw_file" "$evidence_stdout" "$capture_redact"
            redact_text_file "$error_file" "$evidence_stderr" "$capture_redact"
        fi

        if [ "$command_status" -ne 0 ]; then
            calls_failed="$((calls_failed + 1))"
            local failure_reason=host_failed
            [ "$command_status" -ne 124 ] || failure_reason=timeout
            [ "$command_status" -ne 130 ] || failure_reason=interrupted
            jq -nS \
                --arg call_id "$call_id" \
                --arg host "$host" \
                --arg binary "$binary" \
                --arg host_version "$version" \
                --arg stop_reason "$failure_reason" \
                --arg stdout_path "$evidence_stdout" \
                --arg stderr_path "$evidence_stderr" \
                --arg prompt_capture_mode "$capture_prompts" \
                --arg prompt_sha256 "$prompt_capture_hash" \
                --arg prompt_path "$prompt_capture_path" \
                --argjson redacted "$capture_redact" '
              {
                schema:"hotl.evaluation-call-evidence/v1",
                call_id:$call_id,
                host:$host,
                host_binary:$binary,
                host_version:$host_version,
                status:"failed",
                stop_reason:$stop_reason,
                raw_stdout:(if $stdout_path == "" then null else $stdout_path end),
                raw_stderr:(if $stderr_path == "" then null else $stderr_path end),
                prompt_capture:{
                  mode:$prompt_capture_mode,
                  sha256:(if $prompt_sha256 == "" then null else $prompt_sha256 end),
                  local_path:(if $prompt_path == "" then null else $prompt_path end)
                },
                redacted:$redacted,
                configuration_changes_performed:false
              }
            ' > "$output_root/evidence/${slug}.json"
            write_manifest incomplete "$failure_reason"
            echo "ERROR: evaluation call stopped: $failure_reason ($call_id)." >&2
            return 1
        fi

        if ! {
            case "$host" in
                codex)
                    normalize_codex "$raw_file" "$response_file" "$requested_model" "$requested_effort" "$measured_duration_ms"
                    ;;
                claude-code)
                    normalize_claude "$raw_file" "$requested_model" "$requested_effort" "$measured_duration_ms"
                    ;;
                generic)
                    normalize_generic "$raw_file" "$requested_model" "$requested_effort" "$measured_duration_ms"
                    ;;
            esac
        } > "$normalized_file"; then
            calls_failed="$((calls_failed + 1))"
            write_manifest incomplete malformed_response
            echo "ERROR: malformed structured evaluation response: $call_id" >&2
            return 1
        fi

        jq -cS '.structured_output' "$normalized_file" > "$response_file"
        if ! validate_structured_response "$response_file" "$schema_file"; then
            calls_failed="$((calls_failed + 1))"
            write_manifest incomplete malformed_response
            echo "ERROR: structured evaluation response does not match its schema: $call_id" >&2
            return 1
        fi

        local evidence_response="$output_root/evidence/${slug}.response.json"
        redact_json_file "$response_file" "$evidence_response" "$capture_redact"
        local assertion_match=true contract_failures='[]'
        if ! jq -e --slurpfile expected "$assertion_file" '. == $expected[0]' "$response_file" >/dev/null; then
            assertion_match=false
            contract_failures='["assertion_mismatch"]'
        fi

        local evidence_metadata="$output_root/evidence/${slug}.json"
        jq -nS \
            --arg call_id "$call_id" \
            --arg host "$host" \
            --arg binary "$binary" \
            --arg host_version "$version" \
            --arg response_path "$evidence_response" \
            --arg stdout_path "$evidence_stdout" \
            --arg stderr_path "$evidence_stderr" \
            --arg prompt_capture_mode "$capture_prompts" \
            --arg prompt_sha256 "$prompt_capture_hash" \
            --arg prompt_path "$prompt_capture_path" \
            --argjson assertion_match "$assertion_match" \
            --argjson redacted "$capture_redact" \
            --argjson telemetry_provenance "$(jq -c '.telemetry_provenance' "$normalized_file")" '
          {
            schema:"hotl.evaluation-call-evidence/v1",
            call_id:$call_id,
            host:$host,
            host_binary:$binary,
            host_version:$host_version,
            status:"completed",
            assertion_match:$assertion_match,
            structured_response:$response_path,
            raw_stdout:(if $stdout_path == "" then null else $stdout_path end),
            raw_stderr:(if $stderr_path == "" then null else $stderr_path end),
            prompt_capture:{
              mode:$prompt_capture_mode,
              sha256:(if $prompt_sha256 == "" then null else $prompt_sha256 end),
              local_path:(if $prompt_path == "" then null else $prompt_path end)
            },
            telemetry_provenance:$telemetry_provenance,
            redacted:$redacted,
            configuration_changes_performed:false
          }
        ' > "$evidence_metadata"

        local result_relative="results/${slug}.json"
        local result_file="$output_root/$result_relative"
        local result_tmp="$temporary_root/${slug}.result.json"
        jq -nS \
            --arg recorded_at "$recorded_at" \
            --arg scenario_id "$scenario_id" \
            --arg scenario_revision "$scenario_revision" \
            --arg profile_id "$profile_id" \
            --arg host "$host" \
            --arg implementation "$(if [ "$host" = "generic" ]; then printf fallback; else printf native_adapter; fi)" \
            --arg adapter_version "$adapter_version" \
            --arg repo_revision "$repo_revision" \
            --arg host_version "$version" \
            --arg os "$os_name" \
            --arg arch "$architecture" \
            --arg toolchain "$toolchain_fingerprint" \
            --arg evidence "$evidence_metadata" \
            --argjson contract_failures "$contract_failures" \
            --argjson normalized "$(jq -c . "$normalized_file")" '
          {
            schema_version:1,
            recorded_at:$recorded_at,
            scenario_id:$scenario_id,
            scenario_revision:$scenario_revision,
            profile_id:$profile_id,
            host:$host,
            execution_implementation:$implementation,
            resolved_model:$normalized.resolved_model,
            effort_profile:$normalized.effort_profile,
            adapter_version:(if $adapter_version == "" then null else $adapter_version end),
            environment:{
              repo_revision:$repo_revision,
              host_version:$host_version,
              os:$os,
              arch:$arch,
              toolchain_fingerprint:$toolchain
            },
            terminal_outcome:"completed",
            contract_failures:$contract_failures,
            post_completion_defects:0,
            interventions:0,
            retries:(
              if (($normalized.structured_output.retry_count | type) == "number" and
                  ($normalized.structured_output.retry_count | floor) == $normalized.structured_output.retry_count and
                  $normalized.structured_output.retry_count >= 0)
              then $normalized.structured_output.retry_count
              else 0
              end
            ),
            telemetry:{
              duration_ms:$normalized.duration_ms,
              agent_count:1,
              tokens:$normalized.tokens,
              cost:$normalized.cost
            },
            telemetry_provenance:$normalized.telemetry_provenance,
            evidence_refs:[$evidence],
            notes:"Collected by the Phase 8 budgeted HOTL evaluation collector; no configuration change was performed."
          }
        ' > "$result_tmp"
        if ! bash "$CONFORMANCE" validate-evaluation "$result_tmp" >/dev/null; then
            calls_failed="$((calls_failed + 1))"
            write_manifest incomplete invalid_result
            echo "ERROR: normalized evaluation result failed validation: $call_id" >&2
            return 1
        fi
        mkdir -p "$output_root/results"
        mv "$result_tmp" "$result_file"

        calls_completed="$((calls_completed + 1))"
        result_paths="$(jq -cn --argjson paths "$result_paths" --arg path "$result_relative" '$paths + [$path]')"
        local cost_source call_cost
        cost_source="$(jq -r '.cost.source' "$normalized_file")"
        call_cost="$(jq -c '.cost.usd' "$normalized_file")"
        if [ "$max_cost" != "null" ]; then
            if [ "$cost_source" != "observed" ]; then
                write_manifest incomplete cost_telemetry_unknown
                echo "ERROR: evaluation cost telemetry is unknown while a cost budget is configured." >&2
                return 1
            fi
            observed_cost="$(jq -cn --argjson observed "$observed_cost" --argjson current "$call_cost" '$observed + $current')"
            if jq -en --argjson observed "$observed_cost" --argjson maximum "$max_cost" '$observed > $maximum' >/dev/null; then
                write_manifest incomplete cost_budget_exceeded
                echo "ERROR: evaluation cost budget exceeded." >&2
                return 1
            fi
        elif [ "$cost_source" = "observed" ]; then
            observed_cost="$(jq -cn --argjson observed "$observed_cost" --argjson current "$call_cost" '$observed + $current')"
        fi
        write_manifest running ""
    done < <(jq -c '.calls[]' <<< "$plan")

    write_manifest completed ""
    cleanup
    CLEANUP_ROOT=""
    trap - EXIT
    echo "Evaluation campaign completed: $manifest"
}

main() {
    require_tools
    [ "$#" -ge 2 ] || {
        usage >&2
        exit 1
    }
    [ "$1" = "run" ] || {
        usage >&2
        exit 1
    }
    local campaign="$2"
    shift 2

    local approved_live=false
    local call_timeout_seconds=300
    local run_label=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --approve-live)
                approved_live=true
                shift
                ;;
            --call-timeout-seconds)
                [ "$#" -ge 2 ] || {
                    echo "ERROR: --call-timeout-seconds requires a value." >&2
                    exit 1
                }
                call_timeout_seconds="$2"
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
                echo "ERROR: unknown collector option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
    positive_integer "$call_timeout_seconds" || {
        echo "ERROR: --call-timeout-seconds must be a positive integer." >&2
        exit 1
    }
    if [ -n "$run_label" ] && [[ ! "$run_label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        echo "ERROR: --run-label must use only letters, numbers, dot, underscore, or hyphen." >&2
        exit 1
    fi

    collect_campaign "$campaign" "$approved_live" "$call_timeout_seconds" "$run_label"
}

main "$@"
