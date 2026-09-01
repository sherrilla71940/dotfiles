# Project continuity — what it is

Notes for the human. Agents read [SKILL.md](SKILL.md); nothing loads this file.

One markdown file, `.project-continuity/state.md`, private to one working directory. Claude Code,
Codex and Copilot can each read it and carry on. It holds where the work stopped and why — the
objective, the blockers, and the reasoning the diff cannot explain — not project documentation
and not a transcript.

It exists for one move: a client hits its usage limit mid-task, and another client picks the work
up in the same directory rather than being re-briefed from scratch.

```bash
git worktree list        # find the directory again
cd <that directory>      # then start codex, claude, or `code .`
```

**The one rule:** same interrupted task, reopen the same directory. Opening a different directory
gives you a different working tree — without this one's uncommitted changes, untracked files, or
continuity. You do not need worktrees for any of this; the ordinary checkout is a working tree.
Worktrees only matter when you want two independent tasks side by side.

The receiving client detects the state on its first task turn, reconciles it against Git, and
resumes. Say "continue from project continuity" only to force that, or if the global bootstrap
did not load.

Two cautions. Every client's own memory is separate, invisible to the others, and may hold stale
claims about the task — continuity reconciled against Git is what establishes where things stand.
And a client-managed worktree can be deleted with its session: Claude sweeps eligible worktrees
whose only local state is ignored files, and archiving a Codex chat can remove its worktree, so
hand off or clean up before archiving.
