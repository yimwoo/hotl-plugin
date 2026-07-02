---
template_status: inert
host: codex
schedule_kind: project_automation
---

# Codex Project-Automation Template

HOTL does not install or enable this automation. Codex project automations are created from the Automations pane or by asking Codex to create one; the operator must make the final schedule and enablement decision.

Recommended setup:

1. Test the common [`prompt.md`](prompt.md) manually in a normal thread with fake or intentionally approved inputs.
2. Create a standalone project automation in the Codex app and select this repository.
3. Use local-project execution so append-only `.hotl` history persists. The prompt writes only evaluation evidence beneath the reviewed output root; review this trade-off before enabling it.
4. Paste the common prompt, replace its placeholders, choose the cadence, model, reasoning effort, and workspace-write sandbox deliberately, and review the first runs in Triage.
5. Enable only after the campaign preflight, credentials, capture/retention policy, and provider budgets are accepted.

The repository contains no `automation.toml`, writes nothing under `~/.codex/automations`, and performs no automation registration during installation.

Current Codex guidance: <https://developers.openai.com/codex/app/automations>
