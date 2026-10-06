# ADR-0050: Preserve app-written Windows Terminal actions and keybindings

- Status: Accepted
- Date: 2026-10-06

## Context

ADR-0009 added a Shift+Enter action and four durable Windows Terminal keybindings by
owning the complete `actions` and `keybindings` arrays. As a result, an action or shortcut
added through Windows Terminal's settings UI disappeared on the next `chezmoi apply`.
This is the same ownership problem addressed for VS Code and Copilot CLI in ADR-0049.

Windows Terminal actions can name an `id`, and keybinding entries refer to those actions by
ID. Keybinding entries also have a `keys` value. These fields let the repository identify the
entries it owns while retaining the rest of the arrays.

## Decision

- Merge `actions` by action `id`. Repository action IDs win collisions. Actions without an ID
  are retained unless they exactly duplicate an entry already present.
- Merge `keybindings` by the JSON value of `keys`. Repository key chords win collisions;
  entries with other `keys` values remain app-owned.
- Keep the existing repository action and four keybindings in
  `home/.chezmoitemplates/windows-terminal/settings-durable.json`.
- Removing a durable entry releases ownership without deleting the corresponding live entry.
- Keep `profiles.list` and every other unnamed key app-owned. Continue normalizing the JSON
  file's formatting when an apply writes it.

## Alternatives considered

- **Continue owning both arrays wholesale:** rejected because it removes any app-added action
  or keybinding absent from the repository.
- **Stop managing the arrays:** rejected because new machines would lose the durable Shift+Enter
  behavior and the other explicitly selected shortcuts.
- **Merge exact entries only:** rejected because an app edit to a repository-owned action ID or
  key chord would then coexist with the repository entry instead of leaving one clear owner.

## Consequences

New application actions and keybindings with unowned identities survive `chezmoi apply`.
Changing a repository-owned action or key chord in the UI is temporary until that entry is
removed from the durable source. A released entry remains in the current live file, consistent
with other modify templates. Formatting continues to normalize on apply.

## Reconsider when

- Windows Terminal changes the structure or identity fields of actions or keybindings.
- `keys` values change format in a way that makes equivalent chords compare differently.
- JSON formatting churn becomes disruptive enough to outweigh the explicit durable settings.

## Related files and verification

- [`home/.chezmoitemplates/windows-terminal/settings-durable.json`](../../home/.chezmoitemplates/windows-terminal/settings-durable.json)
- [`home/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/modify_settings.json`](../../home/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/modify_settings.json)
- [ADR-0009](./0009-own-windows-terminal-actions-and-keybindings.md)
- [Windows Terminal actions and keybindings](https://learn.microsoft.com/windows/terminal/customize-settings/actions)

Verify the target with `chezmoi diff` and check its action IDs and keybindings structurally;
unlisted live entries should remain in the rendered result.
