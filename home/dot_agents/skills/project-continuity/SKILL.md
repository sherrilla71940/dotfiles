---
name: project-continuity
description: Maintain private, working-tree-local work-session continuity across Claude Code, Codex and GitHub Copilot. Use when the current working tree already has continuity state, when the user asks to start, resume, checkpoint, hand off or clean up continuity, or when substantive work would be expensive to reconstruct if the current session ended abruptly. Do not initialize it for trivial or self-contained work.
---

# Project Continuity

Continuity does not try to remember everything. It minimizes the cost of suddenly losing the current client's conversation — most often because usage limits end a session with no chance to hand off.

Treat it as **where the work stopped and why**, not as project documentation, native client memory, or a transcript.

## Operating principles

1. Repository and Git reality are authoritative for what exists. Continuity is context and last-known state, never proof.
2. Native client memory may inform reasoning but never by itself establishes the current objective, progress, blockers, next actions, or whether work is complete. Treat any current-task claim it makes as potentially stale and reconcile against Git. Do not read, write, curate or synchronize native memory as part of continuity work; each client's memory system keeps following its own rules independently.
3. Keep only state that materially reduces the cost of resuming.
4. Reconcile and prune stale state whenever reading or writing.
5. Never claim work is complete unless repository evidence supports it.
6. Do not silently promote temporary state into durable instructions.
7. Once enabled for a task, maintain it without asking permission to checkpoint again.
8. Re-read before overwriting; another client may be in the same working tree.

Read [references/state-format.md](references/state-format.md) when creating or restructuring the file.

## Supported clients

Claude Code, Codex, and GitHub Copilot. The file is client-neutral, so ordinary operations need no client detection — determine the client only when routing durable private instructions.

Copilot reaches this skill through `~/.copilot/instructions/**/*.instructions.md`, documented for Copilot CLI and for VS Code sessions running on Agent Host, which read user-level instructions from that harness-agnostic folder rather than VS Code profile data. Other Copilot surfaces are untested; if the bootstrap did not arrive, the user can invoke the skill by name.

One Copilot-specific caution: Copilot Memory is repository-scoped and shared with others who have access to that repository, where Claude and Codex memory are machine-local and private. Continuity itself stays untracked and local either way.

## Scope: the physical working tree

Continuity belongs to **one working directory**, and each working tree has at most one active continuity state, describing its current unfinished task.

- The repository's primary checkout is a working tree. Continuity does not require creating a worktree.
- The same working tree is reused over time: finish task 1, clean up, start task 2 there.
- Same repository does not imply same continuity. Neither does same branch.
- **Switching branches does not create a new continuity scope.** Continuity is scoped to the directory, not the branch. If a branch switch means a different task while useful unfinished state is still present, apply the wrong-task rules below before replacing it. When both tasks must stay independently resumable, park one of them, or use a separate worktree when they also need separate uncommitted changes.
- **A branch switch is not a reconciliation trigger.** Claude's Stop hook reports a recorded branch that no longer matches the checkout, and that report is a warning not to merge rather than an instruction to update. Do not fold the new branch's work into state describing the old task, and do not rewrite the recorded branch just to silence the notice. Reconcile only once the task is established to be the same one. Do not key state files by branch name to avoid this decision either: a detached HEAD has no branch to key on, which is how the Codex app runs its managed worktrees, and uncommitted work belongs to the directory rather than to any branch.
- **Uncommitted work does not follow a branch.** If a branch switch stashed or carried the task's changes, record that in `Status`; otherwise a later reconciliation sees a clean tree and may conclude the work was finished or lost.
- A new worktree starts with no continuity and must not inherit another task's state. Claude Code and the Codex app both read `.worktreeinclude` at the repository root to decide which ignored files to copy into a new worktree, so a pattern there matching `.project-continuity/` would leak one task's state into every new worktree of both clients. Never add one.

Client worktree support differs, and that affects only how a directory is *created*, never who may work in it:

- **Claude Code** creates worktrees natively (`--worktree`, `EnterWorktree`, `isolation: worktree`) under `.claude/worktrees/`.
- **Codex CLI** has no worktree flag; it operates on the directory you start it in, which is all interoperability requires.
- **The Codex app** manages worktrees itself, in `$CODEX_HOME/worktrees` and in detached HEAD. Archiving a chat can delete its worktree, so clean up or hand off before archiving. Do not assume CLI, IDE extension and app behave alike.

Whoever created the directory, any supported client can work in it.

## Activation

Enable continuity when losing the conversation now would cost materially more than re-reading the diff: substantive implementation, multi-file changes, investigation that produced real findings, refactors, migrations, architectural work, or unresolved dependencies.

**Wait for material state before creating the file.** Discussion, questions, options being weighed and a plan still being negotiated are not yet expensive to lose — the user holds that context too, and writing state during them produces a file describing a task nobody has started. Create it at the first point where the work itself becomes the record: implementation begins, a change spans several files, an investigation turns up something non-obvious, a decision is made that constrains what follows, or a dependency is left unresolved. This is later activation, not optional activation — once that point is reached, create it without asking.

Reassess when a small task grows into one of those, and always use continuity for an explicit handoff, an explicit resume, or recovery after compaction, whatever stage the work is at.

Do not enable it for explanation-only questions, small self-contained edits, formatting, or work that is obvious from the diff.

The presence of `.project-continuity/state.md` means continuity is already active — resume it without asking to opt in again, once you have confirmed it tracks the current task. When the file is absent and the work qualifies, create it and say so rather than interrogating the user first. Ask only when it is genuinely unclear whether the work qualifies.

This skill cannot bootstrap its own discovery. The user's always-on instructions carry a small rule that checks for the file and invokes this skill by name, with `~/.agents/skills/project-continuity/SKILL.md` as an explicit fallback path when name resolution fails.

## Location and privacy

Continuity always lives at one canonical path, relative to the working tree root:

```text
.project-continuity/state.md
```

The directory belongs to this workflow. Never put anything else in it.

**Always write the file in English.** It is working state handed between agent sessions and
clients, not a project artifact, so neither a repository's comment-language convention nor the
language of the current conversation reaches it. A reconciling session should never have to
translate before it can establish where the work stopped. This does not change the language of
your replies, and it does not apply to quoted material: keep an error message, a UI string, or a
user's own wording verbatim when the exact text matters, and write the surrounding state in
English.

In a Git repository, ensure it is ignored before relying on it as private:

1. Check whether `.project-continuity/` is already ignored, and stop if it is.
2. Resolve the exclude file with `git rev-parse --git-path info/exclude`.
3. Add the anchored entry `/.project-continuity/`.
4. Do not touch tracked `.gitignore` for this workflow unless the user asks.

`info/exclude` lives in the repository's common directory, so it is **shared by the primary checkout and every linked worktree**, and the anchored pattern resolves against each working tree's own root. One entry therefore protects every working tree, including ones created later — which is why cleanup must never remove it.

Outside Git, keep the file local and tell the user that ignore-based protection is unavailable.

Never store secrets, credentials, personal data unrelated to the work, or large copied artifacts.

## Resume

Step 1 is a gate, not a formality. Everything after it assumes the answer was yes.

1. **Read the `Objective` and `Started from`, and decide whether this state tracks the task you
   were just asked to do.** If it does not, stop here and follow the wrong-task rules below.
   Do not reconcile first and decide afterwards: reconciling rewrites the file to match what you
   are doing now, which is exactly how another task's handoff state gets destroyed.
2. Inspect enough repository state to establish reality: branch and HEAD, working-tree status and diffs, the files continuity names, and tests or build output when a claim depends on them.
3. Reconcile — correct claims that are no longer true, drop resolved blockers and completed TODOs, replace superseded decisions, absorb work done after the last checkpoint, and deduplicate.
4. Preserve reasoning that is still load-bearing, especially rejected approaches and constraints the code does not explain.
5. Identify the first genuinely unfinished action and continue the task. Do not spend the response restating continuity unless a status report was asked for.

Where repository evidence and continuity disagree, the repository wins and continuity is corrected. Where the user's current instruction and continuity disagree about intent, the user wins.

## Wrong-task continuity

When the existing state clearly belongs to a different task, never merge it into the current one. Then:

- If it is completed, obsolete, or no longer useful, replace it.
- If it still represents useful unfinished work, preserve it and ask before replacing. The test is whether replacing would destroy recoverable handoff state, not whether the new request is ambiguous — a user saying "forget that for now, fix the navbar" may be switching tasks temporarily, not abandoning the old one.
- If the user says to abandon the previous task, replace it.

Do not build an archive or history system to avoid this decision. When both tasks need to stay resumable in the same directory, park the first one.

## Parking a second task

A worktree is the right answer when two tasks need separate working trees — separate uncommitted changes, separate HEAD. It is the wrong answer when they do not, and it is unavailable in a repository whose own instructions forbid worktrees. Parking covers that case:

```text
.project-continuity/
  state.md                 the active task
  parked/<short-slug>.md   tasks set aside, same format, not active
```

- **Park:** move `state.md` to `parked/<short-slug>.md`, where the slug comes from the objective. Add `Parked: <ISO date>` to its Verification block and change nothing else — a parked file is a handoff, not a summary.
- **Resume:** move it back to `state.md`, then run the ordinary Resume workflow against it. Park whatever was active first; there is never more than one `state.md`.
- **List:** read the directory. There is no index to maintain and nothing to keep in sync.
- **Close:** delete the file when its task is done. Parked state is not an archive, and a finished task leaves nothing behind here — Git history and the pull request are where a decision's reasoning belongs.

Park when the user turns to something substantial while unfinished state is still useful, and say that you did. Do not park to avoid asking: if the new request is small, answer it and leave `state.md` alone. If the old task is genuinely abandoned, replace it rather than parking it, so the directory does not fill with work nobody will return to.

The Git exclude entry is `/.project-continuity/`, so it already covers `parked/`. The Stop hook only reads `state.md`, so parked tasks raise no drift or cleanup notices.

## Checkpoint

Checkpoint when the cost of losing what is not yet recorded becomes material. Favor what cannot be cheaply reconstructed from the repository: undocumented API or backend behavior, a user decision that constrains the implementation, a rejected approach and why, a surprising test or debug finding, a change of architectural direction, a hidden dependency, the cause of a blocker. Execution state also qualifies when rebuilding it would be expensive.

Before the first substantive action of a turn, checkpoint when the current user instruction materially changes the objective, requirements, decisions, blockers or next action. Record normalized task state, not prompt text. During a long-running turn, checkpoint again at meaningful phase boundaries when losing the new state would be materially expensive.

At each checkpoint and before ending a response with unfinished work, apply this resumability test:
if this session ended now, could another supported client identify the objective, current phase,
first unfinished action, blockers, required external materials, and unverified assumptions without
guessing? If not, update continuity. Skip the update when every fact needed to resume is already
durable in the repository or current state.

Before ending a response, apply the complementary check for the finished case: if continuity
state exists and no unfinished action, blocker, or deferred item remains, say continuity looks
unnecessary and offer cleanup in that response. This trigger is deliberately independent of
checkpointing, because a finished task removes the reason to checkpoint — an offer reachable
only from inside a checkpoint therefore never fires at all, which is why completed state used
to linger. Offer once per task, and if the user declines, record `Cleanup: declined` in the
Verification block rather than raising it again.

Do not checkpoint when nothing meaningful changed, when the information is already obvious in code or tests, when the update would repeat conversation text, or when the change is trivial and cheap to redo.

When checkpointing:

1. Re-read the file immediately before writing and compare it with what was loaded earlier. Merge automatically when changes are clearly non-conflicting; ask only on a real contradiction. Never overwrite a version that was not just re-read.
2. Reconcile against current repository and Git state.
3. Merge and normalize — never append a diary entry.
4. Remove stale, resolved, duplicated, or superseded entries.
5. Keep it under about 120 lines; compact it by dropping resolved history and detail the repository already holds.
6. If the work is complete and nothing continuity-worthy remains, do not invent a next action — say continuity looks unnecessary and offer cleanup.

## Handoff

Only when the user says they are stopping, switching client, or asks for one: checkpoint fully,
apply the resumability test, make the next action concrete and executable, label blockers and
unverified assumptions, record branch and HEAD, and report a short summary rather than the whole
file. A handoff does not imply cleanup.

## Cleanup

Clean up when the user asks, or when the task is complete, nothing continuity-worthy remains, and the user confirms.

The end-of-response completion check in Checkpoint is what raises the second case. Do not wait
for a checkpoint to raise it, and do not treat a quiet final turn as a reason to skip it.

1. Reconcile once more and verify no unfinished work, blocker, deferred item, or useful handoff state remains.
2. If something belongs in durable documentation or private instructions, say so before deleting; never promote it silently.
3. Delete `state.md`. Remove the whole `.project-continuity/` directory only when `parked/`
   is empty or absent; a parked task is somebody's unfinished work, and cleaning up the task
   in front of you is not a reason to discard it. If parked files remain, say which.
4. Leave the Git exclude entry. It is one anchored line covering every working tree of the repository, so removing it would strip protection from the others.
5. Never remove tracked `.gitignore` rules, `CLAUDE.local.md`, `AGENTS.override.md`, native memory, or unrelated files as part of cleanup.
6. Say what was removed.

Clean up before abandoning a client-managed worktree. Claude Code automatically removes clean
subagent worktrees and periodically removes eligible background-session worktrees. It preserves
detectable work, such as changed or untracked files and unpushed commits, but ignored continuity
alone does not make a worktree look active. A Claude-managed worktree whose only local state is
continuity can therefore be removed with that state. Claude's cleanup sweep leaves manually
created worktrees in place.

## Separating continuity from durable knowledge

- **Transient unfinished work** → continuity.
- **Durable project or team rule** → shared project instructions or documentation, but only when the user asks to make it durable.
- **Durable private personal instruction** → the client's private mechanism, only when asked:
  `CLAUDE.local.md` for Claude Code, `AGENTS.override.md` for Codex. Two cautions before writing
  either. Codex reads `AGENTS.override.md` *instead of* its sibling `AGENTS.md` rather than in
  addition to it, so creating one beside a committed `AGENTS.md` silences that file for every
  Codex session with no warning. And Copilot has no private project-scoped equivalent at all —
  its repository instructions are tracked and shared, and `~/.copilot/instructions/` applies to
  every repository — so say the gap exists rather than inventing a filename or falling back to
  another client's mechanism.
- **Client-learned preference** → leave to that client's native memory.

Routine continuity work must not modify `CLAUDE.local.md` or `AGENTS.override.md`. If a discovery looks worth promoting but the user has not asked, say so in your reply instead of editing instruction files.

## Failure and ambiguity

- If repository access is unavailable, state what could not be verified rather than fabricating reconciliation.
- If a completion claim cannot be verified, downgrade it to unverified rather than preserving it as complete.
- If the client cannot be identified and no client-specific routing is needed, continue; the workflow is client-neutral.
