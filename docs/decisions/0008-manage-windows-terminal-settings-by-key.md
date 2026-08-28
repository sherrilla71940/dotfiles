# ADR-0008: Manage Windows Terminal settings by key

- Status: Accepted
- Date: 2026-08-26

## Context

`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
held configuration worth carrying between machines — the Nerd Font face that terminal output
needs in order to draw its glyphs, and the antialiasing mode — while being unmanaged, so
neither followed a new machine and neither was recoverable if the file were lost.

The file is mixed state, and more aggressively so than
[`~/.claude/settings.json`](./0005-merge-durable-claude-settings-as-json.md). Windows
Terminal writes it whenever a setting changes through its own UI, and it appends generated
profiles when a WSL distribution or a Visual Studio installation appears. Those profiles
carry GUIDs that differ per machine: this one holds thirteen, most of them generated. A
`defaultProfile` naming one of those GUIDs is meaningless on another machine.

## Decision

Manage the file with a chezmoi `modify_` template, following the pattern ADR-0005
established for Claude Code. `home/.chezmoitemplates/windows-terminal/settings-durable.json`
holds the durable keys as readable JSON; the sibling `modify_settings.json` merges them over
the live file with `merge $durable $live`, so the repository wins only on keys it names.

The durable set is `profiles.defaults.font.face` and
`profiles.defaults.antialiasingMode`. Both meet ADR-0005's admission criterion: needed on
every machine, stable across sessions, and not something the application rewrites on its own.
The font face is functional rather than cosmetic — an unpatched family renders terminal
glyphs as tofu.

`colorScheme` stays released to Windows Terminal, for the reason ADR-0005 released `theme`:
it is a taste choice the application's own settings UI is authoritative for, and owning it
would silently revert an interactive change on a later apply, possibly on another machine.

The durable file names object keys only. `merge` replaces arrays wholesale rather than
merging them, so naming `profiles.list` would overwrite a machine's generated profiles with
this repository's copy of them.

[ADR-0009](./0009-own-windows-terminal-actions-and-keybindings.md) later admitted two
arrays, `actions` and `keybindings`, on the ground that the repository can supply their
entire contents. `profiles.list` stays excluded because it cannot.

## Alternatives considered

**A plain managed file.** The repository would own the whole file, including thirteen
generated profiles and their per-machine GUIDs. Applying that to a second machine would
assert profiles for software it may not have installed.

**`create_`, as `~/.codex/config.toml` uses.** Write-once avoids fighting the application,
but a source edit then never reaches a machine that already has the file — which is every
machine that has ever launched Windows Terminal, since it writes the file on first run.

**Leaving it unmanaged.** The status quo. Rejected because the font face is a genuine
prerequisite for readable terminal output, not a preference, and a new machine had no way to
learn it.

## Consequences

A `toPrettyJson` round-trip reformats the whole file. Windows Terminal writes four-space
indentation with the opening brace on its own line; the rendered target is two-space with
standard brace placement, and keys come out alphabetically ordered. The first apply
therefore rewrites all 128 lines while changing one key semantically.

AGENTS.md warns against exactly this trade for `~/.codex/config.toml`, where a TOML
round-trip would leave `chezmoi status` dirty after almost every Codex session. The
difference is write frequency, not formatting: Codex writes trust and runtime state as a
matter of course, whereas Windows Terminal rewrites its settings only when a setting changes
through the UI or a generated profile appears. `chezmoi status` is expected to stay clean
between those events. If it does not, this decision is wrong.

The source tree is Windows-only, and `home/.chezmoiignore` already excludes `AppData` on
every other operating system, so no macOS target is created.

## Reconsider when

- `chezmoi status` reports this file dirty routinely rather than after a deliberate settings
  change. That would mean Windows Terminal rewrites more often than assumed, and the
  reformatting churn is no longer worth the two managed keys.
- Windows Terminal changes its package identifier. The path contains
  `Microsoft.WindowsTerminal_8wekyb3d8bbwe`; a Preview or Store re-identification would need
  a second source path or a template.
- The durable set grows to include anything under `profiles.list`, which `merge` cannot
  express safely. Growing it to cover `actions` and `keybindings` triggered this in
  [ADR-0009](./0009-own-windows-terminal-actions-and-keybindings.md).

## Related files and verification

- `home/.chezmoitemplates/windows-terminal/settings-durable.json` — the durable keys
- `home/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/modify_settings.json` — the merge
- `home/.chezmoiignore` — excludes `AppData` off Windows

Verify that the merge preserves application state by comparing the rendered target with the
live file structurally, rather than by reading the reformatted diff:

```bash
chezmoi cat "$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
```

Parse both and compare keys; only the durable keys should differ.
