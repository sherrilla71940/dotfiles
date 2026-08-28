# Client-specific private instruction routing

Use this reference only when the user explicitly asks to promote a discovery into durable **private project instructions**. Routine continuity checkpoints remain in `.project-continuity/state.md` and must not modify these files.

## General routing rule

1. Identify the current client when possible.
2. Inspect existing project instruction files and preserve the repository's established architecture.
3. Do not duplicate a shared rule into a client-specific file merely because that client supports one.
4. Keep private instruction files untracked. Prefer the repository-local Git exclude mechanism when a new private file needs protection, unless the repository already has a deliberate ignore convention.
5. Do not write to native client memory as part of this routing.

## Claude Code

Use `CLAUDE.local.md` for personal, project-specific durable instructions that should not be committed.

Claude Code loads `CLAUDE.local.md` alongside project `CLAUDE.md`. Preserve any existing `CLAUDE.md` imports and shared instruction routing.

Examples appropriate for `CLAUDE.local.md`:

- local sandbox URLs;
- personal test fixtures or local-only workflow preferences;
- private project-specific instructions the user wants loaded every Claude session.

Do not use it for transient work progress such as "page layout is 80% complete"; that belongs in continuity.

## Codex

Use `AGENTS.override.md` for private project instructions when the user explicitly wants a Codex-specific durable override.

At each directory level Codex reads `AGENTS.override.md` if it exists and `AGENTS.md` otherwise, so an override **replaces** its sibling rather than adding to it. The files found from the project root down are then concatenated, with the ones closest to the working directory applied last. The same replacement rule governs the global scope in `~/.codex`.

Creating `AGENTS.override.md` beside a committed `AGENTS.md` therefore silences that file for every Codex session, with no warning. Inspect the repository layout first, and prefer extending the existing instructions unless the user explicitly wants the committed ones bypassed.

Examples appropriate for `AGENTS.override.md`:

- private local workflow overrides;
- personal project-specific conventions intended to affect Codex sessions;
- local environment instructions that should not be committed.

Do not use it for transient work progress; that belongs in continuity.

## Native memory boundaries

Claude Code auto memory, Codex memories, and Copilot Memory are separate client-owned persistence mechanisms. They may retain useful learnings, preferences, corrections, or context, but they are not the source of truth for cross-client work-session continuity.

These boundaries apply to the continuity workflow's own actions only. They do not pause, restrict, or override the client's independent memory system, which continues writing and using memory under its own standing rules whether or not continuity is active.

While performing continuity operations, do not:

- copy native memory wholesale into continuity;
- depend on native memory as the only record of unfinished work;
- modify or delete native memory during checkpoint or cleanup;
- assume one client's memory is visible to another. None of the three are.

## GitHub Copilot

Copilot participates in continuity, but it has **no private project-scoped instruction file** equivalent to `CLAUDE.local.md` or `AGENTS.override.md`. Its repository-level instructions (`.github/copilot-instructions.md`, `AGENTS.md`) are tracked and shared with the team, and `~/.copilot/instructions/**/*.instructions.md` is user-level and applies to every repository.

So there is nowhere to put a private, project-specific, untracked Copilot instruction. Do not invent a filename, and do not silently fall back to a different client's mechanism. Tell the user the gap exists and offer the two real options: a user-level Copilot instruction that applies everywhere, or a tracked repository instruction the team also gets.

Copilot Memory is also different in kind from the other two: it is repository-scoped and shared with everyone who has access to that repository, where Claude and Codex memory are machine-local and private. Never route anything private there.
