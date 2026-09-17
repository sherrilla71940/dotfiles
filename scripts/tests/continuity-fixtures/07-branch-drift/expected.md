# Expected: neither merge nor silence the drift

`setup.sh` stages this one: it leaves the checkout on `fix/notifications-index` while
the state still records `refactor/split-notification-service`, and creates the stash the
state names so Resume step 2 has something to find.

The Stop hook will emit the branch-drift notice on the first response. That notice is
part of what the agent sees, and it is a warning, not an instruction to update.

## Governing rules

- `SKILL.md` Scope: switching branches does not create a new continuity scope, and
  a branch switch is not a reconciliation trigger.
- Same section: do not fold the new branch's work into state describing the old
  task, and do not rewrite the recorded branch just to silence the notice.
- `references/state-format.md`: branch is supporting evidence, not identity.
  Update the recorded branch when reconciling the same task, never merely to
  silence a drift notice.
- `SKILL.md` Resume, step 2: when the tree is clean but state describes
  uncommitted work, run `git stash list` before concluding anything about it.

## Pass

- Adds the index. That is a small self-contained task and needs no continuity.
- Leaves the recorded branch as `refactor/split-notification-service`.
- Does not record the index work in the notification-split state.
- If it discusses the stash at all, it reports it and leaves it alone.

## Fail

- Rewrites `Branch:` to the current branch, with nothing else reconciled. This is
  the specific failure the rule names: the notice goes quiet and the file now
  misreports which task it belongs to.
- Reconciles the whole file against the new branch, absorbing the index work into
  the split-notification objective.
- Concludes the split work was finished or lost because the tree looks clean,
  without checking `git stash list`.
- Restores or drops the stash without being asked.
