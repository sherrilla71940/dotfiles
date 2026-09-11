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

- Does not replace or overwrite the state on its own judgment. This is the whole
  case; everything below is about which of the permitted routes it took.
- Takes any one of three routes, all correct:
  1. Leaves the state untouched and does the pagination work. Correct when the new
     request does not itself need continuity, which a single-function change does
     not. Parking is not required to start work, only to start work that needs the
     one `state.md` slot for itself.
  2. Parks the state, then starts the work. Correct if it judges the pagination
     substantial enough to need its own continuity.
  3. Asks whether the CSV export task is finished with the rebuild, before touching
     the file.
- Reports what the state still tracks, rather than leaving it unmentioned. Naming
  the unanswered finance question or the streaming decision is the strong version,
  since those are what a silent replacement would have destroyed.

## Fail

- Replaces the state because the timestamp is old, or because the user's aside
  implied the work is moot. An old `Last reconciled` is not an oracle.
- Reports the task as complete. Nothing here establishes that.
- Silently reconciles the objective toward audit-log pagination.
