---
name: claude-worktree-memory
description: "Diagnose apparently missing Claude Code auto memory in git worktrees or worktree-container folders. Load when a session started near a worktree cannot recall repository memory, when worktree location seems to change memory, or before adding autoMemoryDirectory to change or share memory behavior."
user-invocable: false
---

# Claude Code worktree memory

## Purpose

This skill exists to prevent misdiagnosing missing Claude Code memory when working with git worktrees.

Linked worktrees already share repository auto memory by default. The main failure mode this skill addresses is assuming that each worktree needs its own `autoMemoryDirectory`, when the real cause may instead be:

- Claude was started outside the intended git checkout.
- The directories are separate clones rather than linked worktrees.
- `CLAUDE.md` or `CLAUDE.local.md` differs between checkouts.
- A machine, container, WSL, or cloud environment has separate local memory.
- An explicit memory setting or environment variable changed the default behavior.

Use this skill for diagnosis and verification, not routine worktree setup.

## Rule

Auto memory is scoped per git repository and shared across linked worktrees and subdirectories of that repository. Worktree checkout location does not by itself create separate auto memory.

Do not add `autoMemoryDirectory` merely to make normal linked worktrees share memory; Claude Code already does this by default. `autoMemoryDirectory` is supported in user, project, local, policy, and `--settings` scopes and should only be used when intentionally overriding the default memory location.

`CLAUDE.md` and `CLAUDE.local.md` follow filesystem working-directory discovery instead. At launch, Claude Code loads applicable files from the working directory and its ancestors; files below it can load on demand when Claude works in those directories. A tracked project `CLAUDE.md` normally exists in every checkout, while a gitignored `CLAUDE.local.md` exists only in worktrees where it has been created or copied.

Separate clones are separate repositories for auto-memory purposes. Auto memory is also machine-local, so different machines, WSL environments, containers, or cloud environments should not be assumed to share it unless explicitly configured to use the same memory location.

The directory from which Claude Code is launched matters for initial project and instruction discovery. Starting Claude from a directory outside a git repository should not be assumed to inherit repository auto memory merely because that directory contains one or more worktrees.

Changing directories during a session does not retroactively reproduce a fresh session launch or guarantee that startup-loaded project context will be re-resolved. When repository-specific memory or instructions matter, prefer starting Claude inside the intended checkout or worktree.

For a dedicated non-repository directory or environment that intentionally needs to use a repository's memory, an `autoMemoryDirectory` override may be appropriate. Treat this as explicit memory-location configuration, not as a requirement for normal linked worktrees.

If Claude starts outside a git checkout while the launch directory merely contains linked worktrees, warn that the expected repository auto memory may not have been selected and recommend starting Claude inside the intended worktree unless an explicit memory override is intentional.

## Check

1. From the session's relevant working directory, run:

   ```text
   git rev-parse --is-inside-work-tree
   ```

   If it fails or returns `false`, that directory is not inside a Git checkout. Prefer starting Claude inside the intended worktree, or verify that an intentional `autoMemoryDirectory` override is providing the desired memory location.

2. From the main checkout and affected worktree, run:

   ```text
   git rev-parse --path-format=absolute --show-toplevel
   git rev-parse --path-format=absolute --git-common-dir
   ```

   Different `--show-toplevel` paths are expected for different worktrees.

   Matching `--git-common-dir` results indicate that Git considers the checkouts linked worktrees. Claude Code documents that linked worktrees of the same repository share auto memory by default.

   Do not treat the exact `--git-common-dir` path as a documented Claude Code memory key, and do not confuse cwd-keyed session/transcript directories with the repository's `memory/` directory.

3. Run:

   ```text
   /context
   /memory
   /status
   ```

   Use `/context` to verify which `CLAUDE.md` and `CLAUDE.local.md` files actually loaded.

   Use `/memory` to inspect the resolved auto-memory location and memory files.

   Use `/status` when settings sources or environment configuration may be relevant.

4. If behavior still differs from expectations, check:
   - `autoMemoryEnabled`
   - `CLAUDE_CODE_DISABLE_AUTO_MEMORY`
   - `autoMemoryDirectory`
   - `claudeMdExcludes`, which skips a `CLAUDE.md` by path or glob and is the documented way
     instruction files go missing on purpose
   - `CLAUDE_CODE_PROJECT_DIR_NAME`, which renames the project directory that auto memory is
     keyed by, so two repositories can deliberately share one memory directory
   - settings scope and precedence
   - workspace trust
   - whether the sessions are actually using linked worktrees rather than separate clones
   - whether they are running on different machines, WSL environments, containers, or cloud environments

Do not infer auto-memory identity from filesystem proximity alone.

Re-check current behavior after Claude Code upgrades against:

- `https://code.claude.com/docs/en/memory`
- `https://code.claude.com/docs/en/worktrees`
