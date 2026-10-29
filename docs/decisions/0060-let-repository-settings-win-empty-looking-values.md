# ADR-0060: Let repository settings win over empty-looking values

- Status: Accepted
- Date: 2026-10-29

## Context

[ADR-0005](./0005-merge-durable-claude-settings-as-json.md),
[ADR-0008](./0008-manage-windows-terminal-settings-by-key.md),
[ADR-0048](./0048-merge-explicit-vscode-settings-by-key.md), and
[ADR-0049](./0049-preserve-app-written-settings-across-clients.md) state that a repository value
wins when the same key is also present in a live settings file. Every partially managed JSON
modify template implemented that rule with sprig's `merge $durable $live`.

Sprig's `merge` is built on mergo, which treats `false`, `0`, `""`, and an empty array in the
destination as empty and fills them from the next argument. A durable `false` therefore never
replaced a live `true`; the live value won instead. On 2026-10-28,
`chezmoi execute-template '{{ $d := dict "a" false "b" "durable" }}{{ $l := dict "a" true "b" "live" }}{{ merge $d $l | toJson }}'`
printed `{"a":true,"b":"durable"}`. Commit `a3cfcd9` had already worked around the bug by
releasing `editor.foldingImportsByDefault` instead of setting it to `false`.

## Decision

- Merge with `mergeOverwrite (deepCopy $live) $durable` in every partially managed JSON modify
  template. The last argument wins, including `false`, `0`, `""`, empty arrays, and `null`.
  Nested objects still merge recursively, and arrays named by the repository are still complete
  values.
- Merge into a copy of the live object. `mergeOverwrite` mutates its destination, and the Windows
  Terminal and VS Code MCP templates read the original live arrays afterward for their per-entry
  rules.
- Keep the existing per-entry rules unchanged: Windows Terminal actions by `id` and keybindings by
  `keys`, VS Code MCP inputs by `id`, Claude lifecycle hook groups, and VS Code keybinding order.
- Guard the rule with `scripts/tests/test-settings-merge.sh`. It renders each real modify
  template against fixture durable sources, checks empty-looking repository values against live
  values, checks the per-entry array rules, and rejects a template that reintroduces
  `merge $durable $live`. The pre-commit hook runs it when a modify template changes.

## Alternatives considered

- **Write a recursive template helper that sets each durable key on the live object.** Rejected
  because `mergeOverwrite` already gives the required semantics for objects, scalars, and arrays,
  and the regression test pins that behavior if a sprig or chezmoi upgrade changes it.
- **Avoid falsy values in durable sources.** Rejected because it silently limits what the
  repository can own and had already caused one setting to be released instead of managed.

## Consequences

Durable keys whose value is `false`, `0`, `""`, or an empty array now override the live value on
apply. Machines where an application had set such a key to a truthy value will see that key
restored to the repository value on the next apply; preview with `chezmoi diff` first. Live
values for unnamed keys survive as before.

## Reconsider when

- A sprig or chezmoi upgrade changes `mergeOverwrite` or `deepCopy` semantics; the regression test
  will fail first.
- A durable source needs to release a key by setting `null` rather than by removing it.

## Related files and verification

- [`home/dot_claude/modify_settings.json`](../../home/dot_claude/modify_settings.json)
- [`home/AppData/Roaming/Code/User/modify_settings.json`](../../home/AppData/Roaming/Code/User/modify_settings.json)
- [`home/AppData/Roaming/Code/User/modify_mcp.json`](../../home/AppData/Roaming/Code/User/modify_mcp.json)
- [`home/dot_copilot/modify_settings.json`](../../home/dot_copilot/modify_settings.json)
- [`home/dot_copilot/modify_mcp-config.json`](../../home/dot_copilot/modify_mcp-config.json)
- [`scripts/tests/test-settings-merge.sh`](../../scripts/tests/test-settings-merge.sh)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)

The macOS VS Code and Windows Terminal templates follow the same pattern. Run
`bash scripts/tests/test-settings-merge.sh`, then preview each target with `chezmoi diff`.
