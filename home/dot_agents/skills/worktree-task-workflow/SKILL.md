---
name: worktree-task-workflow
description: "Run one isolated implementation task through its lifecycle in a Codex worktree, from an explicit task or requested material inference through manual testing, publishing, and branch-preserving handoff."
disable-model-invocation: true
---

# Worktree task workflow

If the current host is GitHub Copilot, stop: this adapter depends on Codex worktree behavior and
must not be translated into Copilot operations.

Run one task in an existing Codex worktree:

```text
validate -> read materials -> confirm isolation -> branch -> plan -> implement -> verify
         -> USER MANUAL TEST -> commit -> push -> request -> app-owned worktree lifecycle
```

This skill orchestrates existing global and project instructions. Use the dedicated document
skills for supplied containers, `project-continuity` for resumable state, `git-commit-action` for
commits, `git-commit-reference` for message conventions, and `natural-zhtw` for Traditional
Chinese publishing text.

## 1. Resolve the invocation

Read [references/invocation.md](references/invocation.md) and follow it through the resolved echo.
Invoke this skill as either:

```text
$worktree-task-workflow <base> "<task>" [materials...] [options...]
$worktree-task-workflow <base> --infer-task <materials...> [options...]
```

`base` is required. Task identity requires exactly one non-empty explicit task or requested
inference from readable materials. `task=""` is invalid; omit `task` when using inference. Do not
touch Git before showing the resolved echo.

## 2. Require a linked worktree

Inspect the current root and worktree registry without changing them:

```bash
git rev-parse --show-toplevel
git rev-parse --git-common-dir
git worktree list --porcelain
git status --porcelain
```

The current root must be a linked worktree, not the repository's primary checkout. It must also
be clean apart from ignored files provisioned for this worktree. If the chat is still Local,
stop before fetching or branching and ask the user to move it with Codex Handoff or start a
Codex Worktree chat from the intended repository. A shell `cd` does not move the chat's workspace.

Stop if repository instructions forbid worktrees. This dotfiles repository does, identifiable by
its root `.chezmoiroot`; offer to run that task in place instead.

## 3. Establish names and the remote base

Unless supplied, derive:

- `type` from the `git-commit-reference` type table;
- an ASCII two-to-four-word kebab-case `slug` from the task's meaning;
- `branch` as `{type}/{slug}/{suffix}`.

Then fetch and verify:

```bash
git fetch origin --prune
git rev-parse --verify --quiet "refs/remotes/origin/<base>"
git rev-parse --verify --quiet "refs/heads/<branch>"
git symbolic-ref --quiet --short HEAD
```

Show near remote matches and stop when `origin/<base>` is absent. For a new task, require detached
HEAD and require the task branch not to exist. Codex-managed worktrees normally begin detached;
create the branch directly from the recorded remote commit:

```bash
git switch -c <branch> origin/<base>
```

If already on `<branch>`, treat it only as a resume: reconcile `project-continuity` and verify that
its objective and starting point match. Stop on any other checked-out branch or on an existing
task branch with no matching continuity; never silently reuse, reset, or relocate it.

## 4. Verify isolation

After branch creation or resume, verify:

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git status --porcelain
```

For a new task, HEAD must equal the recorded `origin/<base>` commit and the branch must be the
resolved task branch. Keep every file operation and command rooted in this worktree. Do not reach
back into the primary checkout with absolute paths, `git -C`, `--git-dir`, or `GIT_DIR`.

Report the worktree's absolute path, branch, and base commit in the response, not only in a tool
call. The chat's workspace is not where the user is working, so an unreported path leaves them
looking at the primary checkout with no sign of the change.

Also report what ignored local configuration this worktree actually has. An app-created Codex
worktree and one made with `git wt-add` can both arrive without it, and a provisioning skip such
as `[skipped] .worktreeinclude: manifest not found in source worktree` is silent until the app
fails to run.

## 5. Implement through publishing

Read [references/lifecycle.md](references/lifecycle.md) and follow it through the manual-test gate
and publishing. Do not commit, push, or open a request until the user explicitly reports that the
manual test passed.

## 6. Leave worktree deletion to Codex

The skill never deletes its active Codex workspace. The task branch and request always survive.

With `cleanup=keep`, retain continuity and report the worktree path. With `cleanup=ask`, after
publishing ask whether the worktree should remain available for review. Recommend keeping it for
non-trivial review.

Only mark it ready for disposal when all are true:

- the user reported the manual test passed;
- `git status --porcelain` is empty;
- `git rev-parse HEAD` equals `git rev-parse origin/<branch>`;
- the request exists and its URL is recorded;
- this task left no stash.

When the user chooses disposal and all checks pass, clean up continuity and explain that the user
can archive the Codex-managed chat or use Handoff according to the app's worktree controls. Do not
run `git worktree remove`, delete a branch, archive a chat, or claim the worktree was removed.

## Resume

Resume in the same physical Codex worktree. In the app, return or hand the chat back to its
associated worktree. In CLI or the IDE extension, start Codex in that exact directory and continue
from `project-continuity`.
