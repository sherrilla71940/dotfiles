# Module: claude-code

Tool module for the [`dotfiles`](../SKILL.md) skill. Invoke with `/dotfiles <os> claude-code`. Run the shared engine (Steps 1–7 in `SKILL.md`) using the values below. Repo subfolder: `~/dotfiles/claude-code/` (or `%USERPROFILE%\dotfiles\claude-code\` on Windows).

> **Why `claude-code`, not `claude`?** A file named `claude.md` case-insensitively matches `CLAUDE.md`, which Claude Code auto-loads as instructions — so this module must not use that name. The tool id is `claude-code` everywhere (arg, filename, repo subfolder, allowlist prefix).

## Applies to

- **Claude Code** (the CLI / IDE extension) — always.
- **Claude Desktop** app — optional. If you don't use the desktop app, skip every row and step that touches `claude_desktop_config.json`.

## Managed items

| Item | Live path — Windows | Live path — Mac | Live path — Linux | Live path — WSL | Repo path | Link type | Required? |
| ---- | ------------------- | --------------- | ----------------- | --------------- | --------- | --------- | --------- |
| Claude Code config dir | `%USERPROFILE%\.claude` | `~/.claude` | `~/.claude` | `~/.claude` (WSL home) | `dotfiles/claude-code/.claude` | directory | yes |
| Claude Desktop config | `%APPDATA%\Claude\claude_desktop_config.json` | `~/Library/Application Support/Claude/claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` | `/mnt/c/Users/<winuser>/AppData/Roaming/Claude/claude_desktop_config.json` ¹ | `dotfiles/claude-code/claude_desktop_config.json` | file | no |

> ¹ **WSL desktop config:** this path is on the Windows filesystem. A `ln -s` from within WSL will work within WSL but the Windows app won't follow it. To track it, either (a) manage it from a Windows shell using `mklink`, keeping the link in both places, or (b) skip the desktop config and only track the WSL-side Claude Code config dir.

## `.gitignore` allowlist lines (append to repo-root `.gitignore`)

Paths are relative to the repo root. Allow only known-safe config; deny anything that can hold secrets or session state.

```gitignore
# --- claude-code module: allow ---
!claude-code/.claude/settings.json
!claude-code/.claude/CLAUDE.md
!claude-code/.claude/skills/**
!claude-code/.claude/commands/**
!claude-code/.claude/rules/**
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
- **Claude Desktop** (quit fully, not just the window — check the system tray on Windows / menu bar on Mac).

## Notes

- **Why selective symlinks, not the whole `.claude` dir:** `.claude` is Claude Code's entire data directory — sessions, history, cache, downloads. Only a few files are user config. Symlinking the whole dir would break Claude's runtime state. This module symlinks individual items inside `.claude` so Claude continues to own its working directory.
- **Hardlink caveat (Windows 5b only):** if you use `mklink /H` for the desktop config *file*, it can silently desync if the Desktop app rewrites the file atomically. Re-verify periodically, or prefer the `5a` symlink. The `/J` junction on `.claude` has no such issue.
- **Backup names (Step 5):** `.claude` → `.claude.bak`; `claude_desktop_config.json` → `claude_desktop_config.json.bak`.
- **Migration from the old `claude` layout:** the earlier `/claude-dotfiles` skill used repo subfolder `dotfiles/claude/` (not `dotfiles/claude-code/`). If you already have that, either rename the folder and update the links, or keep it and adjust the repo paths above back to `claude/`. Fresh setups use `claude-code/`.
