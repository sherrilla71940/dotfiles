@AGENTS.md

# Claude Code in this repository

Everything above is the shared agent guide, imported from `AGENTS.md` so Claude, Codex and
Copilot follow the same constraints here. Codex and the Copilot command-line interface (CLI)
read `AGENTS.md` directly; Claude Code reads only `CLAUDE.md`, which is why this file exists.

One Claude-specific caution: your **user-level** configuration in `~/.claude/` is rendered
from this repo. Editing `~/.claude/CLAUDE.md` or `~/.claude/rules/*.md` while working here
changes the very instructions you are running under, and the change is lost on the next
`chezmoi apply` because those files are templates. Edit `home/dot_claude/CLAUDE.md.tmpl` or
`home/.chezmoitemplates/` instead.
