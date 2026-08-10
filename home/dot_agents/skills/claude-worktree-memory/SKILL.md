---
name: claude-worktree-memory
description: 'Diagnose apparently missing Claude Code auto memory in git worktrees or worktree-container folders. Load when a session started near a worktree cannot recall repository memory, when worktree location seems to change memory, or before adding autoMemoryDirectory to make linked worktrees share memory.'
user-invocable: false
---

# Claude Code worktree memory

## Rule

Auto memory is keyed by git repository, not filesystem ancestry. All linked worktrees and subdirectories of one repository share it regardless of where their checkout directories live. Do not add per-worktree `autoMemoryDirectory` settings for this.

Filesystem ancestry governs `CLAUDE.md` and `CLAUDE.local.md` discovery instead. A tracked project `CLAUDE.md` exists in every checkout; a gitignored `CLAUDE.local.md` exists only in the worktree where it was created. Separate clones, nested repositories, machines, WSL environments, containers, and cloud sessions may have separate auto memory.

Session memory is resolved from the directory where Claude Code starts. Running `cd` inside a shell tool does not change the session's project identity or reload startup memory. A session launched from a non-repository directory that merely contains worktrees is not a worktree session.

Prefer starting Claude inside the actual worktree. For a dedicated non-repository container that holds worktrees from exactly one repository, a local `autoMemoryDirectory` override may intentionally point it at that repository's memory. This is an exception for the container, not a fix for linked worktrees.

When Claude started outside a git checkout but the launch directory contains linked worktrees, immediately tell the user that repository auto memory may not have loaded and recommend restarting Claude inside the intended worktree. Do not wait for the user to notice missing memory.

## Check

1. From the session's default working directory, run `git rev-parse --is-inside-work-tree`. If it fails or returns `false`, Claude did not start inside a checkout. Restart inside the intended worktree or verify an intentional container override.
2. From the main checkout and affected worktree, run:

   ```text
   git rev-parse --path-format=absolute --show-toplevel
   git rev-parse --path-format=absolute --git-common-dir
   ```

   Matching git common directories identify linked worktrees. Do not compare Windows paths by raw string or confuse cwd-keyed transcript directories with the `memory/` directory.
3. Run `/context` to see what loaded, `/memory` to open the resolved memory folder, and `/status` to inspect settings sources.
4. Only if results still disagree, check `autoMemoryEnabled`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY`, `CLAUDE_CODE_DISABLE_CLAUDE_MDS`, `autoMemoryDirectory`, and workspace trust.

Re-check current behavior against https://code.claude.com/docs/en/memory and https://code.claude.com/docs/en/worktrees after upgrades.
