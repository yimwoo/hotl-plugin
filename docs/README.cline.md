# HOTL Plugin for Cline

Cline uses `.clinerules` files in your project root.

## Setup

Run `/hotl:setup` in a Claude Code session to generate `.clinerules` for your project,
or copy the template manually:

```bash
# From GitHub install
cp ~/.claude/plugins/hotl/adapters/.clinerules.template /path/to/your/project/.clinerules

# From Codex install
cp ~/.codex/hotl-plugin/adapters/.clinerules.template /path/to/your/project/.clinerules
```

Edit `.clinerules` to add any project-specific guidelines on top of the HOTL defaults.

## What Gets Generated

The `.clinerules` file instructs Cline to:
- Define intent/success criteria before implementing features
- Loop on steps with success criteria
- Pause for human approval on high-risk changes (auth, encryption, billing)
- Show test and lint output before claiming work is done
