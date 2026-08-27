# ADR-0009: Own the Windows Terminal actions and keybindings arrays

- Status: Accepted
- Date: 2026-08-27

## Context

Shift+Enter did not insert a line break in Claude Code running in Windows Terminal 1.24 with
the Git Bash profile. It submitted the prompt instead, which makes a multi-line prompt
impossible to type without falling back to Ctrl+J or a trailing backslash.

Claude Code's documentation lists Windows Terminal as working without setup, so the
`/terminal-setup` command does not write a binding for it — that command covers VS Code,
Cursor, Alacritty and Zed only. The fix has to be made by hand, and it belongs in the
terminal rather than in Claude Code's own keybindings file: when a terminal sends identical
bytes for Enter and Shift+Enter, no amount of remapping `chat:newline` inside Claude Code can
tell the two apart. The terminal is the layer that turns a key into bytes.

[ADR-0008](./0008-manage-windows-terminal-settings-by-key.md) manages this file with a
`modify_` template whose durable set names object keys only, because `merge` replaces arrays
wholesale. A keybinding is an array element, so ADR-0008 as written cannot express one. Its
own "reconsider when" section anticipated this.

## Decision

Extend the durable set to the two top-level arrays `actions` and `keybindings`, and accept
that naming an array claims all of it.

`actions` gains one entry: a `sendInput` action with the id `User.SendNewline` sending
ESC CR, spelled `\u001b\r` in the settings file. `keybindings` binds `shift+enter` to that id,
and repeats the three bindings previously set through the settings UI — `ctrl+c`, `ctrl+v`
and `alt+shift+d` — which naming the array would otherwise drop.

ESC CR is the sequence Claude Code's own `/terminal-setup` writes for the terminals it does
support, and the same sequence this repository already binds for the VS Code terminal in
`home/.chezmoitemplates/vscode/keybindings.json`. Both terminals therefore hand Claude Code
identical bytes, which is the point: one sequence to reason about instead of two.

`profiles.list` stays unnamed. The distinction is not "arrays are unsafe" but who supplies
the contents: `profiles.list` holds generated per-machine GUIDs that this repository cannot
know, whereas `actions` and `keybindings` hold only what a person deliberately set.

## Alternatives considered

**Merge the arrays by `id` in `modify_settings.json`.** The template would append
repository-owned entries into the live array and leave application-added ones alone,
preserving ADR-0008's ownership boundary exactly. Rejected as disproportionate: it puts
matching and deduplication logic into a template whose stated purpose is to be a merge and
nothing else, to protect four entries that change perhaps once a year.

**Bind a bare line feed instead of ESC CR.** Claude Code accepts one as a newline — that is
what Ctrl+J sends. Rejected for divergence: the VS Code binding in this repository already
sends ESC CR, and two terminals sending different bytes for the same key is a difference
someone has to rediscover later. A bare line feed also submits the current line in Bash's
readline, so Shift+Enter would become indistinguishable from Enter at a shell prompt.

**Leave the live file unmanaged.** The status quo before ADR-0008 for this key. Rejected for
the reason ADR-0008 rejected it for the font face: a new machine would have no way to learn
the binding, and the symptom — a prompt that submits when you meant to add a line — is
obscure enough that rediscovering the cause is expensive.

## Consequences

A keybinding or action added through the Windows Terminal settings UI is reverted on the next
`chezmoi apply`, because the repository now supplies both arrays in full. This is the trap
`/statusline` has for `~/.claude/settings.json`, and the mitigation is the same: add the
binding to `home/.chezmoitemplates/windows-terminal/settings-durable.json` instead of the UI.

This narrows what the settings UI is authoritative for. Under ADR-0008 it owned everything
except two font keys; it now also loses Actions. `colorScheme` and the rest of
`profiles.defaults` are unaffected.

Windows Terminal does not write these arrays on its own, unlike `profiles.list`, so
`chezmoi status` should stay clean between deliberate changes.

Shift+Enter now sends ESC CR to every application in the terminal, not only Claude Code. In
Bash's readline that sequence is unbound and rings the bell. Full-screen applications that
read Shift+Enter through the extended-key protocol no longer see it as a modified Enter.

## Reconsider when

- Windows Terminal starts writing `actions` or `keybindings` without a deliberate settings
  change, which would make `chezmoi status` dirty routinely and reverse the trade above.
- A future Claude Code release makes Shift+Enter work in Windows Terminal unaided, or
  `/terminal-setup` grows Windows Terminal support. The binding would then be redundant, and
  keeping it would mean owning two arrays for nothing.
- The set of hand-set keybindings grows large enough that repeating it in the durable file
  becomes the maintenance burden, at which point the by-`id` merge rejected above earns its
  complexity.
- ESC CR stops being the sequence Claude Code reads as a newline. The VS Code binding in this
  repository would need the same change.

## Related files and verification

- `home/.chezmoitemplates/windows-terminal/settings-durable.json` — the durable keys
- `home/.chezmoitemplates/vscode/keybindings.json` — the matching VS Code binding
- `docs/decisions/0008-manage-windows-terminal-settings-by-key.md` — the merge this extends

Confirm that claiming the arrays did not drop application state, by comparing the rendered
target with the live file structurally rather than reading the reformatted diff:

```bash
chezmoi cat "$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
```

Parse both and compare. Only `actions` and `keybindings` should differ; the thirteen entries
of `profiles.list` and their GUIDs should be identical.
