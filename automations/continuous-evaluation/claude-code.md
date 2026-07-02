---
template_status: inert
host: claude-code
schedule_kind: desktop_local_task
---

# Claude Code Local Scheduled-Task Template

HOTL does not create a Claude schedule. For campaigns that need local binaries and append-only local evidence, use a Claude Desktop **Local** scheduled task and require explicit human enablement after reviewing its permissions.

Recommended setup:

1. Test the common [`prompt.md`](prompt.md) manually with fake or intentionally approved inputs.
2. In Claude Desktop, open Routines, choose **New routine**, then choose **Local** so the task can access this repository and local host binaries.
3. Paste the common prompt, replace its placeholders, select the repository and cadence, minimize permissions, and review the first runs.
4. Enable only after the campaign preflight, credentials, capture/retention policy, and provider budgets are accepted.

Claude Code's `/loop` is session-scoped and therefore is not the durable template here. The CLI `/schedule` creates a cloud routine, whose fresh clone does not share local append-only evidence. Those surfaces can be used only after an operator deliberately redesigns storage and permissions for them.

Current Claude scheduling guidance: <https://code.claude.com/docs/en/scheduled-tasks> and <https://code.claude.com/docs/en/web-scheduled-tasks>
