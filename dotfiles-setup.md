# Dotfiles setup

This repository tracks selected durable configuration for Claude Code, Codex,
and VS Code. Credentials, sessions, caches, logs, memory, workspace state, and
other generated machine state stay local. Never link an application's entire
configuration directory.

## Managed paths

| Application | Live path | Repository source |
| --- | --- | --- |
| Claude Code | `~/.claude/dotfiles` | `claude/` |
| Claude Code | `~/.claude/CLAUDE.md` | `claude/CLAUDE.md` |
| Claude Code | `~/.claude/commands` | `claude/commands` |
| Claude Code | `~/.claude/rules` | `claude/rules` |
| Claude Code | `~/.claude/skills` | `claude/skills` |
| Codex | `~/.codex/AGENTS.md` | `codex/AGENTS.md` |
| Shared agents | `~/.agents/skills` | `agents/skills` |
| GitHub Copilot | `~/.copilot/agents` | `copilot/agents` |
| GitHub Copilot | `~/.copilot/instructions` | `copilot/instructions` |
| GitHub Copilot | `~/.copilot/skills` | `copilot/skills` |
| VS Code | user `settings.json` | `vscode/settings.json` |
| VS Code | user `keybindings.json` | `vscode/keybindings.json` |
| VS Code | user `mcp.json` | `vscode/mcp.json` |
| GitHub Copilot in VS Code | user `prompts/` | `copilot/prompts/` |
| Bash | `~/.bashrc` | `shell/bashrc` |
| Bash | `~/.bash_profile` | `shell/bash_profile` |

Claude's settings source is platform-specific: Windows links
`claude/settings.json`; macOS links `claude/settings.macos.json`.

VS Code's user directory is `%APPDATA%\Code\User` on Windows and
`~/Library/Application Support/Code/User` on macOS. The extension manifest is
`vscode/extensions.txt`; extension binaries are not tracked.

GitHub Copilot agents, instructions, and skills use the cross-editor
`~/.copilot` locations. VS Code user prompt files remain in the active VS Code
profile's user-data directory, but their repository source lives under
`copilot/prompts` to group assets by owner. `~/.copilot/config.json`, `ide/`, and
`logs/` remain local because Copilot manages them as runtime state.

The Bash configuration keeps the existing lazy NVM loading, Git completion,
navigation shortcuts, and terminal-size correction. Paths use `$HOME` so the
same source works in Git Bash and macOS Bash. macOS uses zsh by default, so
these files affect macOS only when Bash is launched; add a separately reviewed
`shell/zshrc` later if zsh customization is wanted.

Codex is intentionally different. `~/.codex/config.toml` mixes durable choices
with app-written paths, project trust, marketplace refresh data, notification
commands, and runtime hashes. The installers bootstrap a missing config from
`codex/config.shared.toml` (plus `codex/config.windows.toml` on Windows) but do
not link or overwrite an existing config. Review the tracked templates when you
want to reapply a durable change. Codex officially supports user config at
`~/.codex/config.toml` and trusted project overrides at `.codex/config.toml`.
Keep the canonical global instructions only at `~/.codex/AGENTS.md`. A separate
`~/AGENTS.md` is discovered as project-level instructions whenever Codex works
below your home directory and can therefore duplicate the global file; the
installer warns about it but does not delete an intentional project file.

User-authored Codex skills deliberately live under `agents/skills` in this
repository and link to `~/.agents/skills`; they do not belong in `~/.codex/skills`,
which also contains Codex's bundled `.system` skills. Codex discovers additions
automatically. In the CLI or IDE extension, run `/skills` or type `$` to select
a skill; restart Codex if a new or changed skill still does not appear. Large
skill sets can be shortened or partially omitted from the initial context list.

## Install on Windows

Install Git, Claude Code, Codex, and VS Code. Enable Windows Developer Mode so
an unelevated terminal can create symbolic links, or run PowerShell as
Administrator. From the repository root:

```powershell
.\setup-windows.ps1
```

The normal mode is no-overwrite. On the first migration of an existing machine,
use:

```powershell
.\setup-windows.ps1 -Migrate
```

Conflicting paths move to a timestamped directory under
`~/.dotfiles-backups/`; nothing is silently deleted. After verifying all apps,
you may remove that backup manually. Restore the tracked VS Code extension list
only when wanted:

On Windows PowerShell 5.1, the installer first tries `New-Item`, then falls back
to the native Windows symbolic-link API with Developer Mode's unprivileged flag.
This avoids requiring elevation when Developer Mode is active.

```powershell
.\setup-windows.ps1 -InstallVSCodeExtensions
```

## Install on macOS

Install Claude Code, Codex, VS Code, and `jq`, then run:

```bash
bash ./setup-macos.sh
```

For an existing machine or extension restoration:

```bash
bash ./setup-macos.sh --migrate
bash ./setup-macos.sh --install-vscode-extensions
```

The same no-overwrite and `~/.dotfiles-backups/` behavior applies. Claude
notifications use `osascript`; run the test printed by the installer and allow
Script Editor notifications in System Settings if necessary.

## Verify

On Windows:

```powershell
Get-Item -Force `
  "$env:USERPROFILE\.claude\settings.json", `
  "$env:USERPROFILE\.codex\AGENTS.md", `
  "$env:USERPROFILE\.agents\skills", `
  "$env:USERPROFILE\.copilot\agents", `
  "$env:USERPROFILE\.copilot\instructions", `
  "$env:USERPROFILE\.copilot\skills", `
  "$env:APPDATA\Code\User\settings.json", `
  "$env:APPDATA\Code\User\keybindings.json", `
  "$env:APPDATA\Code\User\mcp.json", `
  "$env:APPDATA\Code\User\prompts", `
  "$env:USERPROFILE\.bashrc", `
  "$env:USERPROFILE\.bash_profile" |
  Select-Object FullName, LinkType, Target
```

On macOS:

```bash
for path in \
  "$HOME/.claude/settings.json" \
  "$HOME/.codex/AGENTS.md" \
  "$HOME/.agents/skills" \
  "$HOME/.copilot/agents" \
  "$HOME/.copilot/instructions" \
  "$HOME/.copilot/skills" \
  "$HOME/Library/Application Support/Code/User/settings.json" \
  "$HOME/Library/Application Support/Code/User/keybindings.json" \
  "$HOME/Library/Application Support/Code/User/mcp.json" \
  "$HOME/Library/Application Support/Code/User/prompts" \
  "$HOME/.bashrc" \
  "$HOME/.bash_profile"; do
  printf '%s -> %s\n' "$path" "$(readlink "$path")"
done
```

Every reported target should exist inside this repository. Editing a managed
file through its live path should appear in `git status`. Run the installer a
second time to verify idempotency.

## Decide what Git should track

Track a file only when it expresses durable intent, is maintained by you, has
no secrets or account state, and is portable (or explicitly platform-specific).
Examples are instructions, rules, user-authored skills and prompts, keybindings,
secret-free settings, extension IDs, hook scripts, and setup scripts.

Ignore authentication, tokens, sessions, transcripts, auto memory, logs,
caches, backups, state databases, workspace storage, VS Code History and Sync
state, generated profiles, Codex marketplace caches and revisions, project trust
records, runtime executable paths and hashes, and Claude local overrides such as
`.claude/settings.local.json` or `CLAUDE.local.md`.

Prompted secret references are safe to track when the secret value is not in
the file. For example, `vscode/mcp.json` contains `${input:figma-api-key}` and a
password prompt definition, not the token itself. Re-scan diffs before every
commit. VS Code Settings Sync can also synchronize settings, keybindings, and
extensions; decide whether Git or Settings Sync is authoritative for each item
to avoid surprising merges.

References:

- [VS Code user settings and platform paths](https://code.visualstudio.com/docs/configure/settings)
- [VS Code Settings Sync](https://code.visualstudio.com/docs/configure/settings-sync)
- [Codex configuration reference](https://developers.openai.com/codex/config-reference/)
- [Codex AGENTS.md](https://developers.openai.com/codex/guides/agents-md/)

## Add another managed item

1. Apply the tracking test above and scan the candidate for secrets.
2. Add the narrowest necessary source path and ignore rules.
3. Add the corresponding mapping to both installers when cross-platform.
4. Update the managed-path table.
5. Run the installer twice and verify the application before deleting backups.
