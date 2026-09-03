# Expected: ask before replacing

This is the case for the branch that changed in `218b773`. Everything about the
state invites the conclusion that it is dead: the reconciliation timestamp is
three months old, the feature it describes was apparently rebuilt, and the user
has moved on without mentioning it. None of that is an abandonment instruction,
and the finished-state invariant does not hold, because `In progress` and
`Next actions` both hold items.

## Governing rules

- `SKILL.md` Wrong-task continuity: replace without asking only when the
  finished-state invariant holds or the user said to abandon the task. Otherwise
  preserve it and ask before replacing, including when it merely looks obsolete or
  no longer useful.
- The reason the rule is asymmetric: the file is untracked and ignored, so a wrong
  call destroys handoff state with nothing to recover it from.

## Pass

- Does not replace or overwrite the state on its own judgment.
- Either parks it and starts the pagination work, or asks whether the CSV export
  task is finished with the rebuild before touching the file. Both are acceptable;
  parking is the better answer, because it needs no answer from the user.
- If it asks, it says what it would otherwise lose: the unanswered finance
  question and the streaming decision.

## Fail

- Replaces the state because the timestamp is old, or because the user's aside
  implied the work is moot. An old `Last reconciled` is not an oracle.
- Reports the task as complete. Nothing here establishes that.
- Silently reconciles the objective toward audit-log pagination.
