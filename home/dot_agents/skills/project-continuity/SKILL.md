---
name: project-continuity
description: Maintain private, repository-local work-session continuity across Claude Code and Codex. Use when the current repository already has an active continuity file for this workflow, when the user explicitly asks to start or resume continuity, keep continuity for multi-session work, checkpoint progress, prepare a handoff, reconcile stale state, or clean up completed continuity. If no continuity state exists and the user has not opted in, do not initialize it automatically; for work that is clearly likely to span sessions and would materially benefit from handoff, ask once whether the user wants continuity enabled. Do not use for GitHub Copilot.
---

# Project Continuity

Maintain a compact, private snapshot of unfinished project work so a later Claude Code or Codex session can continue without rediscovering the same state.

Treat continuity as **where the work stopped**, not as project documentation, native client memory, or a conversation transcript.

## Operating principles

1. Treat repository and Git reality as authoritative. Never trust saved continuity blindly.
2. Keep continuity private and repository-local by default.
3. Keep only state that materially helps the next session continue.
4. Reconcile and prune stale state whenever reading or writing continuity.
5. Never claim work is complete unless repository evidence supports the claim.
6. Keep native client memory separate from continuity. This restricts only what the continuity workflow itself does: while performing continuity operations, do not read, write, disable, or curate Claude auto memory or Codex memory as part of that work. It does not suspend or override the client's own independent memory system, which keeps following its own separate, standing rules — including writing memories proactively without being asked — regardless of whether continuity is active. Only touch native memory directly when the user separately and explicitly asks for that as its own task.
7. Do not silently promote temporary state into durable project instructions.
8. Once continuity is enabled for tracked work, maintain it without repeatedly asking permission to checkpoint.
9. Treat the continuity file as subject to concurrent edits from another session or client. Re-read it immediately before writing and compare against what was loaded earlier in the turn. Merge automatically when the changes are clearly non-conflicting; ask the user only when there is an actual contradiction or ambiguity that cannot be safely resolved. Never blindly overwrite a version that was not just re-read.

Read [references/state-format.md](references/state-format.md) when creating or substantially restructuring the continuity file. Read [references/client-routing.md](references/client-routing.md) before promoting information into private client-specific project instructions.

## Supported clients

Support only:

- Claude Code
- Codex

Do not use this skill for GitHub Copilot. If the runtime is clearly Copilot, stop the continuity workflow and continue the user's ordinary task without this skill unless the user explicitly asks about the unsupported setup.

Do not require client detection for ordinary continuity operations because the continuity file is client-neutral. Determine the client only when client-specific behavior matters, especially when the user asks to promote durable private project instructions.

## Activation and bootstrap

Use the repository's continuity file as the durable opt-in marker for later sessions.

- If an active continuity file already exists, treat continuity as enabled. Resume and reconcile it without asking the user to opt in again.
- If the user explicitly asks to enable or use continuity and no file exists, initialize it.
- If no continuity file exists and the user has not opted in, do not create one automatically.
- If no continuity file exists but the task is clearly likely to span multiple sessions and continuity would materially reduce rediscovery, ask once whether the user wants to enable project continuity.
- Do not suggest continuity for small, routine, or obviously single-session work.

Good reasons to suggest continuity include multi-phase discovery and implementation, migrations, large refactors, multiple independent TODOs, unresolved external dependencies, cross-session investigations, or likely handoff between Claude Code and Codex.

The skill itself cannot bootstrap discovery in a fresh session before it is selected. The user's always-on Claude/Codex instructions should contain a tiny rule that checks for the continuity file and invokes this skill when present. Keep that bootstrap rule outside this skill. Because skill discovery can fail even when the skill is correctly installed, that bootstrap rule should invoke this skill by name and include an explicit fallback path (`~/.agents/skills/project-continuity/SKILL.md`) to read directly if name-based resolution does not work.

## Continuity location and privacy

Continuity always lives at one canonical path:

```text
.project-continuity/state.md
```

The directory belongs to this workflow. Create it when the user has opted in, and never place anything in it other than continuity state.

In a Git repository, ensure the directory is ignored before relying on it as private state. Prefer a **repository-local Git exclude** over changing tracked `.gitignore`:

1. Check whether `.project-continuity/` is already ignored, and stop here if it is.
2. Resolve the local exclude path with Git, for example `git rev-parse --git-path info/exclude`.
3. Add an anchored entry for `/.project-continuity/` to that local exclude file.
4. Do not modify tracked `.gitignore` solely for this skill unless the user explicitly asks.

If the repository is not managed by Git, keep the file local but clearly tell the user that Git-based ignore protection is unavailable.

Never store secrets, credentials, tokens, personal data unrelated to the work, or large copied artifacts in continuity state.

## Determine the operation

Infer the requested operation from the user's intent:

- **Start / resume**: begin or continue a tracked multi-session task.
- **Checkpoint**: synchronize meaningful progress without ending the work.
- **Handoff**: prepare a clean restart point because the user is stopping or switching sessions/agents.
- **Cleanup**: remove continuity state after the tracked work no longer needs it.

If the user says to "use continuity for this task" without naming an operation, perform start/resume and keep the workflow active for meaningful stopping points during that task.

## Start / resume

1. Find the repository root and locate the existing continuity file.
2. If the file exists, treat continuity as already enabled and read it before substantive project work.
3. Inspect enough current repository state to verify the saved claims. Use relevant evidence such as:
   - current branch and HEAD;
   - working-tree status and diffs;
   - files/components/routes mentioned in continuity;
   - tests, build output, or generated artifacts when necessary to validate a claim.
4. Reconcile saved state against reality before using it:
   - correct claims that are no longer true;
   - remove resolved blockers;
   - remove or mark completed TODOs;
   - replace superseded decisions;
   - update next actions when the implementation path changed;
   - deduplicate overlapping items.
5. Preserve unresolved state that is still useful for continuation.
6. If no continuity file exists, initialize one only when the user explicitly opted in. Use [references/state-format.md](references/state-format.md).
7. Continue the user's actual task. Do not spend the response merely restating continuity unless the user asked for a status report.

If saved state conflicts with repository evidence, use repository evidence and update continuity accordingly.

## Checkpoint automatically at meaningful stopping points

Do not depend on detecting the literal end of a chat session.

Concretely: before sending a response that leaves unresolved TODOs, blockers, an incomplete implementation phase, or a defined next step, evaluate whether continuity changed and checkpoint it if so. This anchors checkpointing to a condition already being evaluated for the response itself, rather than relying solely on a separate judgment call.

For cases outside that checklist, once continuity is enabled, before completing a response that represents a meaningful stopping point, ask internally:

> Would a future session need information from this work that is not already durable in the repository?

If yes, checkpoint before responding.

Meaningful stopping points include:

- completion of a discovery or planning phase;
- completion of a substantial implementation milestone;
- discovery or resolution of a blocker or external dependency;
- a decision that materially changes the implementation path;
- a meaningful change to TODOs or next steps;
- a point where continuing later would otherwise require rediscovery.

Do not checkpoint when:

- continuity has not been enabled;
- nothing meaningful changed;
- the turn is only a small clarification;
- the information is already durable and obvious in code, tests, documentation, or project instructions;
- the update would merely repeat conversation text.

## Checkpoint procedure

When checkpointing:

1. Immediately before writing, re-read the current continuity file and compare it against the version loaded earlier in this session or turn.
2. If it is unchanged, proceed normally.
3. If it changed, attempt an automatic semantic merge when the changes are clearly non-conflicting (for example, additive edits in different sections, or unrelated TODO updates). Ask the user only when there is an actual contradiction (the same field updated two different ways) or genuine ambiguity that cannot be safely resolved. Never blindly overwrite a version that was not just re-read.
4. Reconcile against the current repository and Git state.
5. **Merge and normalize; do not append a diary entry.**
6. Update only useful current state:
   - current objective and phase;
   - verified completed work relevant to the tracked objective;
   - work in progress;
   - blockers and dependencies;
   - unresolved TODOs and deferred integration work;
   - decisions that still constrain future work;
   - exact next actions;
   - relevant files when they make resumption faster;
   - branch/commit/status metadata when useful.
7. Remove stale, contradictory, duplicated, resolved, or no-longer-useful entries.
8. Keep the file under about 120 lines when practical. If it grows beyond that, compact it by removing resolved history, duplicated context, superseded decisions, and details already durable in the repository.
9. If the tracked work is fully complete and no continuity-worthy follow-up remains, do not fabricate a next action. Tell the user continuity no longer appears necessary and ask whether they want cleanup if they have not already requested it.

Do not preserve stale information merely because a previous agent wrote it.

## Separate continuity from durable knowledge

Do not use the continuity file as a substitute for permanent repository documentation or client instructions.

Classify information before storing it:

- **Transient unfinished work** -> continuity file.
- **Durable project/team rule** -> existing shared project instructions or normal documentation, but only when the user asked to make it durable.
- **Durable private personal project instruction** -> client-specific private instruction mechanism, only when explicitly requested; see [references/client-routing.md](references/client-routing.md).
- **Client-learned preference or memory** -> leave to the client's native memory system unless the user explicitly asks otherwise.

If a discovery looks valuable as durable guidance but the user did not ask to promote it, optionally record a short `Candidate durable knowledge` item in continuity rather than editing instruction files silently.

## Handoff

Use a formal handoff only when the user explicitly indicates they are stopping, switching agents/sessions, resuming later, or asks for a handoff.

Before handing off:

1. Perform a full checkpoint and stale-state reconciliation.
2. Ensure the next action is concrete and executable when unfinished work remains.
3. Ensure important blockers and unverified assumptions are clearly labeled.
4. Record branch/HEAD and meaningful working-tree state when relevant.
5. Report a concise handoff summary to the user; do not dump the full continuity file unless requested.

A handoff does **not** imply cleanup.

## Cleanup

Clean up continuity only when:

- the user explicitly requests cleanup; or
- the overall tracked task is complete, no continuity-worthy follow-up remains, and the user confirms continuity is no longer needed.

During cleanup:

1. Reconcile one final time and verify that no unfinished work, blockers, deferred integration, required follow-up, or useful handoff state remains.
2. If useful information belongs in durable documentation or private project instructions, tell the user before deleting it; do not promote it silently.
3. Delete `.project-continuity/`.
4. Leave the repository-local Git exclude entry in place. It is one anchored line matching a path this workflow owns, so a later re-enable finds the privacy protection already correct.
5. Never remove tracked `.gitignore` rules, `CLAUDE.local.md`, `AGENTS.override.md`, native client memory, or unrelated local files as part of continuity cleanup unless the user explicitly requests that separate removal.
6. Confirm what continuity state was removed.

After successful cleanup, the absence of the continuity file means continuity is no longer active for future sessions.

## Private durable project instructions

Routine continuity work must not modify `CLAUDE.local.md` or `AGENTS.override.md`.

Only route information there when the user explicitly asks to make a project-specific instruction durable and private.

Before doing so, inspect the repository's existing instruction architecture and follow [references/client-routing.md](references/client-routing.md). Preserve existing imports, precedence, and ownership conventions instead of creating duplicate instruction systems.

## Failure and ambiguity

- If repository access is unavailable, do not fabricate reconciliation. State what could not be verified.
- If a saved completion claim cannot be verified, downgrade it to unverified/in-progress rather than preserving it as complete.
- If the current client cannot be identified but no client-specific routing is needed, continue with the client-neutral continuity workflow.
- If client-specific routing is required and the client cannot be identified reliably, ask only then.
