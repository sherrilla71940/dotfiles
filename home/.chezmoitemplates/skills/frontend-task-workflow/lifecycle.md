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

Confirm the ignored local configuration this app needs to run is actually present in the
worktree, because a fresh checkout carries no ignored file. Provisioning can report a skip such
as `[skipped] .worktreeinclude: manifest not found in source worktree`, which means nothing was
copied. Do not treat a skip as harmless: say which files were expected, and whether the missing
ones are needed to run the manual test. Resolve a real gap with `git wt-copy` from a worktree
that has them, or name exactly what the user must place and where. A skip that genuinely does
not matter, because the settings the app reads are tracked, is worth one sentence saying so.

When the manual test needs a running app, start it and request one real route before writing
the steps. A fresh worktree can fail at startup for reasons the build output does not reveal:
a first build that restores dependencies but never runs their copy targets is the common one,
and it leaves a tree that compiles cleanly and serves nothing. Treat a redirect to the app's
own error page as failure rather than success, because a custom error page can return 200 and
can state a status code that contradicts the real one. Report the request made and what came
back. When the app cannot be started at all, say so and label the handed-over steps unverified
instead of implying the app ran.

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

Give exact manual steps when user-facing behavior remains. Open with the absolute path of the
task worktree and say plainly that the user's editor, terminal and running dev server are
probably still in the main checkout on the previous branch, so the change is invisible until
they open that directory. Repeat the path here even though isolation already reported it; this
gate can span sessions. Then give the startup command, route or screen, preconditions and test
data, ordered actions, and expected results. Then stop and wait.

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
