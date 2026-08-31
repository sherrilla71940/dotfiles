# Implementation and manual-test lifecycle

## Understand before editing

Use the materials and the existing implementation to summarize the required change and give a
short plan naming likely files. Resolve genuine contradictions, missing assets, or correctness
risks before implementing the affected part. Otherwise proceed without a separate plan approval.

Enable `project-continuity` in the task worktree. Record material paths because they may live
outside it and the manual-test gate can span sessions.

## Implement and verify

Install dependencies according to the lockfile when the fresh worktree needs them. Keep the
implementation within the resolved task.

`agent-test=true` requests proportionate checks that can catch defects in this change: typecheck,
lint, focused tests, a meaningful build, and a targeted browser or runtime pass for visual work
when available. `agent-test=false` skips optional verification, but still requires cheap minimum
checks that avoid knowingly handing back broken syntax or a seconds-long broken build.

In either mode:

- review the complete diff for unintended changes;
- list commands actually run and their outcomes;
- separate execution evidence from conclusions reached by reading;
- never call a UI flow, integration, or runtime behavior tested unless a tool drove it;
- state what could not be run and why.

Agent verification never replaces the user's manual test.

## Stop at the manual-test gate

Give exact manual steps when user-facing behavior remains: startup command, route or screen,
preconditions and test data, ordered actions, and expected results. Then stop and wait.

Do not commit, push, or open a pull or merge request until the user explicitly reports that the
manual test passed. Plan approval, approval of a diff, or green automated checks do not open this
gate. If the user discusses something else meanwhile, leave it closed.

When the manual test fails, investigate the actual cause, make the scoped correction, rerun the
relevant verification, checkpoint the useful finding, and return to the gate with updated steps.

## Publish only after the gate opens

Load and follow `git-commit-action` with the resolved `mode`, `group`, and `lang`. In `draft` mode,
stop after the commit plan because there are no commits to push. Otherwise follow
[publish.md](publish.md) and report the branch, every commit SHA and subject, the target base, and
the request URL.

Never merge, enable auto-merge, approve the request, force-push, or delete either the local or
remote task branch. The branch must outlive the worktree for review and CI.
