# HOTL Host Capability Matrix

> Generated from `runtime/capabilities/catalog.json` (schema v1); claims verified 2026-06-29. Do not edit this table by hand.

This matrix separates three different claims:

- **Provider maturity** describes what the provider documents.
- **Local detection** is reported by `scripts/hotl-capabilities.sh probe` and can remain `unknown` even when a host is installed.
- **HOTL support** describes whether HOTL has a conformant implementation, only a candidate native integration, or a fallback.

The Phase 1 catalog is descriptive. It does not select an execution driver or change permissions.

| Host | Capability | Category | Provider maturity | HOTL support | Minimum version | Observability | Availability conditions | Security boundary | Fallback | Verified | Sources |
|---|---|---|---|---|---|---|---|---|---|---|---|
| claude-code | Agent view | automation | research preview | candidate | not specified | partial | Agent view available in the active Claude Code distribution | Background sessions use subscription quota and isolated worktrees when editing. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://code.claude.com/docs/en/agent-view) |
| claude-code | Worktree-isolated sessions | isolation | stable | candidate | not specified | partial | Git repository | Filesystem and command permissions continue to apply inside the isolated checkout. | hotl-fallback:worktree-isolation | 2026-06-29 | [source 1](https://code.claude.com/docs/en/common-workflows#run-parallel-claude-code-sessions-with-git-worktrees) |
| claude-code | Lifecycle hooks | lifecycle | stable | candidate | not specified | full | Hooks not disabled by user or managed settings | Hooks execute with the trust level of the local Claude Code process and must be reviewed as code. | hotl-fallback:durable-state | 2026-06-29 | [source 1](https://code.claude.com/docs/en/hooks) |
| claude-code | Plugin background monitors | lifecycle | stable | candidate | 2.1.105 | full | Interactive CLI with Monitor tool availability<br>Plugin enabled | Monitors run unsandboxed at hook trust level and require careful command review. | hotl-fallback:durable-state | 2026-06-29 | [source 1](https://code.claude.com/docs/en/plugins-reference#monitors) |
| claude-code | Agent teams | orchestration | experimental | candidate | 2.1.32 | partial | Experimental agent teams enabled<br>Task can be partitioned without conflicting shared-file edits | Each teammate is an independent Claude Code session with team coordination tools. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://code.claude.com/docs/en/agent-teams) |
| claude-code | Dynamic workflows | orchestration | research preview | candidate | 2.1.154 | partial | Paid plan or supported API/provider<br>Dynamic workflows enabled where required | Spawned agents inherit the workflow tool allowlist and use accept-edits behavior for file changes. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://code.claude.com/docs/en/workflows) |
| claude-code | Subagents | orchestration | stable | candidate | not specified | partial | Claude Code session with the Agent tool available | Subagent tools, model, permissions, and MCP access are scoped by the agent definition and parent session. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://code.claude.com/docs/en/sub-agents) |
| claude-code | Auto permission mode | security | research preview | candidate | 2.1.83 | partial | Eligible plan and supported model/provider<br>Workspace admin enablement when required | A classifier reviews actions after hard permission rules; auto mode is not a substitute for sensitive-operation review. | hotl-fallback:human-gates | 2026-06-29 | [source 1](https://code.claude.com/docs/en/permission-modes#eliminate-prompts-with-auto-mode) |
| codex | Automations | automation | stable | candidate | not specified | partial | Codex app<br>Automation availability for the active account and workspace | Automation runs use the configured project permissions and workspace policy. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://developers.openai.com/codex/app/automations) |
| codex | Browser Developer mode | browser | stable | candidate | not specified | full | Codex app Browser or Chrome integration<br>Full CDP access enabled and allowed by workspace policy | Full CDP inspection requires explicit approval and can be disabled by managed policy. | hotl-fallback:typed-verification | 2026-06-29 | [source 1](https://developers.openai.com/codex/app/browser#developer-mode) |
| codex | Managed worktrees | isolation | stable | candidate | not specified | partial | Git repository<br>Codex app or supported local surface | Filesystem access remains bounded by the active Codex permissions. | hotl-fallback:worktree-isolation | 2026-06-29 | [source 1](https://developers.openai.com/codex/app/worktrees) |
| codex | Lifecycle hooks | lifecycle | stable | candidate | not specified | full | Hooks feature enabled<br>Non-managed hook definition reviewed and trusted | Non-managed command hooks require hash-based user trust before execution. | hotl-fallback:durable-state | 2026-06-29 | [source 1](https://developers.openai.com/codex/hooks) |
| codex | Memories | memory | stable | candidate | not specified | partial | Memories available for the active account<br>Memory use or generation enabled | Memory use follows account, workspace, and per-thread controls. | none | 2026-06-29 | [source 1](https://developers.openai.com/codex/memories) |
| codex | Goal mode | orchestration | stable | candidate | not specified | partial | Codex app, CLI, or IDE extension<br>May require the goals feature flag when not visible | Uses the active Codex sandbox and approval policy. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://developers.openai.com/codex/prompting#goal-mode) |
| codex | Subagents | orchestration | stable | candidate | not specified | partial | Enabled by default in current Codex releases<br>Spawned only after an explicit user request | Subagents inherit parent sandbox and live approval overrides. | hotl-fallback:workflow-execution | 2026-06-29 | [source 1](https://developers.openai.com/codex/subagents) |
| codex | Native code review | review | stable | candidate | not specified | partial | Git repository with a reviewable diff, commit, or base branch | Review is read-oriented unless the user separately authorizes fixes. | hotl-fallback:reporting | 2026-06-29 | [source 1](https://developers.openai.com/codex/app/review) |
| hotl-fallback | HOTL worktree isolation | isolation | stable | conformant | 2.18.0 | full | Git repository with at least one commit | Protected branches, dirty worktrees, and branch collisions stop according to HOTL preflight rules. | none | 2026-06-29 | [source 1](https://github.com/yimwoo/hotl-plugin/blob/main/docs/workflow-format.md#branchworktree-preflight) |
| hotl-fallback | HOTL workflow execution | orchestration | stable | conformant | 2.18.0 | full | HOTL runtime or inline executor available | Uses the active host's shell sandbox and approval boundary. | none | 2026-06-29 | [source 1](https://github.com/yimwoo/hotl-plugin/blob/main/docs/workflow-format.md) |
| hotl-fallback | Durable run state | persistence | stable | conformant | 2.18.0 | full | jq installed | State remains local under the execution root and is gitignored by default. | none | 2026-06-29 | [source 1](https://github.com/yimwoo/hotl-plugin/blob/main/docs/workflow-format.md#execution-state-hotlstate) |
| hotl-fallback | Durable execution reporting | review | stable | conformant | 2.18.0 | full | jq installed for state-managed reporting | Reports default to concise successful output and captured failure evidence. | none | 2026-06-29 | [source 1](https://github.com/yimwoo/hotl-plugin/blob/main/docs/contracts/execution-report-output.md) |
| hotl-fallback | Risk-sensitive human gates | security | stable | conformant | 2.18.0 | full | Interactive controller available for human gates | High-risk human gates cannot be auto-approved. | none | 2026-06-29 | [source 1](https://github.com/yimwoo/hotl-plugin/blob/main/docs/workflow-format.md#auto-approve-logic) |
| hotl-fallback | Typed verification | verification | stable | conformant | 2.18.0 | full | HOTL runtime available<br>Required verifier capability available or human fallback accepted | Verification commands run inside the active host shell boundary. | none | 2026-06-29 | [source 1](https://github.com/yimwoo/hotl-plugin/blob/main/docs/workflow-format.md#verification-types) |

## HOTL support states

- `candidate`: provider capability identified for a future native adapter; no HOTL conformance claim yet.
- `experimental`: a HOTL integration exists but is opt-in and not yet conformant.
- `conformant`: deterministic HOTL contract scenarios pass for the implementation.
- `fallback_only`: HOTL deliberately uses a generic fallback rather than a native integration.
- `unsupported`: HOTL has no safe native or fallback path for the capability.
- `deprecated`: the integration remains visible only for migration.

## Interpretation rules

- An installed executable does not prove plan entitlement, rollout availability, administrator enablement, or usable permissions.
- Preview and experimental capabilities remain opt-in even when locally detected.
- `unknown` is an evidence-preserving result, not an error and not a synonym for unavailable.
- Host security controls remain authoritative when they are stricter than HOTL policy.
- Relevant catalog rows must be refreshed from official sources when a driver or support claim changes.
