# Module: <Tool Name>

Template for a new tool module for the [`dotfiles`](../SKILL.md) skill. Copy this file to `references/<tool>.md` (lowercase, no spaces — that name becomes the `/dotfiles <tool>` argument), fill in the blanks, then run `/dotfiles <tool>`. Repo subfolder: `%USERPROFILE%\dotfiles\<tool>\`.

> **Never name a module `claude.md`.** Claude Code auto-loads any file case-insensitively matching `CLAUDE.md` as instructions, and Windows/macOS filesystems are case-insensitive — so `claude.md` would be mistaken for an instruction file. Use a distinct id like `claude-code`.

Delete these instructions and the worked examples at the bottom once your module is written.

## Applies to
- <What this tool is; which parts are always tracked vs optional.>

## Managed items

| Item | Live path (`<LIVE_PATH>`) | Repo path (`<REPO_PATH>`) | Link type | Required? |
|------|---------------------------|---------------------------|-----------|-----------|
| <config dir> | `%...%\<...>` | `%USERPROFILE%\dotfiles\<tool>\<name>` | directory (symlink `5a` / junction `5b`) | yes |
| <config file> | `%...%\<...>.json` | `%USERPROFILE%\dotfiles\<tool>\<name>.json` | file (symlink `5a` / hardlink `5b`) | no |

> Link type rule: **directories** → symlink (`5a`) or junction (`5b`); **single files** → symlink (`5a`) or hardlink (`5b`).
>
> **OS roadmap:** the "Live path" column is the **Windows** path. When Linux/mac support lands, add sibling columns (`Live path (linux)`, `Live path (mac)`) and the engine will pick per the `os` argument. Author paths so adding a column is trivial — one row per logical item, not one row per OS.

## `.gitignore` allowlist lines (append to repo-root `.gitignore`)
Paths are relative to the repo root and must start with `<tool>/`. Allow only known-safe files; deny anything holding secrets, tokens, caches, or session state.

```gitignore
# --- <tool> module: allow ---
!<tool>/<name>/settings.json

# --- <tool> module: never track ---
<tool>/<name>/secrets/
<tool>/<name>/*.local.json
```

## Close-before-relink (Step 4 checkpoint)
- <Which running app(s) hold these files open and must be fully quit before Step 5.>

## Notes
- <Hardlink caveat if a file uses `5b`; any Settings-Sync / cloud-sync interaction; anything unusual.>

---

## Worked examples (delete after copying the one you need)

### VSCode
| Item | Live path | Repo path | Link type |
|------|-----------|-----------|-----------|
| User settings | `%APPDATA%\Code\User\settings.json` | `dotfiles\vscode\settings.json` | file |
| Keybindings | `%APPDATA%\Code\User\keybindings.json` | `dotfiles\vscode\keybindings.json` | file |
| Snippets | `%APPDATA%\Code\User\snippets` | `dotfiles\vscode\snippets` | directory |

Allowlist: `!vscode/settings.json`, `!vscode/keybindings.json`, `!vscode/snippets/**`. Nothing here is normally secret, but exclude any workspace tokens if present.
Close-before-relink: **VSCode** (all windows).
Note: VSCode has built-in **Settings Sync** (syncs to your MS/GitHub account across machines). It can coexist with dotfiles, but both write `settings.json` — pick **one** as the source of truth to avoid churn. If you rely on dotfiles, consider turning Settings Sync off for Settings (keep it for extensions if you like).

### GitHub Copilot
Copilot's editor behavior is configured by `github.copilot.*` keys **inside VSCode `settings.json`** — so the **VSCode module already covers it**. Only add a standalone Copilot module if you use the `gh copilot` CLI, whose config lives at `%USERPROFILE%\.config\gh\` (contains auth — track only non-secret config, deny `hosts.yml`).

### Git (global config)
| Item | Live path | Repo path | Link type |
|------|-----------|-----------|-----------|
| Global config | `%USERPROFILE%\.gitconfig` | `dotfiles\git\.gitconfig` | file |
| Global excludes | `%USERPROFILE%\.config\git\ignore` | `dotfiles\git\ignore` | file |

Allowlist: `!git/.gitconfig`, `!git/ignore`. **Never** track credential-helper stores or `.git-credentials` (plaintext tokens). Close-before-relink: none typically, but avoid running git operations mid-relink.
