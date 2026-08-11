# AI client customization support

This repository manages personal configuration for several local coding-agent clients. A
**surface** is one way to run a client, such as a terminal CLI, an IDE extension, or a
desktop app. Each surface can share some configuration with the others while keeping other
state separate.

The **Model Context Protocol (MCP)** connects a client to external tools and data sources.

## What the support table answers

The table answers: **If this repository manages a customization, which local surface reads
it?** It describes this repository's implementation, not every feature that each product
natively supports.

Paths beginning with `~/` in the table are live **targets** that applications read. Make
durable changes in the corresponding source files under this repository's `home/` directory;
the procedures below identify those source paths.

The columns group surfaces only when they read the same personal configuration:

- **Claude Code local:** Claude Code CLI, its IDE integrations, and the Code tab in Claude
  Desktop. These surfaces share Claude Code configuration under `~/.claude/` and
  `~/.claude.json`.
- **Codex local:** Codex CLI, the Codex IDE extension, and Codex in the ChatGPT desktop app.
  These surfaces share configuration under `~/.codex/`.
- **Copilot CLI** and **VS Code with Copilot:** These surfaces share personal instructions,
  skills, and agents under `~/.copilot/` but keep separate settings, prompts, and MCP files.

| Capability | Claude Code local | Codex local | Copilot CLI | VS Code with Copilot |
| --- | --- | --- | --- | --- |
| Always-on personal instructions | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.copilot/instructions/core-principles.instructions.md` with `applyTo: "**"` | the same personal `*.instructions.md` file |
| Instructions for this repository | root `CLAUDE.md` imports root `AGENTS.md` | root `AGENTS.md` | root `AGENTS.md` | root `AGENTS.md`, enabled by `chat.useAgentsMdFile` |
| Path-scoped instructions | `~/.claude/rules/` | not supported by Codex | `~/.copilot/instructions/*.instructions.md` | the same personal files, selected by `applyTo` |
| Portable shared skills | linked from `~/.agents/skills` | native `~/.agents/skills` discovery | native `~/.agents/skills` discovery | native `~/.agents/skills` discovery |
| Client-only skills | `~/.claude/skills/<name>` | no verified standalone path that stays hidden from Copilot | `~/.copilot/skills/<name>` | `~/.copilot/skills/<name>` |
| Agent definitions | custom subagents under `~/.claude/agents/` | custom agents under `~/.codex/agents/` | custom agents under `~/.copilot/agents/` | the same personal Copilot agents |
| Prompts or commands | `~/.claude/commands/` | standalone custom prompts are deprecated; use a skill | no dedicated Copilot CLI command; compatible Claude commands may also be discovered | prompt files in the VS Code user profile |
| Marketplace plugins | declarative `enabledPlugins` | defaults in create-once `config.toml` | declarative `enabledPlugins` with automatic installation | discovers enabled Copilot plugins when `chat.plugins.enabled` is true |
| User MCP servers | manifest plus hand-run installer protects app-owned `~/.claude.json` | defaults in create-once `config.toml` | `~/.copilot/mcp-config.json` | `mcp.json` in the VS Code user profile |
| General settings | managed `settings.json` | create-once app-owned `config.toml` | managed `~/.copilot/settings.json` | managed VS Code user `settings.json` |

Add an agent or client-only skill only when it has a concrete purpose. Empty prepared
directories exist only where a client requires the directory before a session starts.

### Surfaces outside this table

This repository does not manage complete product or account state:

- Claude Desktop chat and Cowork do not consume every Claude Code file listed above. In
  particular, MCP servers configured for the desktop chat app are separate from the Code
  tab.
- Claude.ai connectors, authentication, conversations, and account settings remain with the
  signed-in account.
- Codex cloud receives repository files such as root `AGENTS.md` when the repository is
  available to the cloud task. It does not receive personal files from this machine's
  `~/.codex/` directory through chezmoi.
- Copilot cloud features can read supported files committed inside a repository. This
  dotfiles setup does not copy personal `~/.copilot/` runtime state into GitHub.

## Add an agent definition

- Claude Code: add `home/dot_claude/agents/<name>.md`.
- Codex: add `home/dot_codex/agents/<name>.toml`.
- Copilot: add `home/dot_copilot/agents/<name>.agent.md`.

Use each client's native schema. Agents are client-specific unless current official
documentation confirms that every field and behavior is portable.

The clients use overlapping terminology for related concepts:

- Claude Code calls files in `agents/` **custom subagents**.
- Codex calls them **custom agents** and uses them when spawning subagent sessions.
- Copilot calls them **custom agents**; its main agent can select one directly or run one as
  a **subagent** with a separate context.

## Add a prompt or command

- Claude Code commands go in `home/dot_claude/commands/`.
- VS Code prompt files have one body under `home/.chezmoitemplates/vscode/` and thin
  OS-specific wrappers in the VS Code profile trees.
- Do not create `home/dot_codex/prompts/`; Codex standalone custom prompts are deprecated.
  Create a skill for a reusable Codex workflow.

VS Code can discover instruction files from several user folders, including Claude's. This
repository disables `~/.claude/rules` in `chat.instructionsFilesLocations` and disables
`chat.useClaudeMdFile`, so Copilot receives the managed Copilot wrappers once without also
loading Claude-only instructions. Keep those exclusions when changing VS Code settings.

## Add an MCP server

### Claude Code

User-scoped MCP configuration shares `~/.claude.json` with authentication, project state,
and caches, so chezmoi must not overwrite that file. Add a non-secret definition to
`scripts/claude-user-mcp-servers.json`, then run the platform installer:

```bash
bash scripts/install-claude-mcp.sh
```

```powershell
powershell -File scripts/install-claude-mcp.ps1
```

The installer adds missing definitions with `claude mcp add-json --scope user` and leaves an
existing server of the same name unchanged for manual review. Authentication remains local.

That manifest intentionally contains only directly configured user MCP servers. Claude can
show additional MCP-backed tools from other sources, and those should stay with their owner:

| Source | This setup | How it follows machines |
| --- | --- | --- |
| Direct user MCP | Chrome DevTools | the manifest and hand-run installer |
| Enabled Claude plugin | Figma and Playwright MCP servers | `enabledPlugins` in the managed Claude settings |
| Claude.ai connector | Figma and Slack | the signed-in Claude account; authenticate through `/mcp` |
| Claude in Chrome | browser tools exposed by the Chrome extension integration | install the extension, then use `/chrome`; its onboarding and enablement state is app-owned |

Do not duplicate a plugin server, Claude.ai connector, or Claude in Chrome integration in the
user manifest merely because it appears in `/mcp`. Run `claude mcp list` or `/mcp` to inspect
the combined effective set.

### Codex

Add non-secret defaults to `home/dot_codex/create_config.toml.tmpl`. They reach a new machine
only when `~/.codex/config.toml` does not exist. For an existing live config, compare the
desired blocks and merge only what is missing; do nothing when those declarations are already
present. Never replace the complete live file, because Codex also writes marketplace metadata,
runtime paths, project trust, and other machine state there. Complete authentication locally.

### GitHub Copilot

Add CLI-compatible servers to `home/dot_copilot/mcp-config.json`. Add VS Code servers to
`home/.chezmoitemplates/vscode/mcp.json` when the IDE also needs them. The schemas and input
mechanisms differ, so share a server definition only when both clients support its fields.

## Add a marketplace plugin

Here, **declarative** means the repository records which plugin should be enabled, while the
client downloads and manages the plugin files. The downloaded cache is not copied into the
dotfiles repository.

- Claude Code: add its marketplace if needed and its plugin ID to `enabledPlugins` in
  `home/dot_claude/settings.json.tmpl`.
- Codex: add its marketplace and plugin defaults to
  `home/dot_codex/create_config.toml.tmpl`; merge only missing declarations into an existing
  app-owned config.
- Copilot: add the plugin specification to `enabledPlugins` in
  `home/dot_copilot/settings.json`. Copilot CLI declaratively installs enabled plugins, and
  VS Code discovers the resulting installation.

Prefer editing the source declaration before installing. If Copilot CLI has already added a
plugin to the live `~/.copilot/settings.json`, preserve it before the next apply:

```bash
chezmoi diff
chezmoi re-add ~/.copilot/settings.json
```

Review the source diff before committing. This works because Copilot's settings file is a
plain managed file, not a template. For Claude's templated settings and Codex's create-once
config, follow the client-specific steps above instead.

Never copy plugin caches, installed-plugin directories, authentication tokens, or client
runtime state into `home/`.

## Verify after applying

- Claude Code: run `claude mcp get chrome-devtools`, then inspect `/agents`, `/skills`, and
  `/plugins` in a new session as relevant to the change.
- Codex: start a new session and inspect its agents, skills, plugins, or MCP tools. Existing
  `~/.codex/config.toml` files need the documented comparison; merge only when the desired
  declaration is missing.
- Copilot CLI: inspect `~/.copilot/settings.json` and `~/.copilot/mcp-config.json`, then start
  a new session. In VS Code, use **Chat: Open Customizations** for agents, instructions,
  prompts, and skills.

## Official references

- [Claude Code Desktop and shared configuration](https://code.claude.com/docs/en/desktop)
- [Claude Code IDE integrations](https://code.claude.com/docs/en/ide-integrations)
- [Claude Code custom subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code MCP sources](https://code.claude.com/docs/en/mcp)
- [Claude Code with Chrome](https://code.claude.com/docs/en/chrome)
- [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Codex custom agents and subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [VS Code custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)
- [VS Code custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents)
- [VS Code agent skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Copilot CLI configuration directory](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference)
- [GitHub Copilot custom agents](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-custom-agents)
