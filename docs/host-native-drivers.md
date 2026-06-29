# Host-Native Drivers

HOTL includes experimental Codex and Claude Code drivers under `runtime/drivers/`. They preserve the portable workflow, gate, verification, receipt, and finish contracts while allowing a host to own scheduling.

Use `preflight <workflow>` to inspect selection. The default `auto` mode is conservative: an installed executable is not proof of entitlement or enabled native features, so it selects fallback unless `HOTL_CODEX_NATIVE=1` or `HOTL_CLAUDE_NATIVE=1` is explicitly set. `--mode native` is an explicit per-run opt-in; `--mode fallback` always uses `hotl-rt`.

Use `envelope <workflow> --mode native` to produce a model-neutral JSON execution envelope with host feature hints and mandatory HOTL lifecycle rules. This command does not launch a model, edit host settings, authenticate, or make network calls.

Examples:

```bash
runtime/drivers/codex.sh preflight docs/plans/2026-06-29-example-workflow.md
runtime/drivers/codex.sh launch docs/plans/2026-06-29-example-workflow.md --mode native
runtime/drivers/claude.sh envelope docs/plans/2026-06-29-example-workflow.md --mode native
```

Host permissions, sandboxes, managed policy, and approvals remain authoritative. A native host's success display never replaces `hotl-rt receipt <run-id>` sufficiency.
