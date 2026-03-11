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
| `worktree` | boolean | no (default: false) | Create a git worktree instead of switching the current directory |

## Step Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `action` | string | yes | What to do in this step |
| `loop` | false\|"until [condition]" | yes | Whether to retry |
| `max_iterations` | integer | no (default: 3) | Safety stop for loops |
| `verify` | string | no | Command to run to check success |
| `gate` | human\|auto | no | Approval behavior |

## Auto-Approve Logic

```
if auto_approve: true AND risk_level != high:
  gate: human → auto-approved
else:
  gate: human → pause for human
```

`risk_level: high` always forces human gates regardless of `auto_approve`.

## Branch/Worktree Preflight

Execution skills (loop-execution, executing-plans, subagent-execution) run a branch/worktree preflight **after document review passes** and **before step 1**. This preflight creates an isolated branch so work does not land directly on main/master.

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

4. Check if branch already exists
   - Exists, same HEAD    → ask: reuse, delete+recreate, or abort
   - Exists, different HEAD → ask: delete+recreate, or abort
   - Does not exist        → create (no prompt)

5. Create branch/worktree
   - If worktree: true → create git worktree with the branch
   - Otherwise → create branch and checkout in current directory
```

### Design Principles

- **No auto-stash.** Hidden state mutation weakens governance.
- **Existing branch always prompts.** Even at the same HEAD — a branch at the same commit may have different intent.
- **Non-git repos skip entirely.** HOTL works for POCs and new projects without git ceremony.
- **Document review runs before any git mutation.** Why create a branch for a plan that might be rejected?

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
