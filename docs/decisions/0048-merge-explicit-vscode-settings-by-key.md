# ADR-0048: Merge explicitly managed VS Code settings by key

- Status: Accepted
- Date: 2026-10-06

## Context

ADR-0003 tracks portable VS Code user files without copying the complete profile. Its
`settings.json` implementation was a complete managed template, so any preference added by
VS Code or an extension but absent from the template was removed by `chezmoi apply`. That
made a normal VS Code settings change require a repository edit before applying unrelated
dotfiles.

The user wants the repository to state exactly which settings it owns and leave the rest to
VS Code and its extensions.

## Decision

- Keep the current portable VS Code setting keys in the shared JSONC source
  `home/.chezmoitemplates/vscode/settings-durable.json`.
- Use platform-specific `modify_settings.json` sources for Windows and macOS. Each source
  parses the live JSONC settings, deep-merges the rendered repository values over it, and
  writes the result.
- Repository values win on key conflicts. Keys absent from the durable source remain
  app-owned, including future keys written by VS Code or extensions.
- Nested objects merge. Arrays are replaced as whole values, so a repository-owned array
  must list every value the repository intends to keep.
- Removing a key from the durable source releases ownership but does not delete its existing
  live value. Users can remove that value through VS Code if they want it gone from the
  current profile.
- JSONC is parsed with chezmoi's `fromJsonc` and serialized as formatted JSON. This preserves
  settings values but normalizes live comments and formatting; comments in the durable source
  remain the place to document managed choices.
- Keep managing individual portable VS Code files as in ADR-0003. History, caches, workspace
  storage, logs, and extension runtime data remain outside the repository.

## Alternatives considered

- **Keep the whole-file settings template:** rejected because any unlisted app setting is
  overwritten on apply.
- **Stop managing VS Code settings:** rejected because portable settings would no longer have
  an explicit, reviewable cross-machine source.
- **Require users to re-add every setting after drift:** rejected because it makes routine
  applies tedious and blurs app ownership with repository ownership.

## Consequences

VS Code changes to repository-owned keys are restored from the durable source. Unlisted keys
survive applies, so users can change app-owned settings without first editing the repository.
Fresh profiles receive the repository-owned values and let VS Code create other values as
needed. The live JSONC file is normalized to JSON on apply, and a named array remains wholly
repository-owned.

## Reconsider when

Revisit this decision if VS Code provides a native user-settings overlay with equivalent
ownership semantics, if JSONC comment preservation becomes a requirement, or if the merge
causes repeated formatting churn that cannot be handled by the current workflow.

## Related files and verification

- [`home/.chezmoitemplates/vscode/settings-durable.json`](../../home/.chezmoitemplates/vscode/settings-durable.json)
- [`home/AppData/Roaming/Code/User/modify_settings.json`](../../home/AppData/Roaming/Code/User/modify_settings.json)
- [`home/Library/Application Support/Code/User/modify_settings.json`](../../home/Library/Application%20Support/Code/User/modify_settings.json)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)
- [`docs/customization-support.md`](../customization-support.md)

Verify with:

```powershell
chezmoi source-path "$env:APPDATA/Code/User/settings.json"
chezmoi diff "$env:APPDATA/Code/User/settings.json"
chezmoi status
```
