# ADR-0026: Integrate the current base before publishing

- Status: Accepted
- Date: 2026-09-18

## Context

Long-running task branches can become stale as the base branch advances. Publishing without an
explicit integration decision leaves surprises to the forge or reviewers. Updating the branch can
also produce conflicts, especially when the task branch has already been published or another
client resumes the work.

## Decision

The publish stage adds a base-freshness and integration gate:

1. Recheck the redacted fetch and push identities, fetch `origin`, and resolve the current
   `origin/<base>` commit.
2. Publish directly only when the current base equals the recorded checkpoint.
3. Stop when the base advanced and ask the user to choose merge or rebase. Do not use `git pull` as
   an implicit strategy, and do not stash, reset, discard, or resolve conflicts automatically.
4. Preserve a conflict state for user- or agent-assisted resolution. Record conflict paths and the
   next operation in the durable issue or handoff, then rerun applicable verification.
5. Recheck the remote and base immediately before pushing. Never silently change the request target.

Merging is the safe default for a task branch that has already been published. Rebasing a published
branch requires separate explicit approval and `--force-with-lease`; plain force-push remains
forbidden. An unpublished branch may be rebased and pushed normally after the user selects that
strategy.

## Alternatives considered

- Publish from the original task commit without checking the current base. This leaves integration
  surprises to the forge or reviewers and makes the workflow's base contract incomplete.
- Run `git pull` automatically. Its configured upstream and merge/rebase behavior are not the
  workflow's explicit `origin/<base>` contract.
- Automatically rebase, stash, or resolve conflicts. These actions can rewrite history or discard
  user intent, and conflict resolution requires repository-specific judgment.
- Require a merge only. This avoids history rewriting but is unnecessarily restrictive for an
  unpublished task branch where the user prefers a linear history.

## Consequences

Publishing can pause when the base moves, and a successful integration can require another
verification pass. Conflicts remain visible in Git and in the durable issue or handoff, including
when another supported client takes over. No workflow can guarantee that the remote base will not
advance after the final check; another advance requires another integration cycle.

## Reconsider when

Revisit this decision if the forge enforces a stronger up-to-date-base policy, if the clients expose
a reliable conflict-aware integration mechanism that preserves this contract, or if the repository
adopts a different branch publication policy.

## Related files and verification

- [`home/.chezmoitemplates/skills/run-task-end-to-end/SKILL.md`](../../home/.chezmoitemplates/skills/run-task-end-to-end/SKILL.md)
- [`home/.chezmoitemplates/skills/task-handoff/SKILL.md`](../../home/.chezmoitemplates/skills/task-handoff/SKILL.md)
