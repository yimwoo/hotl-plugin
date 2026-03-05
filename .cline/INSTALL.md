# Installing HOTL for Cline

Cline uses `.clinerules` files in your project root to define AI behaviour rules.

## Prerequisites

- Git
- [Cline](https://github.com/cline/cline) extension installed in VS Code

## Installation

### 1. Clone the HOTL repository

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.cline/hotl
```

### 2. Copy the rules template into your project

```bash
cp ~/.cline/hotl/adapters/.clinerules.template /path/to/your/project/.clinerules
```

Edit `.clinerules` to add any project-specific guidelines on top of the HOTL defaults.

### 3. (Optional) Generate via Claude Code

If you have Claude Code with HOTL installed, run `/hotl:setup` in your project to auto-generate `.clinerules`.

## What the Rules Do

The `.clinerules` file instructs Cline to:
- Define intent, constraints, and success criteria before implementing features
- Loop on steps with success criteria rather than running once
- Pause for human approval on high-risk changes (auth, encryption, billing)
- Show test and lint output before claiming work is done

## Updating

```bash
cd ~/.cline/hotl && git pull
cp ~/.cline/hotl/adapters/.clinerules.template /path/to/your/project/.clinerules
```

## More

Detailed docs: [docs/README.cline.md](https://github.com/yimwoo/hotl-plugin/blob/main/docs/README.cline.md)
