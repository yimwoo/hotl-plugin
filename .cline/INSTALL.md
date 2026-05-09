# Installing HOTL for Cline

One command. No settings to paste. Works with any API provider (Oracle Code Assist, OpenAI, Anthropic, etc.).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/yimwoo/hotl-plugin/main/install-cline.sh | bash
```

Or clone first:

```bash
git clone https://github.com/yimwoo/hotl-plugin.git ~/.cline/hotl
bash ~/.cline/hotl/install-cline.sh
```

## What Happens

1. HOTL skills install to `~/.cline/hotl/`
2. HOTL rules install to `~/Documents/Cline/Rules/` (Cline's global rules directory)
3. HOTL scripts and runtime install to `~/Documents/Cline/Scripts/`

Rules apply to **all projects** automatically. No per-project setup needed. Start a new Cline task to activate.

## How to Use

Tell Cline what you need:

- **"brainstorm this feature"** — design with contracts before coding
- **"plan the implementation"** — create `docs/plans/YYYY-MM-DD-<slug>-workflow.md` with steps and gates
- **"execute the plan"** — run the workflow with checkpoints
- **"use TDD"** — RED-GREEN-REFACTOR cycle
- **"debug this"** — systematic 4-phase debugging
- **"review the code"** — checklist-based code review

## Updating

```bash
cd ~/.cline/hotl && git pull && bash install-cline.sh
```

## More

Detailed docs: [docs/README.cline.md](https://github.com/yimwoo/hotl-plugin/blob/main/docs/README.cline.md)
