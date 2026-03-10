## HOTL Subagent Execution

**When to use:** When you have a reviewed `hotl-workflow-<slug>.md` and want same-session execution with delegated subagent steps.

**Full skill:** Read `~/.cline/hotl/skills/subagent-execution/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY

- Run `hotl:document-review` on the workflow file before execution
- Do not continue if document review says `REVISE`
- If document review says `HUMAN_OVERRIDE_REQUIRED`, wait for explicit human approval
- Keep human gates and verify commands in the controller session
- Do not run multiple implementation subagents in parallel against the same workflow

### Process

1. Resolve the workflow file
2. Read the full workflow
3. Review it first
4. For each step in order:
   - decide whether to delegate the step
   - if delegated, use a fresh subagent with the exact step text and relevant context
   - run the step's `verify` command in the controller session
   - obey `loop` and `max_iterations`
   - pause on `gate: human`
5. Mark the checkbox complete only after verify passes
6. Run final verification before claiming done

### Default Delegation Heuristic

- Delegate contained implementation, test, and localized docs steps
- Keep security-sensitive, human-gated, and final verification steps in the controller
