# ADR-0004: Manage mixed-state Claude settings by key

- Status: Superseded by [ADR-0005](./0005-merge-durable-claude-settings-as-json.md)
- Date: 2026-08-11

## Context

Claude Code stores durable configuration and frequently changed application preferences in
the same `~/.claude/settings.json` file. Hooks, permissions, environment variables, status
line configuration, and plugin declarations should follow machines. Claude writes model and
effort choices when the user changes them, so replacing the complete file makes those choices
temporary and creates recurring drift.

Removing model and effort from a complete chezmoi template would not make them app-owned.
The next apply would remove the omitted keys from the live file. Using `create_` would
preserve application changes but would also prevent later durable-setting updates from
reaching an existing machine.

## Decision

Manage `~/.claude/settings.json` with
`home/dot_claude/modify_settings.json`, a chezmoi modify template. The template reads the
existing JSON, replaces only durable repository-owned keys, and preserves all other keys.

Claude owns `model`, `effortLevel`, and unknown future keys. The repository owns `env`,
`permissions`, `hooks`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`,
`autoUpdatesChannel`, `theme`, `verbose`, and `tui`.

## Alternatives considered

- **Manage the complete file:** simple, but every model or effort change is reverted on
  apply.
- **Omit volatile keys from a complete template:** still deletes those keys on apply.
- **Use `create_`:** protects application changes but prevents durable updates after the
  first creation.
- **Run a separate merge installer:** works, but duplicates partial-file management that
  chezmoi already provides through `modify_`.

## Consequences

Model and effort values remain local and never enter the current Git source state. Durable
settings still converge across machines. Unknown application-written keys survive an apply.
The modify template generates a complete file when none exists and fails instead of
overwriting malformed JSON.

The rendered JSON can be reordered because chezmoi serializes the merged object. This
formatting change does not alter the settings.

## Reconsider when

- Claude Code stores session preferences in a separate supported user-level file.
- Model or effort becomes an intentional cross-machine policy.
- Chezmoi replaces `modify_` with a safer native structured-configuration mechanism.

## Related files and verification

- [`home/dot_claude/modify_settings.json`](../../home/dot_claude/modify_settings.json)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)
- [`docs/customization-support.md`](../customization-support.md)
- Test with an absent target and with a target containing different model, effort, and
  unknown keys; both must retain app-owned state while receiving durable settings.
