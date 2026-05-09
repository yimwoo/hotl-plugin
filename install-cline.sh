#!/usr/bin/env bash
set -euo pipefail

INSTALL_MODE="legacy-rules"

while [ $# -gt 0 ]; do
    case "$1" in
        --native-skills)
            INSTALL_MODE="native-skills"
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: bash install-cline.sh [--native-skills]" >&2
            exit 1
            ;;
    esac
    shift
done

HOTL_DIR="${HOME}/.cline/hotl"
RULES_SRC="${HOTL_DIR}/cline/rules"
SCRIPTS_SRC="${HOTL_DIR}/scripts"
GLOBAL_RULES_DIR="${HOME}/Documents/Cline/Rules"
GLOBAL_SCRIPTS_DIR="${HOME}/Documents/Cline/Scripts"
CLINE_SKILLS_DIR="${HOME}/.cline/skills/hotl"
MODE_FILE="${HOTL_DIR}/.cline-install-mode"

# ── Step 1: Install HOTL globally ─────────────────────────────────────────────

if [ -d "${HOTL_DIR}/.git" ]; then
    echo "Updating HOTL plugin at ${HOTL_DIR}..."
    git -C "${HOTL_DIR}" pull
else
    echo "Installing HOTL plugin to ${HOTL_DIR}..."
    # If running from a local clone, copy it; otherwise clone from GitHub
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${SCRIPT_DIR}/cline/rules/hotl-operating-model.md" ]; then
        mkdir -p "${HOTL_DIR}"
        cp -r "${SCRIPT_DIR}/." "${HOTL_DIR}/"
    else
        git clone https://github.com/yimwoo/hotl-plugin.git "${HOTL_DIR}"
    fi
fi

# Persist install mode
echo "${INSTALL_MODE}" > "${MODE_FILE}"

# ── Step 2: Install rules and/or skills ───────────────────────────────────────

# The 10 native Cline skills (by directory name)
NATIVE_SKILLS="brainstorming writing-plans document-review executing-plans subagent-execution tdd systematic-debugging code-review pr-reviewing loop-execution"

# The 9 legacy workflow rule files (all except hotl-operating-model.md)
LEGACY_WORKFLOW_RULES="hotl-brainstorming.md hotl-planning.md hotl-execution.md hotl-document-review.md hotl-subagent-execution.md hotl-tdd.md hotl-debugging.md hotl-code-review.md hotl-pr-review.md"

replace_placeholders() {
    local file="$1"
    sed -i.bak \
        -e "s|__HOTL_HOME__|~/.cline/hotl|g" \
        -e "s|__SCRIPTS_HOME__|~/Documents/Cline/Scripts|g" \
        "${file}"
    rm -f "${file}.bak"
}

mkdir -p "${GLOBAL_RULES_DIR}"

if [ "${INSTALL_MODE}" = "native-skills" ]; then
    # Native skills mode: 1 rule + 10 native skills

    # Install only hotl-operating-model.md as a rule
    if [ -f "${RULES_SRC}/hotl-operating-model.md" ]; then
        cp "${RULES_SRC}/hotl-operating-model.md" "${GLOBAL_RULES_DIR}/hotl-operating-model.md"
        replace_placeholders "${GLOBAL_RULES_DIR}/hotl-operating-model.md"
        echo "  Installed hotl-operating-model.md as global rule."
    else
        echo "ERROR: hotl-operating-model.md not found in ${RULES_SRC}"
        exit 1
    fi

    # Remove legacy workflow rules if they exist
    for rule_name in ${LEGACY_WORKFLOW_RULES}; do
        rm -f "${GLOBAL_RULES_DIR}/${rule_name}"
    done

    # Install native skills via symlinks
    mkdir -p "${CLINE_SKILLS_DIR}"
    SKILL_COUNT=0
    for skill_name in ${NATIVE_SKILLS}; do
        skill_src="${HOTL_DIR}/skills/${skill_name}"
        skill_dst="${CLINE_SKILLS_DIR}/${skill_name}"
        if [ -d "${skill_src}" ]; then
            rm -f "${skill_dst}" 2>/dev/null || rm -rf "${skill_dst}" 2>/dev/null || true
            ln -s "${skill_src}" "${skill_dst}"
            SKILL_COUNT=$((SKILL_COUNT + 1))
        else
            echo "WARNING: Skill directory not found: ${skill_src}"
        fi
    done

    COPIED=1  # for the summary output (1 rule file)
    echo "  Installed ${SKILL_COUNT} native Cline skills to ${CLINE_SKILLS_DIR}."

else
    # Legacy rules mode: all 10 rules

    # Remove native skills directory if it exists (cleanup from previous native-skills install)
    if [ -d "${CLINE_SKILLS_DIR}" ]; then
        rm -rf "${CLINE_SKILLS_DIR}"
        echo "  Removed previous native skills installation."
    fi

    COPIED=0
    for rule_file in "${RULES_SRC}"/hotl-*.md; do
        [ -f "${rule_file}" ] || continue
        filename="$(basename "${rule_file}")"
        cp "${rule_file}" "${GLOBAL_RULES_DIR}/${filename}"
        COPIED=$((COPIED + 1))
    done

    if [ "${COPIED}" -eq 0 ]; then
        echo "ERROR: No rule files found in ${RULES_SRC}"
        echo "Try re-running: git clone https://github.com/yimwoo/hotl-plugin.git ${HOTL_DIR}"
        exit 1
    fi

    # Replace path placeholders with Unix paths in installed rule copies
    for rule_file in "${GLOBAL_RULES_DIR}"/hotl-*.md; do
        [ -f "${rule_file}" ] || continue
        replace_placeholders "${rule_file}"
    done
fi

# ── Step 3: Install scripts globally to ~/Documents/Cline/Scripts/ ───────────

mkdir -p "${GLOBAL_SCRIPTS_DIR}"

if [ -d "${SCRIPTS_SRC}" ]; then
    for script_file in "${SCRIPTS_SRC}"/*.sh; do
        [ -f "${script_file}" ] || continue
        cp "${script_file}" "${GLOBAL_SCRIPTS_DIR}/"
        chmod +x "${GLOBAL_SCRIPTS_DIR}/$(basename "${script_file}")"
    done
fi

# ── Step 4: Install runtime (hotl-rt) to Scripts directory ────────────────────

if [ -f "${HOTL_DIR}/runtime/hotl-rt" ]; then
    cp "${HOTL_DIR}/runtime/hotl-rt" "${GLOBAL_SCRIPTS_DIR}/hotl-rt"
    chmod +x "${GLOBAL_SCRIPTS_DIR}/hotl-rt"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "HOTL for Cline installed successfully! (mode: ${INSTALL_MODE})"
echo ""
if [ "${INSTALL_MODE}" = "native-skills" ]; then
    echo "  Global rule:    ${GLOBAL_RULES_DIR}/hotl-operating-model.md"
    echo "  Native skills:  ${CLINE_SKILLS_DIR}/ (${SKILL_COUNT} skills)"
else
    echo "  Global skills:  ${HOTL_DIR}/skills/"
    echo "  Global rules:   ${GLOBAL_RULES_DIR}/ (${COPIED} rule files)"
fi
echo "  Global scripts: ${GLOBAL_SCRIPTS_DIR}/"
echo ""
echo "  Mode persisted to ${MODE_FILE}"
echo ""
echo "  Workflows apply to ALL projects in Cline — no per-project setup needed."
echo ""
echo "Available workflows — just tell Cline:"
echo "  \"brainstorm this feature\"     — design with HOTL contracts before coding"
echo "  \"plan the implementation\"     — create docs/plans/YYYY-MM-DD-<slug>-workflow.md"
echo "  \"execute the plan\"            — run the workflow with checkpoints"
echo "  \"subagent execute the plan\"   — delegate reviewed workflow steps in-session"
echo "  \"use TDD\"                     — RED-GREEN-REFACTOR cycle"
echo "  \"debug this\"                  — systematic 4-phase debugging"
echo "  \"review the code\"             — checklist-based code review"
echo ""
echo "Update: bash ${HOTL_DIR}/update.sh"
