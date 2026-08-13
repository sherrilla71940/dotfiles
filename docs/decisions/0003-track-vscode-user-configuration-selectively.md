# ADR-0003: Track VS Code user configuration selectively

- Status: Accepted
- Date: 2026-08-11

## Context

VS Code has two different configuration scopes that are easy to confuse. A `.vscode/`
directory in this repository would affect only this workspace. Global user configuration
lives in an OS-specific VS Code profile directory, but that directory also contains history,
workspace storage, caches, logs, identifiers, extension data, and other machine-owned state.

Copying the complete profile would mix durable preferences with volatile or sensitive state,
create cross-machine conflicts, and risk overwriting files that VS Code owns.

## Decision

Manage portable VS Code user files individually. The current set is `settings.json`,
`keybindings.json`, MCP configuration, and prompt files. Keep their bodies once under
`home/.chezmoitemplates/vscode/` and render them to the Windows or macOS profile path.

Track desired extensions separately in `scripts/vscode-extensions.txt`. Leave history,
workspace storage, caches, logs, machine identifiers, extension runtime data, and similar
state unmanaged. Add future portable files, such as intentional user snippets, selectively
after checking their contents and ownership.

## Alternatives considered

- **Track a root `.vscode/` directory:** useful for settings specific to this repository, but
  it does not manage the user's global VS Code configuration.
- **Track the complete VS Code user directory:** captures more automatically, but also captures
  volatile, machine-specific, and potentially sensitive state.
- **Rely only on VS Code Settings Sync:** convenient for VS Code, but separates these settings
  from the repository's review, history, templates, and cross-tool configuration workflow.

## Consequences

The managed set is explicit and portable, and adding a new configuration type requires a
small deliberate change. Some VS Code state will not follow machines through this repository;
that is intentional when the state is runtime-owned or machine-specific.

## Reconsider when

- VS Code provides an export format that cleanly separates all durable user configuration
  from runtime state.
- A new portable user file is repeatedly configured by hand across machines.
- Settings Sync becomes the preferred source of truth and the repository no longer needs to
  review or template VS Code configuration.

## Related files and verification

- [`home/.chezmoitemplates/vscode/`](../../home/.chezmoitemplates/vscode/)
- [`home/.chezmoiignore`](../../home/.chezmoiignore)
- [`scripts/vscode-extensions.txt`](../../scripts/vscode-extensions.txt)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)
