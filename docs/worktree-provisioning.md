# Worktree provisioning

A Git worktree is another working directory for the same repository. Git checks out tracked
files there, but it does not copy ignored local files such as `CLAUDE.local.md`, `.env.local`,
or `connections.config`. The new directory can therefore lack the personal instructions or
development configuration used by the original working tree.

This repository manages a provisioning workflow that copies explicitly approved ignored
files into a new or existing worktree. It does not commit, upload, or synchronize those
files. The commands become available after the relevant chezmoi source changes are applied.

## How each worktree receives ignored files

Different worktree creators use different configuration. Each path below provisions local
files without making them tracked:

| Worktree creator | How ignored files arrive |
| --- | --- |
| Claude Code | Claude reads the repository's `.worktreeinclude` automatically. |
| Codex desktop local worktrees | Codex reads `.worktreeinclude` automatically. |
| VS Code and local Copilot sessions | VS Code uses the managed `git.worktreeIncludeFiles` setting. |
| Terminal Git | `git wt-add` creates the worktree, then copies approved files. |
| Already-created worktree | `git wt-copy` reruns only the approved copy step for files that are still missing. |

Already-created means a worktree made earlier with raw `git worktree add`, or one whose
approved local file was later removed. In that case, `git wt-copy` copies the missing file
from another worktree. It does not repair Git metadata, recover unknown contents, switch the
branch, or overwrite a target file that already exists.

The repository-root `.worktreeinclude` file is the primary per-repository contract for
Claude Code, Codex desktop, and the terminal commands. It contains repository-relative Git
ignore patterns, never file contents. For example:

```gitignore
CLAUDE.local.md
EIACarbonRightMatch/connections.config
EIACarbonRightMatch/appsettings.secret.config
```

The terminal workflow copies a source file only when both conditions are true:

- `.worktreeinclude` matches its repository-relative path.
- Git classifies the source file as ignored.

The manifest itself must be tracked before it can authorize any copy. Tracked files already
arrive through Git, and ignored files absent from the manifest remain absent from the new
worktree.

VS Code uses a separate user-level list because it creates worktrees without invoking the
terminal wrapper. The managed list covers local agent instructions, development/test
environment files, and the known local application configuration names. It deliberately
omits production environment files, credential stores, keys, agent state, dependencies, and
build output.

## Create a worktree with `git wt-add`

`git wt-add` wraps `git worktree add`. Wrapper options go before `--`; every argument after
`--` is forwarded to native Git unchanged. This preserves Git's normal control over the
target path, new or existing branch, and start point.

Create `feat/example` from `develop`:

```shell
git wt-add --open-code -- -b feat/example ../example develop
```

Check out an existing branch in a new worktree:

```shell
git wt-add -- ../example feat/example
```

Create a detached worktree from a remote-tracking branch:

```shell
git wt-add -- --detach ../review origin/develop
```

Continuity works in any Git worktree; it does not depend on this wrapper. A cross-client
handoff does depend on both clients opening the same physical working-tree directory. After
creating a worktree, `git wt-add` prints the exact path and the suggested continuation prompt
as a non-blocking reminder. It also reminds you to use a separate worktree for another
unfinished task — which is the right answer when the two tasks need separate uncommitted
changes, and unnecessary when they do not. For a second task in the same directory, the
`project-continuity` skill parks the first under `.project-continuity/parked/` instead.

The wrapper options are:

| Option | Effect |
| --- | --- |
| `--dry-run` | Validate wrapper inputs and show eligible manifest files without creating anything. |
| `--skip-copy` | Create the worktree without provisioning ignored files. |
| `--open-code` | Open the completed worktree in a new VS Code window. |

The command performs these steps:

1. Run `git worktree add` with the arguments after `--`.
2. Stop without copying if Git cannot create the worktree.
3. Read the tracked `.worktreeinclude` from the worktree where the command started.
4. Intersect its matches with Git's normally ignored files.
5. Preserve repository-relative paths and refuse to overwrite existing targets.
6. Reject paths that escape a worktree or traverse symbolic links. Windows also rejects
   reparse points.
7. Optionally open the completed worktree in VS Code.
8. Print the exact-path handoff reminder.

A rejected copy returns exit code 2 but leaves a successfully created worktree in place for
inspection or manual recovery. Missing optional files and existing target conflicts are
reported but do not make an otherwise safe run fail.

## Provision an existing worktree with `git wt-copy`

Run this from the worktree that needs its approved ignored files:

```shell
git wt-copy
```

The command discovers the repository's primary worktree and reports the chosen source. When
that source is not appropriate or cannot be selected unambiguously, provide it explicitly:

```shell
git wt-copy --source /path/to/existing-worktree
```

On Windows, a native path is also valid:

```powershell
git wt-copy --source C:\path\to\existing-worktree
```

`git wt-copy --dry-run` reports what would be copied without changing the target. Every copy
uses the source worktree's tracked manifest and current ignored files. Source and target must
belong to the same Git repository.

## Windows and macOS support

The public commands and behavior are the same on both supported platforms:

| Platform | Managed implementation | Runtime requirement |
| --- | --- | --- |
| Windows | `~/.local/share/git-worktree-provision.ps1` | Windows PowerShell and Git for Windows |
| macOS | `~/.local/share/git-worktree-provision.sh` | The system Bash-compatible shell and Git |

The rendered `~/.gitconfig` selects the appropriate implementation. You use `git wt-add`
and `git wt-copy` on either platform; no PowerShell installation is needed on a Mac. The Bash
implementation stays compatible with the Bash 3.2 version included with macOS.

## Comparison with `claude --worktree`

`git wt-add` makes terminal-created worktrees resemble Claude-created worktrees in one
specific way: both create a Git worktree and provision ignored files approved by
`.worktreeinclude`. They are not otherwise equivalent.

| Capability | `git wt-add` | `claude --worktree` |
| --- | --- | --- |
| Create a Git worktree | Yes, by forwarding native arguments | Yes |
| Copy approved ignored files | Yes, from `.worktreeinclude` | Yes, from `.worktreeinclude` |
| Start an agent session | No | Yes, starts Claude Code in the worktree |
| Choose branch, path, and start point | The user supplies ordinary Git arguments | Claude applies its own worktree naming and base-reference behavior |
| Run Claude worktree hooks | No | Yes |
| Manage Claude session cleanup | No | Yes |
| Provision an existing worktree | Yes, through `git wt-copy` | No equivalent repair command |

Use `claude --worktree` when starting an isolated Claude Code session. Use `git wt-add` when
the worktree itself is the goal and a terminal, VS Code, Codex, or another tool will use it.

### Claude frontend workflow

The Claude-only `frontend-task-workflow` skill combines them, because neither alone gives an
isolated session on a branch taken from an arbitrary remote base. Claude Code's own worktree
creation branches only from the remote default branch or from local `HEAD`; its
`worktree.baseRef` setting accepts no branch name. So the skill creates the worktree with
`git wt-add` from `origin/<base>`, places it at `<repo>/.claude/worktrees/<slug>` where entering
it raises no approval prompt, and then moves the running session into it with the
`EnterWorktree` tool's `path` argument. From that point Claude Code enforces the isolation
itself, refusing edits and commands that resolve back into the main checkout.

Cleanup splits the same way. `ExitWorktree` declines to remove a worktree that was entered by
path, and Claude's periodic sweep leaves every worktree it did not create alone, so the skill
exits with `keep` and then runs `git worktree remove` from the main checkout — never with
`--force`, so git's own refusal on uncommitted or untracked files remains the safety net.

That sweep protection requires **Claude Code v2.1.246 or later**, which is when the sweep began
checking for the marker Claude Code writes into the git metadata of worktrees it creates. Before
that version the sweep could remove a worktree created with `git worktree add` when a stale
background-session record pointed at its path — a collision this workflow makes more reachable,
because it deliberately reuses Claude's own `.claude/worktrees/<name>` naming.

The exposure is narrow but not theoretical, and it needs every one of these at once:

- a stale background-session record pointing at that path, most likely from an earlier
  `claude --worktree <slug>` session that was backgrounded under the same slug;
- a worktree that looks empty to the sweep. This is the sharp edge: the sweep spares changed or
  untracked files and unpushed commits, but `.project-continuity/`, `.env` and `node_modules` are
  all ignored, so a `cleanup=keep` worktree whose commits are already pushed looks like nothing
  would be lost;
- an age past [`cleanupPeriodDays`](https://code.claude.com/docs/en/settings-reference), which
  defaults to 30 days and this repository does not set.

On an older version, `git worktree lock` on a worktree being kept for review is the reliable
guard, since the sweep never releases a lock set by hand.

Removing a worktree is not retiring a branch. `git worktree remove` deletes no refs, and the
skill deletes none either: the task branch stays for the open request, its reviews and its CI.
`ExitWorktree` with `action: "remove"` is the one operation here that *would* delete the branch
along with the directory, which is why that path is never used.

### Codex frontend workflow

The Codex adapter of `frontend-task-workflow` starts only after the chat is already in a linked
worktree. In the Codex app, choose Worktree when starting the chat or use Handoff from Local. In
the CLI or IDE extension, start Codex in a worktree created with `git wt-add`; changing only a
shell's directory does not move an existing chat's workspace.

Codex-managed worktrees begin detached. After fetching, the skill creates the task branch from
the requested `origin/<base>` inside that clean worktree, so the selected starting branch does not
silently replace the workflow's explicit base. It keeps every operation in that directory and
uses project continuity so another client can resume there.

The running skill never removes its active Codex worktree. After the branch is clean, pushed, and
attached to an open request, the user can keep it for review or dispose of it through the app's
worktree lifecycle. Neither choice deletes the task branch.

## Safety boundaries

The terminal workflow never copies:

- User-global `~/.claude`, `~/.codex`, `~/.copilot`, or `~/.agents` configuration.
- Authentication files, production environment files, private keys, or certificates.
- Agent history, memory, caches, `.project-continuity/**`, or Codex local state.
- Dependencies or build output such as `node_modules`, `packages`, `bin`, `obj`, `coverage`,
  or `dist`.
- Database files or backups.

It also does not install dependencies, synchronize ignored files between machines, or commit
or upload copied files. Restore dependencies separately with the repository's normal package
manager or build workflow.

## Add the manifest to a repository

For a repository that needs provisioning, add and commit a `.worktreeinclude` at its root.
Keep it narrow: list only ignored development files that are safe and useful in another local
worktree. For the EIA Carbon Right Match repository, the current candidate is:

```gitignore
CLAUDE.local.md
EIACarbonRightMatch/connections.config
EIACarbonRightMatch/appsettings.secret.config
# Add .claude/settings.local.json only if its repository-specific permissions should be shared.
```

Review that repository's local files before committing the manifest. The manifest names are
tracked, but the ignored files and their contents remain local.

## References

- [Git worktree command reference](https://git-scm.com/docs/git-worktree.html)
- [VS Code branches and worktrees](https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees)
- [Claude Code worktrees and `.worktreeinclude`](https://code.claude.com/docs/en/worktrees)
