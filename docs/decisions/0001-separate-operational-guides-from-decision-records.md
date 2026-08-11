# ADR-0001: Separate operational guides from decision records

- Status: Accepted
- Date: 2026-08-11

## Context

This repository configures several coding agents, so future sessions need both the current
procedure and the reasoning behind architectural choices. Mixing both into `AGENTS.md`
would consume context in every session. Mixing historical rationale into the workflow guide
would make routine instructions harder to scan and encourage old decisions to be silently
rewritten.

## Decision

Keep three distinct documentation layers:

- `AGENTS.md` contains short, always-on constraints that an agent could otherwise get wrong.
- `docs/chezmoi-workflow.md` contains the current operational procedure.
- `docs/decisions/` contains durable rationale, tradeoffs, and reconsideration triggers.

Accepted ADRs are historical records. A changed decision receives a new ADR that supersedes
the old one; the operational guide is then updated to describe only the new procedure.

## Alternatives considered

- **One architecture document:** easier to start, but unrelated decisions become coupled and
  their status and replacement history become ambiguous.
- **Put all rationale in the workflow guide:** keeps fewer files, but mixes history with the
  commands people need to follow today.
- **Put rationale in `AGENTS.md`:** makes it automatically visible, but spends agent context on
  background that rarely affects an individual edit.

## Consequences

Decisions remain discoverable and reviewable without bloating every session. A change that
affects both architecture and procedure must update an ADR and the workflow guide, but each
file has one clear purpose.

## Reconsider when

- The repository gains a documentation system that provides equivalent decision status,
  history, and cross-linking with less maintenance.
- ADRs repeatedly describe temporary implementation details rather than durable choices.

## Related files and verification

- [`AGENTS.md`](../../AGENTS.md)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md)
- [`docs/decisions/README.md`](./README.md)
