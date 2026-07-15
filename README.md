# dotfiles

Personal config tracking — Claude Code settings, skills, rules, and other tool configs kept in git and symlinked into place.

**New machine / after cloning:** open Claude Code and run `/dotfiles <os>` (e.g. `/dotfiles mac`, `/dotfiles windows`). The skill handles relinking automatically. No manual steps needed.

> The skill pattern is tool-agnostic — the same `/dotfiles` flow works for GitHub Copilot, Codex, or any other AI assistant that has config worth tracking. Add a module for it under `claude/skills/dotfiles/references/` and the rest of the playbook applies unchanged.

**Full docs:** [`claude/skills/dotfiles/SKILL.md`](claude/skills/dotfiles/SKILL.md)
