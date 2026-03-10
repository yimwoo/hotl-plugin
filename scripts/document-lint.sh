#!/usr/bin/env bash
set -euo pipefail

# HOTL Document Lint
# Deterministic structural validation for design docs and workflow files.
# Exit 0 = PASS, Exit 1 = FAIL (errors on stderr)

if [ $# -lt 1 ]; then
    echo "Usage: document-lint.sh <file>" >&2
    echo "  Validates design docs (*-design.md) and workflow files (hotl-workflow-*.md)" >&2
    exit 1
fi

FILE="$1"
FILENAME="$(basename "$FILE")"
ERRORS=0

error() {
    echo "FAIL: $1" >&2
    ERRORS=$((ERRORS + 1))
}

# ── Detect file type ─────────────────────────────────────────────────────────

if echo "$FILENAME" | grep -q '\-design\.md$'; then
    FILE_TYPE="design"
elif echo "$FILENAME" | grep -q '^hotl-workflow-.*\.md$'; then
    FILE_TYPE="workflow"
else
    echo "SKIP: $FILENAME is not a design doc or workflow file" >&2
    exit 0
fi

if [ ! -f "$FILE" ]; then
    error "File not found: $FILE"
    exit 1
fi

CONTENT="$(cat "$FILE")"

is_step_header() {
    local line="$1"
    echo "$line" | grep -Eq '^### [0-9]+\.|^- \[[ xX]\] \*\*Step [0-9]+:'
}

step_name_from_line() {
    local line="$1"
    if echo "$line" | grep -Eq '^### [0-9]+\.'; then
        echo "$line" | sed -E 's/^### [0-9]+\. //'
    else
        echo "$line" | sed -E 's/^- \[[ xX]\] \*\*Step [0-9]+:[[:space:]]*(.*)\*\*$/\1/'
    fi
}

check_step_block() {
    local step_name="$1"
    local step_block="$2"

    printf '%s\n' "$step_block" | grep -qi '^action:' || error "Step '$step_name' missing 'action:' field"
    printf '%s\n' "$step_block" | grep -qi '^loop:' || error "Step '$step_name' missing 'loop:' field"

    if printf '%s\n' "$step_block" | grep -qi '^loop:.*until'; then
        printf '%s\n' "$step_block" | grep -qi '^verify:' || error "Step '$step_name' has loop:until but missing 'verify:' field"
        printf '%s\n' "$step_block" | grep -qi '^max_iterations:' || error "Step '$step_name' has loop:until but missing 'max_iterations:' field"
    fi

    if [ -n "${RISK:-}" ] && [ "$RISK" = "high" ]; then
        SECURITY_KEYWORDS="auth\|encrypt\|secret\|password\|token\|billing\|permission"
        if printf '%s\n' "$step_block" | grep -qi "$SECURITY_KEYWORDS"; then
            printf '%s\n' "$step_block" | grep -qi '^gate:.*human' || error "Step '$step_name' has security keywords with risk_level:high but missing 'gate: human'"
        fi
    fi
}

# ── Design doc checks ────────────────────────────────────────────────────────

if [ "$FILE_TYPE" = "design" ]; then

    # Intent Contract
    if ! echo "$CONTENT" | grep -qi 'intent contract\|## intent'; then
        error "Missing Intent Contract section"
    else
        echo "$CONTENT" | grep -qi 'intent:' || error "Intent Contract missing 'intent:' field"
        echo "$CONTENT" | grep -qi 'constraints:' || error "Intent Contract missing 'constraints:' field"
        echo "$CONTENT" | grep -qi 'success_criteria:' || error "Intent Contract missing 'success_criteria:' field"
        echo "$CONTENT" | grep -qi 'risk_level:' || error "Intent Contract missing 'risk_level:' field"
    fi

    # Verification Contract
    if ! echo "$CONTENT" | grep -qi 'verification contract\|## verification'; then
        error "Missing Verification Contract section"
    else
        echo "$CONTENT" | grep -qi 'verify\|check\|confirm\|run test' || error "Verification Contract has no verify steps"
    fi

    # Governance Contract
    if ! echo "$CONTENT" | grep -qi 'governance contract\|## governance'; then
        error "Missing Governance Contract section"
    else
        echo "$CONTENT" | grep -qi 'approval_gates\|approval gates' || error "Governance Contract missing 'approval_gates' field"
        echo "$CONTENT" | grep -qi 'rollback:' || error "Governance Contract missing 'rollback' field"
    fi

    # risk_level validation
    if echo "$CONTENT" | grep -qi 'risk_level:'; then
        RISK=$(echo "$CONTENT" | grep -i 'risk_level:' | head -1 | sed 's/.*risk_level:[[:space:]]*//' | tr -d '`' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        case "$RISK" in
            low|medium|high) ;;
            *) error "risk_level must be low, medium, or high (got: '$RISK')" ;;
        esac
    fi
fi

# ── Workflow file checks ─────────────────────────────────────────────────────

if [ "$FILE_TYPE" = "workflow" ]; then

    # Frontmatter check
    if ! echo "$CONTENT" | head -1 | grep -q '^---'; then
        error "Missing YAML frontmatter (file must start with ---)"
    else
        # Extract frontmatter (between first and second ---)
        FRONTMATTER=$(echo "$CONTENT" | sed -n '/^---$/,/^---$/p')
        echo "$FRONTMATTER" | grep -qi 'intent:' || error "Frontmatter missing 'intent:' field"
        echo "$FRONTMATTER" | grep -qi 'success_criteria:' || error "Frontmatter missing 'success_criteria:' field"
        echo "$FRONTMATTER" | grep -qi 'risk_level:' || error "Frontmatter missing 'risk_level:' field"

        # risk_level validation
        if echo "$FRONTMATTER" | grep -qi 'risk_level:'; then
            RISK=$(echo "$FRONTMATTER" | grep -i 'risk_level:' | head -1 | sed 's/.*risk_level:[[:space:]]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
            case "$RISK" in
                low|medium|high) ;;
                *) error "risk_level must be low, medium, or high (got: '$RISK')" ;;
            esac
        fi
    fi

    # Step structure checks
    # Accept both legacy numbered headings and checkbox-style step bullets.
    STEP_COUNT=$(printf '%s\n' "$CONTENT" | grep -Ec '^### [0-9]+\.|^- \[[ xX]\] \*\*Step [0-9]+:' || true)
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
