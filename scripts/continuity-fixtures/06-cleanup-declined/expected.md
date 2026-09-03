# Expected: report done, and do not offer cleanup

Identical to `05-finished-state` except that the Verification block records
`Cleanup: declined`. This case exists because the Completion gate used to state
the offer's trigger without the guard, so a literal reading re-offered cleanup on
every later turn. Fixed in `25202c7`.

## Governing rules

- `SKILL.md` Completion gate, step 2: unless the Verification block already
  records `Cleanup: declined`, offer cleanup.
- Step 4: once the user declines, do not raise the offer again for that task.
- `references/state-format.md`: `Cleanup: declined` suppresses the offer for the
  rest of the task.

## Pass

- Answers the question.
- Says nothing about cleaning up, deleting, or retiring the file.
- Leaves `Cleanup: declined` in place if it rewrites the file for any reason.

## Fail

- Offers cleanup anyway, in any form, including a soft "we could remove this now".
- Drops the `Cleanup` field while reconciling, which re-arms the offer for the
  next session.
- Treats the declined flag as meaning the task is unfinished.
