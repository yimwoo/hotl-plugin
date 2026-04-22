# Research: HOTL State Audit, Competitive Landscape Update, and Gap Analysis

**Date**: 2026-03-30
**Triggered by**: Comprehensive audit of HOTL's current state, competitive positioning, and improvement opportunities
**Relevance**: HOTL is at v2.10.5 with 163 commits in March alone. The Claude Code plugin ecosystem has matured rapidly (9,600+ repos, 101 official plugins). This audit identifies what is solid, what is thin, and where HOTL should invest next.

---

## Part 1: Current State Audit

### 1.1 Codebase Maturity Assessment

**Version**: 2.10.5 (163 commits in March 2026, 79 in last 10 days)
**GitHub**: 16 stars, 2 forks, 0 open issues
**Contributors**: 1 (sole developer)
**Tests**: 164 passing across 6 test suites (smoke, runtime, runtime-integration, execution-scenarios, render-summary, codex-execution-helpers)
**CI**: GitHub Actions runs smoke tests only on push/PR to main

| Component | Files | Maturity | Assessment |
|-----------|-------|----------|------------|
| **Skills** | 17 skill directories | Mixed | Core workflow skills (brainstorming, writing-plans, loop-execution) are substantial (68-349 lines). Utility skills (tdd, systematic-debugging, verification-before-completion) are thin shells (31-34 lines). |
| **Commands** | 9 slash commands | Solid | All commands are wired up and documented. |
| **Runtime (hotl-rt)** | 1,285 lines bash | Strong | State machine, verification execution, report generation, atomic state persistence. 50+ dedicated tests. The most technically differentiated component. |
| **Hooks** | 4 files (bash, PowerShell, JSON, CMD) | Solid | Cross-platform (Unix, Windows PowerShell, CMD). Session-start hook injects context reliably. |
| **Tests** | 1,906 lines across 6 suites | Good | 164 passing tests. Runtime has 50 unit tests + 11 integration tests. Smoke tests validate structural integrity. CI gap: only smoke.bats runs in GitHub Actions. |
| **Documentation** | 20+ docs | Extensive | Workflow format reference, authoring guide, contracts, checklists, per-platform setup guides. |
| **Adapters** | 4 templates | Adequate | AGENTS.md, Cursor rules, Copilot instructions, Cline rules. Cursor and Copilot are thin (static templates, no deep integration). |
| **Cline rules** | 10 rule files | Strong | Comprehensive mirrors of canonical skills for Cline users, including native skills mode (v2.9.7). |
| **Codex packaging** | Plugin + native skills | Strong | Both install modes supported with plugin cache sync, marketplace registration, and update detection. |
| **Scripts** | 6 utility scripts | Solid | document-lint.sh, render-execution-summary.sh, finalize-codex-summary.sh, show-codex-current-step.sh, check-update.sh, dev-setup.sh. |

### 1.2 Skill Depth Analysis

Skills vary dramatically in depth. This matters because thin skills provide little behavioral guidance to the LLM -- they read more like reminders than actionable protocols.

**Robust skills (100+ lines, structured state machine or multi-step protocol):**
- `loop-execution` (349 lines) -- Full execution state machine, branch preflight, verification types, review checkpoints, platform-specific rendering, safety rules
- `pr-reviewing` (324 lines) -- Multi-dimension parallel subagent reviews
- `document-review` (155 lines) -- Two-layer validation (deterministic lint + AI qualitative review)
- `code-review` (150 lines) -- Dispatch-first with inline fallback
- `executing-plans` (138 lines) -- Batch execution with human checkpoints
- `writing-plans` (134 lines) -- Plan generation with self-check loop and typed verification
- `resuming` (110 lines) -- Full sidecar state schema and verify-first resume
- `subagent-execution` (101 lines) -- Delegated step runner with controller governance

**Adequate skills (60-100 lines, clear protocol but less detailed):**
- `requesting-code-review` (91 lines) -- Standardized review dispatch
- `receiving-code-review` (87 lines) -- Verify-Evaluate-Respond-Implement
- `setup-project` (76 lines) -- Template generation for multiple tools
- `brainstorming` (68 lines) -- Contract-first design with greenfield detection

**Thin skills (< 60 lines, high-level guidelines only):**
- `using-hotl` (58 lines) -- Skill index and routing table
- `tdd` (33 lines) -- Generic RED-GREEN-REFACTOR, not HOTL-specific
- `systematic-debugging` (34 lines) -- Generic 4-phase debugging, not HOTL-specific
- `verification-before-completion` (31 lines) -- Checklist only
- `dispatch-agents` (29 lines) -- Brief parallelism guide

**Assessment**: The thin skills (tdd, systematic-debugging, verification-before-completion, dispatch-agents) are not differentiated from what any LLM already knows. They add minimal behavioral guidance beyond "remember to do this." For HOTL's governance identity, these should either be deepened with HOTL-specific integrations (e.g., TDD steps that tie into `hotl-rt` verification, debugging that records hypotheses in `.hotl/`) or acknowledged as lightweight reminders rather than full skills.

### 1.3 Test Coverage Gaps

| Suite | Tests | What it covers | What it misses |
|-------|-------|----------------|----------------|
| `smoke.bats` (49) | Structural integrity, manifest validity, documentation consistency | Everything beyond surface structure |
| `runtime.bats` (50) | hotl-rt unit tests: init, step, gate, verify, finalize, summary | Edge cases: concurrent access, corrupted state files, very long step names |
| `runtime-integration.bats` (11) | End-to-end agent conformance, human-review flow | Only tests the runtime, not agent behavior |
| `execution-scenarios.bats` (22) | Execution scenario parsing | Thin; tests parsing not actual execution |
| `render-summary.bats` (25) | Summary rendering across platforms | Good coverage |
| `codex-execution-helpers.bats` (7) | Codex helper scripts | Minimal |

**CI gap**: GitHub Actions only runs `smoke.bats`. The runtime, integration, execution-scenario, render-summary, and Codex helper tests (115 tests) are not in CI. This means runtime regressions are not caught automatically.

### 1.4 Documentation Quality

Documentation is extensive and generally well-maintained. Key assets:

- `docs/workflow-format.md` -- Complete workflow format reference including typed verification
- `docs/how-it-works.md` -- 7-phase workflow explanation
- `docs/authoring-skills-vs-agents.md` -- Canonical guide for skill/agent creation
- `docs/contracts/` -- Three output contracts (PR review, code review, execution report) with cross-contract conventions
- `docs/checklists/` -- Four reusable review heuristic files
- `docs/README.codex.md` and `docs/README.cline.md` -- Platform-specific setup guides
- `docs/updating.md` -- Update guide covering all platforms

**Gaps**:
- No architecture diagram or visual overview of how components relate
- No getting-started tutorial (README Quick Start is install-only, no walkthrough)
- No troubleshooting guide
- No FAQ document (Cline docs have a brief FAQ, but there is no project-wide FAQ)
- `docs/skills.md` exists but is a flat table -- no guidance on which skills to use when (routing logic is only in `using-hotl` SKILL.md)

### 1.5 Platform Support Assessment

| Platform | Integration Depth | Assessment |
|----------|------------------|------------|
| **Claude Code** | Deep (plugin, hooks, commands, skills) | Primary platform. Fully supported. |
| **Codex** | Strong (plugin + native skills, marketplace, cache sync) | Second-class citizen but functional. No slash commands. |
| **Cline** | Good (10 global rules, native skills mode, script copying) | Well-supported. Rule maintenance is manual. |
| **Cursor** | Minimal (static adapter template) | Cursor has its own Plan Mode and Automations now. The HOTL template is a basic rules file. |
| **GitHub Copilot** | Minimal (static adapter template) | Copilot has its own issue-to-PR workflow. The HOTL template is a basic instructions file. |
| **Windsurf** | None | Listed in cc-sdd's supported tools. HOTL has no Windsurf adapter. |
| **Gemini CLI** | None | Listed in cc-sdd's supported tools. HOTL has no Gemini CLI adapter. |
| **OpenCode** | Stub only (.opencode/INSTALL.md exists but minimal) | Mentioned in CHANGELOG 1.1.0 but not developed. |

---

## Part 2: Competitive Landscape Update (March 30, 2026)

The competitive landscape has shifted significantly since the initial research on March 29. New competitors have emerged and existing ones have matured.

### 2.1 New Competitors Since Last Research

#### Quantum-Loop (andyzengmath)
- **Stars**: 17 | **Architecture**: Spec-driven + dependency DAG + parallel worktree agents
- **Unique features**: Directed Acyclic Graph for story dependencies (not a flat list), parallel worktree isolation (each agent in its own git worktree), two-stage review gates (spec compliance before code quality), "Iron Law" verification (fresh evidence required for every completion claim), autonomous overnight runs
- **State management**: `quantum.json` (machine-readable, cross-session persistent)
- **Testing**: 79+ shell test cases
- **Relevance to HOTL**: Quantum-Loop implements dependency-aware parallel execution -- the #1 feature gap identified in the previous research. Its parallel worktree approach is more sophisticated than HOTL's `dispatch-agents` skill and more natural than what Claude Workflow (sighup) offers.

#### claude-code-workflow-orchestration (barkain)
- **Stars**: 38 | **Architecture**: Hook-based delegation + native Plan Mode integration
- **Unique features**: PreToolUse hooks that enforce delegation (blocks direct tool usage), conditional orchestrator injection (lightweight stub loads on startup, full orchestrator only when invoked), experimental Agent Teams mode (teammates share context via SendMessage), smart dependency analysis for parallel/sequential mode selection
- **Relevance to HOTL**: This plugin represents a different philosophy -- enforcement via hooks rather than skills. The conditional loading pattern (minimizing token overhead when the orchestrator is not needed) is worth studying.

#### HumanInLoop (deepeshBodh)
- **Stars**: ~42,000 (stated; needs verification -- may conflate with a parent framework) | **Architecture**: Spec-first multi-agent framework
- **Unique features**: 9 specialized agents (State Analyst, Requirements Analyst, Devil's Advocate, Principal Architect, etc.), 29 skills, Python DAG engine with MCP server, constitution-based governance (RFC 2119-compliant project standards), 403 tests with ~95% coverage
- **Relevance to HOTL**: HumanInLoop is the closest philosophical competitor -- both enforce "human decisions before AI writes code." HumanInLoop has a Devil's Advocate pattern (automated gap detection) and a constitution concept that HOTL lacks. However, HOTL has deeper execution governance (typed verification, resumable state, `hotl-rt` runtime) while HumanInLoop's execution is simpler.

### 2.2 Updated Competitive Positioning

The plugin ecosystem has grown from a few dozen workflow plugins to hundreds. Key adoption metrics:

| Plugin | Stars (approx.) | Key Differentiator |
|--------|---------|-------------------|
| **Superpowers** (obra) | ~99,200 | Accepted into Anthropic marketplace Jan 2026. Lifecycle planning + TDD + debugging + subagent dev. The market leader. |
| **Everything Claude Code** | ~82,000 | Agent harness with memory, security, performance optimization |
| **HumanInLoop** | ~42,000 | Spec-first multi-agent with DAG engine and MCP server |
| **feature-dev** | ~89,000 installs | 7-phase workflow with 3 specialized agents. Most popular individual plugin. |
| **Claude HUD** | ~9,000 | Dashboard/monitoring for Claude Code sessions |
| **Quantum-Loop** | 17 | DAG + parallel worktrees + two-stage review |
| **Workflow Orchestration** (barkain) | 38 | Hook-based delegation + Plan Mode integration |
| **HOTL** | 16 | Three-contract governance + typed verification + `hotl-rt` runtime + 5-platform adapters |

**Stark adoption gap**: HOTL has 16 stars vs. leading plugins with tens of thousands. This is not a quality indicator -- HOTL's technical depth exceeds most competitors -- but it is a visibility and adoption signal that needs attention.

### 2.3 What Top Plugins Do That HOTL Does Not

| Capability | Superpowers | HumanInLoop | Quantum-Loop | feature-dev | HOTL |
|-----------|-------------|-------------|--------------|-------------|------|
| Dependency DAG / parallel steps | No | Yes (Python MCP) | Yes (shell) | No | No |
| Token/cost tracking | No | No | No | No | No |
| Native Plan Mode integration | No | No | No | No | No |
| Anthropic marketplace listing | Yes | Yes | No | Yes | No |
| Devil's advocate / gap detection | No | Yes | No | No | No |
| Cross-session persistence | No | No | Yes | No | Yes (hotl-rt) |
| Typed verification (shell/browser/artifact/human-review) | No | Limited | No | No | Yes |
| Multi-platform adapters (5+ tools) | No | No | No | No | Yes |
| Resumable execution | No | No | Yes | No | Yes |
| Execution report artifacts | No | No | No | No | Yes |
| Project constitution/conventions | No | Yes | No | No | No |
| Review checklists (reusable) | No | No | No | No | Yes |

---

## Part 3: Gap Analysis

### 3.1 Critical Gaps (directly blocking adoption)

#### Gap 1: Not Listed in Major Directories
HOTL is **not listed** in `awesome-claude-code` (the primary curated directory by hesreallyhim), not on `claudemarketplaces.com`, and does not appear in any "best Claude Code plugins" roundup articles. For a plugin that exists in a 9,600+ repo ecosystem, discoverability is existential.

**Action**: Submit PRs to awesome-claude-code, awesome-claude-plugins (ComposioHQ), and awesome-codex-plugins. Register on claudemarketplaces.com and claudepluginhub.com.

**Priority**: Critical
**Effort**: Small (one afternoon)

#### Gap 2: Not in Anthropic Official Marketplace
Superpowers, HumanInLoop, and feature-dev are all listed in the official Anthropic plugin marketplace. HOTL is not. The Anthropic marketplace is the primary discovery mechanism for most Claude Code users.

**Action**: Apply for inclusion in `anthropics/claude-plugins-official`. Ensure `marketplace.json` and `plugin.json` meet all Anthropic requirements.

**Priority**: Critical
**Effort**: Small (application process)

#### Gap 3: No Onboarding Tutorial
The README has Quick Start (install instructions) but no walkthrough. A new user who installs HOTL has no guided path to their first successful workflow run. Competing plugins like Superpowers and feature-dev provide blog posts, video tutorials, and step-by-step guides.

**Action**: Create a `docs/tutorial.md` or `docs/getting-started.md` that walks through: (1) install, (2) first brainstorm, (3) first plan, (4) first execution, (5) interpreting the report. Consider a blog post or Medium article.

**Priority**: High
**Effort**: Medium

### 3.2 Strategic Gaps (competitive differentiation at risk)

#### Gap 4: No Dependency-Aware Parallel Execution
This was identified in the March 29 research and the gap has widened. Quantum-Loop now ships DAG-based execution with parallel worktree agents. HumanInLoop has a Python DAG engine with an MCP server. HOTL's workflow format is strictly sequential. The `dispatch-agents` skill handles ad-hoc parallel tasks but is not integrated into the main execution engine.

**What to build**: Add an optional `depends_on: [step_numbers]` field to workflow steps. Teach `loop-execution` to run independent steps as parallel subagents. Use isolated git worktrees as the default execution root for each run, with explicit opt-out only when a user wants current-checkout execution. Fall back to sequential when `depends_on` is absent (backward-compatible).

**Priority**: High
**Effort**: Large

#### Gap 5: GitHub Actions CI Only Runs smoke.bats
115 out of 164 tests (70%) do not run in CI. The runtime tests, integration tests, execution-scenario tests, render-summary tests, and Codex helper tests are all local-only. A regression in `hotl-rt` would not be caught by CI.

**Action**: Update `.github/workflows/smoke.yml` to install `jq` and run all 6 test suites.

**Priority**: High
**Effort**: Small

#### Gap 6: Thin Utility Skills (tdd, systematic-debugging, verification-before-completion, dispatch-agents)
These four skills total 127 lines combined and contain generic advice that any LLM already knows. They do not integrate with `hotl-rt`, do not produce artifacts, and do not reference HOTL contracts. They dilute the skill count without adding governance value.

**Options**:
- (a) **Deepen them**: Add `hotl-rt` integration (e.g., TDD cycles that record RED/GREEN/REFACTOR state, debugging that logs hypotheses to `.hotl/debug-<session>.md`)
- (b) **Consolidate**: Merge tdd + systematic-debugging + verification-before-completion into a single "development-practices" skill
- (c) **Accept and document**: Acknowledge these as lightweight reminders and keep them thin

**Priority**: Medium
**Effort**: Medium (for option a), Small (for option b or c)

#### Gap 7: No Token/Cost Tracking or Budget Enforcement
Reiterated from March 29 research. Token drain is now the #1 complaint in the Claude Code community (March 26 incident where users reported 5-hour session windows depleted in 1-2 hours). HOTL is a governance tool that does not govern the most expensive resource.

**What to build**: Track per-step duration in `hotl-rt` state JSON. Estimate token consumption from tool call counts and output sizes. Add a `token_budget` frontmatter field with warnings at 80% and hard-stop at 100%.

**Priority**: High
**Effort**: Medium

#### Gap 8: No Native Plan Mode Integration
Claude Code's native Plan Mode (EnterPlanMode/ExitPlanMode) is now widely used. The `claude-code-workflow-orchestration` plugin integrates with it directly. HOTL's planning phase generates a Markdown file but does not interact with the native plan UI.

**What to build**: Use the Plan Mode API during `writing-plans` to present the plan in the native UI before saving to Markdown.

**Priority**: Medium
**Effort**: Medium

### 3.3 Minor Gaps

#### Gap 9: No Windsurf or Gemini CLI Adapters
cc-sdd supports both. HOTL does not. These are growing platforms.

**Priority**: Low
**Effort**: Small

#### Gap 10: No Architecture Diagram
The project has extensive text documentation but no visual representation of how hooks, skills, commands, runtime, and adapters connect. A single Mermaid diagram in README.md or docs/ would significantly improve comprehension for new contributors.

**Priority**: Low
**Effort**: Small

#### Gap 11: OpenCode Integration Is a Stub
`.opencode/INSTALL.md` exists but OpenCode was mentioned in CHANGELOG 1.1.0 and never developed further.

**Priority**: Low
**Effort**: Small (either develop or remove)

---

## Part 4: Community and Adoption Signals

### 4.1 Claude Code Plugin Ecosystem Context

- **9,602 total repositories** indexed in the ecosystem as of March 29, 2026
- **101 official plugins** in the Anthropic marketplace (33 Anthropic-built, 68 partner)
- **150+ skills** listed on claudemarketplaces.com
- **41-68% of developers** actively use Claude or Claude Code
- Most popular plugin (feature-dev) has ~89,000 installs
- Superpowers has ~99,200 GitHub stars in 3 months

### 4.2 HOTL's Position

With 16 stars, HOTL is in the long tail of the ecosystem. This is consistent with a sole-developer project that has not invested in marketing, directory listings, or community engagement. The technical quality is disproportionately high relative to the adoption signal.

**Key observation**: The March 2026 token drain incident demonstrates that governance tools are now more urgent than ever. HOTL's value proposition ("AI-generated changes do not land without evidence") directly addresses the root cause of that incident (uncontrolled resource consumption during unstructured agent loops).

### 4.3 What Successful Plugins Have Done for Adoption

| Tactic | Examples | HOTL Status |
|--------|----------|-------------|
| Anthropic official marketplace listing | Superpowers, HumanInLoop, feature-dev | Not listed |
| Blog posts / Medium articles | Superpowers (builder.io blog), Deep Trilogy (Medium), multiple others | None found |
| Listed in awesome-claude-code | Superpowers, Ralph Loop, many others | Not listed |
| Listed on claudemarketplaces.com | Dozens of plugins | Not listed |
| Video tutorials / demos | Superpowers (YouTube), feature-dev | None |
| Clear "before/after" value demo | Superpowers, Deep Trilogy | README has execution summary example but no before/after narrative |
| Cross-posted to HN / Reddit | Multiple plugins have been shared on r/ClaudeCode, HN | No evidence of HOTL being shared |

### 4.4 Developer Pain Points That HOTL Addresses

From current community research:

1. **"The 80% Problem"** (Addy Osmani): AI rapidly generates 80% of a solution; the remaining 20% creates hidden, compounding costs. HOTL's verification contracts and `hotl-rt` runtime directly address the verification gap that makes the last 20% expensive.

2. **Token drain / runaway agents** (March 26 incident): Users report 5-hour sessions depleted in 1-2 hours. HOTL's step-by-step execution with gates and max_iterations provides structural guardrails against runaway loops -- but does not yet track or budget tokens.

3. **"Vibe coding" backlash**: Developers increasingly recognize that unstructured AI coding leads to technical debt. HOTL's brainstorm-plan-execute model is the antidote, but the term "human-on-the-loop" has less marketing momentum than "spec-driven development."

4. **Context window failures**: As agents compact context, they forget task lists and quality criteria. HOTL's `.hotl/state/` persistence and resumable execution directly address this.

5. **AI bug rate correlation**: Google's DORA report found 90% AI adoption increase correlates with 9% more bugs. HOTL's verification-before-completion and typed verification are evidence-based responses to this finding.

---

## Part 5: Recommendations

### Priority 1: Visibility and Adoption (Critical, Small Effort)

1. **Submit to awesome-claude-code and awesome-claude-plugins** -- This is the minimum viable discoverability action. HOTL is not in any curated directory.
   - Priority: Critical | Effort: Small (1-2 hours)

2. **Apply for Anthropic official marketplace** -- The three leading workflow plugins are all listed. HOTL's technical depth should qualify it.
   - Priority: Critical | Effort: Small (application + any required manifest changes)

3. **Register on claudemarketplaces.com and claudepluginhub.com** -- Community directories that aggregate plugin discovery.
   - Priority: High | Effort: Small

### Priority 2: Technical Quick Wins (High Impact, Small Effort)

4. **Expand CI to run all test suites** -- Add `jq` install and run all 6 bats suites in GitHub Actions. 115 tests currently not in CI.
   - Priority: High | Effort: Small (update smoke.yml)

5. **Add an architecture diagram** -- A Mermaid diagram showing hooks -> skills -> commands -> runtime -> adapters flow. Improves README and contributor onboarding.
   - Priority: Medium | Effort: Small

6. **Write a getting-started tutorial** -- Walk a new user from install to first completed workflow. Critical for converting installs to active users.
   - Priority: High | Effort: Medium

### Priority 3: Competitive Feature Development (High Impact, Medium-Large Effort)

7. **Add step-level telemetry to hotl-rt** -- Per-step duration_ms, verify_attempts, verify_output_size in state JSON. Foundation for token budgeting.
   - Priority: High | Effort: Medium

8. **Add dependency-aware parallel execution** -- `depends_on` field in workflow format. Independent steps run as parallel subagents. Use worktrees for isolation.
   - Priority: High | Effort: Large

9. **Add token budget frontmatter** -- `token_budget: 500000` with 80% warning and 100% hard-stop. Unique governance feature.
   - Priority: High | Effort: Medium

### Priority 4: Depth and Polish (Medium Impact)

10. **Deepen thin skills** -- Integrate tdd, systematic-debugging, and verification-before-completion with `hotl-rt` (record state transitions, produce artifacts).
    - Priority: Medium | Effort: Medium

11. **Add Devil's Advocate pattern to brainstorming** -- HumanInLoop's automated gap detection during design is compelling. Add a self-challenge step to the brainstorming skill that systematically probes for missing constraints, edge cases, and assumption propagation.
    - Priority: Medium | Effort: Small

12. **Explore Native Plan Mode integration** -- Use EnterPlanMode during writing-plans for native UI presentation.
    - Priority: Medium | Effort: Medium

---

## Sources

- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) -- Primary curated Claude Code plugin directory; HOTL is not listed
- [claudemarketplaces.com](https://claudemarketplaces.com/) -- Community plugin directory aggregator; HOTL is not listed
- [Quantum-Loop](https://github.com/andyzengmath/quantum-loop) -- DAG-based parallel execution with worktree isolation (17 stars)
- [HumanInLoop](https://github.com/deepeshBodh/human-in-loop) -- Spec-first multi-agent framework with DAG engine and MCP server
- [claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration) -- Hook-based delegation with Plan Mode integration (38 stars)
- [Superpowers Plugin](https://www.builder.io/blog/claude-code-superpowers-plugin) -- Leading skills framework (~99,200 GitHub stars)
- [Feature Dev Plugin](https://claude.com/plugins/feature-dev) -- Most popular plugin by installs (~89,000)
- [Claude Code Plugin Ecosystem Stats](https://github.com/quemsah/awesome-claude-plugins) -- 9,602 repos indexed as of March 29, 2026
- [Claude Code Plugins Review 2026](https://aitoolanalysis.com/claude-code-plugins/) -- 9,000+ extensions overview
- [The 80% Problem in Agentic Coding -- Addy Osmani](https://addyo.substack.com/p/the-80-problem-in-agentic-coding) -- The verification gap in AI-generated code
- [Claude Code Rate Limit Drain Bug](https://www.macrumors.com/2026/03/26/claude-code-users-rapid-rate-limit-drain-bug/) -- Token drain incident March 26, 2026
- [Three Things Wrong with AI Agents in 2026](https://dev.to/jarveyspecter/the-three-things-wrong-with-ai-agents-in-2026-and-how-we-fixed-each-one-4ep3) -- Lack of structure, context loss, production readiness
- [AI Agents Not Production-Ready -- VentureBeat](https://venturebeat.com/ai/why-ai-coding-agents-arent-production-ready-brittle-context-windows-broken) -- Context window failures, operational awareness gaps
- [Best Claude Code Plugins 2026 -- Composio](https://composio.dev/content/top-claude-code-plugins) -- Top plugin roundups (HOTL absent)
- [Best Claude Code Skills & Plugins Guide -- DEV Community](https://dev.to/raxxostudios/best-claude-code-skills-plugins-2026-guide-4ak4) -- Ecosystem overview
- [Spec-Driven Development with Claude Code -- Medium](https://levelup.gitconnected.com/spec-driven-development-with-claude-code-1b08184965e3) -- SDD as the dominant paradigm
- [Human-on-the-Loop Control Model -- The New Stack](https://thenewstack.io/human-on-the-loop-the-new-ai-control-model-that-actually-works/) -- HOTL concept gaining mainstream recognition
- [Anthropic Claude Plugins Official](https://github.com/anthropics/claude-plugins-official) -- Official Anthropic-managed plugin directory
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins) -- Official plugin creation documentation
