#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: hotl-evaluation-proposal.sh [--format json|text] [--current-profile ID] <history-report.json>"
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

validate_report() {
    local report="$1"

    [ -f "$report" ] || {
        echo "ERROR: evaluation history report not found: $report" >&2
        return 1
    }
    jq -e '
      def nonempty_string: type == "string" and length > 0;
      def nonnegative_integer: type == "number" and floor == . and . >= 0;
      .schema == "hotl.evaluation-history-report/v1" and
      (.source_recorded_through | nonempty_string) and
      (.entry_count | nonnegative_integer) and
      (.campaigns | type == "array") and
      (.cohorts | type == "array") and
      (.profile_comparisons | type == "array") and
      (.comparisons | type == "array") and
      (.regression_count | nonnegative_integer) and
      (.drift_count | nonnegative_integer) and
      (.evidence_state | nonempty_string) and
      .human_review_required == true and
      .configuration_changes_performed == false and
      all(.profile_comparisons[];
          (.campaign_run_id | nonempty_string) and
          .summary.schema == "hotl.evaluation-summary/v1" and
          .summary.recommendation.human_review_required == true and
          .summary.recommendation.configuration_changes_performed == false)
    ' "$report" >/dev/null || {
        echo "ERROR: invalid HOTL evaluation history report: $report" >&2
        return 1
    }
}

build_proposal() {
    local report="$1"
    local current_profile="$2"
    local report_sha256="$3"

    jq -cS \
        --arg current_profile "$current_profile" \
        --arg report_sha256 "$report_sha256" '
      . as $history |
      ([.profile_comparisons[] |
        select(.summary.recommendation.state == "review_profile_candidate") |
        .summary.recommendation.candidate_profile_id |
        select(. != null)] | unique | sort) as $candidates |
      ([.profile_comparisons[].summary.recommendation.reason_codes[]?] | unique | sort) as $recommendation_reasons |
      ([.comparisons[] | select((.classifications // [.classification]) | index("quality_regression") != null)]
       | sort_by(.profile_id, .scenario_id, .previous_run_id, .current_run_id)) as $regressions |
      ([.comparisons[] |
        select(any((.classifications // [.classification])[];
                   . != "compatible" and . != "quality_regression"))]
       | sort_by(.profile_id, .scenario_id, .previous_run_id, .current_run_id)) as $drift |
      (($recommendation_reasons +
        [.comparisons[] | (.classifications // [.classification])[] | select(. != "compatible")] +
        (if .evidence_state == "insufficient_evidence" then ["insufficient_evidence"] else [] end))
       | unique | sort) as $gaps |
      (if ($candidates | length) == 0 then null else $candidates[0] end) as $candidate |
      ([.profile_comparisons[] as $comparison |
        $comparison.summary.cohorts[].profiles[] |
        select(.profile_id == $candidate) |
        {
          campaign_run_id:$comparison.campaign_run_id,
          eligible:.safety.eligible,
          disqualifiers:.safety.disqualifiers,
          terminal_outcomes:.safety.terminal_outcomes,
          contract_failures:.safety.contract_failures,
          metrics:.metrics,
          observed_dimensions:.observed_dimensions,
          dominated_by:.dominated_by
        }]
       | sort_by(.campaign_run_id)) as $candidate_safety |
      (($candidate_safety | length) > 0 and all($candidate_safety[]; .eligible == true)) as $candidate_reviewable |
      (if ($candidates | length) != 1 then []
       elif ($candidate_safety | length) == 0 then ["candidate_safety_evidence_missing"]
       elif ($candidate_safety | any(.eligible != true)) then ["candidate_not_safety_eligible"]
       else []
       end) as $safety_gaps |
      (($gaps + $safety_gaps) | unique | sort) as $all_gaps |
      (if ($candidates | length) == 0 then "collect_more_evidence"
       elif ($candidates | length) > 1 then "conflicting_candidates"
       elif ($candidate_reviewable | not) then "collect_more_evidence"
       elif (($regressions | length) > 0 or ($drift | length) > 0 or ($all_gaps | length) > 1)
         then "review_candidate_with_warnings"
       else "review_candidate"
       end) as $proposal_state |
      {
        schema:"hotl.evaluation-profile-proposal/v1",
        generated_at:.source_recorded_through,
        source:{
          schema:.schema,
          sha256:$report_sha256,
          recorded_through:.source_recorded_through,
          entry_count:.entry_count,
          evidence_state:.evidence_state
        },
        proposal:{
          state:$proposal_state,
          current_profile_id:(if $current_profile == "" then null else $current_profile end),
          candidate_profile_id:(if (($candidates | length) == 1 and $candidate_reviewable) then $candidate else null end),
          candidate_count:($candidates | length),
          candidate_profile_ids:$candidates,
          human_review_required:true,
          automatic_selection_performed:false,
          configuration_changes_performed:false
        },
        evidence:{
          campaign_run_ids:([.campaigns[].campaign_run_id] | unique | sort),
          campaign_statuses:([.campaigns[] | {campaign_run_id,status}] | sort_by(.campaign_run_id)),
          result_paths:([.campaigns[].result_paths[]] | unique | sort),
          candidate_safety:$candidate_safety,
          regressions:$regressions,
          drift:$drift,
          incompatible_or_missing:$all_gaps,
          profile_relationships:([.profile_comparisons[] |
            {
              campaign_run_id,
              comparison_status:(.comparison_status // null),
              comparison_identity:(.comparison_identity // null),
              observed_profiles:(.observed_profiles // []),
              recommendation:.summary.recommendation,
              requirements:.summary.requirements,
              cohorts:.summary.cohorts
            }] | sort_by(.campaign_run_id))
        },
        tradeoffs:{
          measured_candidate_metrics:[$candidate_safety[] |
            {campaign_run_id,metrics,observed_dimensions}],
          interpretation:"Metrics are local observations for compatible recorded workloads, not a claim of general model superiority.",
          configuration_action:"none"
        },
        confidence:{
          level:(if $proposal_state == "collect_more_evidence" then "insufficient"
                 elif $proposal_state == "review_candidate" then "limited"
                 else "low"
                 end),
          limitations:[
            "Local campaign evidence does not establish statistical significance or broad production superiority.",
            "Host versions, provider model resolution, prompts, tools, and telemetry semantics may drift after the recorded campaigns.",
            "A candidate remains advisory until a human reviews safety evidence, incompatible cohorts, costs, and operational fit.",
            "Missing or ambiguous telemetry remains unknown and is never converted to zero or estimated cost."
          ]
        },
        rollback:{
          required_before_manual_change:true,
          guidance:[
            "Record the current profile identity and the owner-approved rollback condition before any manual change.",
            "Change only one reviewed profile dimension at a time and retain the previous configuration for restoration.",
            "Revert manually if contract failures, post-completion defects, interventions, retries, or incompatible drift increase.",
            "Run the same approved campaign again after rollback and append the evidence instead of replacing history."
          ]
        },
        human_review_required:true,
        automatic_selection_performed:false,
        configuration_changes_performed:false
      }
    ' "$report"
}

render_text() {
    local proposal="$1"

    jq -r '
      "HOTL Profile-Change Proposal",
      "State: \(.proposal.state)",
      "Current profile: \(.proposal.current_profile_id // "not specified")",
      "Candidate profile: \(.proposal.candidate_profile_id // "none")",
      "Evidence report SHA-256: \(.source.sha256)",
      "Campaign runs: \(if (.evidence.campaign_run_ids | length) == 0 then "none" else (.evidence.campaign_run_ids | join(", ")) end)",
      "Regression evidence: \(.evidence.regressions | length)",
      "Drift evidence: \(.evidence.drift | length)",
      "Incompatible or missing evidence: \(if (.evidence.incompatible_or_missing | length) == 0 then "none" else (.evidence.incompatible_or_missing | join(", ")) end)",
      "Confidence: \(.confidence.level)",
      "Limitations:",
      (.confidence.limitations[] | "- " + .),
      "Rollback guidance:",
      (.rollback.guidance[] | "- " + .),
      "Human review required: yes",
      "Automatic profile selection performed: no",
      "Configuration changes performed: no"
    ' <<< "$proposal"
}

main() {
    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq is required for HOTL evaluation proposals." >&2
        exit 1
    }

    local format=json
    local current_profile=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --format)
                [ "$#" -ge 2 ] || {
                    echo "ERROR: --format requires json or text." >&2
                    exit 1
                }
                format="$2"
                shift 2
                ;;
            --current-profile)
                [ "$#" -ge 2 ] || {
                    echo "ERROR: --current-profile requires an ID." >&2
                    exit 1
                }
                current_profile="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --*)
                echo "ERROR: unknown proposal option: $1" >&2
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    [ "$#" -eq 1 ] || {
        usage >&2
        exit 1
    }
    case "$format" in
        json|text) ;;
        *)
            echo "ERROR: --format must be json or text." >&2
            exit 1
            ;;
    esac

    local report="$1"
    validate_report "$report"
    local proposal
    proposal="$(build_proposal "$report" "$current_profile" "$(sha256_file "$report")")"
    if [ "$format" = "text" ]; then
        render_text "$proposal"
    else
        printf '%s\n' "$proposal"
    fi
}

main "$@"
