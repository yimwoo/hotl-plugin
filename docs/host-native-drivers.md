# Host-Native Drivers

HOTL includes experimental Codex and Claude Code drivers under `runtime/drivers/`. They preserve portable controller ownership, workflow, gate, effect, budget, verification, receipt, and finish contracts while allowing a host to assist with scheduling.

Use `preflight <workflow>` to inspect selection. The default `auto` mode is conservative: an installed executable is not proof of entitlement or enabled native features, so it selects fallback unless `HOTL_CODEX_NATIVE=1` or `HOTL_CLAUDE_NATIVE=1` is explicitly set. `--mode native` is an explicit per-run opt-in; `--mode fallback` always uses `hotl-rt`.

Use `envelope <workflow> --mode native` to produce a model-neutral JSON execution envelope with host feature hints and mandatory HOTL lifecycle rules. This command does not launch a model, edit host settings, authenticate, or make network calls.

Current envelopes describe stable Codex Goal mode, automations, hooks, and thread handoff and stable Claude Code goal/loop continuation plus background subagents. These features provide scheduling and liveness only; they are never completion authority. Claude Code agent view and other preview/experimental surfaces remain opt-in. Every launch initializes ownership-required state, and the controller must claim and heartbeat before mutations.

Examples:

```bash
runtime/drivers/codex.sh preflight docs/plans/2026-06-29-example-workflow.md
runtime/drivers/codex.sh launch docs/plans/2026-06-29-example-workflow.md --mode native
runtime/drivers/claude.sh envelope docs/plans/2026-06-29-example-workflow.md --mode native
```

Host permissions, sandboxes, managed policy, and approvals remain authoritative. A native host's success display never replaces HOTL state or `hotl-rt receipt <run-id>` sufficiency. Successful `finalize` means `ready_to_finish`; explicit `finish` is still required for `completed`.
