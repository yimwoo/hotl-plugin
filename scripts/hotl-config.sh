#!/usr/bin/env bash
# hotl-config.sh — canonical reader for .hotl/config.yml
#
# Single source of truth for resolving HOTL initiative-support config fields.
# Both markdown skills (via Bash tool) and hotl-rt shell out to this helper —
# no caller parses .hotl/config.yml directly.
#
# Usage:
#   hotl-config.sh get <field> [--default=<value>]
#
# Exit contract (per docs/plans/2026-04-14-slice-1-config-reader-plan.md §2.1 Group A):
#   - field absent, no default          → empty stdout, exit 0
#   - field absent, default provided    → default on stdout, exit 0
#   - field present in .hotl/config.yml → value on stdout, exit 0
#   - malformed config                  → non-zero exit, stderr explains
#   - unknown subcommand                → non-zero exit, usage on stderr

set -euo pipefail

CONFIG_PATH=".hotl/config.yml"

usage() {
    cat >&2 <<'EOF'
usage: hotl-config.sh get <field> [--default=<value>]

Reads .hotl/config.yml from the current working directory and prints the
value of <field> on stdout. Returns the --default value (or empty) when the
field is absent. Always exit 0 unless config is malformed or the subcommand
is unknown.
EOF
}

# Validate config file — basic YAML sanity checks on simple top-level
# string-valued fields. .hotl/config.yml is intentionally a flat key:value
# document; complex YAML constructs are not expected.
validate_config() {
    local file="$1"
    local lineno=0
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        # Skip blank lines and comments
        case "$line" in
            ''|\#*) continue ;;
        esac
        # Strip trailing comments
        local stripped="${line%%#*}"
        # Tolerate indented continuation? No — flat schema only.
        case "$stripped" in
            [[:space:]]*) continue ;;
        esac
        # Must contain a colon
        case "$stripped" in
            *:*) ;;
            *)
                echo "ERROR: malformed config at $file:$lineno (no key:value): $line" >&2
                return 1
                ;;
        esac
        # Detect unterminated flow constructs ([ or { on value side without close)
        local value="${stripped#*:}"
        # Trim leading/trailing whitespace
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        local opens closes
        opens=$(printf '%s' "$value" | tr -cd '[' | wc -c | tr -d ' ')
        closes=$(printf '%s' "$value" | tr -cd ']' | wc -c | tr -d ' ')
        if [ "$opens" != "$closes" ]; then
            echo "ERROR: malformed config at $file:$lineno (unterminated '['): $line" >&2
            return 1
        fi
        opens=$(printf '%s' "$value" | tr -cd '{' | wc -c | tr -d ' ')
        closes=$(printf '%s' "$value" | tr -cd '}' | wc -c | tr -d ' ')
        if [ "$opens" != "$closes" ]; then
            echo "ERROR: malformed config at $file:$lineno (unterminated '{'): $line" >&2
            return 1
        fi
    done < "$file"
    return 0
}

# Read a field's value from the config file. Prints the value on stdout (or
# nothing if the field is absent). Caller must have already validated.
read_field() {
    local file="$1"
    local field="$2"
    local line value
    # Last definition wins (consistent with most YAML loaders for flat keys).
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
            "$field":*)
                value="${line#"$field":}"
                # Strip trailing comments
                value="${value%%#*}"
                # Trim leading/trailing whitespace
                value="${value#"${value%%[![:space:]]*}"}"
                value="${value%"${value##*[![:space:]]}"}"
                # Strip surrounding single or double quotes
                case "$value" in
                    \"*\") value="${value#\"}"; value="${value%\"}" ;;
                    \'*\') value="${value#\'}"; value="${value%\'}" ;;
                esac
                printf '%s\n' "$value"
                return 0
                ;;
        esac
    done < "$file"
    return 0
}

cmd_get() {
    local field=""
    local default=""
    local have_default=0

    if [ $# -eq 0 ]; then
        echo "ERROR: 'get' requires a <field> argument" >&2
        usage
        exit 1
    fi

    field="$1"
    shift

    while [ $# -gt 0 ]; do
        case "$1" in
            --default=*)
                default="${1#--default=}"
                have_default=1
                ;;
            --default)
                if [ $# -lt 2 ]; then
                    echo "ERROR: --default requires a value" >&2
                    exit 1
                fi
                default="$2"
                have_default=1
                shift
                ;;
            *)
                echo "ERROR: unknown argument: $1" >&2
                usage
                exit 1
                ;;
        esac
        shift
    done

    if [ ! -f "$CONFIG_PATH" ]; then
        if [ "$have_default" -eq 1 ]; then
            printf '%s\n' "$default"
        fi
        return 0
    fi

    validate_config "$CONFIG_PATH" || exit 1

    local value
    value="$(read_field "$CONFIG_PATH" "$field")"
    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    elif [ "$have_default" -eq 1 ]; then
        printf '%s\n' "$default"
    fi
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

CMD="$1"
shift

case "$CMD" in
    get)
        cmd_get "$@"
        ;;
    --help|-h|help)
        usage
        exit 0
        ;;
    *)
        echo "ERROR: unknown subcommand: $CMD" >&2
        usage
        exit 1
        ;;
esac
