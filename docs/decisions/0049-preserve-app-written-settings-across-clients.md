# ADR-0049: Preserve app-written settings across client configuration files

- Status: Accepted
- Date: 2026-10-06

## Context

Several clients let users add or change settings through the application. A whole-file chezmoi
source erases those app-written values at the next apply unless every change is first copied into
the repository. The user wants the repository to own only the settings it names and let each
application retain the rest.

VS Code writes user settings, keyboard shortcuts, and Model Context Protocol (MCP) server
configuration through its UI and command-line tools. GitHub Copilot CLI writes user settings
through `/settings` and MCP server configuration through `/mcp add`. Claude Code and Windows
Terminal already merge explicit durable settings. Codex creates its mixed-state `config.toml`
only when the target does not exist; its hook browser reviews and trusts hook definitions while
trust state is stored separately.

## Decision

- Keep VS Code and Copilot CLI durable values in shared sources under
  `home/.chezmoitemplates/{vscode,copilot}/`.
- Use `modify_` templates to merge repository values over each live target. Repository values
  win key or server-name collisions; values absent from the source remain app-owned.
- Merge VS Code MCP server definitions by server name and inputs by `id`. Repository inputs win
  duplicate IDs; app-added server names and input IDs survive.
- Keep repository VS Code keybindings once at the start of the rendered rules, followed by
  app-authored rules. VS Code evaluates user rules from bottom to top, so an app-authored rule
  can override a repository binding. The template removes exact copies of repository rules from
  the live list before appending it, which prevents duplicates on later applies.
- Treat arrays inside a repository-owned settings key or MCP server definition as complete
  values. The per-entry merge rules above apply only to VS Code keybindings and MCP inputs.
- Parse JSONC with chezmoi and serialize formatted JSON. App values survive, but comments and
  formatting in live JSONC files are normalized on apply.
- Keep Codex's create-once config and hook definition files under their existing ownership
  rules. Claude Code keeps its existing modify-template rules. Windows Terminal action IDs and
  key chords use per-entry ownership, as recorded in ADR-0050.

## Alternatives considered

- **Keep the files wholly managed:** rejected because adding a setting or server through a client
  can silently remove it on the next apply.
- **Stop managing app-written files:** rejected because portable repository settings would no
  longer have a reviewable source.
- **Merge every array wholesale:** rejected because it would discard app-defined keybindings or
  MCP inputs and could change client behavior.

## Consequences

Users can change settings or add servers through VS Code and Copilot CLI without editing the
repository before every apply. To share an app-added value across machines, add it to the
corresponding durable source. Editing a repository-owned setting in an app remains temporary
unless the user also updates the source, except for VS Code keybindings where live app rules are
ordered after repository defaults and can override them.

The first apply normalizes comments and formatting in affected JSONC files. Repository-owned
values remain visible and reviewable in the durable source; app-owned values remain in the live
target.

## Reconsider when

- VS Code or Copilot changes the user configuration paths or save behavior.
- A keybinding or MCP input format no longer has a stable per-entry identity.
- JSONC comment preservation becomes necessary or serialization causes repeated disruptive
  churn.
- Another supported application exposes an app-written configuration file with the same
  ownership problem.

## Related files and verification

- [`home/.chezmoitemplates/vscode/settings-durable.json`](../../home/.chezmoitemplates/vscode/settings-durable.json)
- [`home/.chezmoitemplates/vscode/keybindings.json`](../../home/.chezmoitemplates/vscode/keybindings.json)
- [`home/.chezmoitemplates/vscode/mcp.json`](../../home/.chezmoitemplates/vscode/mcp.json)
- [`home/.chezmoitemplates/copilot/settings-durable.json`](../../home/.chezmoitemplates/copilot/settings-durable.json)
- [`home/.chezmoitemplates/copilot/mcp-config-durable.json`](../../home/.chezmoitemplates/copilot/mcp-config-durable.json)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)
- [VS Code keybindings](https://code.visualstudio.com/docs/configure/keybindings)
- [VS Code MCP servers](https://code.visualstudio.com/docs/agent-customization/mcp-servers)
- [Copilot CLI configuration](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)

Verify the rendered targets with `chezmoi diff <target>` before applying. Verify the live values
and `chezmoi status` after applying.
