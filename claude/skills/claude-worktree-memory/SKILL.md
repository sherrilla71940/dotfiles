---
name: claude-worktree-memory
description: 'Diagnoses and fixes Claude Code auto-memory (MEMORY.md) not being shared across real git worktrees, and clarifies where autoMemoryDirectory / .claude/settings.local.json actually take effect. Load this whenever troubleshooting worktree memory issues, "why is my MEMORY.md empty in this worktree", or deciding whether a subagent / Agent View session will have memory access.'
user-invocable: false
---

# Claude Code worktree + auto-memory: confirmed gap, working fix, and mental model

Confirmed on one specific machine (a Windows work PC), Claude Code v2.1.221, repo `taoyuansewer2`. Re-verify on a fresh machine/version before trusting this wholesale — see "Before relying on this" below.

## The bug

Docs say auto memory is shared across worktrees via a git-derived project key, and that `.claude/settings.local.json` at repo root "resolves through worktrees to the main checkout." On this machine **both claims are empirically false for real linked worktrees** — confirmed by a live test, not just disk inspection (2026-08-05).

**Live-tested finding:** root-only `autoMemoryDirectory` does NOT propagate into real worktrees here. Test: pointed the repo-root setting at an obviously-fake marker path, then ran `claude -p "<probe>"` from three locations. The repo root itself picked up the marker (proving `-p` mode *does* apply local settings — rules out a trust-mode confound). A real linked worktree (confirmed via `git worktree list`) ignored the repo-root setting entirely and fell back to its own self-derived, wrong (case-mismatched) path. So the documented worktree-resolution behavior for `settings.local.json` is not functioning for real worktrees here, at least in headless (`-p`) mode — true interactive-session behavior wasn't separately isolated and remains a small residual gap.

Root-cause theory (secondary detail, not the load-bearing fact): a drive-letter case-sensitivity bug in Claude Code's fallback project-key encoding — main checkout's key is lowercase `c--...`, worktree self-derived keys are uppercase `C--...`. The more load-bearing fact is that resolution itself isn't happening at all, regardless of why.

**GitHub issues:** `anthropics/claude-code#34437` ("Worktrees should share the same project directory as the main repo," open as of 2026-08-05) describes this exact symptom. `#39920` (closed "not planned") describes the *opposite* symptom — worktrees collapsing INTO main (over-sharing) — and does not explain this. Don't cite #39920 as if it explains the under-sharing case.

## The confirmed working fix

Place a **local** `.claude/settings.local.json` with `autoMemoryDirectory` directly inside **every location a session might launch from** — not just the repo root. Verified working (2026-08-05) on two real worktrees on this machine: probe returned the correct shared path only after adding the local file to each.

This is the opposite of the pre-bug-discovery assumption that duplicating `settings.local.json` into worktrees is wasteful — it isn't, here, because resolution doesn't work. Two different reasons a location needs its own copy, don't conflate them:
- **Non-git launch-point folder** (e.g. a plain container folder sitting above several worktrees): needs one for a *permanent, by-design* reason — docs explicitly say it never resolves to repo root, full stop.
- **A real linked worktree**: needs one for a *live-bug* reason — docs say it *should* resolve, and it currently doesn't. This one may stop being necessary if/when `#34437` (or the underlying bug) gets fixed — worth re-testing after any Claude Code upgrade.
- The file also stays local (instead of resolving) when the repo root **is** the home directory, or in **Agent SDK** sessions (not plain CLI) — documented, permanent, unlikely to apply to normal repo work, and moot now that per-location local files are the actual working approach anyway.

**Procedure, per location that needs it (repo root, AND every real worktree, AND any non-git launch folder in use):**
1. If `.claude/settings.local.json` doesn't exist yet in that location, create it; if it exists, merge in the key rather than overwriting the file.
2. Add/update `autoMemoryDirectory` to point at the shared memory path (same value everywhere: `~/.claude/projects/<base-repo-encoded-path>/memory`).
3. Check whether it's actually gitignored (`git status --porcelain .claude/settings.local.json` — no output means ignored or unchanged-and-tracked; check which). Don't assume a global gitignore rule covers it without checking.
4. If it is **not** ignored, add it to the repo's (or a personal) `.gitignore` — it can contain machine-specific absolute paths and shouldn't be committed as-is. Remind the user to commit that `.gitignore` change themselves.
5. **Verify, don't assume** — re-run the marker-path test (below) for that specific location before trusting it's actually working.
6. Value must be an absolute path or start with `~/`. In project/local settings it's honored only after the workspace-trust dialog is accepted for that folder — expect that prompt the first time a new session starts there.

**If an old pre-2.1.211 `settings.local.json` is still sitting inside a worktree** (left over from before upgrading): it isn't simply superseded. When both the old worktree-local file and the new repo-root file set the same key, the repo root's value wins for non-permission keys, but **permission rules from both files stay in effect** — don't assume the worktree-local file is safe to ignore or delete without checking its permission rules first.

**If `MEMORY.md` content looks unexpectedly empty in a new worktree:** don't assume there's no history. Check sibling folders under `~/.claude/projects/` for one matching the same repo without a worktree-path suffix, read memory from there, and add a local `autoMemoryDirectory` entry to that worktree per the procedure above.

### The marker-path test (reproducible verification procedure)

1. Temporarily set the repo-root `autoMemoryDirectory` to an obviously-fake path, e.g. `~/.claude/projects/ZZZ-TRUST-SKIP-TEST-MARKER/memory`.
2. From the location you want to test, run: `claude -p "Look only at the system-reminder / context you were given at the very start of this conversation about your auto-memory MEMORY.md file. Reply with ONLY the exact absolute file path shown for it, nothing else. If no such path or memory content was shown to you at all, reply with exactly: NO_MEMORY_PATH_SHOWN" --output-format text`
3. Interpret: `NO_MEMORY_PATH_SHOWN` or the marker path itself → that location correctly read the setting (from wherever it resolved). A *different* self-derived path → it never read the setting at all (the bug, or a missing local file at that location).
4. Restore the repo-root file to its correct value immediately after testing.

## Before relying on this

Re-fetch `https://code.claude.com/docs/en/memory#storage-location` and `https://code.claude.com/docs/en/settings` directly before troubleshooting fresh — this may be a live, unfixed bug that could change with any Claude Code upgrade. Re-run the marker-path test above rather than trusting this file's snapshot if anything seems off.

## Mental model — how session launch location and orchestration actually interact

Personal notes, not a spec — written to stop re-deriving this every time.

1. **Memory resolution happens PER-PROCESS, at launch, based on that process's own cwd** — never inherited from a "parent" session. Every `claude` process (interactive, `-p`, or an Agent-View background session) independently resolves its own memory folder from wherever IT was started. That's why the fix has to be applied to each location separately instead of once globally. A brand-new worktree created later starts back at zero until the same local `settings.local.json` fix is copied into it too.

2. **Subagents (the Agent tool — Explore, general-purpose, etc.) are NOT the same as launching a new process**, and do NOT participate in the project's `MEMORY.md` system at all by default, regardless of what directory they're pointed at. The main conversation's auto memory isn't loaded into subagents, except a "fork" (inherits a snapshot of the parent's already-loaded content, not a live folder lookup) or a subagent explicitly configured with its own separate `memory` field (gets its own distinct memory dir, not the parent's). "Will my subagent share memory with the parent" is the wrong question — ordinary subagents are memory-isolated by design, independent of location.

3. **This also applies to Claude Code's own Agent View (`claude agents`).** Typing that command just opens a dashboard; the dashboard's own location doesn't matter. Each individual background agent it dispatches is a separate process per (1), with its own cwd — typically a freshly auto-created worktree under `.claude/worktrees/<name>/`, nested inside the repo rather than a sibling folder like manually-created worktrees. Per (1), each of those is a brand-new, never-fixed location — still a real linked worktree, so it very likely hits the same bug, just untested. The fix here only covers the locations actually tested; anything Agent View auto-creates has no fix applied and would need the same treatment (or a way to apply it automatically per new worktree) if its memory sharing matters.

4. **Correct architecture for parallel work in existing (manually-created) worktrees, with working shared memory:** don't use Agent-tool subagents pointed at them (memory-isolated regardless of location, per 2), and don't use Agent View's own "dispatch a new agent" flow (creates a fresh, unfixed worktree per 3, not the existing ones). Instead: `cd` into each existing worktree and launch a real `claude` session from there — interactive, or `claude --bg` (starts as a background agent, manageable via `claude agents`). That's a separate process per (1), so it correctly resolves the already-applied fix. Use `claude agents` only as a dashboard afterward, to monitor/manage sessions started this way — not to spawn them in the first place.

5. **Agent View is monitoring, not orchestration.** `claude agents` watches independent, unrelated processes — none of them direct, wait on, or synthesize results from another; *I* am the orchestrator via the dashboard, not an AI session. Real orchestration (something that waits on results and decides next steps) only comes from one main session spawning subagents — but that's exactly the pattern that loses `MEMORY.md` per (2), categorically, regardless of worktree isolation. So subagent work depends entirely on what I hand it in the prompt — the parent session has memory loaded, so it's on the parent to pull out what's relevant and write a self-contained prompt, not assume the subagent knows it. Open question, not yet verified: "Agent Teams" (experimental, shared task list + direct inter-agent messaging) might be a middle path — real coordination between separate processes, not subagents — but whether those get memory access, or how mature it is, is unchecked. Worth investigating before assuming subagent/no-memory is the final tradeoff.
