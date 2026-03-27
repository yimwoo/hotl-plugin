# Updating HOTL

Use the updater script to refresh any installed HOTL environments.

## Recommended Update Command

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/update.sh | bash
```

This always downloads the latest updater first, then refreshes any installed HOTL environments.

If you already have a fresh local clone of this repo, you can also run:

```bash
bash update.sh
```

The updater scans for supported HOTL installs and updates every one it finds in the
same run. That means a single command can refresh Claude Code, Codex, and Cline
sequentially when you have more than one installed. Tools that are not installed
are skipped automatically.

Supported update targets:

- Claude Code plugin checkout at `~/.claude/plugins/hotl` plus its plugin cache
- Codex native-skills checkout at `~/.codex/hotl`
- Codex plugin source checkout at `~/.codex/plugins/hotl-source` plus the local Codex plugin cache
- Cline checkout at `~/.cline/hotl` plus its synced rules/skills/scripts/runtime

Not supported by `update.sh`:

- Old Codex copied-bundle installs at `~/.codex/plugins/hotl`

If you still have the old copied-bundle Codex plugin install, the updater reports
it and skips it. Migrate with `bash install.sh --codex-plugin` so future updates
can refresh the source checkout instead.

## Manual Update Checks

Use the manual check when you want to verify the installed version without applying an update:

```bash
bash update.sh --check
```

In Claude Code, you can also run:

```text
/hotl:check-update
```

## Update Notifications

HOTL can check for new versions automatically on session start where hook delivery is available.

- Claude Code: best-effort session-start notice
- Codex: treat update checks as manual for now; the current Codex integration is skills-based and does not guarantee a startup notice
- All platforms: manual explicit check is always available

## Codex Stable Channel and Backups

For Codex, the updater treats `~/.codex/hotl` as the stable channel.

- If the install drifted to another branch, the updater switches it back to `main`
- If it finds local changes, it creates a backup under `~/.codex/backups/hotl/<timestamp>/`
- After the backup, it resets the stable install to the latest `origin/main`

Use `--force-codex` only if you intentionally want to discard local Codex changes without creating that backup:

```bash
bash ~/.codex/hotl/update.sh --force-codex
```

Restart Codex after updating so it re-discovers the latest skill files.

## Codex Plugin Install Notes

For Codex plugin installs, `update.sh --codex-plugin` updates the source checkout
at `~/.codex/plugins/hotl-source` and refreshes the local Codex plugin cache
under `~/.codex/plugins/cache/codex-plugins/hotl/` when present. On a fresh
plugin install, HOTL seeds the `local/` cache directory so the cached bundle is
already aligned with the source checkout before restart.
