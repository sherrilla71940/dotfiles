# Module: claude-code

Tool module for the [`dotfiles`](../SKILL.md) skill. Invoke with `/dotfiles claude-code`. Run the shared engine (Steps 1–7 in `SKILL.md`) using the values below. Repo subfolder: `%USERPROFILE%\dotfiles\claude-code\`.

> **Why `claude-code`, not `claude`?** A file named `claude.md` case-insensitively matches `CLAUDE.md`, which Claude Code auto-loads as instructions — so this module must not use that name. The tool id is `claude-code` everywhere (arg, filename, repo subfolder, allowlist prefix).

## Applies to
- **Claude Code** (the CLI / IDE extension) — always.
- **Claude Desktop** app — optional. If you don't use the desktop app, skip every row and step that touches `claude_desktop_config.json`.

## Managed items

| Item | Live path (`<LIVE_PATH>`) | Repo path (`<REPO_PATH>`) | Link type | Required? |
|------|---------------------------|---------------------------|-----------|-----------|
| Claude Code config dir | `%USERPROFILE%\.claude` | `%USERPROFILE%\dotfiles\claude-code\.claude` | directory (symlink `5a` / junction `5b`) | yes |
| Claude Desktop config file | `%APPDATA%\Claude\claude_desktop_config.json` | `%USERPROFILE%\dotfiles\claude-code\claude_desktop_config.json` | file (symlink `5a` / hardlink `5b`) | no |

## `.gitignore` allowlist lines (append to repo-root `.gitignore`)

Paths are relative to the repo root. Allow only known-safe config; deny anything that can hold secrets or session state.

```gitignore
# --- claude-code module: allow ---
!claude-code/.claude/settings.json
!claude-code/.claude/CLAUDE.md
!claude-code/.claude/skills/**
!claude-code/.claude/commands/**
!claude-code/claude_desktop_config.json

# --- claude-code module: never track (even if allowed above) ---
claude-code/.claude/sessions/
claude-code/.claude/keys/
claude-code/.claude/login/
claude-code/.claude/history/
claude-code/.claude/*.local.json
```

## Close-before-relink (Step 4 checkpoint)
Close **all** of these before running Step 5:
- Every **Claude Code** session — CLI terminals and IDE extension windows, **including the one running this skill**.
- **Claude Desktop** (quit fully, not just the window — check the tray).

## Notes
- **Hardlink caveat:** if you use the `5b` cmd fallback for the desktop config *file* (`mklink /H`), it can silently desync if the Desktop app rewrites the file atomically. Re-verify it periodically, or prefer the `5a` Dev-Mode symlink. The `/J` junction on `.claude` has no such issue.
- **Backup names (Step 5):** `.claude` → `.claude.bak`; `claude_desktop_config.json` → `claude_desktop_config.json.bak`.
- **Migration from the old `claude` layout:** the earlier `/claude-dotfiles` skill (and the first draft of this module) used repo subfolder `dotfiles\claude\`. If you already have that, either rename the folder to `dotfiles\claude-code\` and update the links, or keep it and change the repo paths above back to `claude\`. Fresh setups need nothing.
