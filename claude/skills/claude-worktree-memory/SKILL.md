---
name: claude-worktree-memory
description: 'Diagnose apparently missing Claude Code auto memory in git worktrees. Load when comparing a main checkout with a linked worktree, when worktree location seems to change memory, or before adding autoMemoryDirectory to make worktrees share memory.'
user-invocable: false
---

# Claude Code worktree memory

## Rule

Auto memory is keyed by git repository, not filesystem ancestry. All linked worktrees and subdirectories of one repository share it regardless of where their checkout directories live. Do not add per-worktree `autoMemoryDirectory` settings for this.

Filesystem ancestry governs `CLAUDE.md` and `CLAUDE.local.md` discovery instead. A tracked project `CLAUDE.md` exists in every checkout; a gitignored `CLAUDE.local.md` exists only in the worktree where it was created. Separate clones, nested repositories, machines, WSL environments, containers, and cloud sessions may have separate auto memory.

## Check

1. From each checkout, run:

   ```text
   git rev-parse --path-format=absolute --show-toplevel
   git rev-parse --path-format=absolute --git-common-dir
   ```

   Matching git common directories identify linked worktrees. Do not compare Windows paths by raw string or confuse cwd-keyed transcript directories with the `memory/` directory.
2. Run `/context` to see what loaded, `/memory` to open the resolved memory folder, and `/status` to inspect settings sources.
3. Only if results still disagree, check `autoMemoryEnabled`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY`, `CLAUDE_CODE_DISABLE_CLAUDE_MDS`, `autoMemoryDirectory`, and workspace trust.

Re-check current behavior against https://code.claude.com/docs/en/memory and https://code.claude.com/docs/en/worktrees after upgrades.
