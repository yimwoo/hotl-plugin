#!/usr/bin/env bash
set -euo pipefail

# HOTL Plugin Update Script
# Updates Claude Code, Codex, and Cline installations if present.

CLAUDE_PLUGIN_DIR="${HOME}/.claude/plugins/hotl"
CLAUDE_CACHE_DIR="${HOME}/.claude/plugins/cache/hotl-plugin/hotl"
CODEX_HOTL_DIR="${HOME}/.codex/hotl"
CLINE_HOTL_DIR="${HOME}/.cline/hotl"
CLINE_RULES_DIR="${HOME}/Documents/Cline/Rules"

UPDATED=0

# ── Claude Code ───────────────────────────────────────────────────────────────

if [ -d "${CLAUDE_PLUGIN_DIR}/.git" ]; then
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

if [ -d "${CODEX_HOTL_DIR}/.git" ]; then
    echo "Updating Codex plugin at ${CODEX_HOTL_DIR}..."
    git -C "${CODEX_HOTL_DIR}" pull

    # Refresh skills symlink target if using ~/.agents/skills/hotl
    if [ -L "${HOME}/.agents/skills/hotl" ]; then
        echo "  Skills symlink intact at ~/.agents/skills/hotl"
    fi

    UPDATED=$((UPDATED + 1))
    echo "  Codex plugin updated."
    echo ""
fi

# ── Cline ─────────────────────────────────────────────────────────────────────

if [ -d "${CLINE_HOTL_DIR}/.git" ]; then
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

if [ "$UPDATED" -eq 0 ]; then
    echo "No HOTL installations found."
    echo ""
    echo "Install for Claude Code:  bash install.sh"
    echo "Install for Codex:        see .codex/INSTALL.md"
    echo "Install for Cline:        bash install-cline.sh"
    exit 1
fi

echo "Done. ${UPDATED} installation(s) updated."
echo "Restart your Claude Code session or start a new Cline task to use the latest version."
