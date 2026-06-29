# Policy, Budget, and Recovery Contract

HOTL policy is additive to host security. A host sandbox, permission denial, managed setting, or approval requirement always wins when stricter.

## Sensitive actions

Action kinds are `local_write`, `network_read`, `external_write`, `production_change`, and `secret_access`. The last three require a run-bound human decision before execution. `hotl-rt action request` records intent and pauses; `action decide` records approval or rejection but does not perform the action. Empty or reusable blanket targets are not valid action descriptions.

## Budgets

Optional workflow fields are `max_total_attempts`, `max_agents`, `max_cost_usd`, and `max_elapsed_minutes`. Attempts are derived from state. Other aggregate observations must be recorded explicitly and cannot decrease. A configured limit with unavailable telemetry is `unknown`, not zero or within-budget. Known exceedance pauses a running run and makes its receipt insufficient.

## Recovery

`hotl-rt reconcile <run-id>` is read-only. It evaluates durable state, action decisions, budgets, and receipt sufficiency, then returns the narrowest next action. It never trusts a host transcript or success label and never mutates a run.
