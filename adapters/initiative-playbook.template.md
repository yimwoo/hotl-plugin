# {{INITIATIVE_NAME}} — Session Playbook

**Purpose.** A ready-to-use prompt library for every session that advances `{{INITIATIVE_NAME}}` from kickoff through the final phase. Copy the prompt for the session you are about to start — each prompt is self-contained and tells the code agent what to read, what role to take, and what artifact to produce.

**Agent-neutral.** Works with Claude Code, Codex, Cline, Cursor, and Copilot. Prompt content does not change across agents; only how you dispatch them differs.

**Related.**

- Parent strategic design: `docs/designs/{{INITIATIVE_NAME}}.md`
- Operating model for this initiative: `docs/prompts/{{INITIATIVE_NAME}}-operating-model.md`
- Executable workflows produced by these sessions: `docs/plans/YYYY-MM-DD-<slug>-workflow.md`

---

## §0. Session discipline — new session vs. same context

Session discipline is the single biggest lever on artifact quality. A fresh session reading a well-written design doc or workflow outperforms a long chat that drifted.

**Always start a new session when:**

- Moving to a new phase
- Switching roles (e.g., `@pm` → `@architect` → `@dev`)
- Switching skills (e.g., `brainstorming` → `writing-plans` → `executing-plans`)
- The previous session produced a committed artifact and the next one will read it
- Context usage crosses ~40% (check and restart before ~60%)
- The current conversation has drifted into exploratory tangents or abandoned attempts

**Continue in the same context only when:**

- Iterating on the same artifact within the same role (e.g., refining code after a failing test)
- The task is one logical unit of work and restart would lose nothing but gain nothing

**Rule of thumb.** If the next step has a different goal or a different role, it is a new session. Your design docs, ADRs, requirements docs, and workflow docs are the continuity layer — they carry state across sessions far better than a single long chat.

Expect roughly **{{N}} sessions total** across the initiative. That is correct and healthy.

---

## §1. The repeating per-phase pattern

Every phase follows the same cycle. Each step is one session.

```
  1. @pm                → docs/requirements/phase-N-{{slug}}.md       (if phase has user-facing scope)
  2. brainstorming      → docs/designs/YYYY-MM-DD-phase-N-<slug>-design.md (tactical, per phase)
  3. @architect         → docs/decisions/NNN-{{slug}}.md              (ADR — only when a decision is expensive to reverse)
  4. writing-plans      → docs/plans/YYYY-MM-DD-<slug>-workflow.md    (executable decomposition)
  5. @dev               → source code and tests                       (one session per workflow step)
  6. @reviewer          → review memo in docs/reviews/                (gate before merge)
```

The parent strategic design at `docs/designs/{{INITIATIVE_NAME}}.md` is created once before phase execution begins. Steps 1 and 3 are optional per phase — see per-phase guidance below for which to run.

---

## §2. Global Session 0 — kickoff and alignment

**Run this once, before any phase.** Output: a review memo and a reaction plan.

```
Read, in this order:
  - docs/designs/{{INITIATIVE_NAME}}.md (full)
  - Any prior ADRs in docs/decisions/ that constrain this initiative
  - Top-level source layout (ls only; then read the module entry points)

Then produce docs/reviews/{{INITIATIVE_NAME}}-kickoff-review.md with:

1. Summary in your own words: how the new initiative fits on top of the
   existing system. Name every module it reuses vs. extends vs. leaves
   untouched.
2. Inconsistencies or gaps between the design and the current codebase.
3. Three concrete risks in the phased rollout that the design underweights.
4. Recommended adjustments to phase ordering, if any.
5. A checklist of prerequisites before Phase 1 can start (missing fixtures,
   missing schema, feature flags, etc.).

Do not write any code. Do not modify any doc other than the review memo.
```

After this session: read the memo. Update the design doc or open a new ADR if the review surfaced real issues. Only then move to Phase 1.

---

## §2.5. Per-phase kickoff workflow — `workflows/phase-kickoff.md`

Every new phase of `{{INITIATIVE_NAME}}` can be started via the reusable HOTL workflow `workflows/phase-kickoff.md` (shipped with the plugin). It automates the three-step kickoff — **review → triage → requirements** — with a human gate after each step. Output artifacts land in `docs/reviews/` and `docs/requirements/`, giving the per-phase brainstorming session its input.

**Resolve the workflow template** via the same six-location install-path order as `document-lint.sh` and the other HOTL helpers (see `skills/document-review/SKILL.md`):

1. In-repo: `workflows/phase-kickoff.md`
2. Codex native-skills install: `~/.codex/hotl/workflows/phase-kickoff.md`
3. Codex plugin install: `~/.codex/plugins/hotl-source/workflows/phase-kickoff.md`
4. Codex plugin cache fallback: `~/.codex/plugins/cache/codex-plugins/hotl/*/workflows/phase-kickoff.md`
5. Cline install fallback: `~/.cline/hotl/workflows/phase-kickoff.md`
6. Claude Code plugin fallback: `~/.claude/plugins/hotl/workflows/phase-kickoff.md`

**Usage:**

1. Copy the resolved template to `docs/plans/YYYY-MM-DD-{{INITIATIVE_NAME}}-phase-N-kickoff-workflow.md` (substitute a real date and phase number).
2. Replace every `{{SLUG}}` token with `{{INITIATIVE_NAME}}` and every `{{PHASE_ID}}` token with the phase number.
3. Run via `/hotl:loop <copied-filename>` or `/hotl:execute-plan <copied-filename>`. Approve each of the three human gates after reviewing the produced artifact.
4. After the kickoff workflow finishes, start a fresh session and run `/hotl:brainstorm` with scope: phase — the requirements doc at `docs/requirements/{{INITIATIVE_NAME}}-phase-N.md` is now the input.

The kickoff workflow is optional. A phase whose scope is unambiguous and whose prior-phase artifacts are already solid may skip straight to `brainstorming` (scope: phase). Most phases benefit from the kickoff because it surfaces risks and prerequisites before implementation design begins.

---

## §3. Phase 1 — {{PHASE_1_NAME}}

One subsection per session. Copy the prompt into a fresh session.

### 3.1 Requirements session

**Role:** `@pm`
**Skill:** (none — prompt-driven)
**Output:** `docs/requirements/phase-1-{{slug}}.md`

```
You are the @pm for phase 1 of {{INITIATIVE_NAME}}.

Read:
  - docs/designs/{{INITIATIVE_NAME}}.md (Phase 1 row in §7 phase breakdown)
  - docs/reviews/{{INITIATIVE_NAME}}-kickoff-review.md (prerequisites checklist)

Produce docs/requirements/phase-1-{{slug}}.md with:
  - User stories and personas (who, what, why)
  - Acceptance criteria — testable, observable
  - UX copy and interaction expectations (if applicable)
  - Explicit non-goals for this phase
  - Exit gate — what "done" looks like from a user-visible perspective

No architecture or module design. That is the @architect's job.
Do not write code.
```

### 3.2 Design and workflow session

**Role:** `@architect`
**Skill:** `brainstorming`, then `writing-plans`
**Output:** `docs/designs/YYYY-MM-DD-phase-1-{{slug}}-design.md` (brainstorming) + `docs/plans/YYYY-MM-DD-{{slug}}-workflow.md` (writing-plans)

```
You are the @architect for phase 1 of {{INITIATIVE_NAME}}.

Read:
  - docs/designs/{{INITIATIVE_NAME}}.md (Phase 1 row + the Architecture section)
  - docs/requirements/phase-1-{{slug}}.md (from the prior session)
  - Any ADRs in docs/decisions/ that constrain this phase

Use the HOTL brainstorming skill to produce a tactical phase design at
docs/designs/YYYY-MM-DD-phase-1-{{slug}}-design.md with:
  - Intent, Verification, Governance contracts
  - Scope (in / out)
  - Module-level changes
  - Task breakdown that feeds writing-plans

After the design is accepted, use the writing-plans skill to produce the
executable workflow at docs/plans/YYYY-MM-DD-{{slug}}-workflow.md.
```

### 3.3 Implementation sessions

**Role:** `@dev`
**Skill:** `executing-plans` or `loop-execution`
**Output:** source code, tests, updated CHANGELOG

One session per workflow step. Session discipline from §0 applies — start fresh per step.

### 3.4 Code-review session

**Role:** `@reviewer`
**Skill:** `code-review`
**Output:** review memo; merge or request-changes

Dispatch after implementation is complete. Gate on merging is PASS verdict + passing test suite.

---

## §4. Phase 2 — {{PHASE_2_NAME}}

Copy §3's structure, replacing `phase-1` with `phase-2` and updating the inputs:

- §4.1 Requirements: reads Phase 1's committed artifacts as baseline
- §4.2 Design and workflow: input is the Phase 2 row of the design's phase breakdown
- §4.3 Implementation: same shape as §3.3
- §4.4 Code review: same shape as §3.4

---

## §5. Phase N — {{PHASE_N_NAME}}

Repeat the per-phase pattern until all phases in `docs/designs/{{INITIATIVE_NAME}}.md` §7 are shipped.

---

## §6. Cross-cutting sessions

These run once per initiative, not per phase.

### 6.1 Mid-initiative digest

**Role:** `@reviewer`
**Cadence:** weekly during active development

```
Summarize progress on {{INITIATIVE_NAME}} since the last digest. Read:
  - All new files in docs/plans/ and docs/decisions/ in the last 7 days
  - CHANGELOG.md under Unreleased
  - Any open review memos in docs/reviews/

Produce docs/reviews/{{INITIATIVE_NAME}}-digest-YYYY-MM-DD.md with:
  - Phases shipped vs. planned
  - Outstanding blockers
  - Risks that emerged and how they were resolved
  - Open questions still waiting on a human decision
```

### 6.2 Initiative-exit review

**Role:** `@reviewer`
**Trigger:** final phase merged

```
{{INITIATIVE_NAME}} is feature-complete. Produce
docs/reviews/{{INITIATIVE_NAME}}-exit-review.md assessing:
  - Did the shipped work match the design's vision (§2)?
  - Which non-goals were violated (if any)?
  - Which maturity stage did we reach vs. target?
  - What was learned that should update the operating model?
  - What follow-up work belongs in docs/backlog.md?
```

---

## §7. Escalation — when to bring the human in

See `docs/prompts/{{INITIATIVE_NAME}}-operating-model.md` for the full decision-rights matrix and tripwire list. Default escalations:

- Any new ADR
- Any schema migration or data-mutating change
- Any change that crosses more than {{N}} files
- Two consecutive review rejections on the same artifact
- Security / cost / compliance findings of any severity

When in doubt: escalate. Narrow the decision-rights matrix in the operating model, not this playbook.
