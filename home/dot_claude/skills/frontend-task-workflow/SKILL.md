---
name: frontend-task-workflow
description: "Run one isolated frontend implementation task through its whole lifecycle in a Claude Code worktree: validate the invocation, read the supplied materials, branch from the latest origin/<base>, plan, implement, verify, stop for the user's manual test, then commit through git-commit-action, push, open a pull or merge request against that same base, and remove the worktree without touching the branch."
argument-hint: '<base> "<task>" [materials...] — or base=… task=… materials=… [--infer-task] [--no-agent-test] [cleanup=ask]'
disable-model-invocation: true
---

# Frontend task workflow

One frontend task, start to finish, in its own worktree:

```text
validate -> read materials -> worktree -> understand -> plan -> implement -> verify
         -> YOUR MANUAL TEST -> commit -> push -> request -> remove the worktree
```

This skill orchestrates. It does not restate what already applies: global and project
instructions, the path-scoped rules, `git-commit-action` for commits, `git-commit-reference` for
message conventions, `natural-zhtw` for Traditional Chinese, the `pdf`/`pptx`/`xlsx`/`docx`
skills for materials, and `project-continuity` for session state. Delegate to those.

## Invocation

Positional, where order matters:

```text
/frontend-task-workflow <base> "<task>" [materials...]
```

Named, where it does not:

```text
/frontend-task-workflow base=feat/CCTVPipiCons task="污水管線 TV 檢視紀錄" materials="handoff.md" "screens.pptx"
```

Both normalize to the same values. `base` is always required, and so is a task — either typed, or
requested explicitly with `--infer-task` / `infer-task=true`, never assumed from an omission.

| Option | Values | Default |
| --- | --- | --- |
| `type` `slug` `branch` `suffix` | branch naming | `{type}/{slug}/frontend`, type and slug inferred |
| `lang` | `en` · `zhtw` — commit and request text only | `zhtw` |
| `mode` | `commit` · `draft` | `commit` |
| `group` | `batch` · `single` | `batch` |
| `agent-test` | `true` · `false`, or the `--no-agent-test` flag | `true` |
| `cleanup` | `ask` · `auto` · `keep` | `ask` |

[references/invocation.md](references/invocation.md) holds the tokenizer, the slot-filling rule,
every rejection case, and the echo-back format. Follow it exactly; it is the difference between a
misread invocation and a wrong branch.

`lang` reaches the commit messages and the request text, and stops there. It does not decide the
language of code comments or UI copy, which follow the global rules whatever `lang` says — so
`lang=en` never turns a project repository's comments into English ones.

## Never

- Never commit, push, or open a request before the user states in this conversation that their
  manual testing passed. A plan approval, a "looks good" on the diff, or a green check run is not
  that statement.
- Never merge the request, and never delete a branch — see [step 11](#11-clean-up-the-worktree-not-the-branch).
- Never call `ExitWorktree` with `action: "remove"`: that deletes the task branch with the
  worktree. This workflow always exits with `keep`.
- Never run `git worktree remove --force`, and never remove a worktree holding work that is not
  both committed and pushed.
- Never report something as tested when it was only read.
- Never widen the scope beyond the requested task.

## 1. Resolve the invocation and the task

Follow [references/invocation.md](references/invocation.md) end to end: tokenize, classify, fill
slots, reject structural errors, read every material, infer the task if that was requested,
cross-check an explicit task against the materials, then echo one resolved interpretation.

The boundary this step protects is git, not the filesystem. Reading a local material changes
nothing and can be undone by closing the file; creating a branch or a worktree cannot. So the
materials are read first and the echo comes last, showing the task that was actually resolved
rather than a blank waiting on inference.

Nothing below runs until that echo block has been shown.

## 2. Resolve names, and check the repository allows this

```bash
git rev-parse --show-toplevel
git remote get-url origin
```

Stop if the repository's own instructions forbid worktree work — this dotfiles repository does,
and its root holds `.chezmoiroot`. Say so, and offer to run the task in place instead.

Then derive, unless the invocation supplied them:

- **type** — from the `git-commit-reference` type table. When genuinely ambiguous, `feat` for new
  behavior and `fix` for correcting existing behavior.
- **slug** — two to four words, ASCII kebab-case, from the task's meaning. Translate a
  Traditional Chinese task rather than transliterating it: 再生水巡檢 PM 回報修正 becomes
  `recycle-water-inspection-pm`.
- **branch** — `{type}/{slug}/{suffix}`, for example `fix/recycle-water-inspection-pm/frontend`.
- **worktree path** — `<repo-root>/.claude/worktrees/<slug>`.

## 3. Establish the base from the remote

```bash
git fetch origin --prune
git rev-parse --verify --quiet "refs/remotes/origin/<base>"
git rev-parse --verify --quiet "refs/heads/<branch>"
```

- No `origin/<base>`: stop. Show near matches from `git branch -r --list "origin/*<fragment>*"`
  and ask which was meant.
- `<branch>` already exists locally: stop and ask. Never silently reuse or reset it.

Record the `origin/<base>` commit. A local `<base>`, if one exists, is irrelevant to this
workflow — never check it out, merge it, or update it.

## 4. Create the worktree, then enter it

Keep the worktree directory out of the main checkout's status first, unless the repository
already ignores it:

```bash
exclude="$(git rev-parse --git-path info/exclude)"
git check-ignore -q .claude/worktrees || printf '\n/.claude/worktrees/\n' >> "$exclude"
```

That entry is local and never committed. The leading newline keeps it off the end of an existing
line, and `info/exclude` lives in the shared git directory, so one anchored line covers every
worktree of the repository.

Create it with the managed wrapper, which also copies the ignored local files the repository's
`.worktreeinclude` approves — Claude Code does not copy those into a worktree that git created:

```bash
git wt-add -- -b <branch> "<repo-root>/.claude/worktrees/<slug>" "origin/<base>"
```

If `git wt-add` is unavailable, fall back to `git worktree add -b <branch> <path> origin/<base>`
and tell the user that approved ignored files were not provisioned.

Then move this session into it with the **`EnterWorktree` tool, passing `path`** — not `name`.
`EnterWorktree` creates from `worktree.baseRef`, which accepts only the remote default branch or
local `HEAD` and cannot take a branch name, so an arbitrary base needs this two-step route. A
path under `.claude/worktrees/` also enters without the approval prompt that any other location
raises.

## 5. Confirm the isolation is real

From inside the worktree:

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git status --porcelain
```

The toplevel must be the worktree path, `HEAD` must be on `<branch>` at the recorded
`origin/<base>` commit, and the status must be clean apart from files `.worktreeinclude`
provisioned. Anything else: stop and report rather than working on.

Claude Code now enforces the boundary itself. It blocks edits to the main checkout, Bash commands
whose working directory resolves there, git redirected there through `-C`, `--git-dir` or
`GIT_DIR`, and command shapes it cannot trace — unquoted heredoc delimiters and brace expansion
among them. If a command is refused, rewrite it as plain separate commands; do not reach around
the check.

Enable `project-continuity` here, at the worktree root. The manual-test gate means this task waits
on a human, so the session may well be compacted or lost across it. Materials live outside the
worktree, so record their paths in that state.

## 6. Understand before editing

Work from the materials and the code that already implements the surrounding behavior. Summarize
what the change actually requires, and give a short implementation plan naming the files.

Raise genuine ambiguities, contradictions, missing assets or data, and implementation risks,
prefixed `⚠️ Needs clarification:`. Ask before implementing a part whose wrong reading would
change correctness, and implement everything unaffected meanwhile. Absent a blocking ambiguity,
proceed without asking for approval.

## 7. Implement, then verify at the requested level

The worktree is a fresh checkout with no dependencies. Install them the way the lockfile says
(`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`) before verifying
anything. Implement only the requested scope.

`agent-test` decides whether you run optional verification before handing the work back. Neither
setting is destructive, and neither touches shared or remote state.

| `agent-test` | What to run |
| --- | --- |
| `true` (default) | The proportionate, relevant checks this environment actually offers: typecheck, lint, the focused tests covering what changed, a build when it is cheap and meaningful, and a targeted browser or runtime pass when the change is visual and a tool for it is available. Use judgment — run what would actually catch a defect in *this* change, not everything available. |
| `false` | Skip optional verification. Still do the minimum that avoids knowingly handing back obviously broken work: the changed files parse, and the project still builds when that costs seconds. Then go to the manual steps. |

`agent-test` governs your own verification and nothing else. It never moves the manual gate in
step 8: with `true`, passing checks do not open it; with `false`, skipping checks does not skip
it.

Then review `git diff` for anything unintended.

Report verification honestly under either setting:

- List the commands actually run and their outcomes.
- Separate **verified by execution** from **reviewed by reading**. Static reading of a component
  is never evidence that its flow works.
- Never state that a UI flow, user journey, integration, or runtime behavior was tested unless a
  browser or runtime tool actually drove it — name the tool when it did.
- Say what you could not run, and why.

Verification never replaces the gate below, whatever was run and however it came out.

## 8. Stop at the manual test gate

Give exact manual testing steps whenever meaningful user-facing behavior remains: how to start
the app, the route or screen, the preconditions and test data, the actions in order, and what
should happen. Then **stop and wait.**

Do not commit, push, or create a request in this turn or in any later turn until the user says
testing passed. If they ask about something else meanwhile, answer it and leave the gate closed.

## 9. When the manual test fails

Investigate the actual cause, fix it, re-run the same verification, and give updated testing
steps. Checkpoint what the failure revealed. Return to the gate — it does not open until the user
says the implementation passes.

## 10. Commit, push, open the request

Only after that statement. Invoke the `git-commit-action` skill through the `Skill` tool rather
than composing commits here, passing the resolved axes as its arguments:

```text
commit batch zhtw
```

Substitute the resolved `mode`, `group` and `lang` values into that argument string. Then follow
[references/publish.md](references/publish.md) to push, open the request against the original
base, and report branch, commit SHA, target and URL.

## 11. Clean up the worktree, not the branch

These are two lifecycles. This skill owns only the first.

| Thing | This skill | Who owns the rest |
| --- | --- | --- |
| Task worktree | removes it when the checks below pass | — |
| Local task branch | never deletes it | you, once the request is merged or closed |
| Remote task branch | never deletes it | the repository's merge policy on the forge |

The branch outlives the worktree on purpose: the open request needs it, and so do review changes,
CI fixes, later commits, and recreating the worktree. "Cleanup" here never means the branch. Both
native mechanisms already agree — `git worktree remove` does not touch branches, and Claude
Code's sweep leaves worktrees it did not create alone — so there is no branch-deletion logic to
get wrong. Deleting a branch needs its own explicit request, in its own turn.

Worktree removal is allowed only when **all** of these hold:

- the user stated the manual test passed;
- `git status --porcelain` is empty;
- `git rev-parse HEAD` equals `git rev-parse origin/<branch>` — everything is pushed;
- the request exists and its URL is recorded;
- `git stash list` holds nothing from this task;
- the user has not asked to keep the worktree.

If any of them fails, keep the worktree, say which one failed, and stop.

With `cleanup=keep`, stop here and report the path. With `cleanup=ask` (the default), ask once,
naming what removal deletes — the directory including `node_modules` and build output, which a
round of review feedback would make you reinstall. Recommend keeping while the request is open
unless the change is trivial. With `cleanup=auto`, invocation is the authorization; proceed.

Then, in this order:

1. Clean up continuity per its own skill.
2. Leave the worktree with the **`ExitWorktree` tool, `action: "keep"`**. Never `"remove"` — that
   deletes the branch, and it refuses a worktree entered by path anyway.
3. From the main checkout, `git worktree remove "<path>"`. Never `--force`: git refuses to remove
   a worktree holding uncommitted or untracked files, and that refusal is the safety net. Report
   it verbatim and leave everything in place.
4. `git worktree prune`, which only clears metadata for worktrees whose directories are already
   gone.
5. Confirm with `git worktree list` and `git branch --list "<branch>"` — the branch must still be
   there. Report both the removed path and the surviving branch.

## Resuming later

A resumed session returns to its worktree on its own. A brand-new session should launch in the
main checkout and re-enter with `EnterWorktree` and the worktree `path`; this task's continuity
state lives inside the worktree, not in the main checkout.
