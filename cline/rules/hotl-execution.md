## HOTL Execution

**When to use:** When you have a `hotl-workflow-<slug>.md` to execute.

**Full skills:** Read `~/.cline/hotl/skills/executing-plans/SKILL.md` (linear), `~/.cline/hotl/skills/loop-execution/SKILL.md` (autonomous), or `~/.cline/hotl/skills/subagent-execution/SKILL.md` (delegated same-session execution) for complete processes. If unavailable, follow the condensed version below.

### MANDATORY RULES

- **NEVER skip steps.** Execute every step in order.
- **NEVER skip verification.** Run the verify command for every step.
- **NEVER claim a step passed if verify failed.** Report the failure and retry or stop.
- **NEVER mark task complete without running ALL verify commands.**

### Workflow Resolution

1. If the user specifies a filename → use it
2. Else look for `hotl-workflow-*.md` in project root:
   - One match → use it
   - Multiple → list and ask user to pick
   - None → ask if they want to create one

### Execution Process

For each step in the workflow:

1. **Announce:** "Step N: [name]"
2. **Execute** the action
3. **Run verify command** — show the actual output
4. **If verify passes:** Log "Done — Step N: [name]" and continue
5. **If verify fails AND loop is set:** Retry up to max_iterations. Show each attempt.
6. **If verify fails AND max_iterations reached:** STOP. Show the output. Ask the user what to do.
7. **If gate: human:** STOP. Show what was done. Ask "Continue?" Wait for response.

### After Each 3 Steps — Checkpoint

After every 3 completed steps, pause and show:
- Summary of what was done
- What's coming next
- Ask: "Continue with next batch?"

### Safety Rules

- `risk_level: high` ALWAYS requires human approval at gates, even with `auto_approve: true`
- NEVER skip gates on security-sensitive steps (auth, encrypt, secret, password, token, billing)
- On failure: show the actual verify output — do not summarize or hide errors

### When All Steps Complete

Show a summary table of all steps with status. Then run a final verification:
- Run the test suite
- Run the linter
- Confirm the success criteria from the intent contract are met
- Show evidence — NEVER claim success without proof

**ONLY THEN mark the task as complete.**
