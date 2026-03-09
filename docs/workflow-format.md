# Workflow File Format Reference

The workflow file (`hotl-workflow-<slug>.md`) defines work to be executed by the `loop-execution` skill. The `<slug>` is a short kebab-case name derived from the intent (e.g., `hotl-workflow-add-rate-limiting.md`). This naming convention prevents file conflicts when multiple agents work on the same project.

## Frontmatter Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `intent` | string | yes | One sentence describing what this builds |
| `success_criteria` | string | yes | How you know the workflow is done |
| `risk_level` | low\|medium\|high | yes | Determines auto-approve behavior |
| `auto_approve` | boolean | no (default: false) | Skip `gate: human` for non-high-risk steps |

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

## Example

```markdown
---
intent: Add rate limiting to the API
success_criteria: Rate limit tests pass, no existing tests broken
risk_level: low
auto_approve: true
---

## Steps

### 1. Write failing tests
action: Write tests for rate limit behavior (429 response after N requests)
loop: false
verify: pytest tests/test_rate_limit.py -v

### 2. Implement rate limiting
action: Add rate limiting middleware
loop: until tests pass
max_iterations: 5
verify: pytest tests/test_rate_limit.py -v

### 3. Full regression check
action: Run complete test suite
loop: false
verify: pytest -v

### 4. Final approval
action: Summarize what was implemented
loop: false
gate: human
```
