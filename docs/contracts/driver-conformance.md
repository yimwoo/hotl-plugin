# HOTL Driver Conformance Contract

This contract defines the normalized behavioral outcomes every HOTL execution implementation must preserve. The generic `hotl-rt` path is the Phase 1 reference implementation. Future native Codex, Claude Code, or other drivers may schedule and render work differently, but they must produce equivalent governed outcomes and evidence.

## Conformance boundary

Conformance applies to portable HOTL semantics:

- Workflow identity, intent, risk, steps, verification requirements, and gates.
- Lint-before-mutation ordering and safe execution-root selection.
- Step states, attempts, verification outcomes, block reasons, and approval decisions.
- Explicit run targeting when more than one run exists.
- Durable state, report discoverability, final summary, and finish disposition.
- Verify-first recovery rather than silently advancing an interrupted step.

Host-native progress cards, background-task panels, command names, and other presentation details are not required to be byte-identical. A driver can use them only when the normalized HOTL outcome remains observable and durable.

## Required normalized outcomes

| Outcome | Required meaning |
|---|---|
| `completed` | Every required step passed verification or received an accepted gate decision; required evidence is present |
| `paused` | Work cannot advance without a human decision or host capability; no later step has started |
| `blocked` | A failed check, denied gate, exhausted retry, invalid capability, or safety condition prevents completion |
| `running` | At least one step is in progress and no terminal outcome has been recorded |

A driver must never translate missing evidence, an unknown host result, a lost session, or a rejected action into `completed`.

## Invariant families

### Workflow resolution and preflight

- Canonical and supported legacy workflow paths resolve deterministically.
- Structural lint succeeds before branch, worktree, or source mutation.
- Dirty files, protected branches, detached heads, and worktree collisions follow the documented stop conditions.
- The resolved execution root and source identity remain attached to the run.

### Verification and retries

- Shell, artifact, browser, human-review, and multi-check semantics retain their documented meaning.
- Unsupported verification blocks clearly instead of being skipped.
- Failed verification cannot complete a step.
- Retry increments attempts, preserves the failure trail, and stops at the declared bound.

### Gates and risk

- Human-review verification always pauses for a decision.
- Rejection remains terminal unless a later, explicit recovery flow is authorized.
- Low- and medium-risk human gates may be auto-approved only when the workflow allows it.
- High-risk human gates cannot be auto-approved.

### Identity, persistence, and recovery

- Every state-changing operation targets one immutable run identity.
- Multiple matching runs require explicit selection.
- Recovery locates state across supported worktrees and re-verifies the interrupted step before advancing.
- Missing or partially observed native-host state reconciles to `paused` or `blocked`, not inferred success.

### Reporting and finish

- State transitions update the durable report before equivalent live UI claims.
- The final summary includes every step and its normalized status and attempts.
- Failure, block, pause, and completion responses identify the durable report.
- Merge, publish, keep, and discard are explicit finish outcomes rather than implicit cleanup.

### Executor profiles

Loop, manual, and delegated execution may differ in autonomy and scheduling. They share the same verification, gate, report, recovery, and completion authority. A delegated worker report is evidence input, not proof of completion by itself.

## Scenario manifest

`test/fixtures/conformance/scenarios.json` is the machine-readable index of baseline scenario families. Each scenario contains:

- A stable scenario identity and invariant summary.
- The expected terminal outcome.
- One or more exact Bats tests that provide deterministic evidence.
- An explicit `gap` value. A gap requires a non-empty reason and remains visible until a later phase adds coverage.

The manifest does not duplicate test logic. It maps portable contract requirements to the repository tests that already enforce them.

## Driver acceptance

A future driver is conformant only when it can map its native events into the normalized outcomes above and pass the scenario corpus applicable to its supported capabilities. Unsupported optional capabilities may use a documented fallback. Required policy, gate, or verification semantics may not be downgraded silently.
