#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFORMANCE="${HOTL_CONFORMANCE:-${SCRIPT_DIR}/hotl-conformance.sh}"
SCENARIOS="${HOTL_CONFORMANCE_SCENARIOS:-${REPO_ROOT}/test/fixtures/conformance/scenarios.json}"

usage() {
    printf '%s\n' \
        "usage: hotl-evaluation-report.sh [--format json|text] <evaluation.json> [evaluation.json ...]" \
        "       hotl-evaluation-report.sh --help"
}

require_jq() {
    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq is required for HOTL evaluation reports." >&2
        exit 1
    }
}

normalize_record() {
    local file="$1"

    jq -c --arg path "$file" '
      def slug_part:
        tostring
        | ascii_downcase
        | gsub("[^a-z0-9._/-]"; "-")
        | gsub("-+"; "-")
        | if length == 0 then "unknown" else . end;
      def environment_known:
        (.environment | type) == "object" and
        ([.environment.repo_revision,
          .environment.host_version,
          .environment.os,
          .environment.arch,
          .environment.toolchain_fingerprint]
         | all(.[]; type == "string" and length > 0));
      . as $evaluation |
      (if (.profile_id // null) != null then
         {id:.profile_id, source:"explicit"}
       else
         {id:(["legacy", .host, .execution_implementation,
               (.resolved_model // "unknown"),
               (.effort_profile // "unknown"),
               (.adapter_version // "unknown")]
              | map(slug_part) | join("/")),
          source:"derived"}
       end) as $profile |
      (environment_known) as $environment_known |
      {
        path:$path,
        scenario_id:.scenario_id,
        scenario_revision:.scenario_revision,
        scenario_key:(.scenario_id + "@" + .scenario_revision),
        profile_id:$profile.id,
        profile_identity_source:$profile.source,
        environment_status:(if $environment_known then "known" else "unknown" end),
        environment:(.environment // null),
        environment_key:(if $environment_known
          then ([.environment.repo_revision,
                 .environment.host_version,
                 .environment.os,
                 .environment.arch,
                 .environment.toolchain_fingerprint] | @json)
          else "unknown"
          end),
        recorded_at:.recorded_at,
        evaluation:$evaluation
      }
    ' "$file"
}

build_summary() {
    local records="$1"

    jq -cn --argjson records "$records" '
      def metric_summary($values; $sample_count):
        ($values | length) as $observed |
        {
          availability:(if $observed == 0 then "unavailable"
                        elif $observed == $sample_count then "complete"
                        else "partial"
                        end),
          observed_samples:$observed,
          mean:(if $observed == $sample_count and $sample_count > 0
                then ($values | add) / $sample_count
                else null
                end)
        };
      def count_summary($values):
        ($values | length) as $sample_count |
        ($values | add // 0) as $total |
        {
          total:$total,
          mean:(if $sample_count > 0 then $total / $sample_count else null end)
        };
      def scenario_intersection($sets):
        if ($sets | length) == 0 then []
        else
          reduce ($sets[1:][]) as $set
            ($sets[0];
             . as $current |
             [$current[] as $candidate |
              select($set | index($candidate)) |
              $candidate])
          | unique
          | sort
        end;
      def metric_value($profile; $dimension):
        if $dimension == "interventions" then $profile.metrics.interventions.mean
        elif $dimension == "retries" then $profile.metrics.retries.mean
        elif $dimension == "duration_ms" then $profile.metrics.duration_ms.mean
        elif $dimension == "agent_count" then $profile.metrics.agent_count.mean
        elif $dimension == "tokens" then $profile.metrics.tokens.mean
        elif $dimension == "cost_usd" then $profile.metrics.cost_usd.mean
        else null
        end;
      def dominates($candidate; $other):
        ($candidate.safety.eligible and $other.safety.eligible) as $safe |
        (all($other.observed_dimensions[];
             . as $dimension |
             ($candidate.observed_dimensions | index($dimension)) != null)) as $dimensions_covered |
        ([$other.observed_dimensions[] as $dimension |
          {candidate:metric_value($candidate; $dimension),
           other:metric_value($other; $dimension)}]) as $pairs |
        $safe and
        $dimensions_covered and
        all($pairs[]; .candidate <= .other) and
        any($pairs[]; .candidate < .other);
      def build_profile($samples; $shared_scenarios):
        ($samples | length) as $sample_count |
        ($samples
         | map(. as $sample |
               select($shared_scenarios | index($sample.scenario_key)))) as $comparison_samples |
        ($comparison_samples | length) as $comparison_sample_count |
        ($comparison_samples | map(.evaluation.telemetry.duration_ms | select(. != null))) as $durations |
        ($comparison_samples | map(.evaluation.telemetry.agent_count | select(. != null))) as $agents |
        ($comparison_samples
         | map(select(.evaluation.telemetry.tokens.source == "observed") |
               (.evaluation.telemetry.tokens.input +
                .evaluation.telemetry.tokens.output +
                .evaluation.telemetry.tokens.cached))) as $tokens |
        ($comparison_samples
         | map(select(.evaluation.telemetry.cost.source == "observed") |
               .evaluation.telemetry.cost.usd)) as $costs |
        (metric_summary($durations; $comparison_sample_count)) as $duration_summary |
        (metric_summary($agents; $comparison_sample_count)) as $agent_summary |
        (metric_summary($tokens; $comparison_sample_count)) as $token_summary |
        (metric_summary($costs; $comparison_sample_count)) as $cost_summary |
        (count_summary($comparison_samples | map(.evaluation.interventions))) as $intervention_summary |
        (count_summary($comparison_samples | map(.evaluation.retries))) as $retry_summary |
        ([$samples[] |
          if .evaluation.terminal_outcome != "completed" then "non_completed_outcome" else empty end,
          if (.evaluation.contract_failures | length) > 0 then "contract_failure" else empty end,
          if .evaluation.post_completion_defects > 0 then "post_completion_defect" else empty end]
         | unique | sort) as $disqualifiers |
        {
          profile_id:$samples[0].profile_id,
          profile_identity_source:(if any($samples[]; .profile_identity_source == "derived")
                                   then "derived" else "explicit" end),
          sample_count:$sample_count,
          comparison_sample_count:$comparison_sample_count,
          scenarios:($samples | map(.scenario_key) | unique | sort),
          comparison_scenarios:($comparison_samples | map(.scenario_key) | unique | sort),
          evidence_refs:($samples | map(.evaluation.evidence_refs[]) | unique | sort),
          safety:{
            eligible:($disqualifiers | length == 0),
            disqualifiers:$disqualifiers,
            terminal_outcomes:($samples | map(.evaluation.terminal_outcome) | unique | sort),
            contract_failures:($samples | map(.evaluation.contract_failures[]) | unique | sort)
          },
          metrics:{
            contract_failures:($samples | map(.evaluation.contract_failures | length) | add // 0),
            post_completion_defects:($samples | map(.evaluation.post_completion_defects) | add // 0),
            interventions:$intervention_summary,
            retries:$retry_summary,
            duration_ms:$duration_summary,
            agent_count:$agent_summary,
            tokens:$token_summary,
            cost_usd:$cost_summary
          },
          observed_dimensions:(
            (if $comparison_sample_count > 0 then ["interventions", "retries"] else [] end) +
            (if $duration_summary.availability == "complete" then ["duration_ms"] else [] end) +
            (if $agent_summary.availability == "complete" then ["agent_count"] else [] end) +
            (if $token_summary.availability == "complete" then ["tokens"] else [] end) +
            (if $cost_summary.availability == "complete" then ["cost_usd"] else [] end)
          ),
          dominated_by:[]
        };
      def build_cohort($cohort):
        ($cohort[0].environment_status) as $environment_status |
        ($cohort | map(.profile_id) | unique | sort) as $profile_ids |
        ($profile_ids
         | map(. as $profile_id |
               [$cohort[] | select(.profile_id == $profile_id) | .scenario_key]
               | unique | sort)) as $scenario_sets |
        (scenario_intersection($scenario_sets)) as $shared_scenarios |
        ($cohort
         | group_by(.profile_id)
         | map(build_profile(.; $shared_scenarios))
         | sort_by(.profile_id)) as $profiles |
        ([$environment_status != "known" as $unknown |
          if $unknown then "unknown_environment_identity" else empty end,
          if ($profile_ids | length) < 2 then "minimum_profiles_not_met" else empty end,
          if ($shared_scenarios | length) < 3 then "minimum_shared_scenarios_not_met" else empty end,
          if any($profiles[]; .profile_identity_source == "derived") then "derived_profile_identity" else empty end]
         | unique | sort) as $eligibility_reasons |
        ($profiles as $all |
         $profiles
         | map(. as $profile |
               .dominated_by = ([$all[] |
                                  select(.profile_id != $profile.profile_id) |
                                  select(dominates(.; $profile)) |
                                  .profile_id]
                                | unique | sort))) as $ranked_profiles |
        ($ranked_profiles
         | map(select(.safety.eligible and
                      .profile_identity_source == "explicit" and
                      (.dominated_by | length) == 0) |
               .profile_id)
         | sort) as $frontier |
        {
          id:(if $environment_status == "known"
              then "known/" + ($cohort[0].environment_key | @uri)
              else "unknown"
              end),
          environment_status:$environment_status,
          environment:(if $environment_status == "known" then $cohort[0].environment else null end),
          profile_count:($profile_ids | length),
          profile_ids:$profile_ids,
          shared_scenarios:$shared_scenarios,
          shared_scenario_count:($shared_scenarios | length),
          profiles:$ranked_profiles,
          eligibility:{
            eligible:($eligibility_reasons | length == 0),
            reasons:$eligibility_reasons
          },
          pareto_frontier:(if ($eligibility_reasons | length) == 0 then $frontier else [] end)
        };
      ($records | sort_by(.path)) as $sorted |
      ($sorted
       | group_by(.environment_key)
       | map(build_cohort(.))
       | sort_by(.id)) as $cohorts |
      ([$cohorts[] | select(.eligibility.eligible)]) as $eligible_cohorts |
      (if any($cohorts[]; .environment_status == "unknown") then
         {state:"collect_more_evidence", candidate:null,
          reasons:["unknown_environment_identity"]}
       elif ($eligible_cohorts | length) == 0 then
         {state:"collect_more_evidence", candidate:null,
          reasons:([$cohorts[].eligibility.reasons[]] | unique | sort)}
       elif ($eligible_cohorts | length) > 1 then
         {state:"human_review_required", candidate:null,
          reasons:["multiple_comparable_cohorts"]}
       elif ($eligible_cohorts[0].pareto_frontier | length) == 0 then
         {state:"human_review_required", candidate:null,
          reasons:["no_safety_eligible_profile"]}
       elif ($eligible_cohorts[0].pareto_frontier | length) == 1 then
         {state:"review_profile_candidate",
          candidate:$eligible_cohorts[0].pareto_frontier[0],
          reasons:["single_pareto_candidate"]}
       else
         {state:"human_review_required", candidate:null,
          reasons:["pareto_tie"]}
       end) as $recommendation |
      {
        schema:"hotl.evaluation-summary/v1",
        source:"local-evaluation-results",
        source_recorded_through:($sorted | map(.recorded_at) | max),
        requirements:{
          minimum_profiles:2,
          minimum_shared_scenarios:3,
          known_environment_required:true
        },
        inputs:{
          count:($sorted | length),
          records:($sorted | map(del(.evaluation, .environment_key, .scenario_key)))
        },
        cohorts:$cohorts,
        recommendation:{
          state:$recommendation.state,
          candidate_profile_id:$recommendation.candidate,
          reason_codes:$recommendation.reasons,
          human_review_required:true,
          configuration_changes_performed:false
        }
      }
    '
}

render_text() {
    local summary="$1"

    jq -r '
      def value_or_unknown($value):
        if $value == null then "unknown" else ($value | tostring) end;
      "HOTL Evaluation Report",
      "Source records: \(.inputs.count)",
      "Recommendation: \(.recommendation.state)",
      "Candidate profile: \(.recommendation.candidate_profile_id // "none")",
      "Reasons: \(if (.recommendation.reason_codes | length) == 0 then "none" else (.recommendation.reason_codes | join(", ")) end)",
      "Human review required: \(if .recommendation.human_review_required then "yes" else "no" end)",
      "Configuration changes performed: \(if .recommendation.configuration_changes_performed then "yes" else "no" end)",
      (.cohorts[] |
        "",
        "Cohort: \(.id)",
        "Environment: \(.environment_status)",
        "Profiles: \(.profile_count)",
        "Shared scenarios: \(.shared_scenario_count)",
        "Comparison eligible: \(if .eligibility.eligible then "yes" else "no" end)",
        "Eligibility gaps: \(if (.eligibility.reasons | length) == 0 then "none" else (.eligibility.reasons | join(", ")) end)",
        "Pareto frontier: \(if (.pareto_frontier | length) == 0 then "none" else (.pareto_frontier | join(", ")) end)",
        (.profiles[] |
          "- \(.profile_id): safety=\(if .safety.eligible then "eligible" else "disqualified" end), disqualifiers=\(if (.safety.disqualifiers | length) == 0 then "none" else (.safety.disqualifiers | join(", ")) end), outcomes=\(.safety.terminal_outcomes | join(", ")), contract_failure_ids=\(if (.safety.contract_failures | length) == 0 then "none" else (.safety.contract_failures | join(", ")) end), samples=\(.sample_count), comparison_samples=\(.comparison_sample_count), scenarios=\(.scenarios | join(", ")), comparison_scenarios=\(.comparison_scenarios | join(", "))",
          "  Metrics: contract_failures=\(.metrics.contract_failures), post_completion_defects=\(.metrics.post_completion_defects), interventions_total=\(.metrics.interventions.total), interventions_mean=\(value_or_unknown(.metrics.interventions.mean)), retries_total=\(.metrics.retries.total), retries_mean=\(value_or_unknown(.metrics.retries.mean))",
          "  Telemetry: duration_ms=\(value_or_unknown(.metrics.duration_ms.mean)) [\(.metrics.duration_ms.availability)], agent_count=\(value_or_unknown(.metrics.agent_count.mean)) [\(.metrics.agent_count.availability)], tokens=\(value_or_unknown(.metrics.tokens.mean)) [\(.metrics.tokens.availability)], cost_usd=\(value_or_unknown(.metrics.cost_usd.mean)) [\(.metrics.cost_usd.availability)]",
          "  Evidence: \(.evidence_refs | join(", "))",
          "  Dominated by: \(if (.dominated_by | length) == 0 then "none" else (.dominated_by | join(", ")) end)"))
    ' <<< "$summary"
}

main() {
    require_jq

    local format="json"

    case "${1:-}" in
        help|--help|-h)
            usage
            exit 0
            ;;
    esac

    if [ "${1:-}" = "--format" ]; then
        [ "$#" -ge 2 ] || {
            echo "ERROR: --format requires json or text." >&2
            exit 1
        }
        format="$2"
        shift 2
    fi

    case "$format" in
        json|text) ;;
        *)
            echo "ERROR: format must be json or text." >&2
            exit 1
            ;;
    esac

    [ "$#" -gt 0 ] || {
        usage >&2
        exit 1
    }

    local records='[]'
    local file normalized
    for file in "$@"; do
        [ -f "$file" ] || {
            echo "ERROR: evaluation result not found: $file" >&2
            exit 1
        }
        bash "$CONFORMANCE" validate-evaluation "$file" "$SCENARIOS" >/dev/null
        normalized="$(normalize_record "$file")"
        records="$(jq -cn --argjson records "$records" --argjson record "$normalized" '$records + [$record]')"
    done

    local summary
    summary="$(build_summary "$records")"
    if [ "$format" = "text" ]; then
        render_text "$summary"
    else
        jq -cS . <<< "$summary"
    fi
}

main "$@"
