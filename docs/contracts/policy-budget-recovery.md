# Policy, Budget, and Recovery Contract

HOTL policy is additive to host security. A host sandbox, permission denial, managed setting, or approval requirement always wins when stricter.

## Sensitive actions

Action kinds are `local_write`, `network_read`, `external_write`, `production_change`, and `secret_access`. The last three require a run-bound human decision and durable effect evidence. Empty or reusable blanket targets are not valid action descriptions.

The sensitive lifecycle is `action request --idempotency-key` → human `action decide` → `action begin` → bounded external operation → `action complete`. `action begin` persists intent before the effect. Completion records one of `succeeded`, `failed`, `uncertain`, or `cancelled` with an evidence reference. Approval alone never proves success. If an interruption leaves an effect `in_progress` or `uncertain`, inspect the target and use terminal `action reconcile`; never replay the action blindly. Reusing an idempotency key deduplicates the same bounded action and is rejected for a different target.

## Controller ownership

Driver-managed runs require a renewable controller. `owner claim` returns a one-time raw token; state stores only its hash. The controller retains that token as `HOTL_OWNER_TOKEN`, renews with `owner heartbeat`, and supplies it for every mutation. `owner handoff`, `owner release`, and `owner takeover` are auditable transitions. Age alone never authorizes takeover: an active lease requires explicit human review plus forced takeover, while a stale lease still requires a recorded reason.

## Budgets

Optional workflow fields are `max_total_attempts`, `max_agents`, `max_cost_usd`, and `max_elapsed_minutes`. Attempts and elapsed time are enforced by runtime transitions; external agent and cost observations must be recorded explicitly and cannot decrease. Per-step `max_iterations`, step order, total attempts, and elapsed limits are runtime stops rather than prompt-only advice. A configured limit with unavailable telemetry is `unknown`, not zero or within-budget. Known exceedance pauses a running run and makes its receipt insufficient.

## Recovery

`hotl-rt reconcile <run-id>` is read-only. It evaluates durable state, controller ownership, action decisions and effects, budgets, `ready_to_finish` disposition state, and receipt sufficiency, then returns the narrowest next action. It never trusts a host transcript, background-session notification, or success label and never mutates a run. Host continuation provides scheduling and liveness only.
