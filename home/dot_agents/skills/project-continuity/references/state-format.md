# Continuity state format

Use this as the default shape for `.project-continuity/state.md`. Keep sections concise and omit empty optional sections when that improves readability.

```markdown
# Project Continuity

## Objective

One or two sentences describing the tracked outcome.

## Current phase

The phase another session should resume from.

## In progress

- Work that has started but is not verified complete.

## Blockers

- External dependencies, missing APIs, decisions needed, or other conditions that prevent progress.

## Next actions

1. The most useful concrete next step.
2. Additional ordered steps only when they materially help resumption.

## TODO / deferred

- Unresolved work that is real but not the immediate next action.
- Use labels such as `TODO integration` when appropriate to the project.

## Decisions still in force

- Decisions that continue to constrain implementation and would be costly to rediscover.

## Verification

- Working tree: `<absolute path of this working directory>`
- Branch: `<branch or unknown>`
- HEAD: `<commit or unknown>`
- Started from: `<commit this task began at, when known>`
- Status: `<clean / modified / concise description>`
- Last reconciled: `<ISO date/time when practical>`
- Cleanup: `<omit normally; set to declined once the user has refused cleanup for this task>`
- Parked: `<omit normally; set to the ISO date when this file is moved into parked/>`
```

## Maintenance rules

- Treat the continuity file's existence as the marker that continuity is active here.
- `Objective` plus `Started from` is the task identity. It exists only to detect an obvious mismatch when a working tree is reused for a different task; do not add version or identifier machinery beyond it.
- Branch is supporting evidence, not identity. A branch switch in the same working tree does not by itself mean a different task. Update the recorded branch when reconciling the same task, never merely to silence a drift notice.
- Record in `Status` whether a branch switch stashed or carried this task's uncommitted changes. Without that, a later reconciliation sees a clean tree and may conclude the work was finished or lost.
- Keep the file under about 120 lines when practical. Compact it by removing resolved history, duplicated context, superseded decisions, and details already durable in the repository before it grows past that.
- Treat the file as subject to concurrent edits from another session or client. Re-read it immediately before writing and compare against what was loaded earlier; merge non-conflicting changes automatically and ask the user only on an actual contradiction. Never overwrite a version that was not just re-read.
- Write every section in English, quoting a foreign-language string verbatim only where its exact wording matters.
- Prefer current state over historical narrative.
- Replace superseded information instead of keeping both versions.
- Remove resolved blockers and completed TODOs from active sections.
- Record a completed step only inside `Current phase` or a decision that still constrains the work; there is no `Completed` section, because finished work belongs to Git.
- Label assumptions and unverified claims explicitly.
- Keep implementation details in the repository rather than copying large code snippets here.
- Do not invent next actions when the tracked work is complete; ask about cleanup instead.
- `In progress`, `Next actions`, `Blockers` and `TODO / deferred` are the sections that carry unfinished work. All four being empty or absent is what marks the task finished, and Claude's Stop hook reads exactly that to raise the cleanup offer, so do not park a placeholder item in them to keep a finished file alive.
- Set `Cleanup: declined` only after the user has actually refused cleanup. It suppresses the offer for the rest of the task, so it must never be used to pre-empt asking.
- A file in `parked/` keeps this same format. Add `Parked` and change nothing else; it is a
  handoff that was set aside, not a summary of one.
- Do not store secrets or credentials.
