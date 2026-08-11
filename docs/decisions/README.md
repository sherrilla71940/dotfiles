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
- Set the status to `Proposed`, `Accepted`, `Superseded`, or `Rejected`.
- Once accepted, preserve the record. If the decision changes, add a new ADR and mark the
  old one `Superseded by ADR-NNNN`.
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
| [0004](./0004-manage-mixed-state-claude-settings-by-key.md) | Accepted | Manage durable Claude settings while preserving app-owned choices |

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
