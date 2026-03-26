#!/usr/bin/env bash
set -euo pipefail

HOTL_DIR="${HOME}/.cline/hotl"
RULES_SRC="${HOTL_DIR}/cline/rules"
SCRIPTS_SRC="${HOTL_DIR}/scripts"
GLOBAL_RULES_DIR="${HOME}/Documents/Cline/Rules"
GLOBAL_SCRIPTS_DIR="${HOME}/Documents/Cline/Scripts"

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

# ── Step 2: Install rules globally to ~/Documents/Cline/Rules/ ───────────────

mkdir -p "${GLOBAL_RULES_DIR}"

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
    sed -i.bak \
        -e "s|__HOTL_HOME__|~/.cline/hotl|g" \
        -e "s|__SCRIPTS_HOME__|~/Documents/Cline/Scripts|g" \
        "${rule_file}"
    rm -f "${rule_file}.bak"
done

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
echo "HOTL for Cline installed successfully!"
echo ""
echo "  Global skills:  ${HOTL_DIR}/skills/"
echo "  Global rules:   ${GLOBAL_RULES_DIR}/ (${COPIED} rule files)"
echo "  Global scripts: ${GLOBAL_SCRIPTS_DIR}/"
echo ""
echo "  Rules apply to ALL projects in Cline — no per-project setup needed."
echo ""
echo "Available workflows — just tell Cline:"
echo "  \"brainstorm this feature\"     — design with HOTL contracts before coding"
echo "  \"plan the implementation\"     — create a hotl-workflow-<slug>.md"
echo "  \"execute the plan\"            — run the workflow with checkpoints"
echo "  \"subagent execute the plan\"   — delegate reviewed workflow steps in-session"
echo "  \"use TDD\"                     — RED-GREEN-REFACTOR cycle"
echo "  \"debug this\"                  — systematic 4-phase debugging"
echo "  \"review the code\"             — checklist-based code review"
echo ""
echo "Update: bash ${HOTL_DIR}/update.sh"
