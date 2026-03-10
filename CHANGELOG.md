# Changelog

All notable changes to the HOTL plugin will be documented in this file.

## [1.1.0] - 2026-03-10

### Added
- Marketplace support for Claude Code, Cursor, Codex, Cline, and OpenCode
- Brainstorming skill auto-discovers design docs in `docs/plans/`
- Smoke tests, pre-push hook, and GitHub Actions CI
- `marketplace.json` so the repo can serve as its own plugin marketplace

### Fixed
- Unique workflow filenames (`hotl-workflow-<slug>.md`) to prevent multi-agent conflicts
- Removed unsupported `agents` field from plugin manifest

### Changed
- Workspace artifacts and IDE files added to `.gitignore`

## [1.0.0] - Initial Release

### Added
- Core HOTL skills: brainstorming, writing-plans, executing-plans, loop-execution, dispatch-agents
- TDD, systematic-debugging, code-review, verification-before-completion skills
- SessionStart hook for automatic skill injection
- Slash commands: `/hotl:brainstorm`, `/hotl:write-plan`, `/hotl:loop`, `/hotl:execute-plan`, `/hotl:setup`
- Adapter templates for Codex, Cline, Cursor, and GitHub Copilot
- `install.sh` for manual installation
