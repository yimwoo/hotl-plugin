#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_CATALOG="${REPO_ROOT}/runtime/capabilities/catalog.json"

usage() {
    printf '%s\n' \
        "usage: hotl-capabilities.sh validate [catalog.json]" \
        "       hotl-capabilities.sh render [catalog.json] [--check]" \
        "       hotl-capabilities.sh probe [catalog.json]"
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required for HOTL capability catalog operations." >&2
        exit 1
    fi
}

validate_catalog() {
    local catalog="$1"

    if [ ! -f "$catalog" ]; then
        echo "ERROR: capability catalog not found: $catalog" >&2
        return 1
    fi

    jq -e '
      def nonempty_string: type == "string" and length > 0;
      def valid_date: nonempty_string and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
      def allowed($values): . as $value | $values | index($value) != null;
      def valid_source:
        nonempty_string and
        test("^https://(developers\\.openai\\.com|openai\\.com|help\\.openai\\.com|code\\.claude\\.com|www\\.anthropic\\.com|github\\.com/yimwoo/hotl-plugin)(/|$)");
      .schema_version == 1 and
      (.verified_at | valid_date) and
      (.capabilities | type == "array" and length > 0) and
      (all(.capabilities[];
        (.id | nonempty_string) and
        (.host | allowed(["codex", "claude-code", "hotl-fallback"])) and
        (.category | allowed(["orchestration", "isolation", "lifecycle", "automation", "review", "memory", "browser", "security", "persistence", "verification"])) and
        (.name | nonempty_string) and
        (.provider_maturity | allowed(["stable", "beta", "experimental", "research_preview", "unknown"])) and
        (.hotl_support | allowed(["candidate", "experimental", "conformant", "fallback_only", "unsupported", "deprecated"])) and
        ((.min_version == null) or (.min_version | nonempty_string)) and
        (.availability_conditions | type == "array" and length > 0 and all(.[]; nonempty_string)) and
        (.observability | allowed(["full", "partial", "none", "unknown"])) and
        (.security_boundary | nonempty_string) and
        ((.fallback == null) or (.fallback | nonempty_string)) and
        (.sources | type == "array" and length > 0 and all(.[]; valid_source)) and
        (.verified_at | valid_date)
      )) and
      (([.capabilities[] | "\(.host):\(.id)"] | length) == ([.capabilities[] | "\(.host):\(.id)"] | unique | length)) and
      ([.capabilities[] | "\(.host):\(.id)"] as $ids |
        all(.capabilities[]; .fallback == null or (.fallback as $fallback | $ids | index($fallback) != null)))
    ' "$catalog" >/dev/null || {
        echo "ERROR: invalid HOTL capability catalog: $catalog" >&2
        return 1
    }
}

render_catalog() {
    local catalog="$1"
    validate_catalog "$catalog"

    jq -r '
      def esc: gsub("\\|"; "\\\\|");
      def humanize: gsub("_"; " ");
      def conditions: map(esc) | join("<br>");
      def links: to_entries | map("[source \(.key + 1)](\(.value))") | join(" ");
      "# HOTL Host Capability Matrix",
      "",
      "> Generated from `runtime/capabilities/catalog.json` (schema v\(.schema_version)); claims verified \(.verified_at). Do not edit this table by hand.",
      "",
      "This matrix separates three different claims:",
      "",
      "- **Provider maturity** describes what the provider documents.",
      "- **Local detection** is reported by `scripts/hotl-capabilities.sh probe` and can remain `unknown` even when a host is installed.",
      "- **HOTL support** describes whether HOTL has a conformant implementation, only a candidate native integration, or a fallback.",
      "",
      "The Phase 1 catalog is descriptive. It does not select an execution driver or change permissions.",
      "",
      "| Host | Capability | Category | Provider maturity | HOTL support | Minimum version | Observability | Availability conditions | Security boundary | Fallback | Verified | Sources |",
      "|---|---|---|---|---|---|---|---|---|---|---|---|",
      (.capabilities | sort_by(.host, .category, .id)[] |
        "| \(.host) | \(.name | esc) | \(.category | humanize) | \(.provider_maturity | humanize) | \(.hotl_support | humanize) | \(.min_version // "not specified") | \(.observability) | \(.availability_conditions | conditions) | \(.security_boundary | esc) | \(.fallback // "none") | \(.verified_at) | \(.sources | links) |"
      ),
      "",
      "## HOTL support states",
      "",
      "- `candidate`: provider capability identified for a future native adapter; no HOTL conformance claim yet.",
      "- `experimental`: a HOTL integration exists but is opt-in and not yet conformant.",
      "- `conformant`: deterministic HOTL contract scenarios pass for the implementation.",
      "- `fallback_only`: HOTL deliberately uses a generic fallback rather than a native integration.",
      "- `unsupported`: HOTL has no safe native or fallback path for the capability.",
      "- `deprecated`: the integration remains visible only for migration.",
      "",
      "## Interpretation rules",
      "",
      "- An installed executable does not prove plan entitlement, rollout availability, administrator enablement, or usable permissions.",
      "- Preview and experimental capabilities remain opt-in even when locally detected.",
      "- `unknown` is an evidence-preserving result, not an error and not a synonym for unavailable.",
      "- Host security controls remain authoritative when they are stricter than HOTL policy.",
      "- Relevant catalog rows must be refreshed from official sources when a driver or support claim changes."
    ' "$catalog"
}

command_version() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        return 1
    fi
    "$command_name" --version 2>/dev/null | head -n 1 || true
}

probe_catalog() {
    local catalog="$1"
    local codex_command="${HOTL_CODEX_BIN:-codex}"
    local claude_command="${HOTL_CLAUDE_BIN:-claude}"
    local codex_version=""
    local claude_version=""
    local fallback_available=false

    validate_catalog "$catalog"

    codex_version="$(command_version "$codex_command" || true)"
    claude_version="$(command_version "$claude_command" || true)"
    if [ -x "${REPO_ROOT}/runtime/hotl-rt" ] && command -v jq >/dev/null 2>&1; then
        fallback_available=true
    fi

    jq -n \
      --arg catalog "$catalog" \
      --arg codex_command "$codex_command" \
      --arg codex_version "$codex_version" \
      --arg claude_command "$claude_command" \
      --arg claude_version "$claude_version" \
      --argjson fallback_available "$fallback_available" \
      --slurpfile source "$catalog" '
        def host_state($version): if $version == "" then "unavailable" else "unknown" end;
        {
          schema_version: 1,
          catalog: $catalog,
          hosts: [
            {host: "codex", command: $codex_command, detected_version: (if $codex_version == "" then null else $codex_version end), state: host_state($codex_version)},
            {host: "claude-code", command: $claude_command, detected_version: (if $claude_version == "" then null else $claude_version end), state: host_state($claude_version)},
            {host: "hotl-fallback", command: "runtime/hotl-rt", detected_version: null, state: (if $fallback_available then "available" else "unavailable" end)}
          ],
          capabilities: [
            $source[0].capabilities[] as $cap |
            ($cap.host) as $host |
            ($codex_version != "") as $has_codex |
            ($claude_version != "") as $has_claude |
            {
              host: $host,
              id: $cap.id,
              state: (
                if $host == "hotl-fallback" then (if $fallback_available then "available" else "unavailable" end)
                elif $host == "codex" then (if $has_codex then "unknown" else "unavailable" end)
                elif $host == "claude-code" then (if $has_claude then "unknown" else "unavailable" end)
                else "unknown"
                end
              ),
              reason: (
                if $host == "hotl-fallback" and $fallback_available then "local runtime and jq detected"
                elif $host == "hotl-fallback" then "local runtime or jq unavailable"
                elif $host == "codex" and $has_codex then "host detected; entitlement, configuration, rollout, and usability not proven"
                elif $host == "claude-code" and $has_claude then "host detected; entitlement, configuration, rollout, and usability not proven"
                else "host executable not detected"
                end
              )
            }
          ]
        }
      '
}

main() {
    require_jq
    local command_name="${1:-}"
    local catalog="${2:-$DEFAULT_CATALOG}"

    case "$command_name" in
        validate)
            validate_catalog "$catalog"
            echo "Capability catalog valid: $catalog"
            ;;
        render)
            local check=0
            if [ "$catalog" = --check ]; then
                catalog="$DEFAULT_CATALOG"
                check=1
            elif [ "${3:-}" = --check ]; then
                check=1
            elif [ $# -gt 2 ]; then
                echo "ERROR: Unknown render option: ${3:-}" >&2
                exit 1
            fi
            if [ "$check" -eq 1 ]; then
                local matrix="${REPO_ROOT}/docs/host-capabilities.md"
                if diff -u "$matrix" <(render_catalog "$catalog"); then
                    echo "Capability matrix is current: $matrix"
                else
                    echo "ERROR: capability matrix is stale; regenerate it from the catalog" >&2
                    exit 1
                fi
            else
                render_catalog "$catalog"
            fi
            ;;
        probe)
            probe_catalog "$catalog"
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
