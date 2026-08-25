# Switching clients mid-task

Practical guidance for humans. The rule underneath all of it: **continuity lives in a directory, so continue the task in that same directory.**

## Find the directory

```bash
git worktree list
```

Works in any client, any repository, and does not depend on a vendor's storage layout. It lists the primary checkout first, then every linked worktree.

If nothing was ever created with a worktree, there is only the primary checkout, and that is where continuity is.

Client-specific defaults are conveniences, not guarantees — Claude Code puts its worktrees under `.claude/worktrees/<name>/`, and the Codex app manages its own per thread. Prefer `git worktree list` when the two disagree.

## Hand off

Every case is the same shape: open the receiving client against the existing directory.

```bash
# Codex CLI — no worktree flag; it uses the directory you start it in
cd <existing-directory>
codex

# Claude Code
cd <existing-directory>
claude

# VS Code, for Copilot or the Codex extension
code <existing-directory>
```

Then say "continue from project continuity". The receiving client reads the state, reconciles against Git, and resumes at the first genuinely unfinished action.

## What not to do

**Do not create a new worktree for the same interrupted task.** A new worktree is a fresh checkout: it has none of the original's uncommitted changes, untracked files, or continuity state. `git worktree add` copies no ignored or untracked files, so the new directory starts empty of everything that made the old one resumable.

**Do not archive or delete the originating session or thread while another client is still using its worktree.** A client-managed worktree can be removed with its session. Claude Code removes a *clean* worktree when the session exits, and ignored files such as `.project-continuity/` do not count as making it dirty — so a worktree whose only remaining local state is continuity can be cleaned up and take continuity with it.

**Do not rely on the previous client's memory carrying over.** It does not. Claude auto memory, Codex memories, and Copilot Memory are separate stores, none visible to the others, and each may hold stale claims about the task. Continuity plus Git is the handoff.

**Do not add a `.worktreeinclude` pattern that matches `.project-continuity/`.** That file copies gitignored files into new worktrees, which is exactly how one task's state would leak into another's.

## Codex app threads

Community reports describe the Codex app creating a worktree per thread and offering a handoff that moves a thread between local and worktree mode, transferring uncommitted changes between the two checkouts. No official documentation for this was found, so treat it as unverified: whether such a handoff also moves ignored files like `.project-continuity/` is unknown.

Until it is confirmed, after any Codex app handoff check that continuity is where you expect:

```bash
git worktree list
ls .project-continuity/
```

## Privacy across worktrees

The exclude entry that keeps continuity private is a single anchored line, `/.project-continuity/`, in the repository's shared `info/exclude`. Because that file lives in the common Git directory and the anchor resolves against each working tree's own root, one entry covers the primary checkout and every linked worktree, including ones created afterwards.

This is why cleanup deletes `.project-continuity/` but leaves the exclude entry: removing it would strip protection from every other working tree of the repository.

Verify it anywhere with:

```bash
git check-ignore -v .project-continuity/state.md
```
