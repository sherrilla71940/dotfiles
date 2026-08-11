# Agent customization support

This repository manages personal configuration for Claude Code, Codex, GitHub Copilot CLI,
and VS Code with GitHub Copilot. The tools support different customization surfaces, so
"supported" does not always mean the same file shape or installation mechanism.

## Support matrix

| Capability | Claude Code | Codex | GitHub Copilot |
| --- | --- | --- | --- |
| Always-on instructions | managed `CLAUDE.md` | managed `AGENTS.md` | managed user instructions and repository `AGENTS.md` |
| Path-scoped instructions | managed rules | not supported by Codex | managed instructions |
| Portable shared skills | linked from `~/.agents/skills` | native `~/.agents/skills` discovery | native `~/.agents/skills` discovery |
| Client-only skills | `~/.claude/skills/<name>` | no verified standalone path that stays hidden from Copilot | `~/.copilot/skills/<name>` |
| Agent definitions | custom subagents under `~/.claude/agents/` | custom agents under `~/.codex/agents/`, used for subagent delegation | custom agents under `~/.copilot/agents/`, selectable directly or invoked as subagents |
| Prompts/commands | managed commands | standalone custom prompts are deprecated; use a skill | managed VS Code prompts |
| Marketplace plugins | declarative `enabledPlugins` | defaults in create-once `config.toml` | declarative `enabledPlugins` with auto-install |
| User MCP servers | manifest plus hand-run installer protects app-owned `~/.claude.json` | defaults in create-once `config.toml` | managed CLI `mcp-config.json` plus VS Code `mcp.json` |
| General settings | managed `settings.json` | create-once app-owned `config.toml` | managed CLI and VS Code settings |

Prepared directories contain no dummy customization. Add a real agent or client-only skill
only when it has a concrete purpose.

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

## Add an MCP server

### Claude Code

User-scoped MCP configuration shares `~/.claude.json` with OAuth, project state, and caches,
so chezmoi must not overwrite that file. Add a non-secret definition to
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

Never copy plugin caches, installed-plugin directories, OAuth tokens, or client runtime state
into `home/`.

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

- [Claude Code custom subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code MCP sources](https://code.claude.com/docs/en/mcp)
- [Claude Code with Chrome](https://code.claude.com/docs/en/chrome)
- [Codex custom agents and subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [GitHub Copilot custom agents](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-custom-agents)
