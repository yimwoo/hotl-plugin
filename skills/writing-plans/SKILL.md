---
name: writing-plans
description: Use after design approval to create a hotl-workflow-<slug>.md implementation plan with bite-sized tasks, exact file paths, and loop/gate definitions.
---

# Writing HOTL Plans

## Overview

Produce a `hotl-workflow-<slug>.md` file that `loop-execution` can execute. The `<slug>` is a short kebab-case name from the intent (e.g., `hotl-workflow-add-rate-limiting.md`). Each step should be 2-5 minutes of work. Include loop conditions and gates from the design's governance contract.

**Announce:** "I'm using the writing-plans skill to create the implementation plan."

## Output Filename

Save as `hotl-workflow-<slug>.md`, where `<slug>` is a short kebab-case slug derived from the intent (e.g., `hotl-workflow-add-user-auth.md`, `hotl-workflow-refactor-api.md`). The slug prevents conflicts when multiple agents work on the same project simultaneously.

## Output Directory

Default: project root. Opt-in override via `.hotl/config.yml: workflows_dir: <path>`. Resolution procedure:

1. Resolve the install path of `hotl-config-resolve.sh` using the same six-location rule documented for `document-lint.sh` and `hotl-config.sh` (see `skills/document-review/SKILL.md`):
   1. In-repo: `scripts/hotl-config-resolve.sh`
   2. Codex native-skills install: `~/.codex/hotl/scripts/hotl-config-resolve.sh`
   3. Codex plugin install: `~/.codex/plugins/hotl-source/scripts/hotl-config-resolve.sh`
   4. Codex plugin cache fallback: `~/.codex/plugins/cache/codex-plugins/hotl/*/scripts/hotl-config-resolve.sh`
   5. Cline install fallback: `~/.cline/hotl/scripts/hotl-config-resolve.sh`
   6. Claude Code plugin fallback: `~/.claude/plugins/hotl/scripts/hotl-config-resolve.sh`

2. Invoke the resolver as a command proxy — it forwards argv to `hotl-config.sh`, no intermediate path-locator step:

   ```bash
   bash <resolved-hotl-config-resolve.sh> get workflows_dir --default=.
   ```

3. Use the returned directory as the output location. `.` means project root (the unchanged default). Any other value is an opt-in override — write `hotl-workflow-<slug>.md` inside that directory, creating it if needed.

Projects with no `.hotl/config.yml` receive `.` from the `--default=.` fallback — behavior identical to before the config was introduced.

Format:

```markdown
---
intent: [from design's intent contract]
success_criteria: [from design's intent contract]
risk_level: low | medium | high
auto_approve: true | false
# branch: custom/branch-name   # optional — execution derives hotl/<slug> if absent
# worktree: true                # optional — default false, creates git worktree instead of branch checkout
# dirty_worktree: allow         # optional — proceed even if non-HOTL files are uncommitted
---

## Steps

- [ ] **Step N: [Step name]**
action: [what to do]
loop: false | until [condition]
max_iterations: [number, default 3]
verify: [scalar command OR typed block]
gate: human | auto   # optional
```

**CRITICAL — field indentation:** `action:`, `loop:`, `verify:`, `max_iterations:`, and `gate:` MUST start at column 0 (no leading spaces). The document linter matches `^action:`, `^loop:`, etc. — any indentation (even 2 spaces under the list item) will fail validation. Only the sub-fields of structured `verify:` blocks (like `type:`, `path:`, `assert:`) are indented.

## Typed Verification

Choose the appropriate verify type for each step:

- **shell** — for test suites, linters, build commands (default; scalar shorthand accepted)
- **browser** — for UI work requiring visual inspection (capability-gated; falls back to human-review)
- **human-review** — for subjective quality checks with no automated signal
- **artifact** — for verifying files/outputs exist and meet criteria

```yaml
# Scalar shorthand (type: shell)
verify: pytest tests/ -v

# Structured
verify:
  type: browser
  url: http://localhost:3000/dashboard
  check: priority badge renders with correct color

# Artifact with structured assert
verify:
  type: artifact
  path: migrations
  assert:
    kind: matches-glob
    value: "*.sql"

# Greenfield scaffold check
verify:
  type: artifact
  path: src
  assert:
    kind: exists

# Multiple checks per step
verify:
  - type: shell
    command: npm test
  - type: artifact
    path: coverage/lcov.info
    assert:
      kind: exists
```

## Step Granularity

Break work into atomic steps:
- "Write failing test for X" (loop: false, verify: pytest)
- "Implement X" (loop: until tests pass, verify: pytest)
- "Fix lint errors" (loop: until clean, verify: ruff check .)
- "Verify UI renders correctly" (loop: false, verify: type: browser)
- "Human review of security logic" (loop: false, gate: human — REQUIRED for risk_level: high)

## Artifact Verification Rules

- Prefer `kind: exists` when the step creates a new file or directory from scratch
- Use `kind: matches-glob` only when `path` is an existing directory and `value` is a filename glob such as `*.tsx` or `*.md`
- Do not put directory segments in `value`; write `path: src` with `value: "*.tsx"`, not `path: .` with `value: "src/*.tsx"`
- For greenfield frontend scaffolds, Step 1 should usually verify `src` or `package.json` with `kind: exists`, not `matches-glob`

## risk_level Guidelines

- **low:** UI changes, new endpoints, non-critical features
- **medium:** Schema changes, refactors, performance work
- **high:** Auth/authz, encryption, privacy logic, billing, multi-tenant isolation

`risk_level: high` **always** generates `gate: human` on security-sensitive steps, regardless of `auto_approve`.

## Self-Check Loop

After saving the workflow file, run a self-check before offering execution options. Review the plan for:

- **Step sizing** — each step should be 2-5 minutes of atomic work
- **Verify coverage** — every looped step has a verify command that tests what the step claims
- **Gate placement** — risky steps (auth, encryption, billing, secrets) have `gate: human`
- **Loop safety** — `max_iterations` is reasonable (typically 3-5)
- **Ordering** — logical dependencies between steps are respected

If issues are found, fix them in the workflow file and re-check until clean. Do not ask the user to review — this is an internal quality pass.

## After Saving

Once the self-check passes, offer execution options:

**"Plan saved to `hotl-workflow-<slug>.md`. How would you like to execute?"**

Present the three execution modes using the current host tool's native invocation style. Never show Claude Code slash commands in Codex or any other skill-based agent.

Use these mappings:

1. **Loop execution (this session)** — runs steps autonomously with auto-approve
   - **Codex:** ask me to use `$hotl:loop-execution` on `hotl-workflow-<slug>.md`
   - **Claude Code:** `/hotl:loop hotl-workflow-<slug>.md`
2. **Manual execution** — linear execution with explicit checkpoints
   - **Codex:** ask me to use `$hotl:executing-plans` on `hotl-workflow-<slug>.md`
   - **Claude Code:** `/hotl:execute-plan hotl-workflow-<slug>.md`
3. **Subagent execution (this session)** — delegates implementation-friendly steps to fresh subagents while the controller keeps gates and verification
   - **Codex:** ask me to use `$hotl:subagent-execution` on `hotl-workflow-<slug>.md`
   - **Claude Code:** `/hotl:subagent-execute hotl-workflow-<slug>.md`

If a previous run was interrupted, point the user to the host tool's native resume entry point.
- **Codex:** ask me to use `$hotl:resuming` on `hotl-workflow-<slug>.md`
- **Claude Code:** `/hotl:resume hotl-workflow-<slug>.md`
- **Other agents:** use that agent's native skill/command invocation instead of inventing Claude-style slash commands

*(Always tell the user the exact filename so they can pass it to the execution request if multiple workflow files exist.)*
