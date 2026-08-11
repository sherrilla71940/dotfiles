# Dotfiles setup

This guide covers first-time installation on Windows or macOS. Recurring edits, additions,
removals, and applies belong in [the chezmoi workflow](./chezmoi-workflow.md).

The repository manages durable shell, VS Code, Claude Code, Codex, and GitHub Copilot
configuration. Credentials, sessions, caches, logs, memory, and workspace state stay local.

Chezmoi calls the desired files in its repository clone the **source state**. It renders
those files into live **targets** under your home directory when you run `chezmoi apply`.
For example, the source `home/dot_bashrc` renders to the target `~/.bashrc`.

## Onboarding a new machine

> **`chezmoi apply` can replace existing configuration.** Do not start with
> `chezmoi init --apply` on a machine that has settings to preserve. Initialize, verify the
> source directory, and review `chezmoi diff` first.

### Setup sequence

| Order | Requirement | Why it comes first |
| --- | --- | --- |
| 1 | Git and chezmoi | Required to initialize and version the source repository |
| 2 | This repository | Created by `chezmoi init`; a separate clone is unnecessary |
| 3 | Source-path verification and diff | Prevents applying a stale clone or overwriting existing settings |
| 4 | `chezmoi apply` | Writes the reviewed source state into the home directory |
| 5 | Applications and authentication | Lets each application load the managed files; credentials remain local |

### Step 1 — install Git and chezmoi

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

### Step 2 — enable Windows symlink creation

Skip this step on macOS. Portable skills render as symbolic links under `~/.claude/skills`.
On Windows, enable **Developer Mode** before the first apply, or run the apply from an account
with `SeCreateSymbolicLinkPrivilege`. Without one of those, chezmoi cannot create the skill
links. See [chezmoi's Windows guidance](https://www.chezmoi.io/user-guide/machines/windows/#create-symlinks).

### Step 3 — initialize without applying

```bash
chezmoi init https://github.com/sherrilla71940/dotfiles.git
```

If you use a fork, replace the URL. Chezmoi places the clone in its default source directory.

Immediately confirm that chezmoi is reading the expected clone:

```bash
chezmoi source-path
```

The result must end inside this repository, normally
`~/.local/share/chezmoi/home`. If it points at a different clone, stop and reconcile the
source directories before continuing.

### Step 4 — preview

```bash
chezmoi diff
```

Every removed line is live configuration that apply would replace. Back up anything you need
or incorporate it into the source first.

Useful safer variants:

| Command or flag | Behavior |
| --- | --- |
| `chezmoi apply --dry-run --verbose` | Show operations without writing |
| `chezmoi apply --interactive` | Prompt for every operation |
| `chezmoi apply --less-interactive` | Prompt for changed or pre-existing targets |

### Step 5 — apply

```bash
chezmoi apply -v
chezmoi status
```

Empty status output means the managed targets match the source. Restart applications so they
reload their configuration.

### Genuinely empty machines only

When there is certainly no existing configuration to preserve, initialization and apply can
be combined:

```bash
chezmoi init --apply https://github.com/sherrilla71940/dotfiles.git
```

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

Claude stores user MCP definitions inside app-owned `~/.claude.json`, so chezmoi must not
replace that file. After Claude Code is installed, add missing direct user servers with:

```bash
bash scripts/install-claude-mcp.sh
```

```powershell
powershell -File scripts/install-claude-mcp.ps1
```

The shell installer requires `jq`; the PowerShell installer does not. Existing server names
are left unchanged. Plugin MCP servers, Claude.ai connectors, and Claude in Chrome remain
owned by their respective plugin, account, or browser integration. See the
[customization support guide](./customization-support.md#add-an-mcp-server).

### Plugins

The repository carries portable plugin declarations, not downloaded caches or authentication.
Claude and Copilot settings are managed directly. Codex uses create-once defaults and requires
only missing declarations to be merged into an existing config. See
[the plugin workflow](./chezmoi-workflow.md#installing-a-third-party-plugin).

## Enable repository validation

Run once in each clone:

```bash
git config core.hooksPath scripts/git-hooks
```

The pre-commit hook:

1. confirms the default chezmoi source resolves inside this repository,
2. materializes and renders the staged Git snapshot,
3. checks skill file-count parity and individual Claude skill links,
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
chezmoi source-path  # inside this repository
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
[ownership and app-written settings](./chezmoi-workflow.md#apps-that-write-their-own-config)
before importing a live application file.

## Version-sensitive references

| Item | Why it can drift | Verify |
| --- | --- | --- |
| Chezmoi source attributes and special files | Filename transformations affect rendered names | [Source attributes](https://www.chezmoi.io/reference/source-state-attributes/) and [special files](https://www.chezmoi.io/reference/special-files/) |
| Claude rules, skills, agents, and settings | Discovery paths and accepted fields evolve | [Claude Code documentation](https://code.claude.com/docs/en/overview) |
| Codex prompts, agents, config, and skills | Customization surfaces and deprecations evolve | [Codex customization](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| VS Code and Copilot customization | User folders and instruction discovery evolve | [VS Code agent customization](https://code.visualstudio.com/docs/agent-customization/overview) and [Copilot customization](https://docs.github.com/en/copilot/customizing-copilot) |
