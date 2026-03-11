#!/usr/bin/env bash
set -euo pipefail

# HOTL Plugin Update Script
# Updates Claude Code, Codex, and Cline installations if present.

FORCE_CODEX=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force-codex)
            FORCE_CODEX=1
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: bash update.sh [--force-codex]" >&2
            exit 1
            ;;
    esac
    shift
done

CLAUDE_PLUGIN_DIR="${HOME}/.claude/plugins/hotl"
CLAUDE_CACHE_DIR="${HOME}/.claude/plugins/cache/hotl-plugin/hotl"
CODEX_HOTL_DIR="${HOME}/.codex/hotl"
CLINE_HOTL_DIR="${HOME}/.cline/hotl"
CLINE_RULES_DIR="${HOME}/Documents/Cline/Rules"

FOUND=0
UPDATED=0
SKIPPED=0

is_git_work_tree() {
    local path="$1"
    [ -e "${path}" ] && git -C "${path}" rev-parse --is-inside-work-tree > /dev/null 2>&1
}

current_branch() {
    git -C "$1" branch --show-current 2>/dev/null || true
}

is_clean_work_tree() {
    local path="$1"
    git -C "${path}" diff --quiet && git -C "${path}" diff --cached --quiet
}

# ── Claude Code ───────────────────────────────────────────────────────────────

if is_git_work_tree "${CLAUDE_PLUGIN_DIR}"; then
    FOUND=$((FOUND + 1))
    echo "Updating Claude Code plugin at ${CLAUDE_PLUGIN_DIR}..."
    git -C "${CLAUDE_PLUGIN_DIR}" pull

    # Refresh plugin cache if it exists
    if [ -d "${CLAUDE_CACHE_DIR}" ]; then
        # Find the cached version directory (e.g., 1.0.0/)
        for CACHE_VER_DIR in "${CLAUDE_CACHE_DIR}"/*/; do
            [ -d "${CACHE_VER_DIR}" ] || continue
            echo "Refreshing plugin cache at ${CACHE_VER_DIR}..."

            # Sync skills
            if [ -d "${CLAUDE_PLUGIN_DIR}/skills" ]; then
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/skills/" "${CACHE_VER_DIR}skills/"
            fi

            # Sync commands
            if [ -d "${CLAUDE_PLUGIN_DIR}/commands" ]; then
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/commands/" "${CACHE_VER_DIR}commands/"
            fi

            # Sync hooks
            if [ -d "${CLAUDE_PLUGIN_DIR}/hooks" ]; then
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/hooks/" "${CACHE_VER_DIR}hooks/"
            fi

            # Sync scripts
            if [ -d "${CLAUDE_PLUGIN_DIR}/scripts" ]; then
                mkdir -p "${CACHE_VER_DIR}scripts/"
                rsync -a --delete "${CLAUDE_PLUGIN_DIR}/scripts/" "${CACHE_VER_DIR}scripts/"
            fi
        done
        echo "  Cache refreshed."
    fi

    UPDATED=$((UPDATED + 1))
    echo "  Claude Code plugin updated."
    echo ""
fi

# ── Codex ─────────────────────────────────────────────────────────────────────

if is_git_work_tree "${CODEX_HOTL_DIR}"; then
    FOUND=$((FOUND + 1))
    CODEX_BRANCH="$(current_branch "${CODEX_HOTL_DIR}")"
    CODEX_BRANCH_DISPLAY="${CODEX_BRANCH:-detached HEAD}"

    if ! is_clean_work_tree "${CODEX_HOTL_DIR}"; then
        echo "Codex install at ${CODEX_HOTL_DIR} has uncommitted changes; skipping update."
        SKIPPED=$((SKIPPED + 1))
        echo ""
    elif [ "${FORCE_CODEX}" -ne 1 ] && [ "${CODEX_BRANCH_DISPLAY}" != "main" ] && [ "${CODEX_BRANCH_DISPLAY}" != "master" ]; then
        echo "Codex install is on branch ${CODEX_BRANCH_DISPLAY}; skipping to avoid mutating a feature branch. Re-run with --force-codex to update anyway."
        SKIPPED=$((SKIPPED + 1))
        echo ""
    else
        echo "Updating Codex plugin at ${CODEX_HOTL_DIR}..."
        git -C "${CODEX_HOTL_DIR}" pull

        if [ -L "${HOME}/.agents/skills/hotl" ]; then
            echo "  Skills symlink intact at ~/.agents/skills/hotl"
        fi

        UPDATED=$((UPDATED + 1))
        echo "  Codex plugin updated."
        echo ""
    fi
fi

# ── Cline ─────────────────────────────────────────────────────────────────────

if is_git_work_tree "${CLINE_HOTL_DIR}"; then
    FOUND=$((FOUND + 1))
    echo "Updating Cline plugin at ${CLINE_HOTL_DIR}..."
    git -C "${CLINE_HOTL_DIR}" pull

    # Refresh global rules
    if [ -d "${CLINE_RULES_DIR}" ] && [ -d "${CLINE_HOTL_DIR}/cline/rules" ]; then
        echo "Refreshing Cline global rules at ${CLINE_RULES_DIR}..."
        for rule_file in "${CLINE_HOTL_DIR}"/cline/rules/hotl-*.md; do
            [ -f "${rule_file}" ] || continue
            cp "${rule_file}" "${CLINE_RULES_DIR}/"
        done
        RULE_COUNT=$(ls "${CLINE_RULES_DIR}"/hotl-*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  ${RULE_COUNT} rule files updated."
    fi

    UPDATED=$((UPDATED + 1))
    echo "  Cline plugin updated."
    echo ""
fi

# ── Result ────────────────────────────────────────────────────────────────────

if [ "$FOUND" -eq 0 ]; then
    echo "No HOTL installations found."
    echo ""
    echo "Install for Claude Code:  bash install.sh"
    echo "Install for Codex:        see .codex/INSTALL.md"
    echo "Install for Cline:        bash install-cline.sh"
    exit 1
fi

echo "Done. ${UPDATED} installation(s) updated."
if [ "$SKIPPED" -gt 0 ]; then
    echo "${SKIPPED} installation(s) skipped."
fi
echo "Restart Codex to re-discover updated HOTL skills."
echo "Restart your Claude Code session or start a new Cline task to use the latest version."
