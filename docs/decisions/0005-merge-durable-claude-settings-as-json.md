# ADR-0005: Merge durable Claude settings from a JSON source

- Status: Accepted
- Date: 2026-08-24

## Context

[ADR-0004](./0004-manage-mixed-state-claude-settings-by-key.md) established that
`~/.claude/settings.json` holds both durable configuration and application-written state, and
that a chezmoi `modify_` template is the right mechanism. Three problems emerged in use.

`setValueAtPath` replaces the whole value at a key. Any child that Claude Code or the user
adds under a repository-owned key is therefore deleted, not merged. Installing a plugin at
user scope writes `enabledPlugins`, and a standing approval can add to `permissions`; both
were lost on the next apply even though the repository only intended to set a baseline.

The owned set included `theme`, `verbose`, and `tui`. Those are the keys the `/config` menu
writes into user settings, so an interactive change was reverted on a later apply, possibly
on a different machine, with nothing to signal it. The keys are cosmetic session preferences,
so enforcing them across machines bought little and cost a silent revert.

The durable values were expressed as Go template calls — `dict`, `list`, `setValueAtPath` —
which made the file hard to read and hard to edit for anyone adding a single setting.

## Decision

Keep the `modify_` template. Move the durable values into
`home/.chezmoitemplates/claude/settings-durable.json`, written as JSON with `{{ }}` only
where a value differs per machine. `home/dot_claude/modify_settings.json` reduces to reading
the live file, including that partial, and combining them with `merge $durable $live`.

`merge` gives the first argument precedence and recurses into nested objects, so the
repository wins on any key it names while a locally added sibling under the same parent is
preserved.

Admit a key to the durable set only when it is needed on every machine, stable enough that
it would not be changed mid-session, and not written by the application.

Narrow repository ownership to `env`, `hooks`, `statusLine`, and `autoUpdatesChannel`.
Release `theme`, `verbose`, `tui`, `permissions`, and `enabledPlugins` to Claude Code and to
project settings, and drop `extraKnownMarketplaces` entirely.

`permissions` fails the stability test: which rules are worth having changes with the
workflow, and a project's own `.claude/settings.json` outranks the user file, so a guardrail
that must hold belongs there rather than in a machine-wide default.

`enabledPlugins` fails it as well, and the merge cannot express a disable, so a pinned plugin
could not be turned off locally at all. Plugins are installed software rather than
configuration, so `scripts/bootstrap-macos.sh` and `scripts/bootstrap-windows.ps1` install
them with `claude plugin install`, the way they install any other tool. Which plugins are
enabled after that is a local decision.

`extraKnownMarketplaces` declared the `claude-code-plugins` demo marketplace while every
plugin installed by the bootstrap scripts comes from `claude-plugins-official`, which Claude
Code registers on its own. The entry served no declared plugin.

`statusLine` stays owned despite being writable by `/statusline`, because the repository ships
both statusline scripts. Releasing the setting would leave a fresh machine rendering two
scripts that nothing references. Where the repository ships the implementation it has to ship
the reference, which is the same reason `hooks` cannot be released.

## Alternatives considered

- **Manage the complete file and round-trip with `chezmoi add`/`re-add`:** rejected again.
  Claude Code writes this file, so an apply reverts its writes and a re-add commits them. The
  file also holds per-OS hook commands and an absolute Git Bash path, which require a
  template, and `chezmoi add` on a template flattens it. Re-adding on one platform would
  hardcode that platform's values.
- **`mergeOverwrite` instead of `merge`:** the live file would win, so durable settings would
  never converge after the first apply.
- **Keep `setValueAtPath` and only release the three cosmetic keys:** fixes the `/config`
  revert but leaves subtree deletion and the readability problem.
- **Move durable settings to enterprise `managed-settings.json`:** highest precedence and not
  written by the application, but it lives outside `$HOME`, needs administrator rights, and
  cannot be overridden per project, which is too rigid for personal preferences.
- **Capture local changes automatically into the source state:** would sweep up
  machine-local state and overwrite the template expressions that render per-machine paths.

## Consequences

`/config` is authoritative for theme, verbosity, and terminal interface; permission rules are
set per project or per workflow; and `/plugin` is unconstrained. Nothing the repository owns
is reachable from an interactive command except `/statusline`.

A fresh machine starts with no `ask` rules, so the `git push` and `git commit` confirmations
this repository used to guarantee are now set per project or added back by hand. Releasing
`permissions` is what buys the freedom to change them without a commit.

One command still meets a repository-owned key: `/statusline` writes `statusLine` and
additionally leaves an unmanaged script in `~/.claude/`.

Installing plugins from bootstrap trades enforcement for freedom. A plugin is installed once
on a new machine rather than re-enabled on every apply, so a plugin disabled later stays
disabled. This is the same trade as `permissions`.

The merge cannot express removal. Deleting an application-written key requires editing the
live file, or a mechanism other than `merge`.

Promoting a local setting into the source state stays manual, supported by
`scripts/claude-settings-drift.sh`, because `chezmoi diff` only reports repository-owned keys
and so cannot surface a candidate.

The ADR-0004 invariants still hold: a complete file is generated when the target is absent,
and malformed JSON fails the apply instead of being overwritten.

## Reconsider when

- Chezmoi gains a native structured-configuration merge that replaces `modify_`.
- Claude Code stores session preferences in a separate supported user-level file, or begins
  writing a key the repository owns.
- Theme, verbosity, or terminal interface becomes an intentional cross-machine policy.
- The repository needs to remove an application-written key rather than override it.

## Related files and verification

- [`home/.chezmoitemplates/claude/settings-durable.json`](../../home/.chezmoitemplates/claude/settings-durable.json)
- [`home/dot_claude/modify_settings.json`](../../home/dot_claude/modify_settings.json)
- [`scripts/claude-settings-drift.sh`](../../scripts/claude-settings-drift.sh)
- [`scripts/bootstrap-macos.sh`](../../scripts/bootstrap-macos.sh) and
  [`scripts/bootstrap-windows.ps1`](../../scripts/bootstrap-windows.ps1), which install the
  plugins and the typescript language server the plugins need
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)

Verified with `chezmoi apply --destination` against a seeded target: released keys and
unknown keys survive, a locally added `permissions.allow` is kept alongside the repository's
`ask` list, a user-scope plugin is kept alongside the repository's baseline,
`autoUpdatesChannel` is still enforced, an absent target yields a complete file, and
malformed JSON fails the apply with the live file untouched. On an already-configured
machine the rendered output is byte-identical to the ADR-0004 template.
