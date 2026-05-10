#!/usr/bin/env bash
set -euo pipefail

# HOTL Document Lint
# Deterministic structural validation for design docs and workflow files.
# Exit 0 = PASS, Exit 1 = FAIL (errors on stderr)

if [ $# -lt 1 ]; then
    echo "Usage: document-lint.sh <file>" >&2
    echo "  Validates canonical design docs (docs/designs/*.md), legacy design/plan docs (*-design.md, *-plan.md)," >&2
    echo "  and canonical/legacy workflow files (docs/plans/*-workflow.md, hotl-workflow-*.md)" >&2
    exit 1
fi

FILE="$1"
FILENAME="$(basename "$FILE")"
ERRORS=0

error() {
    echo "FAIL: $1" >&2
    ERRORS=$((ERRORS + 1))
}

contains_ci() {
    local content="$1"
    local pattern="$2"
    grep -qi -- "$pattern" <<< "$content"
}

contains_ere() {
    local content="$1"
    local pattern="$2"
    grep -Eq -- "$pattern" <<< "$content"
}

first_match_ci() {
    local content="$1"
    local pattern="$2"
    grep -im 1 -- "$pattern" <<< "$content"
}

detect_design_type() {
    local filepath="$1"
    local fname
    fname="$(basename "$filepath")"

    # Valid design types
    local valid_types="feature phase initiative architecture contract reference"

    # 1. Try YAML frontmatter: design_type field between FIRST --- (must be line 1)
    #    and the next --- only. Stops the range early so body fences using ---
    #    cannot spoof detection (e.g. an architecture doc demonstrating a phase
    #    doc would otherwise be reclassified).
    if [ -f "$filepath" ]; then
        local first_line
        first_line="$(head -n 1 "$filepath")"
        if [ "$first_line" = "---" ]; then
            local frontmatter
            frontmatter="$(awk 'NR==1 && /^---$/ {flag=1; next} flag && /^---$/ {exit} flag {print}' "$filepath")"
            if [ -n "$frontmatter" ]; then
                local dt
                dt="$(grep -i '^design_type:' <<< "$frontmatter" | head -1 | sed 's/.*design_type:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
                # Strip surrounding YAML quoted-scalar quotes (Phase 1.6 review WARN).
                dt="${dt#\"}"; dt="${dt%\"}"
                dt="${dt#\'}"; dt="${dt%\'}"
                if [ -n "$dt" ]; then
                    for vt in $valid_types; do
                        if [ "$dt" = "$vt" ]; then
                            echo "$dt"
                            return 0
                        fi
                    done
                fi
            fi
        fi
    fi

    # 2. Filename pattern fallback
    # Dated pattern: YYYY-MM-DD-<slug>-design.md
    if contains_ere "$fname" '^[0-9]{4}-[0-9]{2}-[0-9]{2}-.*-design\.md$'; then
        # Extract slug between date and -design.md
        local slug
        slug="$(sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-(.*)-design\.md$/\1/' <<< "$fname")"
        if contains_ere "$slug" '(^|-)phase-[0-9]+($|-)'; then
            echo "phase"
        else
            echo "feature"
        fi
        return 0
    fi

    # Undated docs without frontmatter return non-zero so the opt-in marker gate
    # can route them through AI review instead of HOTL strict lint. (Phase 1.6)

    # 3. No match
    return 1
}

# has_hotl_marker — opt-in gate (Phase 1.6).
# Returns 0 if the file's frontmatter declares either:
#   - design_type: <one of feature|phase|initiative|architecture|contract|reference>
#   - hotl_managed: true
# Returns 1 otherwise. Filename pattern alone is NOT a marker.
has_hotl_marker() {
    local filepath="$1"
    local valid_types="feature phase initiative architecture contract reference"

    if [ ! -f "$filepath" ]; then
        return 1
    fi

    local first_line
    first_line="$(head -n 1 "$filepath")"
    if [ "$first_line" != "---" ]; then
        return 1
    fi

    local frontmatter
    frontmatter="$(awk 'NR==1 && /^---$/ {flag=1; next} flag && /^---$/ {exit} flag {print}' "$filepath")"
    if [ -z "$frontmatter" ]; then
        return 1
    fi

    # Check 1: design_type with a recognized value.
    # Strip surrounding YAML quoted-scalar quotes so `design_type: "feature"` and
    # `design_type: 'feature'` both opt in (Phase 1.6 review WARN).
    local dt
    dt="$(grep -i '^design_type:' <<< "$frontmatter" | head -1 | sed 's/.*design_type:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
    dt="${dt#\"}"; dt="${dt%\"}"
    dt="${dt#\'}"; dt="${dt%\'}"
    if [ -n "$dt" ]; then
        for vt in $valid_types; do
            if [ "$dt" = "$vt" ]; then
                return 0
            fi
        done
    fi

    # Check 2: hotl_managed: true
    if grep -qiE '^hotl_managed:[[:space:]]*true[[:space:]]*$' <<< "$frontmatter"; then
        return 0
    fi

    return 1
}

check_implementation_leakage() {
    local filepath="$1"
    local resolved_type="$2"

    # Only fires for feature and phase design types
    case "$resolved_type" in
        feature|phase) ;;
        *) return 0 ;;
    esac

    # Extract body: skip frontmatter (lines before and including the second ---)
    local in_frontmatter=0
    local frontmatter_closed=0
    local line_num=0
    local body_lines=()
    local body_line_nums=()

    # If file does not start with ---, there is no frontmatter; collect all lines as body.
    local first_line
    first_line="$(head -n 1 "$filepath")"
    if [ "$first_line" != "---" ]; then
        frontmatter_closed=1
    fi

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$frontmatter_closed" -eq 0 ]; then
            if [ "$line" = "---" ]; then
                in_frontmatter=$((in_frontmatter + 1))
                if [ "$in_frontmatter" -ge 2 ]; then
                    frontmatter_closed=1
                fi
            fi
            continue
        fi
        body_lines+=("$line")
        body_line_nums+=("$line_num")
    done < "$filepath"

    local i=0
    local count=${#body_lines[@]}

    # Pattern 1: file:line references
    while [ "$i" -lt "$count" ]; do
        local bline="${body_lines[$i]}"
        local bnum="${body_line_nums[$i]}"
        local match
        match="$(grep -oE '\b\w+\.(py|ts|js|go|rs|java|cpp|sh):[0-9]+\b' <<< "$bline" | head -1)" || true
        if [ -n "$match" ]; then
            printf 'category=implementation-leakage severity=warning design_type=%s line=%d\n' "$resolved_type" "$bnum"
            printf 'message="file:line reference '\''%s'\'' belongs in workflow, not design"\n' "$match"
        fi
        i=$((i + 1))
    done

    # Pattern 2: fenced code blocks with >10 content lines
    i=0
    while [ "$i" -lt "$count" ]; do
        local bline="${body_lines[$i]}"
        local bnum="${body_line_nums[$i]}"
        if [[ "$bline" =~ ^\`\`\` ]]; then
            local fence_open_line="$bnum"
            local content_lines=0
            i=$((i + 1))
            while [ "$i" -lt "$count" ]; do
                local inner="${body_lines[$i]}"
                if [[ "$inner" =~ ^\`\`\` ]]; then
                    break
                fi
                content_lines=$((content_lines + 1))
                i=$((i + 1))
            done
            if [ "$content_lines" -gt 10 ]; then
                printf 'category=implementation-leakage severity=warning design_type=%s line=%d\n' "$resolved_type" "$fence_open_line"
                printf 'message="code block at line %d has %d content lines (>10); design shows shape, not impl"\n' "$fence_open_line" "$content_lines"
            fi
        fi
        i=$((i + 1))
    done

    # Pattern 3: lines with 6 or more -- flag tokens
    i=0
    while [ "$i" -lt "$count" ]; do
        local bline="${body_lines[$i]}"
        local bnum="${body_line_nums[$i]}"
        local dash_count
        dash_count="$(grep -oE '(^|[[:space:]])--[A-Za-z]' <<< "$bline" | wc -l | tr -d ' ')" || true
        if [ "$dash_count" -ge 6 ]; then
            printf 'category=implementation-leakage severity=warning design_type=%s line=%d\n' "$resolved_type" "$bnum"
            printf 'message="dense flag line at line %d (%d '\''--'\'' tokens); argv goes in workflow + tests"\n' "$bnum" "$dash_count"
        fi
        i=$((i + 1))
    done
}

check_required_sections() {
    local filepath="$1"
    local resolved_type="$2"

    # Only fires for feature and phase design types
    case "$resolved_type" in
        feature|phase) ;;
        *) return 0 ;;
    esac

    # Extract body: skip frontmatter (lines before and including the second ---)
    local in_frontmatter=0
    local frontmatter_closed=0
    local body=""

    # If file does not start with ---, there is no frontmatter; collect all lines as body.
    local first_line
    first_line="$(head -n 1 "$filepath")"
    if [ "$first_line" != "---" ]; then
        frontmatter_closed=1
    fi

    while IFS= read -r line; do
        if [ "$frontmatter_closed" -eq 0 ]; then
            if [ "$line" = "---" ]; then
                in_frontmatter=$((in_frontmatter + 1))
                if [ "$in_frontmatter" -ge 2 ]; then
                    frontmatter_closed=1
                fi
            fi
            continue
        fi
        body="${body}${line}
"
    done < "$filepath"

    # Required top-level headings for feature/phase design docs
    local required_headings="Intent Contract
Verification Contract
Governance Contract
Scope
Decisions
Surface
Risks & Open Questions"

    while IFS= read -r heading; do
        if ! grep -q "^## ${heading}" <<< "$body"; then
            printf 'category=structure severity=warning design_type=%s\n' "$resolved_type"
            printf 'message="missing required section: ## %s"\n' "$heading"
        fi
    done <<< "$required_headings"
}

# ── Detect file type ─────────────────────────────────────────────────────────

if contains_ere "$FILE" '(^|/)docs/designs/[^/]+\.md$'; then
    FILE_TYPE="design"
elif contains_ere "$FILENAME" '\-(design|plan)\.md$'; then
    FILE_TYPE="design"
elif contains_ere "$FILE" '(^|/)docs/plans/[^/]+-workflow\.md$'; then
    FILE_TYPE="workflow"
elif contains_ere "$FILENAME" '^hotl-workflow-.*\.md$'; then
    FILE_TYPE="workflow"
else
    echo "SKIP: $FILENAME is not a HOTL design doc or workflow file" >&2
    exit 0
fi

if [ ! -f "$FILE" ]; then
    error "File not found: $FILE"
    exit 1
fi

# Phase 1.6 opt-in gate: design docs need a frontmatter HOTL marker
# (design_type: <recognized> OR hotl_managed: true) to receive HOTL strict lint.
# Unmarked docs SKIP cleanly so document-review can route them to AI review.
# Workflow files are NOT subject to this gate — they remain execution-critical.
if [ "$FILE_TYPE" = "design" ]; then
    if ! has_hotl_marker "$FILE"; then
        echo "SKIP: $FILENAME is not a HOTL-managed design doc (no design_type or hotl_managed marker) — use hotl:document-review for AI review." >&2
        exit 0
    fi
fi

CONTENT="$(cat "$FILE")"

# ── Implementation-leakage check (warning-only) ─────────────────────────────

if [ "$FILE_TYPE" = "design" ]; then
    RESOLVED_DESIGN_TYPE=""
    RESOLVED_DESIGN_TYPE="$(detect_design_type "$FILE")" || true
    if [ "$RESOLVED_DESIGN_TYPE" = "feature" ] || [ "$RESOLVED_DESIGN_TYPE" = "phase" ]; then
        check_implementation_leakage "$FILE" "$RESOLVED_DESIGN_TYPE"
        check_required_sections "$FILE" "$RESOLVED_DESIGN_TYPE"
    fi
fi

is_step_header() {
    local line="$1"
    contains_ere "$line" '^### [0-9]+\.|^- \[[ xX]\] \*\*Step [0-9]+:'
}

step_name_from_line() {
    local line="$1"
    if contains_ere "$line" '^### [0-9]+\.'; then
        sed -E 's/^### [0-9]+\. //' <<< "$line"
    else
        sed -E 's/^- \[[ xX]\] \*\*Step [0-9]+:[[:space:]]*(.*)\*\*$/\1/' <<< "$line"
    fi
}

validate_verify_block() {
    local step_name="$1"
    local step_block="$2"

    # Check if verify: exists
    if ! contains_ci "$step_block" '^verify:'; then
        return 0
    fi

    # Get verify line and check if scalar (value on same line)
    local verify_line
    verify_line=$(first_match_ci "$step_block" '^verify:')
    local verify_value
    verify_value="${verify_line#*:}"
    verify_value="${verify_value#"${verify_value%%[![:space:]]*}"}"

    if [ -n "$verify_value" ]; then
        # Scalar form — valid as type:shell shorthand
        return 0
    fi

    # Structured form — extract indented block after verify:
    local in_verify=0
    local verify_block=""
    while IFS= read -r line; do
        if [ "$in_verify" -eq 0 ] && contains_ci "$line" '^verify:$'; then
            in_verify=1
            continue
        fi
        if [ "$in_verify" -eq 1 ]; then
            if contains_ere "$line" '^[[:space:]]'; then
                verify_block="${verify_block}${line}
"
            elif [ -z "$line" ]; then
                continue
            else
                in_verify=0
            fi
        fi
    done <<< "$step_block"

    if [ -z "$verify_block" ]; then
        error "Step '$step_name' has empty verify block"
        return 0
    fi

    # Validate type field(s) exist
    if ! contains_ci "$verify_block" 'type:'; then
        error "Step '$step_name' has structured verify block but missing 'type:' field"
        return 0
    fi

    # Validate each type value is valid
    local types
    types=$(grep -i -- 'type:' <<< "$verify_block" | sed 's/.*type:[[:space:]]*//' | tr -d ' ')
    while IFS= read -r vtype; do
        [ -z "$vtype" ] && continue
        case "$vtype" in
            shell)
                contains_ci "$verify_block" 'command:' || error "Step '$step_name' verify type:shell missing 'command:' field"
                ;;
            browser)
                contains_ci "$verify_block" 'url:' || error "Step '$step_name' verify type:browser missing 'url:' field"
                contains_ci "$verify_block" 'check:' || error "Step '$step_name' verify type:browser missing 'check:' field"
                ;;
            human-review)
                contains_ci "$verify_block" 'prompt:' || error "Step '$step_name' verify type:human-review missing 'prompt:' field"
                ;;
            artifact)
                contains_ci "$verify_block" 'path:' || error "Step '$step_name' verify type:artifact missing 'path:' field"
                contains_ci "$verify_block" 'kind:' || error "Step '$step_name' verify type:artifact missing 'assert.kind' field"
                ;;
            *)
                error "Step '$step_name' has invalid verify type '$vtype' (expected: shell, browser, human-review, artifact)"
                ;;
        esac
    done <<< "$types"
}

check_step_block() {
    local step_name="$1"
    local step_block="$2"

    contains_ci "$step_block" '^action:' || error "Step '$step_name' missing 'action:' field"
    contains_ci "$step_block" '^loop:' || error "Step '$step_name' missing 'loop:' field"

    if contains_ci "$step_block" '^loop:.*until'; then
        contains_ci "$step_block" '^verify:' || error "Step '$step_name' has loop:until but missing 'verify:' field"
        contains_ci "$step_block" '^max_iterations:' || error "Step '$step_name' has loop:until but missing 'max_iterations:' field"
    fi

    # Validate typed verify blocks if present
    validate_verify_block "$step_name" "$step_block"

    if [ -n "${RISK:-}" ] && [ "$RISK" = "high" ]; then
        SECURITY_KEYWORDS="auth\|encrypt\|secret\|password\|token\|billing\|permission"
        if contains_ci "$step_block" "$SECURITY_KEYWORDS"; then
            contains_ci "$step_block" '^gate:.*human' || error "Step '$step_name' has security keywords with risk_level:high but missing 'gate: human'"
        fi
    fi
}

# ── Design doc checks ────────────────────────────────────────────────────────

if [ "$FILE_TYPE" = "design" ]; then

    # Intent Contract
    if ! contains_ci "$CONTENT" 'intent contract\|## intent'; then
        error "Missing Intent Contract section"
    else
        contains_ci "$CONTENT" 'intent:' || error "Intent Contract missing 'intent:' field"
        contains_ci "$CONTENT" 'constraints:' || error "Intent Contract missing 'constraints:' field"
        contains_ci "$CONTENT" 'success_criteria:' || error "Intent Contract missing 'success_criteria:' field"
        contains_ci "$CONTENT" 'risk_level:' || error "Intent Contract missing 'risk_level:' field"
    fi

    # Verification Contract
    if ! contains_ci "$CONTENT" 'verification contract\|## verification'; then
        error "Missing Verification Contract section"
    else
        contains_ci "$CONTENT" 'verify\|check\|confirm\|run test' || error "Verification Contract has no verify steps"
    fi

    # Governance Contract
    if ! contains_ci "$CONTENT" 'governance contract\|## governance'; then
        error "Missing Governance Contract section"
    else
        contains_ci "$CONTENT" 'approval_gates\|approval gates' || error "Governance Contract missing 'approval_gates' field"
        contains_ci "$CONTENT" 'rollback:' || error "Governance Contract missing 'rollback' field"
    fi

    # risk_level validation
    if contains_ci "$CONTENT" 'risk_level:'; then
        RISK=$(first_match_ci "$CONTENT" 'risk_level:' | sed 's/.*risk_level:[[:space:]]*//' | tr -d '`' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        case "$RISK" in
            low|medium|high) ;;
            *) error "risk_level must be low, medium, or high (got: '$RISK')" ;;
        esac
    fi
fi

# ── Workflow file checks ─────────────────────────────────────────────────────

if [ "$FILE_TYPE" = "workflow" ]; then

    # Frontmatter check
    FIRST_LINE="${CONTENT%%$'\n'*}"
    if [[ ! "$FIRST_LINE" =~ ^--- ]]; then
        error "Missing YAML frontmatter (file must start with ---)"
    else
        # Extract frontmatter (between first and second ---)
        FRONTMATTER=$(sed -n '/^---$/,/^---$/p' <<< "$CONTENT")
        contains_ci "$FRONTMATTER" 'intent:' || error "Frontmatter missing 'intent:' field"
        contains_ci "$FRONTMATTER" 'success_criteria:' || error "Frontmatter missing 'success_criteria:' field"
        contains_ci "$FRONTMATTER" 'risk_level:' || error "Frontmatter missing 'risk_level:' field"

        # risk_level validation
        if contains_ci "$FRONTMATTER" 'risk_level:'; then
            RISK=$(first_match_ci "$FRONTMATTER" 'risk_level:' | sed 's/.*risk_level:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
            case "$RISK" in
                low|medium|high) ;;
                *) error "risk_level must be low, medium, or high (got: '$RISK')" ;;
            esac
        fi

        # progress validation (optional field)
        if contains_ci "$FRONTMATTER" 'progress:'; then
            PROGRESS=$(first_match_ci "$FRONTMATTER" 'progress:' | sed 's/.*progress:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
            case "$PROGRESS" in
                verbose) ;;
                *) error "progress must be 'verbose' if set (got: '$PROGRESS')" ;;
            esac
        fi

        # report_detail validation (optional field)
        if contains_ci "$FRONTMATTER" 'report_detail:'; then
            REPORT_DETAIL=$(first_match_ci "$FRONTMATTER" 'report_detail:' | sed 's/.*report_detail:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
            case "$REPORT_DETAIL" in
                full) ;;
                *) error "report_detail must be 'full' if set (got: '$REPORT_DETAIL')" ;;
            esac
        fi

        # worktree validation (optional field)
        if contains_ci "$FRONTMATTER" '^worktree:'; then
            WORKTREE_MODE=$(first_match_ci "$FRONTMATTER" '^worktree:' | sed 's/.*worktree:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
            case "$WORKTREE_MODE" in
                true|false|host) ;;
                *) error "worktree must be true, false, or host if set (got: '$WORKTREE_MODE')" ;;
            esac
        fi

        # dirty_worktree validation (optional field)
        if contains_ci "$FRONTMATTER" 'dirty_worktree:'; then
            DIRTY_WT=$(first_match_ci "$FRONTMATTER" 'dirty_worktree:' | sed 's/.*dirty_worktree:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
            case "$DIRTY_WT" in
                allow) ;;
                *) error "dirty_worktree must be 'allow' if set (got: '$DIRTY_WT')" ;;
            esac
        fi
    fi

    # Step structure checks
    # Accept both legacy numbered headings and checkbox-style step bullets.
    STEP_COUNT=$(grep -Ec -- '^### [0-9]+\.|^- \[[ xX]\] \*\*Step [0-9]+:' <<< "$CONTENT" || true)
    if [ "$STEP_COUNT" -eq 0 ]; then
        error "No steps found (expected either '### N. Step name' or '- [ ] **Step N: Step name**')"
    else
        CURRENT_STEP=""
        CURRENT_BLOCK=""

        while IFS= read -r line; do
            if is_step_header "$line"; then
                if [ -n "$CURRENT_STEP" ] && [ -n "$CURRENT_BLOCK" ]; then
                    check_step_block "$CURRENT_STEP" "$CURRENT_BLOCK"
                fi

                CURRENT_STEP="$(step_name_from_line "$line")"
                CURRENT_BLOCK=""
            else
                CURRENT_BLOCK="${CURRENT_BLOCK}
${line}"
            fi
        done <<< "$CONTENT"

        if [ -n "$CURRENT_STEP" ] && [ -n "$CURRENT_BLOCK" ]; then
            check_step_block "$CURRENT_STEP" "$CURRENT_BLOCK"
        fi
    fi
fi

# ── Result ────────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
    echo "LINT FAILED: $ERRORS error(s) in $FILENAME" >&2
    exit 1
else
    echo "LINT PASSED: $FILENAME"
    exit 0
fi
