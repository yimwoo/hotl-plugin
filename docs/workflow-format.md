# Workflow File Format Reference

The workflow file (`hotl-workflow-<slug>.md`) defines work to be executed by the `loop-execution` skill. The `<slug>` is a short kebab-case name derived from the intent (e.g., `hotl-workflow-add-rate-limiting.md`). This naming convention prevents file conflicts when multiple agents work on the same project.

## Frontmatter Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `intent` | string | yes | One sentence describing what this builds |
| `success_criteria` | string | yes | How you know the workflow is done |
| `risk_level` | low\|medium\|high | yes | Determines auto-approve behavior |
| `auto_approve` | boolean | no (default: false) | Skip `gate: human` for non-high-risk steps |
| `branch` | string | no | Override branch name (default: derived as `hotl/<slug>` from workflow filename) |
| `worktree` | true\|false\|host | no (default: true, or host inside an unpinned named linked worktree) | Choose the execution checkout. `true` creates an isolated HOTL worktree, `false` uses the current checkout and may create/switch to the target branch, and `host` uses the current feature branch exactly as provided by the host tool. |
| `progress` | verbose | no | Enable verbose progress view — prints full step list at each step transition |
| `report_detail` | full | no | Include all verify output in the execution report, not just failures |
| `dirty_worktree` | allow | no | Proceed even if non-HOTL files are uncommitted (HOTL artifacts are always excluded automatically) |

## Step Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `action` | string | yes | What to do in this step |
| `loop` | false\|"until [condition]" | yes | Whether to retry |
| `max_iterations` | integer | no (default: 3) | Safety stop for loops |
| `verify` | string \| object \| list | no | How to check success (see Verification Types) |
| `gate` | human\|auto | no | Approval behavior |

## Verification Types

The `verify` field supports 4 types. A scalar string is shorthand for `type: shell`.

### Scalar Shorthand (backward-compatible)

```yaml
verify: pytest tests/
# equivalent to:
verify:
  type: shell
  command: pytest tests/
```

### shell

Run a command and check exit code. Stdout/stderr captured for reporting.

```yaml
verify:
  type: shell
  command: pytest tests/test_rate_limit.py -v
```

### browser

Verify UI behavior via browser tooling. **Capability-gated:** if browser tooling is unavailable, execution downgrades to `human-review` with the `check` text as prompt. Never silently skipped.

```yaml
verify:
  type: browser
  url: http://localhost:3000/dashboard
  check: priority badge is visible with correct color
```

### human-review

Mandatory pause for human inspection. Always pauses regardless of `auto_approve`.

```yaml
verify:
  type: human-review
  prompt: Check that priority colors match the approved design spec
```

### artifact

Verify a file or output exists and meets an assertion.

```yaml
verify:
  type: artifact
  path: migrations
  assert:
    kind: matches-glob
    value: "*.sql"
```

Supported assert kinds:
- `exists` — file or directory at `path` exists (no `value` needed)
- `contains` — file at `path` contains the text in `value`
- `matches-glob` — directory at `path` contains at least one file matching `value` glob
  Use a filename glob such as `*.sql` or `*.md`; do not include directory segments like `src/*` in `value`

### Multiple Checks Per Step

`verify` can be a list. All checks must pass for the step to pass.

```yaml
verify:
  - type: shell
    command: npm test
  - type: browser
    url: http://localhost:3000
    check: login page renders correctly
  - type: artifact
    path: coverage/lcov.info
    assert:
      kind: exists
```

## Auto-Approve Logic

```
if auto_approve: true AND risk_level != high:
  gate: human → auto-approved
else:
  gate: human → pause for human
```

`risk_level: high` always forces human gates regardless of `auto_approve`.

## Branch/Worktree Preflight

Execution skills (loop-execution, executing-plans, subagent-execution) run a branch/worktree preflight **after document review passes** and **before step 1**. This preflight resolves an isolated execution root so work does not land in the wrong checkout or on `main`/`master`.

### Branch Name Derivation

| Scenario | Branch Name |
|---|---|
| `branch: feat/add-auth` in frontmatter | `feat/add-auth` |
| No `branch:`, file is `hotl-workflow-add-auth.md` | `hotl/add-auth` |
| No `branch:`, file is `hotl-workflow-fix-login-timeout.md` | `hotl/fix-login-timeout` |

### Preflight Steps

```
1. Is this a git repo with at least one commit?
   - No  → log "Skipping branch setup (no git history)" → proceed to step 1
   - Yes → continue

2. Check for uncommitted changes
   - Dirty → HARD-FAIL. Show choices:
     a. Clean up manually, then re-run
     b. Stash manually, then re-run
     c. Explicitly approve HOTL to stash and continue
   - Clean → continue

3. Determine branch name
   - If branch: field exists in frontmatter → use it
   - Otherwise → derive hotl/<slug> from hotl-workflow-<slug>.md

4. Capture authoring origin
   - Record the current branch name (if any) and current HEAD commit as the workflow's authoring origin
   - If the current branch is neither `main` nor `master`, and the workflow does not already pin `branch:` or `worktree:`, pause and ask whether to:
     a. continue on the current branch in this checkout (`branch: <current-branch>` + `worktree: false`)
     b. use HOTL's isolated execution branch/worktree (recommended)
     c. use a custom execution branch

5. Determine isolation mode
   - If `worktree: host` → use the current checkout and current feature branch exactly as provided by the host tool; reject `main` and `master`
   - If `worktree: false` → stay in the current checkout and use a dedicated branch there
   - If running inside a named linked git worktree and neither `branch:` nor `worktree:` is set → default to host mode to avoid stacking a second worktree
   - Otherwise → use an isolated git worktree by default

6. Check if the target branch/worktree already exists
   - Current helper behavior: branch/worktree collisions stop with a clear error; interactive reuse/recreate is not implemented yet
   - If a collision occurs, pause and ask the user whether to resolve it manually, delete and recreate manually, or abort
   - Does not exist → create (no prompt)

7. Resolve the execution root with `scripts/hotl-prepare-execution-root.sh <workflow-file> --executor-mode <mode>`
   - Returns JSON with: `branch`, `repo_root`, `execution_root`, `workflow_path`, `source_workflow_path`, `source_branch`, `source_head`, `worktree_path`
   - By default → create a linked git worktree with the branch, copy the current workflow into it, and execute from that worktree
   - If `worktree: false` → create/switch to the dedicated branch in the current checkout and execute from the repo root
   - If `worktree: host` → keep the current branch and execute from the current checkout; if `branch:` is set, it must match the current branch
   - If `branch:` matches the currently checked-out branch while worktree isolation is still enabled, STOP and tell the user to use `worktree: false` or `worktree: host` for same-branch continuity
8. Change into `execution_root`
   - Every later git command, runtime call, helper call, and review command for that run must execute from this directory
```

### Common Branch Scenarios

| Starting checkout | Workflow frontmatter | What HOTL does |
|---|---|---|
| Normal repo on `main` | no `branch`, no `worktree` | Creates a HOTL worktree on derived branch `hotl/<slug>` from current `HEAD` |
| Normal repo on `feature/enhance-worktree` | no `branch`, no `worktree` | Execution skills pause and ask whether to use the current branch, a HOTL worktree, or a custom branch |
| Codex or other linked worktree on `feature/enhance-worktree` | no `branch`, no `worktree` | Uses host mode automatically: executes in the current linked worktree on `feature/enhance-worktree` |
| Any checkout on `main` or `master` | `worktree: host` | Rejected; use `worktree: true` or switch to a feature branch |
| Any checkout | `worktree: true` | Creates a separate HOTL-managed worktree unless the target branch is already checked out |
| Any checkout | `worktree: false` | Uses the current checkout and creates/switches to the target branch if needed |
| Any checkout | `worktree: host` | Uses the current checkout's current branch; `branch:` must be absent or match that branch |

### Design Principles

- **No auto-stash.** Hidden state mutation weakens governance.
- **Existing branch always prompts.** Even at the same HEAD — a branch at the same commit may have different intent.
- **Non-git repos skip entirely.** HOTL works for POCs and new projects without git ceremony.
- **Structural lint runs before any git mutation.** Catches format issues before execution begins.

## Execution State (`.hotl/state/`)

The `hotl-rt` shared runtime (`runtime/hotl-rt`) manages all execution state. Agents call `hotl-rt` subcommands; they do not manage state files directly.

State is persisted in `.hotl/state/<run-id>.json` — the authoritative source of truth for execution progress. The runtime also maintains `.hotl/reports/<run-id>.md` as a durable Markdown report, updated incrementally on each state transition.

Workflow checkboxes (`- [x]`) are a human-visible mirror updated by the agent on step completion. If a chat transcript or native progress card disagrees with the runtime artifacts, trust the artifacts.

**Runtime API:**
```
hotl-rt init <workflow-file> [metadata flags] → creates run, state JSON, report
hotl-rt step <N> start|verify|retry|block     [--run-id <run-id>] → step state transitions
hotl-rt gate <N> approved|rejected            [--run-id <run-id>] → records gate decisions
hotl-rt finalize [--json]                     [--run-id <run-id>] → finalizes run, prints summary
hotl-rt summary <run-id> [--json]             → read-only query
```

**Run ID format:** `<slug>-<YYYYMMDDTHHMMSSZ>` (e.g., `add-auth-20260320T212315Z`) — human-readable, lexicographically sortable, UTC

**Execution-root rule:** after `hotl-rt init` returns a run id, every later runtime/helper call for that run must use the same `execution_root` and the same `run_id`. Do not rely on "latest file in .hotl/state" when multiple runs exist.

**Gitignore:** Add `.hotl/` to your project's `.gitignore` — execution state should not be committed.

## Step Syntax

Preferred syntax uses checkboxes so progress is visible in the workflow file itself:

```markdown
- [ ] **Step 1: Write failing tests**
action: Write tests for rate limit behavior (429 response after N requests)
loop: false
verify: pytest tests/test_rate_limit.py -v
```

Legacy numbered headings are still accepted during transition:

```markdown
### 1. Write failing tests
action: Write tests for rate limit behavior (429 response after N requests)
loop: false
verify: pytest tests/test_rate_limit.py -v
```

## Example

```markdown
---
intent: Add rate limiting to the API
success_criteria: Rate limit tests pass, no existing tests broken
risk_level: low
auto_approve: true
---

## Steps

- [ ] **Step 1: Write failing tests**
action: Write tests for rate limit behavior (429 response after N requests)
loop: false
verify: pytest tests/test_rate_limit.py -v

- [ ] **Step 2: Implement rate limiting**
action: Add rate limiting middleware
loop: until tests pass
max_iterations: 5
verify: pytest tests/test_rate_limit.py -v

- [ ] **Step 3: Full regression check**
action: Run complete test suite
loop: false
verify: pytest -v

- [ ] **Step 4: Final approval**
action: Summarize what was implemented
loop: false
gate: human
```
