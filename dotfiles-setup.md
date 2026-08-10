# Dotfiles setup

This repository tracks selected durable configuration for Claude Code, Codex,
GitHub Copilot, VS Code, and shell environments across Windows and macOS.
Credentials, sessions, caches, logs, memory, workspace state, and other generated
machine state stay local. Never link an application's entire configuration
directory.

Both installers accept a component list so a machine can be configured for only
the applications installed on it; see [Selecting components](#selecting-components).

## Managed paths

| Component | Application | Live path | Repository source |
| --- | --- | --- | --- |
| `claude` | Claude Code | `~/.claude/dotfiles` | `claude/` |
| `claude` | Claude Code | `~/.claude/CLAUDE.md` | `claude/CLAUDE.md` |
| `claude` | Claude Code | `~/.claude/commands` | `claude/commands` |
| `claude` | Claude Code | `~/.claude/rules` | `claude/rules` |
| `claude` | Claude Code | `~/.claude/settings.json` | `claude/settings.json` (macOS: `claude/settings.macos.json`) |
| `claude` | Claude Code | `~/.claude/skills` | `claude/skills` |
| `codex` | Codex | `~/.codex/AGENTS.md` | `codex/AGENTS.md` |
| `codex` | Shared agents | `~/.agents/skills` | `agents/skills` |
| `copilot` | GitHub Copilot | `~/.copilot/agents` | `copilot/agents` |
| `copilot` | GitHub Copilot | `~/.copilot/instructions` | `copilot/instructions` |
| `copilot` | GitHub Copilot | `~/.copilot/skills` | `copilot/skills` |
| `vscode` | VS Code | user `settings.json` | `vscode/settings.json` |
| `vscode` | VS Code | user `keybindings.json` | `vscode/keybindings.json` |
| `vscode` | VS Code | user `mcp.json` | `vscode/mcp.json` |
| `vscode` | GitHub Copilot in VS Code | user `prompts/` | `copilot/prompts/` |
| `shell` | Bash | `~/.bashrc` | `shell/bashrc` |
| `shell` | Bash | `~/.bash_profile` | `shell/bash_profile` |

Claude's settings source is platform-specific: Windows links
`claude/settings.json`; macOS links `claude/settings.macos.json`.

VS Code's user directory is `%APPDATA%\Code\User` on Windows and
`~/Library/Application Support/Code/User` on macOS. The extension manifest is
`vscode/extensions.txt`; extension binaries are not tracked.

### Why each customization type lives where it does

The four Copilot customization types are distinct and are **not** interchangeable;
none of them may be flattened into the VS Code `prompts` directory.

- **Custom agents** (`*.agent.md`) stay in `~/.copilot/agents`. When Agent Host
  is enabled, VS Code reads user-level agents from `~/.copilot/agents` and *not*
  from VS Code profile user data, so this is the portable location. The
  `.agent.md` suffix is required for discovery.
- **Instructions** (`*.instructions.md`) stay in `~/.copilot/instructions`, one
  of the harness-agnostic user-level folders VS Code reads (alongside
  `~/.claude/rules`). Discovery requires the `.instructions.md` suffix; the
  optional `applyTo` glob scopes a file to matching files.
- **Skills** stay as complete directories in `~/.copilot/skills`. Each skill is a
  folder whose name matches the `name` in its `SKILL.md` frontmatter, and a skill
  may bundle scripts, examples, and reference files. Linking the whole `skills`
  directory (rather than individual Markdown files) is what keeps those bundled
  resources reachable.
- **Prompt files** (`*.prompt.md`) are the exception: they live in the active VS
  Code profile's user-data `prompts/` directory, not under `~/.copilot`. Their
  repository source stays at `copilot/prompts` so Copilot-owned assets remain
  grouped together.

`~/.copilot/config.json`, `~/.copilot/ide/`, and `~/.copilot/logs/` remain local
and untracked because Copilot manages them as runtime state. Only the three
customization subdirectories are linked, so Copilot's own files are never
touched; `copilot/.gitignore` also excludes them defensively. The installers
report these paths as `LOCAL` so their presence is visible but unmanaged.

### MCP configuration: one source at `vscode/mcp.json`

Tracked source `vscode/mcp.json` → live `%APPDATA%\Code\User\mcp.json` (Windows)
or `~/Library/Application Support/Code/User/mcp.json` (macOS). There is exactly
one tracked file and one symlink.

VS Code supports two candidate locations, and the deciding factor is this
configuration's use of interactive inputs:

- `~/.copilot/mcp-config.json` is read natively by the Agent Host and is the more
  portable choice **for configurations that do not need interactive input**.
- The VS Code profile `mcp.json` is what supports the `inputs` array and
  `${input:...}` variables, because VS Code itself renders the prompt and caches
  the entered value.

VS Code forwards configured servers to the Agent Host **except servers that
require interactive input**, and the documented guidance for
`~/.copilot/mcp-config.json` is to configure servers there *without* input
variable references. This configuration depends on `${input:...}` for both active
stdio servers — `${input:figma-api-key}` (a `password` prompt for the Figma token)
and `${input:allowed_dirs}` — so moving it to `~/.copilot/mcp-config.json` would
break the secret prompt and force the token to be hardcoded or supplied through
the environment. Keeping secrets out of the repository outweighs Agent Host
portability here, so the profile-level `mcp.json` is the correct target.
`chat.agentHost.enabled` is also not set in the tracked `vscode/settings.json`,
so Agent Host is not currently in use on this machine.

If Agent Host is adopted later and these servers are reworked to read credentials
from the environment instead of `${input:...}`, move the single source to
`~/.copilot/mcp-config.json` and update the one link — do not create a second
file. Two independently editable MCP configurations would silently diverge.

Because prompts and `mcp.json` both live in VS Code's profile directory while
agents, instructions, and skills live under `~/.copilot`, **a full
Copilot-in-VS-Code setup needs both the `copilot` and `vscode` components.**

### Bash

The Bash configuration keeps the existing lazy NVM loading, Git completion,
navigation shortcuts, and terminal-size correction. Paths use `$HOME` so the
same source works in Git Bash and macOS Bash. macOS uses zsh by default, so
these files affect macOS only when Bash is launched; add a separately reviewed
`shell/zshrc` later if zsh customization is wanted.

### Codex

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

## Prerequisites

1. **Clone this repository anywhere.** No path is hardcoded. Both installers
   resolve repository sources from the script's own location, and resolve home and
   application-data directories from environment variables (`%USERPROFILE%`,
   `%APPDATA%`, `$HOME`) or standard OS conventions.
2. **Installing the relevant applications first is recommended**, because it lets
   the installers validate the commands they expect (`git`, `jq`, `osascript`,
   `code`) and confirms the real profile location before anything is linked.
3. Installation is **not an absolute requirement**. Where the standard
   configuration directory can safely be created before first launch, the
   installer creates it — `~/.claude`, `~/.codex`, `~/.agents`, `~/.copilot`, and
   VS Code's user directory are all safe to pre-create, and the application picks
   up the linked files on first run. Only the selected components' directories are
   created.
4. On Windows, enable Developer Mode so an unelevated terminal can create symbolic
   links, or run PowerShell as Administrator.

**Restart each application after links change.** Running editors and CLIs cache
these files at startup and will not notice a swapped symlink.

## Selecting components

Both installers configure application groups selectively. The components are
`claude`, `codex`, `copilot`, `vscode`, `shell`, and `all`. **Omitting the option
means `all`**, which preserves the original behavior. Unknown names are rejected
with the valid list. Only the selected components' directories and links are
created; nothing belonging to an unselected component is touched.

Pick the components matching the applications actually installed on the machine.
Remember that **Copilot in VS Code needs both `copilot` and `vscode`**: agents,
instructions, and skills go to `~/.copilot`, while prompt files and `mcp.json`
belong to VS Code's profile directory.

`-Migrate` / `--migrate` is needed only when a live path already exists and is
**not** already the intended symlink — typically the first run on a machine that
has real configuration files. Without it the installer refuses to replace
anything, printing the live path, what it currently resolves to, and the intended
source. With it, the conflicting path is moved into a timestamped directory under
`~/.dotfiles-backups/` before the link is created; nothing is deleted, and if link
creation then fails the backup is moved back. A path that is already the correct
link reports `OK` and needs no migration, so reruns never require `-Migrate`.

## Install on Windows

From the repository root:

```powershell
# Everything (default)
.\setup-windows.ps1

# Only Copilot and VS Code
.\setup-windows.ps1 -Components copilot,vscode

# First run on a machine with existing real config files
.\setup-windows.ps1 -Components copilot,vscode -Migrate

# Restore the tracked extension list (requires the vscode component)
.\setup-windows.ps1 -Components vscode -InstallVSCodeExtensions
```

On Windows PowerShell 5.1, the installer first tries `New-Item`, then falls back
to the native Windows symbolic-link API with Developer Mode's unprivileged flag.
This avoids requiring elevation when Developer Mode is active.

## Install on macOS

```bash
# Everything (default)
bash ./setup-macos.sh

# Only Copilot and VS Code
bash ./setup-macos.sh --components copilot,vscode

# First run on a machine with existing real config files
bash ./setup-macos.sh --components copilot,vscode --migrate

# Restore the tracked extension list (requires the vscode component)
bash ./setup-macos.sh --components vscode --install-vscode-extensions
```

The same no-overwrite and `~/.dotfiles-backups/` behavior applies. Required
commands are checked per component: `jq` for `codex`, `osascript` for `claude`.
Claude notifications use `osascript`; run the test printed by the installer and
allow Script Editor notifications in System Settings if necessary.

## VS Code profiles

Both installers target the **default** profile, whose files live directly in
`%APPDATA%\Code\User` (Windows) and `~/Library/Application Support/Code/User`
(macOS).

Named profiles are different: VS Code stores each one under a generated
subdirectory of `.../Code/User/profiles/<id>`, where `<id>` is an opaque
identifier, not the profile's display name. The installers deliberately do not
guess a profile ID — linking into the wrong one would silently appear to succeed
while the customizations never load. If you adopt a named profile, that warrants
an explicit future enhancement (an option that takes the profile directory
directly) rather than inference. Note that agents, instructions, and skills are
unaffected, because `~/.copilot` is profile-independent; only prompt files and
`mcp.json` are profile-scoped.

Linux is intentionally not supported. Its VS Code user directory
(`~/.config/Code/User`) would be straightforward, but the shell, Claude settings
variant, and Codex bootstrap paths would all need review, which is more than a
clean addition.

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

Adjust the listed paths to the components you actually installed. Every reported
target should exist inside this repository — a link whose target is missing is a
broken source reference, not a working link. Editing a managed file through its
live path should appear in `git status`. Run the installer a second time to verify
idempotency: every managed path should report `OK` and nothing should change.

### Verify Copilot discovery inside VS Code

Symlinks only prove the files are reachable; these steps confirm VS Code actually
discovers them. Restart VS Code first.

1. **Chat: Open Customizations** — run it from the Command Palette to list the
   discovered agents, instructions, skills, and prompt files.
2. **Chat view → Diagnostics** — shows which customization files were loaded for a
   request, which is how you confirm an `applyTo` glob matched.
3. **MCP: List Servers** — confirms the servers from `mcp.json` are registered.
   Starting the `framelinkFigma` or `filesystem` server should prompt for its
   `${input:...}` value; the Figma prompt must mask the token.

Expected discovery counts: 6 agents, 10 instruction files, 13 skills, 4 prompt
files. Every file in `copilot/instructions` uses the `.instructions.md` suffix, so
a file appearing in that folder but missing from the Customizations list means its
name or frontmatter is wrong.

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
password prompt definition, not the token itself — this is precisely the property
that decided the MCP location above. Re-scan diffs before every commit. VS Code
Settings Sync can also synchronize settings, keybindings, and extensions; decide
whether Git or Settings Sync is authoritative for each item to avoid surprising
merges.

References:

- [VS Code user settings and platform paths](https://code.visualstudio.com/docs/configure/settings)
- [VS Code profiles](https://code.visualstudio.com/docs/configure/profiles)
- [VS Code custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents)
- [VS Code custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)
- [VS Code agent skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [VS Code prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files)
- [VS Code MCP servers](https://code.visualstudio.com/docs/agent-customization/mcp-servers)
- [VS Code MCP configuration reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)
- [VS Code Settings Sync](https://code.visualstudio.com/docs/configure/settings-sync)
- [Codex configuration reference](https://developers.openai.com/codex/config-reference/)
- [Codex AGENTS.md](https://developers.openai.com/codex/guides/agents-md/)

## Add another managed item

1. Apply the tracking test above and scan the candidate for secrets.
2. Add the narrowest necessary source path and ignore rules.
3. Confirm the live location against current official documentation rather than
   assuming, especially for Copilot: `~/.copilot` and VS Code's profile directory
   own different customization types.
4. Add the corresponding mapping to both installers when cross-platform, tagging it
   with the owning component (`Component = "..."` on Windows, the matching
   `component_selected` block on macOS).
5. Update the managed-path table, including the component column.
6. Run the installer twice and verify the application before deleting backups.
