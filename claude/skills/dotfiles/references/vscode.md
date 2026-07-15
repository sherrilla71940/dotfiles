# Module: vscode

Tool module for the [`dotfiles`](../SKILL.md) skill. Invoke with `/dotfiles <os> vscode`. Run the shared engine (Steps 1–7 in `SKILL.md`) using the values below. Repo subfolder: `~/dotfiles/vscode/` (or `%USERPROFILE%\dotfiles\vscode\` on Windows).

## Applies to

- **VSCode** user settings, keybindings, and snippets — the per-user config shared across all workspaces.
- Workspace-level `.vscode/` folders are intentionally excluded — those belong in each project's own repo.

## Managed items

| Item | Live path — Windows | Live path — Mac | Live path — Linux | Live path — WSL | Repo path | Link type | Required? |
| ---- | ------------------- | --------------- | ----------------- | --------------- | --------- | --------- | --------- |
| User settings | `%APPDATA%\Code\User\settings.json` | `~/Library/Application Support/Code/User/settings.json` | `~/.config/Code/User/settings.json` | `~/.config/Code/User/settings.json` ¹ | `dotfiles/vscode/settings.json` | file | yes |
| Keybindings | `%APPDATA%\Code\User\keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` | `~/.config/Code/User/keybindings.json` | `~/.config/Code/User/keybindings.json` ¹ | `dotfiles/vscode/keybindings.json` | file | no |
| Snippets dir | `%APPDATA%\Code\User\snippets` | `~/Library/Application Support/Code/User/snippets` | `~/.config/Code/User/snippets` | `~/.config/Code/User/snippets` ¹ | `dotfiles/vscode/snippets` | directory | no |

> ¹ **WSL:** if you run `code` from inside WSL, it uses the WSL-native config paths above. If you only run VSCode on the Windows side and remote into WSL via the Remote-WSL extension, the config lives on Windows at `%APPDATA%\Code\User\` and WSL has no separate copy to track.

## `.gitignore` allowlist lines (append to repo-root `.gitignore`)

```gitignore
# --- vscode module: allow ---
!vscode/settings.json
!vscode/keybindings.json
!vscode/snippets/**

# --- vscode module: never track ---
vscode/settings.json.bak
vscode/keybindings.json.bak
```

## Close-before-relink (Step 4 checkpoint)

- **All VSCode windows** — including any that have this file open. VSCode holds `settings.json` open and rewrites it; relinking while it's live can corrupt the file.

## Notes

- **Settings Sync conflict:** VSCode has a built-in **Settings Sync** feature (syncs to your Microsoft or GitHub account). It and dotfiles both write `settings.json` — running both creates a tug-of-war. Pick **one** as the source of truth. Recommended: use dotfiles for settings, and optionally keep Settings Sync active only for extensions list (`syncExtensions: true`, everything else off).
- **Hardlink caveat (Windows 5b):** VSCode rewrites `settings.json` and `keybindings.json` atomically (write-new, rename-over-old), which breaks hardlinks (`mklink /H`). If you use the cmd fallback on Windows, prefer a junction for the snippets directory (no hardlink issue) and accept that file links may desync — re-create them periodically. Use Dev-Mode symlinks (`5a`) for files whenever possible.
- **Insider / Cursor / Windsurf variants:** if you use VSCode Insiders, Cursor, or Windsurf, their user config lives in a parallel directory (`Code - Insiders`, `Cursor`, `Windsurf`). You can add rows for them in this module or create a separate module per editor — the tracked files are identical in structure.
- **Extensions are not tracked here:** extension installs live outside the User config dir and are large. If you want to sync them, export a list: `code --list-extensions > dotfiles/vscode/extensions.txt` and commit that file (add `!vscode/extensions.txt` to the allowlist). Restore with `cat dotfiles/vscode/extensions.txt | xargs -L1 code --install-extension`.
