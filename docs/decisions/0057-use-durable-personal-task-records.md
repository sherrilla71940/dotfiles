# ADR-0057: Use durable personal task records

- Status: Accepted
- Date: 2026-10-12

## Context

ADR-0053 replaced per-worktree continuity state and lifecycle hooks with native client resume and
an explicit `task-handoff` prompt. That prompt captured a point-in-time transfer, but it did not
help an agent find earlier answers or preserve why a decision was made as a task evolved. The
retired `.task-continuity/state.md` was temporary and pruned resolved history, so restoring it
would not solve the decision-history need.

These records serve the owner's personal workflow, including work in company repositories. They
are not a publication format for teammates. Git remains authoritative for code state; an original
message, ticket, or document remains evidence of an external request or answer.

## Decision

- Use one durable personal Markdown record when requested, when work awaits a consequential
  external answer, when a decision's rationale will matter later, or when work is likely to span
  sessions. Store it at
  `~/Documents/task-records/{repo}/{task-key}.md`, where `{repo}` comes from the subject Git
  remote and `{task-key}` is a verified task ID or stable slug. Store the credential-free remote
  identity in the record. If two verified remotes share the same repository name, preserve
  existing folders and use a stable namespace-qualified key for the other repository across
  task records, materials, tests, and handoffs. Include the host only if namespaces still collide;
  do not migrate existing paths automatically. The file belongs to the task, independent of client,
  branch, or worktree. Client session IDs can be optional source pointers,
  with several sessions linked to one task; they do not identify the record. Self-contained tasks
  whose context is recoverable from the request, repository, and Git need no record.
- Put a short discovery trigger in shared core guidance and the conditional procedure and record
  format in the portable `task-record` skill. This is baseline guidance in both `ai_context`
  profiles and reaches Claude Code, Codex, and GitHub Copilot. Its local files remain private and
  outside the chezmoi source tree.
- At task start or resume, find the matching record before creating one. Reconcile current-state
  claims with Git and original sources. Update it at material changes, keep answered questions and
  decision rationale, mark superseded decisions, and retain completed records. For a later question
  about why a choice was made, search completed records and check their cited sources without
  creating a new record. Keep sourced answers and decisions distinct when the decision adds a
  choice or rationale, and link the decision to the answer instead of copying it. The record is
  the durable personal history of task context, not authority over Git, external requirements,
  or approvals. Keep it focused on durable context and a resumption point rather than a second
  implementation checklist; execution and delivery remain with the active workflow. Link relevant
  external artifacts from the record with their purpose instead of copying their content.
- Keep human-facing handoffs under `~/Documents/handoffs/`. Retire the explicit-only
  `task-handoff` skill after transferring its receiver checks to `task-record`. A receiving session
  that cannot access the local record needs its relevant content supplied explicitly and still
  verifies the claims before continuing.
- Keep native conversation/worktree behavior. Do not restore continuity hooks, per-worktree state,
  task parking, or automatic cleanup. Leave existing ignored `.task-continuity/` files untouched
  until individually reviewed.

This supersedes ADR-0053's explicit `task-handoff` and issue/PR-first task-index decisions. Its
native workspace and verified-Git decisions remain active. ADR-0024's human-facing handoff path
remains active; the new `task-records` path has a separate personal purpose.

## Alternatives considered

- Keep an issue or PR/MR as the personal task index. Rejected because it may not exist during
  active work and does not consistently hold evolving private questions and rationale.
- Keep `task-handoff` alongside a task record. Rejected because it creates a second summary of
  the same active task that can drift; record access and receiver checks cover the intended use.
- Restore the retired continuity state. Rejected because its per-worktree scope, resolved-history
  pruning, hooks, and cleanup rules conflict with a durable task-level decision record.
- Put personal records under `~/Documents/handoffs/`. Rejected because that directory is for
  human-facing coordination and delivery records.

## Consequences

An agent can find a task's answer and decision rationale by task key, alias, or feature and then
check its cited source. Current progress and verification can still become stale, so resuming
agents must reconcile them. The local folder is available only where the file can be read; moving
to another machine requires the owner to transfer or sync the record. Guidance is managed by
chezmoi, while task records themselves are not versioned or copied by this repository.

Current-state fields are dated snapshots, not a live Git feed. Optional session references should
help locate material context rather than enumerate every session. Pending questions stay in the
question section; follow-ups name actionable post-delivery work or externally owned dependencies
and can refer back to those questions. A read-only historical search can start from a recorded
repository identity, while creating or updating a record requires a verified subject remote.

The skill rechecks a record immediately before saving so another session's edits are noticed and
reconciled. That prompt-level check does not guarantee atomic writes; add locking only if actual
concurrent edits justify the maintenance cost.

Retiring `task-handoff` removes the rendered `~/.agents/skills/task-handoff` package and
`~/.claude/skills/task-handoff` link only after a reviewed apply. Existing ignored task data and
application-owned state are not removed.

## Reconsider when

Revisit this design if agents repeatedly miss or duplicate records despite the discovery rule,
if local-only access prevents expected continuation, or if maintaining records costs more than
the decisions they preserve.

## Related files and verification

- `home/.chezmoitemplates/core.md`
- `home/dot_agents/skills/task-record/SKILL.md`
- `home/dot_agents/skills/task-record/references/record-format.md`
- `docs/task-record.md` and `docs/task-record.zh-TW.md`
- `home/.chezmoiremove`
- `scripts/tests/test-ai-configuration-profiles.sh`
- `README.md` and `README.zh-TW.md`

Verify both profile renders with `bash scripts/tests/test-ai-configuration-profiles.sh`, review
Markdown links and `chezmoi diff`, and confirm live target removal only after an approved apply.
