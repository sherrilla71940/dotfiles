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

Claude Code auto memory and Codex memory are separate client-owned persistence mechanisms. They may retain useful learnings, preferences, corrections, or context, but they are not the source of truth for cross-client work-session continuity.

These boundaries apply to the continuity workflow's own actions only. They do not pause, restrict, or override the client's independent memory system, which continues writing and using memory under its own standing rules whether or not continuity is active.

While performing continuity operations, do not:

- copy native memory wholesale into continuity;
- depend on native memory as the only record of unfinished work;
- modify or delete native memory during checkpoint or cleanup;
- assume one client's memory is visible to the other.

## Unsupported client

GitHub Copilot is intentionally outside this skill's supported routing. Do not invent a private Copilot instruction filename or silently fall back to a different mechanism.
