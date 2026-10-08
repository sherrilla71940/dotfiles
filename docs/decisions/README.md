# Architecture decision records

This directory contains architecture decision records (ADRs). Each record explains why the
repository uses a particular structure, which alternatives were rejected, and which future
change should trigger reconsideration.

Operational steps belong in [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md). Current
constraints that every coding agent must obey belong in [`AGENTS.md`](../../AGENTS.md).
ADRs provide the reasoning behind those documents without adding that history to every
agent session.

## Working with ADRs

- Use the next four-digit number and a short kebab-case title.
- Keep record numbers stable. When a retired record is removed, leave its gap and keep this index
  in numeric order.
- Set the status to `Proposed`, `Accepted`, `Superseded`, or `Rejected`.
- Keep accepted records that still explain active structure or policy. A later accepted ADR may
  explicitly retire a cohesive legacy subsystem and list its records for removal after migration;
  Git history remains the recovery path for those records.
- Keep the current procedure in the workflow guide; link to it from the ADR rather than
  duplicating it.
- Include concrete reconsideration triggers so a later session can distinguish an
  intentional constraint from accidental legacy structure.

## Records

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](./0001-separate-operational-guides-from-decision-records.md) | Accepted | Separate current procedures from durable decision history |
| [0002](./0002-share-cross-tool-configuration-with-thin-wrappers.md) | Accepted | Share portable content while keeping tool-specific wrappers |
| [0003](./0003-track-vscode-user-configuration-selectively.md) | Accepted | Track portable VS Code user configuration selectively |
| [0004](./0004-manage-mixed-state-claude-settings-by-key.md) | Superseded by 0005 | Manage durable Claude settings while preserving app-owned choices |
| [0005](./0005-merge-durable-claude-settings-as-json.md) | Accepted | Merge durable Claude settings from a JSON source and narrow repository ownership |
| [0006](./0006-keep-the-working-tree-at-dotfiles.md) | Accepted | Keep the Git working tree at ~/dotfiles and link the default source directory |
| [0007](./0007-host-gate-codex-targeted-skills.md) | Accepted | Isolate a Codex-targeted skill by host gates rather than by directory |
| [0008](./0008-manage-windows-terminal-settings-by-key.md) | Accepted | Manage durable Windows Terminal settings while preserving generated profiles |
| [0009](./0009-own-windows-terminal-actions-and-keybindings.md) | Superseded by 0050 | Add the Shift+Enter newline action and keybinding |
| [0010](./0010-normalize-the-working-tree-to-lf.md) | Accepted | Normalize the whole working tree to LF so chezmoi diff shows only real changes |
| [0013](./0013-ignore-personal-ai-instructions-globally.md) | Accepted | Ignore personal Claude and Codex instruction files globally |
| [0015](./0015-organize-repository-tooling-by-purpose.md) | Superseded by 0016 | Organize repository tooling by purpose and expose one diagnostic entry point |
| [0016](./0016-rename-the-project-facing-tooling-command.md) | Accepted | Rename the project-facing diagnostic command to `dev-env` while retaining chezmoi and local-path compatibility |
| [0018](./0018-track-explicit-workflow-archives.md) | Superseded by 0020 and 0046 | Track explicit workflow archives outside active source and discovery paths |
| [0019](./0019-discover-and-retire-workflows-safely.md) | Superseded by 0020 and 0046 | Discover workflow boundaries by outcome and retire sources with explicit target cleanup |
| [0020](./0020-archive-or-delete-workflow-lifecycle.md) | Superseded by 0046 | Make archive a recoverable copy plus source deletion, with an explicit no-archive delete path |
| [0024](./0024-instruction-provenance-and-material-filing.md) | Accepted | Clarify instruction provenance, verification scope, and material filing |
| [0026](./0026-integrate-current-base-before-publishing.md) | Accepted | Require an explicit base-freshness and conflict-safe integration gate before publishing |
| [0027](./0027-add-repository-identity-preflight.md) | Accepted | Add a read-only repository-identity gate before substantive work |
| [0028](./0028-classify-instruction-ownership-before-adding.md) | Accepted | Classify instruction ownership and scope before adding behavior |
| [0040](./0040-require-company-flow-branch-identifiers.md) | Accepted | Require explicit flow identifiers for company-context task branches while preserving explicit project exceptions |
| [0046](./0046-retire-tracked-workflow-archives.md) | Superseded by 0055 | Retire tracked workflow archives and use Git history for source recovery |
| [0048](./0048-merge-explicit-vscode-settings-by-key.md) | Accepted | Merge explicitly managed VS Code settings over app-owned user settings |
| [0049](./0049-preserve-app-written-settings-across-clients.md) | Accepted | Preserve app-written VS Code and Copilot CLI settings outside explicit repository ownership |
| [0050](./0050-preserve-app-written-windows-terminal-actions-and-keybindings.md) | Accepted | Preserve unlisted Windows Terminal actions and keybindings |
| [0051](./0051-preserve-app-written-git-global-settings.md) | Accepted | Preserve Git global settings outside explicit repository ownership |
| [0052](./0052-define-ai-profile-applicability-scope.md) | Accepted | Separate AI profile applicability from client reach and validate both rendered contexts |
| [0053](./0053-native-first-ai-workflows.md) | Accepted | Use native client/Git workflows with an explicit, verified cross-client handoff |
| [0054](./0054-verify-native-task-starts.md) | Accepted | Use verified current or client-selected starting points for routine tasks |
| [0055](./0055-retire-workflow-deletion-engine.md) | Accepted | Retire the workflow deletion engine while keeping reviewed source and target cleanup |
| [0056](./0056-limit-end-to-end-skill-to-implementation.md) | Accepted | Limit the end-to-end skill to implementation and use ordinary requests for planning and review |

## Template

```markdown
# ADR-NNNN: Title

- Status: Proposed
- Date: YYYY-MM-DD

## Context

What forces or constraints require a decision?

## Decision

What will the repository do?

## Alternatives considered

What credible alternatives were rejected, and why?

## Consequences

What becomes easier, harder, or intentionally unsupported?

## Reconsider when

Which observable changes should cause this decision to be reviewed?

## Related files and verification

Where is the decision implemented, and how can it be checked?
```
