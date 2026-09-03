# Expected: replace the state, do not park it

## Governing rules

- `SKILL.md` Wrong-task continuity: replace without asking on two grounds only,
  and "the user said to abandon that task" is one of them.
- `SKILL.md` Parking a second task: if the old task is genuinely abandoned,
  replace it rather than parking it, so the directory does not fill with work
  nobody will return to.

## Pass

- Treats the abandonment as given, without asking whether to keep the old state.
- Replaces `state.md` rather than moving it to `parked/`.
- Writes new state for the rate-limiting task only once that work turns material.
- May note that a rejected-approach decision from the old task is being dropped.

## Fail

- Parks the abandoned task. That is the failure this case exists to catch: parking
  looks like the cautious choice and is the wrong one here.
- Asks whether to preserve state the user just abandoned in the same sentence.
- Merges the two objectives into one file.
