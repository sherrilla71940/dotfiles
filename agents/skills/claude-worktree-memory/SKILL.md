---
name: Codex-worktree-memory
description: 'How Codex auto-memory (MEMORY.md) resolves across git worktrees, and which parallel-work mechanisms do or do not get memory access (subagents, Agent View, Agent Teams). Load when memory looks missing in a worktree, when diagnosing autoMemoryDirectory, or when choosing how to run parallel work across worktrees.'
user-invocable: false
---

# Worktree memory + parallel-work access

## Bottom line

**Auto memory is shared across real git worktrees by default. No configuration needed.** Documented and empirically confirmed (v2.1.221, Windows, 2026-08-06). If memory looks missing in a worktree, suspect one of the two traps below before suspecting a bug.

> **Correction notice.** An earlier version of this skill claimed the opposite — that worktrees each got isolated memory, caused by a "drive-letter case-sensitivity bug," fixed by per-worktree `autoMemoryDirectory`. **All of that was wrong**, from misreading the two traps below. The prescribed fix was a no-op and has been removed from this machine. Don't re-derive it.

## The two traps (this is the actually useful part)

**Trap 1 — transcripts are not memory.** `~/.Codex/projects/<key>/` stores *session transcripts*, keyed by **cwd**, so every worktree legitimately gets its own directory. Auto memory lives in `<key>/memory/`, keyed by **git repository**. Seeing per-worktree project dirs proves nothing. **Check for an actual `memory/` subfolder** — on a correctly-working setup only the main-repo key has one.

**Trap 2 — Windows paths are case-insensitive.** `~/.Codex/projects/C--Users-...-repo/` and `.../c--Users-...-repo/` are the **same directory** (verified: identical inode). A drive-letter case difference in a reported path is cosmetic. Never compare memory locations by string.

## Verifying (by content, not path)

```bash
Codex -p "Answer ONLY from the auto-memory MEMORY.md given to you at session start. Line 1: absolute path of your MEMORY.md. Line 2: does it mention <distinctive string from your real MEMORY.md>? Reply YES or NO_MEMORY_CONTENT." --output-format text
```

Judge on line 2. To compare two paths, compare inodes, not strings:

```bash
stat -c '%i %n' "<pathA>/MEMORY.md" "<pathB>/MEMORY.md"   # same inode = same file
```

## When configuration IS warranted

Almost never. Per docs, memory is keyed by git repo, so **any cwd inside the repo — root, subdirectory, or any linked worktree — resolves to the same memory directory.**

The one real exception: a cwd **outside any git repo** (e.g. a plain container folder sitting above several worktrees, used only as a launch point) falls back to "the project root is used instead" and gets separate memory. Fix by not launching sessions there — `cd` into the repo root or an actual worktree. A local `autoMemoryDirectory` there also works, but it's papering over a self-inflicted problem.

**Don't confuse the two settings.** `autoMemoryEnabled: false` is the **kill switch** — docs: "To turn it off for a single project, set `autoMemoryEnabled` in that project's settings." It has nothing to do with worktrees or storage location, and its snippet sits directly above the Storage location section, which makes it easy to misread as a worktree fix. Adding it to a worktree disables auto memory there entirely — the opposite of sharing. `autoMemoryDirectory` (a path) is the storage setting; `autoMemoryEnabled` (a boolean) is on/off.

`autoMemoryDirectory` reference (docs, verified 2026-08-06): read from **any** settings scope — user, project, local, policy, or `--settings`. (A claim circulates that project/local scope is unsupported — that is false.) Value must be absolute or start with `~/`. In project/local settings it's honored only after the workspace-trust dialog is accepted for that folder — and note the trust dialog is skipped in non-interactive `-p` mode, which can make a project/local setting silently inert there.

## Parallel work: who gets memory

1. **Any real `Codex` session** (interactive, `-p`, or `Codex --bg`) started anywhere in the repo — including any worktree, hand-made or auto-created — **gets the shared memory.** Verified.

2. **Subagents (the Agent tool) do NOT**, regardless of directory. Docs: the main conversation's auto memory isn't loaded into subagents; exceptions are a *fork* (inherits the parent conversation, not a live folder lookup) and a subagent with its own `memory` field (a separate directory). By design, unrelated to worktrees — so **a subagent's prompt must carry whatever project context it needs.**

3. **Agent View (`Codex agents`)** is a dashboard, not an orchestrator. Where you type it doesn't matter. Each background agent it dispatches is a separate process — typically in an auto-created worktree under `.Codex/worktrees/<name>/` — and those **do** get shared memory (verified). But no dispatched session directs or waits on another, so *you* are the orchestrator.

4. **Real AI-driven orchestration** only comes from a main session spawning subagents — which is exactly the memory-isolated case in (2). That tradeoff is inherent: orchestration and inherited memory don't currently come together.

5. **Agent Teams** — closes the orchestration gap; memory access **unconfirmed**. Docs (`/docs/en/agent-teams`): teammates are "full, independent Codex sessions" that "communicate directly with each other," and unlike subagents (which "can only report back to the main agent"), "you can also interact with individual teammates directly without going through the lead." Docs never mention auto memory — but since teammates are full sessions, (1) suggests they'd share it if their cwd is in the repo. Plausible, untested. Experimental: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, v2.1.207+. Limits: no `/resume`/`/rewind` with in-process teammates, one team per session, no nesting, no background subagents from in-process teammates.

## Worktree location does not affect memory

"All worktrees … **within the same repo** share one auto memory directory" means the same *git repository*, not the same directory tree. The memory docs say nothing about worktree filesystem location.

Two different things get conflated here:

- **`.Codex/worktrees/<name>/`** is only the default location for worktrees **Codex creates itself** — `--worktree`/`-w`, `EnterWorktree`, subagent `isolation: worktree`, Agent View. Per `/docs/en/worktrees`: "By default, the worktree is created under `.Codex/worktrees/<name>/` at your repository root."
- **Hand-made worktrees can live anywhere**, including outside the repo. Same page, "Manage worktrees manually": "Create worktrees with Git directly when you need to check out a specific existing branch **or place the worktree outside the repository**," with the example `git worktree add ../project-feature-a -b feature-a` — a sibling path. It further confirms the shared behaviors "apply whether you create the worktree with `--worktree`, with `git worktree add`, or through the desktop app."

So a sibling folder (`../repo.worktrees/<branch>`) is a documented, fully supported layout and causes **no** memory problem — verified empirically here too. Do **not** put worktree checkouts inside `.git/worktrees/`; that path is git's internal administrative metadata. Advice to "recreate your worktrees inside `.git/`" is wrong and risks losing work.
