## HOTL Brainstorming

**When to use:** Before any feature work. Design with intent before writing code.

**Full skill:** Read `__HOTL_HOME__/skills/brainstorming/SKILL.md` for the complete process. If unavailable, follow the condensed version below.

### MANDATORY — DO NOT SKIP ANY STEP

You MUST complete ALL steps below in order. Do NOT mark the task as complete after answering questions. Do NOT skip straight to a solution. The brainstorming process has multiple phases and ALL of them are required.

**NEVER claim "Task Completed" until a design doc is saved AND all three contracts are defined.**

### Step 1: Explore context (cheap preflight first)

**Phase 1 — Cheap preflight** (Glob/ls only, current project directory):
- If user's message references a doc path, read it
- Check for canonical design docs in `docs/designs/*.md`
- Check for legacy design docs in `docs/plans/*.md`
- Check for source code, config manifests, or project-specific config files
- **"Relevant context" means:** design docs, source code, configuration manifests, or project-specific config. `README.md`, `.gitignore`, `LICENSE`, and scaffolding boilerplate do **not** count.

**Phase 2 — Branch on result:**
- **Relevant local context found:** Read the most recent 1-2 design docs from canonical or legacy locations, inspect only relevant in-project files, and optionally review recent commits (only if the directory is a git repo).
- **No relevant local context found:** State: "This appears to be a greenfield or effectively empty project, so I'm skipping deep context scanning and moving to clarifying questions." Proceed directly to step 2.

**Hard rule:** Never scan parent directories, sibling folders, or workspace-wide paths unless the user explicitly provides a path.

### Step 2: Determine scope

Decide between `feature`, `phase`, or `initiative` **before** the clarifying-questions loop. Scope shapes every downstream step: output path, contract structure, depth of inquiry.

**Scope choices:**

- **`feature`** — one feature, one bug fix, one refactor. Output: `docs/designs/YYYY-MM-DD-<slug>-design.md` (dated, tactical).
- **`phase`** — one slice of a multi-phase initiative. Same output family as feature: `docs/designs/YYYY-MM-DD-phase-N-<slug>-design.md`.
- **`initiative`** — a multi-phase project (v1/v2, platform migration, enterprise rebuild). Output: `docs/designs/<topic>.md` (undated, durable, strategic).

**Default: feature.** If the user's initial message clearly describes a feature, proceed with `feature` scope without blocking for input. Optionally acknowledge in one line ("Treating as feature scope; say so if this should be a phase or initiative"). Do not pause the flow.

**Ask the scope question explicitly when the request is ambiguous or multi-phase** (e.g., "migrate v1 to v2", "platform rebuild"). Present the three choices with `feature` as the pre-filled default and wait for the user's answer.

**For initiative scope only:**

- Load the strategic-design template. Read `__HOTL_HOME__/adapters/strategic-design.template.md` (the `hotl-plugin` skill directory) and use its section structure (problem, vision, non-goals, stakeholders, architecture, phase breakdown, risks) as the skeleton of the design doc you produce.
- Resolve the output directory: run `bash __HOTL_HOME__/scripts/hotl-config-resolve.sh get designs_dir --default=docs/designs` and use the returned value as the parent directory. Default is `docs/designs` when no `.hotl/config.yml` is present.

### Step 3: Ask clarifying questions — ONE AT A TIME

Ask the user questions to understand purpose, constraints, and success criteria. Ask ONE question, wait for the answer, then ask the next. Keep going until you fully understand the problem. Minimum 2-3 questions.

**Prefer multiple-choice** when the likely answer space is known (e.g., "Which constraints apply? (a) Must not break existing API (b) Backward-compatible (c) Performance-sensitive (d) Other"). Fall back to open-ended only when the problem is unusual or exploratory.

**DO NOT propose solutions yet. You are only gathering information.**

### Step 4: Propose 2-3 approaches

Present 2-3 different approaches with trade-offs for each. Include a recommendation. Wait for the user to pick or refine.

**DO NOT jump to implementation. Wait for the user to approve an approach.**

### Step 5: Present design for approval

Present the chosen approach as a structured design. Get explicit approval from the user before proceeding.

### Step 6: Define all three HOTL contracts

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

### Step 7: Save design doc

Path depends on scope (decided in Step 2):

- `feature` scope: save to `docs/designs/YYYY-MM-DD-<slug>-design.md` (dated, tactical).
- `phase` scope: save to `docs/designs/YYYY-MM-DD-phase-N-<slug>-design.md` (dated, tactical).
- `initiative` scope: save to `<designs_dir>/<topic>.md` (undated, durable), where `<designs_dir>` is the value returned by the Step 2 resolver — default `docs/designs`.

This file MUST exist before moving on.

### Step 8: Self-check the design doc

Before presenting for human approval, review the saved design doc for: missing constraints, vague success criteria, contract mismatches (do verification steps actually test the intent?), risk_level appropriateness, and scope creep. Fix any issues found. Lightweight: 1-2 passes by default, max 3 only if real issues are found. Do not ask the user to review — this is an internal quality pass.

### Step 9: Hand off to writing-plans

For `feature` and `phase` scope, tell the user the design is ready for `writing-plans`, which will create the dated workflow in `docs/plans/`.

For `initiative` scope, do NOT create a workflow file — initiative designs decompose into child phase designs that each go through their own brainstorming → writing-plans cycle.

**ONLY NOW is the brainstorming task complete.**

<HARD-GATE>
Do NOT mark task complete after creating the design doc unless the user has clearly paused there.
For feature/phase scope, you MUST point the user to `writing-plans` as the next step; brainstorming does not directly create the executable workflow.
</HARD-GATE>

### Rules

- NEVER write code during brainstorming — design only
- NEVER mark task complete after just answering questions
- NEVER skip the contracts — all three are required
- NEVER skip the design doc — it must be saved to disk
- One question at a time — prefer multiple-choice when practical
- YAGNI ruthlessly — remove unnecessary features
- Always propose alternatives before settling on an approach
