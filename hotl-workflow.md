---
intent: Make HOTL installable from Claude Code, Cursor, Codex, and OpenCode marketplaces
success_criteria: All 4 platform manifest/install files in place and README Install section updated
risk_level: low
auto_approve: true
---

## Steps

### 1. Update .claude-plugin/plugin.json
action: Add homepage, repository, skills, agents, commands, and hooks fields to match superpowers format
loop: false
verify: cat .claude-plugin/plugin.json | grep -q "repository"

### 2. Create .cursor-plugin/plugin.json
action: Create .cursor-plugin/plugin.json with displayName, homepage, repository, skills, agents, commands, hooks fields — mirrors .claude-plugin/plugin.json with Cursor-specific format
loop: false
verify: test -f .cursor-plugin/plugin.json

### 3. Create .codex/INSTALL.md
action: Create .codex/INSTALL.md with git clone + symlink instructions for Codex, using yimwoo/hotl-plugin URLs
loop: false
verify: test -f .codex/INSTALL.md

### 4a. Create .opencode/INSTALL.md
action: Create .opencode/INSTALL.md with git clone + symlink instructions for OpenCode, using yimwoo/hotl-plugin URLs
loop: false
verify: test -f .opencode/INSTALL.md

### 5. Update README Install section
action: Replace current Install section with all 4 platform methods (Claude Code marketplace, Cursor, Codex, OpenCode) plus keep existing git/bash method as fallback
loop: false
verify: grep -q "plugin marketplace add" README.md

### 6. Human review of README
action: Present updated README Install section for approval
loop: false
gate: human

### 7. Commit and push
action: git add all new/modified files and commit with message "feat: add marketplace support for Claude Code, Cursor, Codex, and OpenCode"
loop: false
verify: git status | grep -q "nothing to commit"
gate: human
