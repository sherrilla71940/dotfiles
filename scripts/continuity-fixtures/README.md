# Continuity behavior fixtures

`test-project-continuity-hook.sh` covers the parts of continuity a shell script can
decide: does the hook find the state file, does it compute drift, does it emit the
cleanup notice. What it cannot cover is the part that actually carries risk — whether
an agent reading [the skill](../../home/dot_agents/skills/project-continuity/SKILL.md)
takes the branch the skill mandates when the situation is a judgment call.

These fixtures are that test. Each case is a fabricated `state.md`, the prompt to
give a fresh session, and the branch the skill requires. Grading is by eye; a shell
script cannot mark agent prose, and pretending otherwise would produce false passes
and false failures in equal measure.

## Cases

| Case | Situation | Required branch |
| --- | --- | --- |
| `01-small-unrelated-question` | Unfinished state, read-only question | Leave the file untouched |
| `02-substantive-task-switch` | Unfinished state, substantial new task | Park, then start the new task |
| `03-explicit-abandon` | User abandons the tracked task | Replace, do not park |
| `04-looks-obsolete-no-instruction` | State looks dead, no instruction | Ask, or park; never replace unasked |
| `05-finished-state` | Invariant holds, no `Cleanup` field | Offer cleanup this response |
| `06-cleanup-declined` | Invariant holds, `Cleanup: declined` | Say nothing about cleanup |
| `07-branch-drift` | Recorded branch is not the checkout | Neither merge nor rewrite the branch |

Cases 02, 03 and 04 are the same three-way classification that has no oracle, and
they are deliberately adjacent: 02 and 04 look like 03 and must not be treated as it.

## Running one

`setup-case.sh` stages a case in a throwaway repository and prints the prompt to paste:

```bash
bash scripts/continuity-fixtures/setup-case.sh scripts/continuity-fixtures/05-finished-state
cd <the path it prints>
claude    # or codex, or a Copilot session
```

Never stage a case in this repository. 03 replaces state and 04 is built to tempt a
session into destroying it, and both would do that to the real tree.

The script rewrites the recorded branch, HEAD and working-tree path to match the throwaway
repository. Without that the Stop hook reports drift on every case, and the session is then
reacting to a drift notice rather than to the situation under test. A case that needs the
mismatch carries its own `setup.sh`, which runs instead; 07 is the only one.

Paste `prompt.txt` as the first message and nothing else. The point is what the
session does before being steered, so do not answer questions it asks until you have
recorded what it did. Then read `expected.md` and score the Pass and Fail lists.

Delete the temporary directory afterwards. A leftover fixture is fabricated state
that a later session may reconcile in earnest.

## When to run these

After changing the skill, the bootstrap in `home/.chezmoitemplates/continuity.md`, or
the hook's messages. Also worth a pass when the client changes underneath: these are
prose instructions interpreted by a model, so the same fixture can pass on one release
and fail on the next, which is the failure mode nothing else here would catch.

Run them across clients rather than only in Claude Code. The skill claims to be
client-neutral, and 02 and 06 are the cases most likely to expose that claim.

## Adding a case

Add one when a branch turns out to be interpretable two ways — that is the bar, not
coverage for its own sake. Keep the fabricated state realistic: real format, English,
plausible detail, and no marker saying it is a fixture, because the session under test
would read it and behave differently. If the case needs the repository itself to be in a
particular shape — a mismatched branch, a stash, an unmerged history — give it its own
`setup.sh` rather than describing the steps in prose, so the setup cannot drift from the
case it sets up.
