#!/usr/bin/env bash
# hotl-init-initiative.sh — scaffolder for multi-phase initiative support
#
# Opt-in scaffolder invoked by the setup-project skill when the user
# answers yes to the initiative-support question. Writes .hotl/config.yml
# with taxonomy: initiative, creates the six docs/<tier>/ directories, and
# renders four outputs in docs/prompts/ per the Slice 5 plan §1:
#
#   adapters/strategic-design.template.md       → docs/prompts/design-doc-template.md
#   adapters/tactical-plan.template.md          → docs/prompts/plan-template.md
#   adapters/initiative-playbook.template.md    → docs/prompts/<slug>-playbook.md
#   adapters/initiative-operating-model.template.md → docs/prompts/<slug>-operating-model.md
#
# The two per-initiative instances have {{INITIATIVE_NAME}} replaced with
# <slug> and {{DATE}} replaced with today's UTC date.
#
# Usage:
#   hotl-init-initiative.sh --name <slug>
#
# Per docs/plans/2026-04-14-slice-5-setup-scaffolder-plan.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat >&2 <<'EOF'
usage: hotl-init-initiative.sh --name <slug>

Scaffolds the multi-phase initiative-support taxonomy into the current
working directory. Requires a kebab-case initiative slug.

  --name <slug>   Required. Must match [a-z0-9][a-z0-9-]*.

Behavior:
  - Refuses when .hotl/config.yml already exists.
  - Creates .hotl/config.yml with taxonomy: initiative.
  - Creates docs/{designs,plans,decisions,requirements,reviews,prompts}/.
  - Renders four outputs in docs/prompts/. Any of the four that already
    exist is left byte-for-byte unchanged and a SKIP: line is emitted.
    Unrelated docs/prompts/*.md files are neither read nor touched.
EOF
}

# ── Argument parsing ────────────────────────────────────────────────────────

SLUG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --name)
            if [ $# -lt 2 ]; then
                echo "ERROR: --name requires a value" >&2
                usage
                exit 1
            fi
            SLUG="$2"
            shift 2
            ;;
        --name=*)
            SLUG="${1#--name=}"
            shift
            ;;
        --help|-h|help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ -z "$SLUG" ]; then
    echo "ERROR: --name <slug> is required" >&2
    usage
    exit 1
fi

# Validate slug — kebab-case, starts with letter or digit, no uppercase.
if ! printf '%s' "$SLUG" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
    echo "ERROR: --name must match [a-z0-9][a-z0-9-]* (got: '$SLUG')" >&2
    exit 1
fi

# ── Resolve adapters/ via the six-location install-path order ───────────────

resolve_adapters_dir() {
    # 1. Test-only override.
    if [ -n "${HOTL_INSTALL_OVERRIDE:-}" ]; then
        if [ -d "$HOTL_INSTALL_OVERRIDE/hotl/adapters" ]; then
            echo "$HOTL_INSTALL_OVERRIDE/hotl/adapters"
            return 0
        fi
    fi

    # 2. In-repo sibling (scripts/../adapters/).
    if [ -d "$SCRIPT_DIR/../adapters" ]; then
        (cd "$SCRIPT_DIR/../adapters" && pwd)
        return 0
    fi

    # 3–7. Documented install locations, in priority order (mirroring the
    #      document-lint.sh resolution list).
    local candidates=(
        "$HOME/.codex/hotl/adapters"
        "$HOME/.codex/plugins/hotl-source/adapters"
    )
    # Codex plugin cache fallback uses a glob. When no match exists the shell
    # leaves the literal path containing '*' in place — the subsequent
    # `[ -d "$cached" ]` then returns non-zero and the candidate is silently
    # skipped, which is the intended fall-through behavior.
    for cached in "$HOME"/.codex/plugins/cache/codex-plugins/hotl/*/adapters; do
        [ -d "$cached" ] && candidates+=("$cached")
    done
    candidates+=(
        "$HOME/.cline/hotl/adapters"
        "$HOME/.claude/plugins/hotl/adapters"
    )

    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# ── Refuse when .hotl/config.yml already exists ─────────────────────────────

if [ -e ".hotl/config.yml" ]; then
    echo "ERROR: .hotl/config.yml already exists in this repo." >&2
    echo "       The scaffolder refuses to overwrite existing config." >&2
    echo "       Delete or edit .hotl/config.yml manually if you need to reinitialize." >&2
    exit 1
fi

# ── Resolve adapters before touching any files ──────────────────────────────

ADAPTERS_DIR=$(resolve_adapters_dir) || {
    echo "ERROR: could not resolve the adapters/ directory in any install location." >&2
    echo "       Tried in order: HOTL_INSTALL_OVERRIDE, scripts/../adapters," >&2
    echo "       ~/.codex/hotl/adapters, ~/.codex/plugins/hotl-source/adapters," >&2
    echo "       ~/.codex/plugins/cache/codex-plugins/hotl/*/adapters," >&2
    echo "       ~/.cline/hotl/adapters, ~/.claude/plugins/hotl/adapters." >&2
    exit 1
}

for tmpl in \
    strategic-design.template.md \
    tactical-plan.template.md \
    initiative-playbook.template.md \
    initiative-operating-model.template.md; do
    if [ ! -f "$ADAPTERS_DIR/$tmpl" ]; then
        echo "ERROR: adapter template missing: $ADAPTERS_DIR/$tmpl" >&2
        exit 1
    fi
done

# ── Create .hotl/config.yml and docs/<tier>/ directories ────────────────────

mkdir -p .hotl
cat > .hotl/config.yml <<'YAML'
# HOTL plugin configuration — initiative-support taxonomy enabled.
# Generated by scripts/hotl-init-initiative.sh. Edit freely; the plugin
# re-reads this file on demand.
taxonomy: initiative
YAML

for dir in \
    docs/designs \
    docs/plans \
    docs/decisions \
    docs/requirements \
    docs/reviews \
    docs/prompts; do
    mkdir -p "$dir"
done

# ── Render the four outputs into docs/prompts/ ──────────────────────────────

render_generic() {
    local src="$1"
    local dest="$2"
    if [ -e "$dest" ]; then
        echo "SKIP: $dest (already exists — preserved byte-for-byte)"
        return 0
    fi
    cp "$src" "$dest"
}

render_per_initiative() {
    local src="$1"
    local dest="$2"
    if [ -e "$dest" ]; then
        echo "SKIP: $dest (already exists — preserved byte-for-byte)"
        return 0
    fi
    local today
    today=$(date -u +%Y-%m-%d)
    sed \
        -e "s|{{INITIATIVE_NAME}}|${SLUG}|g" \
        -e "s|{{DATE}}|${today}|g" \
        "$src" > "$dest"
}

render_generic \
    "$ADAPTERS_DIR/strategic-design.template.md" \
    "docs/prompts/design-doc-template.md"

render_generic \
    "$ADAPTERS_DIR/tactical-plan.template.md" \
    "docs/prompts/plan-template.md"

render_per_initiative \
    "$ADAPTERS_DIR/initiative-playbook.template.md" \
    "docs/prompts/${SLUG}-playbook.md"

render_per_initiative \
    "$ADAPTERS_DIR/initiative-operating-model.template.md" \
    "docs/prompts/${SLUG}-operating-model.md"

echo ""
echo "Initiative support scaffolded for: $SLUG"
echo "  Config:      .hotl/config.yml (taxonomy: initiative)"
echo "  Directories: docs/{designs,plans,decisions,requirements,reviews,prompts}/"
echo "  Templates:   docs/prompts/"
echo "    - design-doc-template.md     (generic reference)"
echo "    - plan-template.md           (generic reference)"
echo "    - ${SLUG}-playbook.md        (per-initiative)"
echo "    - ${SLUG}-operating-model.md (per-initiative)"
echo ""
echo "Next: edit docs/designs/${SLUG}.md via /hotl:brainstorm (scope: initiative)."
