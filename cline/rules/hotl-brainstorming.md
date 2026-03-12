## HOTL Brainstorming

**When to use:** Before any feature work. Design with intent before writing code.

**Full skill:** Read `~/.cline/hotl/skills/brainstorming/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY — DO NOT SKIP ANY STEP

You MUST complete ALL 7 steps below in order. Do NOT mark the task as complete after answering questions. Do NOT skip straight to a solution. The brainstorming process has multiple phases and ALL of them are required.

**NEVER claim "Task Completed" until a design doc is saved AND all three contracts are defined.**

### Step 1: Explore context (cheap preflight first)

**Phase 1 — Cheap preflight** (Glob/ls only, current project directory):
- If user's message references a doc path, read it
- Check for `docs/plans/*.md`
- Check for source code, config manifests, or project-specific config files
- **"Relevant context" means:** design docs, source code, configuration manifests, or project-specific config. `README.md`, `.gitignore`, `LICENSE`, and scaffolding boilerplate do **not** count.

**Phase 2 — Branch on result:**
- **Relevant local context found:** Read the most recent 1-2 design docs, inspect only relevant in-project files, and optionally review recent commits (only if the directory is a git repo).
- **No relevant local context found:** State: "This appears to be a greenfield or effectively empty project, so I'm skipping deep context scanning and moving to clarifying questions." Proceed directly to step 2.

**Hard rule:** Never scan parent directories, sibling folders, or workspace-wide paths unless the user explicitly provides a path.

### Step 2: Ask clarifying questions — ONE AT A TIME

Ask the user questions to understand purpose, constraints, and success criteria. Ask ONE question, wait for the answer, then ask the next. Keep going until you fully understand the problem. Minimum 2-3 questions.

**DO NOT propose solutions yet. You are only gathering information.**

### Step 3: Propose 2-3 approaches

Present 2-3 different approaches with trade-offs for each. Include a recommendation. Wait for the user to pick or refine.

**DO NOT jump to implementation. Wait for the user to approve an approach.**

### Step 4: Present design for approval

Present the chosen approach as a structured design. Get explicit approval from the user before proceeding.

### Step 5: Define all three HOTL contracts

You MUST define ALL THREE contracts. Do not skip any.

**Intent Contract:**
```
intent: [one sentence goal]
constraints: [what must not change/break]
success_criteria: [how we know it's done]
risk_level: low | medium | high
```

**Verification Contract:**
```
verify_steps:
  - run tests: [test command]
  - check: [what to inspect]
  - confirm: [success signal]
```

**Governance Contract:**
```
approval_gates: [steps requiring human review]
rollback: [how to undo if something goes wrong]
ownership: [who is accountable]
```

### Step 6: Save design doc

Save the complete design to `docs/plans/YYYY-MM-DD-<topic>-design.md`. This file MUST exist before moving on.

### Step 7: Transition to planning

Ask the user: "Design approved. Ready to create the implementation plan?" Then create a `hotl-workflow-<slug>.md` following the planning rules.

After the workflow file is created, present these execution options:

"Workflow file created. How would you like to execute?"
1. **Loop execution** — autonomous execution with auto-approve for low-risk steps
2. **Checkpoint execution** — linear execution with human review every 3 steps
3. **Subagent execution** — delegated execution with parallel subagents

Do NOT auto-execute. Wait for the user to choose.

**ONLY NOW is the brainstorming task complete.**

### Rules

- NEVER write code during brainstorming — design only
- NEVER mark task complete after just answering questions
- NEVER skip the contracts — all three are required
- NEVER skip the design doc — it must be saved to disk
- One question at a time — do not ask multiple questions in one message
- YAGNI ruthlessly — remove unnecessary features
- Always propose alternatives before settling on an approach
