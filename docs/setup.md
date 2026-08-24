# Dotfiles setup

This guide covers first-time installation on Windows or macOS. Recurring edits, additions,
removals, and applies belong in [the chezmoi workflow](./chezmoi-workflow.md).

The repository manages durable shell, VS Code, Claude Code, Codex, and GitHub Copilot
configuration. Credentials, sessions, caches, logs, memory, and workspace state stay local.

Chezmoi calls the desired files in its repository clone the **source state**. It renders
those files into live **targets** under your home directory when you run `chezmoi apply`.
For example, the source `home/dot_bashrc` renders to the target `~/.bashrc`.

## Choose a setup path

Choose based on the configuration already in the home directory:

| Machine state | Setup path |
| --- | --- |
| No shell, editor, or AI-client settings need to be preserved | [Empty machine](#empty-machine) |
| Any existing settings should survive, or you are unsure | [Existing configuration](#existing-configuration) |

A new computer can already have existing configuration if you used an application before
installing these dotfiles. When unsure, use the existing-configuration path. It initializes
the repository without changing live files.

## Common prerequisites

### Install Git and chezmoi

macOS with Homebrew:

```bash
brew install git chezmoi
```

Chezmoi's standalone installer is also available when Homebrew is not desired:

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)"
```

Windows PowerShell:

```powershell
winget install --id Git.Git --exact
winget install --id twpayne.chezmoi --exact
```

Restart the shell after Winget installation. The managed `.bashrc` adds Winget's command
shim directory to Git Bash after the first apply; use PowerShell for initial setup if Git
Bash cannot find `chezmoi` yet.

### Enable Windows symlink creation

Skip this step on macOS. Portable skills render as symbolic links under `~/.claude/skills`.
On Windows, enable **Developer Mode** before the first apply, or run the apply from an account
with `SeCreateSymbolicLinkPrivilege`. Without one of those, chezmoi cannot create the skill
links. See [chezmoi's Windows guidance](https://www.chezmoi.io/user-guide/machines/windows/#create-symlinks).

## Empty machine

Use this path only when no existing configuration needs to be preserved. On macOS or Git
Bash, the standalone installer can install chezmoi and apply the repository in one command:

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply sherrilla71940
```

If chezmoi is already installed, run:

```bash
chezmoi init --apply sherrilla71940
chezmoi source-path
chezmoi status
```

The source path should normally end in `~/.local/share/chezmoi/home`. Empty status output
means the managed targets match the source state.

## Existing configuration

Use this path to inspect and preserve existing settings before chezmoi writes any targets.

### 1. Initialize without applying

```bash
chezmoi init sherrilla71940
```

If you use a fork, replace `sherrilla71940` with the fork's URL or GitHub shorthand. Chezmoi
places the clone in its default source directory.

Immediately confirm that chezmoi is reading the expected clone:

```bash
chezmoi source-path
```

The result must identify this repository, either directly or through a symlink or Windows
junction. A displayed path ending in `~/.local/share/chezmoi/home` is valid when its resolved
target belongs to this repository. Compare filesystem or Git identity instead of displayed
path strings alone. If it identifies a different clone, stop and reconcile the source
directories before continuing.

### 2. Preview every target change

```bash
chezmoi diff
```

Every removed line is live configuration that apply would replace. Do not apply yet.

Useful safer variants:

| Command or flag | Behavior |
| --- | --- |
| `chezmoi apply --dry-run --verbose` | Show operations without writing |
| `chezmoi apply --interactive` | Prompt for every operation during the eventual apply |
| `chezmoi apply --less-interactive` | Prompt for changed or pre-existing targets during the eventual apply |

### 3. Adopt the settings you want to keep

Handle each changed target according to the desired result:

| Desired result | Action before applying |
| --- | --- |
| Use the repository version | Make no source change; the preview already shows what apply will replace |
| Preserve an entire plain file | Confirm `chezmoi source-path <target>` does not end in `.tmpl`, then run `chezmoi re-add <target>` |
| Preserve selected values | Open the live target and its source side by side, then copy only portable values into the source |
| Preserve values from a templated target | Edit the source template or shared body; `re-add` deliberately skips templates |

For example, to preserve an entire live `.bashrc`:

```bash
chezmoi source-path ~/.bashrc
chezmoi re-add ~/.bashrc
chezmoi git -- diff
```

To preserve selected VS Code settings, compare the live `settings.json` with
`home/.chezmoitemplates/vscode/settings.json` and copy only the settings that should follow
every machine. Do not copy credentials, caches, machine paths, or application-owned state.

`chezmoi merge <target>` can perform a three-way merge when a merge tool is configured.
Manual source editing is safer for this repository's templates because one rendered target
can combine a thin wrapper with a shared body.

After adopting settings, review both kinds of change:

```bash
chezmoi git -- diff   # changes you made to the repository source
chezmoi diff          # changes the next apply will make to live targets
```

Back up any irreplaceable live file outside its managed target path before continuing.

### 4. Apply and verify

```bash
chezmoi apply -v
chezmoi status
```

Empty status output means the managed targets match the source. Restart applications so they
reload their configuration.

If adoption changed the source, review and commit those portable changes so they follow the
other machines. Do not commit machine-specific values or credentials.

## Application installation and login

Chezmoi can write configuration before an application exists. Each application discovers its
files when it is installed and started later.

| Product surface | Installed separately? | Local follow-up |
| --- | --- | --- |
| VS Code with GitHub Copilot | Yes | Enable Copilot, sign in to GitHub, then install other desired extensions from the repository manifest |
| Claude Code CLI or IDE integration | Yes | Log in, authenticate connectors with `/mcp`, and install Claude in Chrome if desired |
| Claude Desktop | Optional | Its Code tab shares Claude Code configuration; desktop chat, Cowork, and chat-app MCP configuration remain separate |
| Codex CLI, IDE extension, or ChatGPT desktop app | Yes; install the surfaces you use | Log in and authenticate enabled connectors or plugins; local surfaces share `~/.codex/` configuration |
| GitHub Copilot command-line interface (CLI) | Yes | Install and log in separately; the CLI has its own settings and MCP configuration |
| Node Version Manager (NVM) and Node.js | Yes | The shell supports lazy-loaded NVM but does not install NVM or Node.js |

The post-clone bootstrap helper installs `jq` for the Claude Model Context Protocol (MCP)
installer and checks whether the VS Code CLI is available:

```bash
bash scripts/bootstrap-macos.sh
```

```powershell
powershell -File scripts/bootstrap-windows.ps1
```

### VS Code extensions

The extension manifest is intentionally separate from routine apply:

```bash
grep -v '^#' scripts/vscode-extensions.txt | grep . | xargs -n1 code --install-extension --force
```

```powershell
Get-Content scripts/vscode-extensions.txt | Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object { code --install-extension $_ --force }
```

### Claude user MCP servers

After Claude Code is installed, add the repository's direct user MCP servers with the
platform installer:

```bash
bash scripts/install-claude-mcp.sh
```

```powershell
powershell -File scripts/install-claude-mcp.ps1
```

The shell installer requires `jq`; the PowerShell installer does not. It leaves existing
server names unchanged because `~/.claude.json` also contains application-owned state. The
[MCP customization guide](./customization-support.md#add-an-mcp-server) explains what belongs
in the manifest and what remains owned by plugins, accounts, or browser integrations.

### Plugins

The repository carries portable plugin declarations for Codex and Copilot, and installs
Claude Code's plugins from `scripts/bootstrap-*` instead, so enabling and disabling them stays
local. It never carries downloaded caches or authentication. Follow the
[plugin customization guide](./customization-support.md#add-a-marketplace-plugin) for the
client-specific source and Codex's create-once behavior.

## Enable repository validation

Run once in each clone:

```bash
git config core.hooksPath scripts/git-hooks
```

The pre-commit hook:

1. confirms the default chezmoi source resolves inside this repository,
2. materializes and renders the staged Git snapshot,
3. checks skill file-count parity, shared Claude skill links, and Codex-targeted host gates,
4. compares rendered Claude and Copilot rule bodies with cross-platform tools, and
5. rejects YAML frontmatter in Codex's rendered `AGENTS.md`.

The hook renders only into a temporary directory. Its `--exclude=scripts` flag excludes
chezmoi-managed script entry types; it does not mean the top-level `scripts/` directory.

## Using a manually cloned `~/dotfiles`

Normal `chezmoi init` already creates the default source directory, so no link is required.
If you deliberately cloned the repository as `~/dotfiles`, make the default chezmoi source
point to it. Do this only when `~/.local/share/chezmoi` does not contain changes you need.

macOS or Git Bash with symlink permission:

```bash
mkdir -p ~/.local/share
ln -s ~/dotfiles ~/.local/share/chezmoi
```

Windows PowerShell can use a directory junction without elevated symlink permission:

```powershell
New-Item -ItemType Directory -Force "$HOME\.local\share" | Out-Null
New-Item -ItemType Junction -Path "$HOME\.local\share\chezmoi" -Target "$HOME\dotfiles"
```

Then verify:

```bash
chezmoi source-path
```

## Verification

```bash
chezmoi source-path  # this repository, directly or through a link
chezmoi status       # empty after apply
chezmoi doctor       # environment sanity
```

Then restart each AI client and inspect the customization relevant to the change. Detailed
client paths and verification steps live in [customization-support.md](./customization-support.md).

## Secrets and ownership boundaries

Never commit credentials. `${input:figma-api-key}` in VS Code's `mcp.json` is a prompt
definition, not a stored value. If a template eventually needs a real secret, use a chezmoi
secret source or an environment variable rather than committing it.

Chezmoi deliberately does not own complete application data directories, plugin caches,
sessions, authentication tokens, logs, VS Code workspace storage, Copilot runtime state, or
Codex's existing mixed-state `config.toml`. See
[ownership and app-written settings](./chezmoi-workflow.md#applications-that-write-their-own-configuration)
before importing a live application file.

## Version-sensitive references

| Item | Why it can drift | Verify |
| --- | --- | --- |
| Chezmoi source attributes and special files | Filename transformations affect rendered names | [Source attributes](https://www.chezmoi.io/reference/source-state-attributes/) and [special files](https://www.chezmoi.io/reference/special-files/) |
| Claude rules, skills, agents, and settings | Discovery paths and accepted fields evolve | [Claude Code documentation](https://code.claude.com/docs/en/overview) |
| Codex prompts, agents, config, and skills | Customization surfaces and deprecations evolve | [Codex customization](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| VS Code and Copilot customization | User folders and instruction discovery evolve | [VS Code agent customization](https://code.visualstudio.com/docs/agent-customization/overview) and [Copilot customization](https://docs.github.com/en/copilot/customizing-copilot) |
