#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOTL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="${HOTL_EVAL_REPO_ROOT:-$HOTL_ROOT}"
CONFORMANCE="${HOTL_CONFORMANCE:-${SCRIPT_DIR}/hotl-conformance.sh}"
SCENARIOS="${HOTL_CONFORMANCE_SCENARIOS:-${HOTL_ROOT}/test/fixtures/conformance/scenarios.json}"
CAMPAIGN_HELPER="${HOTL_EVAL_CAMPAIGN_HELPER:-${SCRIPT_DIR}/hotl-evaluation-campaign.sh}"
EVALUATION_REPORT="${HOTL_EVALUATION_REPORT:-${SCRIPT_DIR}/hotl-evaluation-report.sh}"
HISTORY_CLEANUP_ROOT=""

usage() {
    printf '%s\n' \
        "usage: hotl-evaluation-history.sh validate-entry <entry.json>" \
        "       hotl-evaluation-history.sh append <registry-dir> <entry.json>" \
        "       hotl-evaluation-history.sh append-run <registry-dir> <campaign.json> <campaign-run.json>" \
        "       hotl-evaluation-history.sh report <registry-dir>"
}

cleanup_history() {
    [ -z "$HISTORY_CLEANUP_ROOT" ] || rm -rf "$HISTORY_CLEANUP_ROOT"
}

require_jq() {
    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq is required for HOTL evaluation history." >&2
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

sha256_text() {
    local value="$1"

    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$value" | sha256sum | awk '{print $1}'
    else
        echo "ERROR: shasum or sha256sum is required." >&2
        return 1
    fi
}

resolve_repo_result() {
    local relative_path="$1"
    local repo_root candidate physical_parent resolved

    repo_root="$(cd "$REPO_ROOT" && pwd -P)"
    candidate="${repo_root}/${relative_path}"
    [ -f "$candidate" ] || {
        echo "ERROR: evaluation history result not found: $candidate" >&2
        return 1
    }
    if [ -L "$candidate" ]; then
        echo "ERROR: evaluation result is outside the declared repository root through a symlink: $candidate" >&2
        return 1
    fi
    physical_parent="$(cd "$(dirname "$candidate")" && pwd -P)" || return 1
    resolved="${physical_parent}/$(basename "$candidate")"
    case "$resolved" in
        "$repo_root"/*)
            printf '%s\n' "$resolved"
            ;;
        *)
            echo "ERROR: evaluation result is outside the declared repository root: $resolved" >&2
            return 1
            ;;
    esac
}

validate_entry() {
    local entry="$1"

    [ -f "$entry" ] || {
        echo "ERROR: evaluation history entry not found: $entry" >&2
        return 1
    }

    jq -e '
      def nonempty_string: type == "string" and length > 0;
      def nullable_string: . == null or nonempty_string;
      def valid_timestamp: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
      def valid_date: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
      def valid_id: nonempty_string and test("^[a-z0-9][a-z0-9._/@-]*$");
      def valid_run_id: nonempty_string and test("^[A-Za-z0-9][A-Za-z0-9._/@-]*$");
      def valid_hash: nonempty_string and test("^[a-f0-9]{64}$");
      def safe_path:
        nonempty_string and
        test("^[A-Za-z0-9._/@-]+$") and
        (startswith("/") | not) and
        (split("/") | all(.[]; . != ".." and length > 0));
      def allowed($values): . as $value | $values | index($value) != null;
      .schema == "hotl.evaluation-history-entry/v1" and
      (.campaign_id | valid_id) and
      (.run_id | valid_run_id) and
      (.recorded_at | valid_timestamp) and
      (.status | allowed(["valid", "incomplete", "failed"])) and
      (.result_path | safe_path) and
      (.result_sha256 | valid_hash) and
      (.workload_identity.repo_revision | nonempty_string) and
      (.workload_identity.protocol_revision | valid_date) and
      (.workload_identity.scenario_id | valid_id) and
      (.workload_identity.scenario_revision | valid_date) and
      (.workload_identity.prompt_sha256 | valid_hash) and
      (.workload_identity.response_schema_sha256 | valid_hash) and
      (.workload_identity.assertion_sha256 | valid_hash) and
      (.workload_identity.os | nonempty_string) and
      (.workload_identity.arch | nonempty_string) and
      (.workload_identity.toolchain_fingerprint | nonempty_string) and
      (.profile_observation.profile_id | valid_id) and
      (.profile_observation.host | allowed(["codex", "claude-code", "generic"])) and
      (.profile_observation.host_version | nullable_string) and
      (.profile_observation.resolved_model | nullable_string) and
      (.profile_observation.effort_profile | nullable_string) and
      (.profile_observation.adapter_version | nullable_string) and
      .telemetry_provenance.normalization_version == "hotl.tokens/v1" and
      (.telemetry_provenance.tokens.source | nonempty_string) and
      (.telemetry_provenance.tokens.input_semantics |
        allowed(["uncached_input", "provider_total_no_cache", "disjoint_counters", "unavailable"])) and
      (.telemetry_provenance.tokens.cached_semantics |
        allowed(["separate_subset", "disjoint_counter", "none", "unavailable"])) and
      (.telemetry_provenance.tokens.normalized | type == "boolean") and
      (.telemetry_provenance.cost.source | allowed(["observed", "unavailable"])) and
      ((has("campaign_status") | not) or
       (.campaign_status | allowed(["running", "completed", "incomplete", "failed"]))) and
      ((has("campaign_run_id") | not) or (.campaign_run_id | nonempty_string))
    ' "$entry" >/dev/null || {
        echo "ERROR: invalid HOTL evaluation history entry: $entry" >&2
        return 1
    }

    local result_relative result_path expected_hash actual_hash
    result_relative="$(jq -r '.result_path' "$entry")"
    result_path="$(resolve_repo_result "$result_relative")"
    expected_hash="$(jq -r '.result_sha256' "$entry")"
    actual_hash="$(sha256_file "$result_path")"
    [ "$actual_hash" = "$expected_hash" ] || {
        echo "ERROR: result hash mismatch: $result_path" >&2
        return 1
    }

    bash "$CONFORMANCE" validate-evaluation "$result_path" "$SCENARIOS" >/dev/null

    jq -e --slurpfile result "$result_path" '
      $result[0] as $result |
      .workload_identity.scenario_id == $result.scenario_id and
      .workload_identity.scenario_revision == $result.scenario_revision and
      .profile_observation.profile_id == $result.profile_id and
      .profile_observation.host == $result.host and
      .workload_identity.repo_revision == $result.environment.repo_revision and
      .workload_identity.os == $result.environment.os and
      .workload_identity.arch == $result.environment.arch and
      .workload_identity.toolchain_fingerprint == $result.environment.toolchain_fingerprint and
      .profile_observation.host_version == $result.environment.host_version and
      .profile_observation.resolved_model == $result.resolved_model and
      .profile_observation.effort_profile == $result.effort_profile and
      .profile_observation.adapter_version == $result.adapter_version and
      (if $result.telemetry.tokens.source == "observed" then
         .telemetry_provenance.tokens.normalized == true and
         .telemetry_provenance.tokens.input_semantics != "unavailable" and
         .telemetry_provenance.tokens.cached_semantics != "unavailable"
       else
         .telemetry_provenance.tokens.input_semantics == "unavailable" and
         .telemetry_provenance.tokens.cached_semantics == "unavailable"
       end) and
      .telemetry_provenance.cost.source == $result.telemetry.cost.source
    ' "$entry" >/dev/null || {
        echo "ERROR: invalid HOTL evaluation history entry identity or telemetry provenance: $entry" >&2
        return 1
    }

    echo "Evaluation history entry valid: $entry"
}

entry_key() {
    local entry="$1"
    sha256_text "$(jq -r '.run_id' "$entry")"
}

entry_exists() {
    local registry="$1"
    local run_id="$2"
    local key
    key="$(sha256_text "$run_id")"
    [ -f "$registry/entries/$key.json" ]
}

append_entry() {
    local registry="$1"
    local entry="$2"

    validate_entry "$entry" >/dev/null
    mkdir -p "$registry/entries" "$registry/.locks"

    local run_id key destination lock_dir staged
    run_id="$(jq -r '.run_id' "$entry")"
    key="$(entry_key "$entry")"
    destination="$registry/entries/$key.json"
    lock_dir="$registry/.locks/$key.lock"
    staged="$registry/.locks/$key.$$.json"

    if [ -e "$destination" ]; then
        echo "ERROR: duplicate history run_id: $run_id" >&2
        return 1
    fi
    if ! mkdir "$lock_dir" 2>/dev/null; then
        echo "ERROR: duplicate history run_id or concurrent append: $run_id" >&2
        return 1
    fi
    if ! cp "$entry" "$staged"; then
        rmdir "$lock_dir" 2>/dev/null || true
        return 1
    fi
    if [ -e "$destination" ]; then
        rm -f "$staged"
        rmdir "$lock_dir" 2>/dev/null || true
        echo "ERROR: duplicate history run_id: $run_id" >&2
        return 1
    fi
    mv "$staged" "$destination"
    rmdir "$lock_dir" 2>/dev/null || true
    echo "Evaluation history entry appended: $destination"
}

relative_to_repo() {
    local path="$1"
    local repo_root absolute
    repo_root="$(cd "$REPO_ROOT" && pwd -P)"
    if [ -L "$path" ]; then
        echo "ERROR: evaluation result is outside the declared repository root through a symlink: $path" >&2
        return 1
    fi
    absolute="$(cd "$(dirname "$path")" && pwd -P)/$(basename "$path")"

    case "$absolute" in
        "$repo_root"/*)
            printf '%s\n' "${absolute#"$repo_root"/}"
            ;;
        *)
            echo "ERROR: evaluation result is outside the declared repository root: $absolute" >&2
            return 1
            ;;
    esac
}

append_campaign_run() {
    local registry="$1"
    local campaign="$2"
    local manifest="$3"

    bash "$CAMPAIGN_HELPER" validate "$campaign" >/dev/null
    [ -f "$manifest" ] || {
        echo "ERROR: evaluation campaign run not found: $manifest" >&2
        return 1
    }
    jq -e '
      .schema == "hotl.evaluation-campaign-run/v1" and
      (.campaign_id | type == "string" and length > 0) and
      (.run_id | type == "string" and length > 0) and
      (.recorded_at | type == "string" and length > 0) and
      (.status == "completed" or .status == "incomplete" or .status == "failed") and
      (.campaign_sha256 | type == "string" and test("^[a-f0-9]{64}$")) and
      (.protocol_revision | type == "string" and length > 0) and
      (.planned_calls | type == "number" and floor == . and . >= 0) and
      (.calls_completed | type == "number" and floor == . and . >= 0) and
      (.results | type == "array") and
      (.results | length) == .calls_completed and
      .live_approval_observed == true and
      .schedule_changes_performed == false and
      .configuration_changes_performed == false
    ' "$manifest" >/dev/null || {
        echo "ERROR: invalid HOTL evaluation campaign run: $manifest" >&2
        return 1
    }

    local campaign_id protocol_revision campaign_hash manifest_campaign_id manifest_protocol manifest_campaign_hash
    local campaign_status campaign_run_id campaign_run_hash
    campaign_id="$(jq -r '.campaign_id' "$campaign")"
    protocol_revision="$(jq -r '.protocol_revision' "$campaign")"
    campaign_hash="$(sha256_file "$campaign")"
    manifest_campaign_id="$(jq -r '.campaign_id' "$manifest")"
    manifest_protocol="$(jq -r '.protocol_revision' "$manifest")"
    manifest_campaign_hash="$(jq -r '.campaign_sha256' "$manifest")"
    [ "$campaign_id" = "$manifest_campaign_id" ] || {
        echo "ERROR: campaign identity does not match campaign-run evidence." >&2
        return 1
    }
    [ "$protocol_revision" = "$manifest_protocol" ] && [ "$campaign_hash" = "$manifest_campaign_hash" ] || {
        echo "ERROR: campaign content or protocol changed after collection." >&2
        return 1
    }
    campaign_status="$(jq -r '.status' "$manifest")"
    campaign_run_id="$(jq -r '.run_id' "$manifest")"
    campaign_run_hash="$(sha256_file "$manifest")"

    local manifest_dir appended=0 skipped=0 result_relative result_absolute result_repo_relative
    manifest_dir="$(cd "$(dirname "$manifest")" && pwd -P)"
    while IFS= read -r result_relative; do
        [ -n "$result_relative" ] || continue
        case "$result_relative" in
            /*|../*|*/../*|*/..)
                echo "ERROR: unsafe campaign result path: $result_relative" >&2
                return 1
                ;;
        esac
        result_absolute="${manifest_dir}/${result_relative}"
        [ -f "$result_absolute" ] || {
            echo "ERROR: campaign result not found: $result_absolute" >&2
            return 1
        }
        result_repo_relative="$(relative_to_repo "$result_absolute")"
        bash "$CONFORMANCE" validate-evaluation "$result_absolute" "$SCENARIOS" >/dev/null

        local profile_id scenario_id scenario_revision profile scenario result_hash result_name history_run_id
        profile_id="$(jq -r '.profile_id' "$result_absolute")"
        scenario_id="$(jq -r '.scenario_id' "$result_absolute")"
        scenario_revision="$(jq -r '.scenario_revision' "$result_absolute")"
        profile="$(jq -c --arg profile_id "$profile_id" '.profiles[] | select(.profile_id == $profile_id)' "$campaign")"
        scenario="$(jq -c --arg scenario_id "$scenario_id" --arg scenario_revision "$scenario_revision" \
            '.scenarios[] | select(.scenario_id == $scenario_id and .scenario_revision == $scenario_revision)' "$campaign")"
        [ -n "$profile" ] && [ -n "$scenario" ] || {
            echo "ERROR: result identity is absent from its campaign: $result_relative" >&2
            return 1
        }
        result_hash="$(sha256_file "$result_absolute")"
        result_name="$(basename "$result_relative" .json)"
        history_run_id="${campaign_run_id}/${result_name}"
        if entry_exists "$registry" "$history_run_id"; then
            skipped="$((skipped + 1))"
            continue
        fi

        local staged_entry
        staged_entry="$(mktemp "${TMPDIR:-/tmp}/hotl-history-entry.XXXXXX")"
        jq -nS \
            --arg campaign_id "$campaign_id" \
            --arg campaign_run_id "$campaign_run_id" \
            --arg campaign_status "$campaign_status" \
            --arg campaign_run_sha256 "$campaign_run_hash" \
            --arg run_id "$history_run_id" \
            --arg result_path "$result_repo_relative" \
            --arg result_sha256 "$result_hash" \
            --arg protocol_revision "$protocol_revision" \
            --argjson result "$(jq -c . "$result_absolute")" \
            --argjson profile "$profile" \
            --argjson scenario "$scenario" '
          {
            schema:"hotl.evaluation-history-entry/v1",
            campaign_id:$campaign_id,
            campaign_run_id:$campaign_run_id,
            campaign_status:$campaign_status,
            campaign_run_sha256:$campaign_run_sha256,
            run_id:$run_id,
            recorded_at:$result.recorded_at,
            status:"valid",
            result_path:$result_path,
            result_sha256:$result_sha256,
            workload_identity:{
              repo_revision:$result.environment.repo_revision,
              protocol_revision:$protocol_revision,
              scenario_id:$result.scenario_id,
              scenario_revision:$result.scenario_revision,
              prompt_sha256:$scenario.prompt_sha256,
              response_schema_sha256:$scenario.response_schema_sha256,
              assertion_sha256:$scenario.assertion_sha256,
              os:$result.environment.os,
              arch:$result.environment.arch,
              toolchain_fingerprint:$result.environment.toolchain_fingerprint
            },
            profile_observation:{
              profile_id:$result.profile_id,
              host:$result.host,
              host_version:$result.environment.host_version,
              resolved_model:$result.resolved_model,
              effort_profile:$result.effort_profile,
              adapter_version:$result.adapter_version
            },
            telemetry_provenance:$result.telemetry_provenance
          }
        ' > "$staged_entry"
        append_entry "$registry" "$staged_entry" >/dev/null
        rm -f "$staged_entry"
        appended="$((appended + 1))"
    done < <(jq -r '.results[]' "$manifest")

    printf 'Evaluation campaign history recovered: appended=%s skipped=%s campaign_status=%s\n' \
        "$appended" "$skipped" "$campaign_status"
}

report_history() {
    local registry="$1"
    local entries_dir="$registry/entries"
    [ -d "$entries_dir" ] || {
        echo "ERROR: evaluation history registry has no entries: $registry" >&2
        return 1
    }

    local temporary_root
    temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/hotl-history-report.XXXXXX")"
    HISTORY_CLEANUP_ROOT="$temporary_root"
    trap cleanup_history EXIT

    local count=0 entry result_relative result_absolute
    while IFS= read -r entry; do
        validate_entry "$entry" >/dev/null
        result_relative="$(jq -r '.result_path' "$entry")"
        result_absolute="$(resolve_repo_result "$result_relative")"
        jq -nS \
            --argjson entry "$(jq -c . "$entry")" \
            --argjson result "$(jq -c . "$result_absolute")" \
            '{entry:$entry,result:$result}' > "$temporary_root/record-$(printf '%06d' "$count").json"
        count="$((count + 1))"
    done < <(find "$entries_dir" -type f -name '*.json' -print | sort)
    [ "$count" -gt 0 ] || {
        echo "ERROR: evaluation history registry has no entries: $registry" >&2
        return 1
    }

    local profile_comparisons="$temporary_root/profile-comparisons.json"
    jq -n '[]' > "$profile_comparisons"
    local campaign_relationship_id summary_file updated_comparisons comparison_index=0
    while IFS= read -r campaign_relationship_id; do
        local campaign_records
        campaign_records="$temporary_root/campaign-records-$(printf '%06d' "$comparison_index").json"
        jq -sS --arg id "$campaign_relationship_id" \
            '[.[] | select((.entry.campaign_run_id // .entry.campaign_id) == $id)]' \
            "$temporary_root"/record-*.json > "$campaign_records"

        local workload_consistent profile_observation_consistent workload_set workload_fingerprint projected_host_version observed_profiles
        workload_consistent="$(jq -r '
          sort_by(.entry.workload_identity.scenario_id, .entry.workload_identity.scenario_revision) |
          group_by([.entry.workload_identity.scenario_id, .entry.workload_identity.scenario_revision]) |
          all(.[];
            (map(.entry.workload_identity | {
              protocol_revision,
              scenario_id,
              scenario_revision,
              prompt_sha256,
              response_schema_sha256,
              assertion_sha256
            }) | unique | length) == 1)
        ' "$campaign_records")"
        profile_observation_consistent="$(jq -r '
          sort_by(.entry.profile_observation.profile_id) |
          group_by(.entry.profile_observation.profile_id) |
          all(.[]; (map(.entry.profile_observation) | unique | length) == 1)
        ' "$campaign_records")"
        workload_set="$(jq -cS '[.[].entry.workload_identity | {
          protocol_revision,
          scenario_id,
          scenario_revision,
          prompt_sha256,
          response_schema_sha256,
          assertion_sha256
        }] | unique | sort_by(.scenario_id, .scenario_revision, .protocol_revision, .prompt_sha256)' "$campaign_records")"
        workload_fingerprint="$(sha256_text "$workload_set")"
        projected_host_version="phase8-workload-${workload_fingerprint}"
        observed_profiles="$(jq -cS '
          sort_by(.entry.profile_observation.profile_id) |
          group_by(.entry.profile_observation.profile_id) |
          map({
            profile_id:.[0].entry.profile_observation.profile_id,
            hosts:([.[].entry.profile_observation.host | select(. != null)] | unique | sort),
            host_versions:([.[].entry.profile_observation.host_version | select(. != null)] | unique | sort),
            resolved_models:([.[].entry.profile_observation.resolved_model | select(. != null)] | unique | sort),
            effort_profiles:([.[].entry.profile_observation.effort_profile | select(. != null)] | unique | sort),
            adapter_versions:([.[].entry.profile_observation.adapter_version | select(. != null)] | unique | sort)
          })
        ' "$campaign_records")"

        local -a campaign_results=()
        local path_mapping='{}' projection_index=0 record_json projected_path original_path
        while IFS= read -r record_json; do
            result_relative="$(jq -r '.entry.result_path' <<< "$record_json")"
            original_path="$(resolve_repo_result "$result_relative")"
            projected_path="$temporary_root/projected-$(printf '%06d' "$comparison_index")-$(printf '%06d' "$projection_index").json"
            jq --arg projected_host_version "$projected_host_version" \
                '.environment.host_version = $projected_host_version' \
                "$original_path" > "$projected_path"
            campaign_results+=("$projected_path")
            path_mapping="$(jq -c --arg projected "$projected_path" --arg original "$original_path" \
                '. + {($projected):$original}' <<< "$path_mapping")"
            projection_index="$((projection_index + 1))"
        done < <(jq -c '.[]' "$campaign_records")
        [ "${#campaign_results[@]}" -gt 0 ] || continue

        summary_file="$temporary_root/profile-summary-$(printf '%06d' "$comparison_index").json"
        bash "$EVALUATION_REPORT" --format json "${campaign_results[@]}" |
            jq --argjson path_mapping "$path_mapping" \
                '.inputs.records |= map(.path = ($path_mapping[.path] // .path))' > "$summary_file"

        local comparison_status="insufficient_evidence" incompatibility_reason=""
        if [ "$workload_consistent" != "true" ]; then
            comparison_status="incompatible_workload"
            incompatibility_reason="phase8_workload_identity_mismatch"
        elif [ "$profile_observation_consistent" != "true" ]; then
            comparison_status="incompatible_profile_observation"
            incompatibility_reason="phase8_profile_observation_inconsistent"
        fi
        if [ -n "$incompatibility_reason" ]; then
            updated_comparisons="$temporary_root/profile-summary-incompatible-$(printf '%06d' "$comparison_index").json"
            jq --arg incompatibility_reason "$incompatibility_reason" '
              .cohorts |= map(
                .eligibility.eligible = false |
                .eligibility.reasons = ((.eligibility.reasons + [$incompatibility_reason]) | unique | sort) |
                .pareto_frontier = []) |
              .recommendation = {
                state:"collect_more_evidence",
                candidate_profile_id:null,
                reason_codes:[$incompatibility_reason],
                human_review_required:true,
                configuration_changes_performed:false
              }
            ' "$summary_file" > "$updated_comparisons"
            mv "$updated_comparisons" "$summary_file"
        elif jq -e 'any(.cohorts[]; .eligibility.eligible == true)' "$summary_file" >/dev/null; then
            comparison_status="eligible"
        fi

        updated_comparisons="$temporary_root/profile-comparisons.updated.json"
        jq \
            --arg campaign_run_id "$campaign_relationship_id" \
            --arg comparison_status "$comparison_status" \
            --arg workload_set_sha256 "$workload_fingerprint" \
            --argjson workload_set "$workload_set" \
            --argjson observed_profiles "$observed_profiles" \
            --argjson summary "$(jq -c . "$summary_file")" \
            '. + [{
              campaign_run_id:$campaign_run_id,
              comparison_status:$comparison_status,
              comparison_identity:{
                semantics:"phase8-workload-projection/v1",
                workload_set_sha256:$workload_set_sha256,
                workload_set:$workload_set
              },
              observed_profiles:$observed_profiles,
              summary:$summary
            }]' \
            "$profile_comparisons" > "$updated_comparisons"
        mv "$updated_comparisons" "$profile_comparisons"
        comparison_index="$((comparison_index + 1))"
    done < <(jq -sr 'map(.entry.campaign_run_id // .entry.campaign_id) | unique[]' "$temporary_root"/record-*.json)

    jq -sS --slurpfile profile_comparisons "$profile_comparisons" '
      def quality_regression($previous; $current):
        (($previous.result.terminal_outcome == "completed" and
          $current.result.terminal_outcome != "completed") or
         (($current.result.contract_failures | length) > ($previous.result.contract_failures | length)) or
         ($current.result.post_completion_defects > $previous.result.post_completion_defects) or
         ($current.result.interventions > $previous.result.interventions) or
         ($current.result.retries > $previous.result.retries));
      def classifications($previous; $current):
        ([
          if (($current.entry.campaign_status // "completed") != "completed" or
              $current.entry.status != "valid") then "incomplete_campaign" else empty end,
          if ([$previous.entry.workload_identity.scenario_revision,
               $previous.entry.workload_identity.prompt_sha256,
               $previous.entry.workload_identity.response_schema_sha256,
               $previous.entry.workload_identity.assertion_sha256] !=
              [$current.entry.workload_identity.scenario_revision,
               $current.entry.workload_identity.prompt_sha256,
               $current.entry.workload_identity.response_schema_sha256,
               $current.entry.workload_identity.assertion_sha256]) then "prompt_or_schema_drift" else empty end,
          if ([$previous.entry.workload_identity.repo_revision,
               $previous.entry.workload_identity.protocol_revision,
               $previous.entry.workload_identity.scenario_id] !=
              [$current.entry.workload_identity.repo_revision,
               $current.entry.workload_identity.protocol_revision,
               $current.entry.workload_identity.scenario_id]) then "workload_drift" else empty end,
          if ([$previous.entry.workload_identity.os,
               $previous.entry.workload_identity.arch,
               $previous.entry.workload_identity.toolchain_fingerprint] !=
              [$current.entry.workload_identity.os,
               $current.entry.workload_identity.arch,
               $current.entry.workload_identity.toolchain_fingerprint]) then "toolchain_drift" else empty end,
          if ([$previous.entry.profile_observation.host,
               $previous.entry.profile_observation.host_version] !=
              [$current.entry.profile_observation.host,
               $current.entry.profile_observation.host_version]) then "host_drift" else empty end,
          if ([$previous.entry.profile_observation.resolved_model,
               $previous.entry.profile_observation.effort_profile,
               $previous.entry.profile_observation.adapter_version] !=
              [$current.entry.profile_observation.resolved_model,
               $current.entry.profile_observation.effort_profile,
               $current.entry.profile_observation.adapter_version]) then "adapter_or_model_drift" else empty end,
          if ($previous.entry.telemetry_provenance != $current.entry.telemetry_provenance) then "telemetry_drift" else empty end,
          if quality_regression($previous; $current) then "quality_regression" else empty end
        ] | if length == 0 then ["compatible"] else . end);
      (sort_by(.entry.recorded_at, .entry.run_id)) as $records |
      ([$records
        | group_by([.entry.profile_observation.profile_id,
                    .entry.workload_identity.scenario_id])[]
        | sort_by(.entry.recorded_at, .entry.run_id)
        | . as $series
        | range(1; $series | length) as $index
        | $series[$index - 1] as $previous
        | $series[$index] as $current
        | classifications($previous; $current) as $classifications
        | {
            profile_id:$current.entry.profile_observation.profile_id,
            scenario_id:$current.entry.workload_identity.scenario_id,
            previous_run_id:$previous.entry.run_id,
            current_run_id:$current.entry.run_id,
            classification:$classifications[0],
            classifications:$classifications
          }]
       | sort_by(.profile_id, .scenario_id, .previous_run_id, .current_run_id)) as $comparisons |
      ($records
       | sort_by(.entry.workload_identity | tojson)
       | group_by(.entry.workload_identity | tojson)
       | map({
           workload_identity:.[0].entry.workload_identity,
           entry_count:length,
           profile_ids:([.[].entry.profile_observation.profile_id] | unique | sort),
           campaign_ids:([.[].entry.campaign_id] | unique | sort),
           run_ids:([.[].entry.run_id] | sort)
         })) as $cohorts |
      ($records
       | sort_by(.entry.campaign_run_id // .entry.campaign_id)
       | group_by(.entry.campaign_run_id // .entry.campaign_id)
       | map({
           campaign_run_id:(.[0].entry.campaign_run_id // .[0].entry.campaign_id),
           campaign_id:.[0].entry.campaign_id,
           status:(if any(.[]; ((.entry.campaign_status // "completed") != "completed"))
                   then ([.[].entry.campaign_status // "completed"]
                         | if index("failed") then "failed"
                           elif index("incomplete") then "incomplete"
                           elif index("running") then "running"
                           else "completed"
                           end)
                   else "completed"
                   end),
           entry_count:length,
           result_paths:([.[].entry.result_path] | sort)
         })) as $campaigns |
      {
        schema:"hotl.evaluation-history-report/v1",
        source:"append-only-local-history",
        source_recorded_through:($records | map(.entry.recorded_at) | max),
        entry_count:($records | length),
        campaigns:$campaigns,
        cohorts:$cohorts,
        profile_comparisons:$profile_comparisons[0],
        comparisons:$comparisons,
        regression_count:([$comparisons[] | select(.classifications | index("quality_regression") != null)] | length),
        drift_count:([$comparisons[] |
          select(any(.classifications[]; . != "compatible" and . != "quality_regression"))] | length),
        evidence_state:(if ($comparisons | length) == 0 then "insufficient_evidence" else "history_available" end),
        supported_classifications:[
          "compatible",
          "workload_drift",
          "prompt_or_schema_drift",
          "host_drift",
          "adapter_or_model_drift",
          "toolchain_drift",
          "telemetry_drift",
          "incomplete_campaign",
          "quality_regression",
          "insufficient_evidence"
        ],
        human_review_required:true,
        configuration_changes_performed:false
      }
    ' "$temporary_root"/record-*.json

    cleanup_history
    HISTORY_CLEANUP_ROOT=""
    trap - EXIT
}

main() {
    require_jq
    case "${1:-}" in
        validate-entry)
            [ "$#" -eq 2 ] || {
                usage >&2
                exit 1
            }
            validate_entry "$2"
            ;;
        append)
            [ "$#" -eq 3 ] || {
                usage >&2
                exit 1
            }
            append_entry "$2" "$3"
            ;;
        append-run)
            [ "$#" -eq 4 ] || {
                usage >&2
                exit 1
            }
            append_campaign_run "$2" "$3" "$4"
            ;;
        report)
            [ "$#" -eq 2 ] || {
                usage >&2
                exit 1
            }
            report_history "$2"
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
