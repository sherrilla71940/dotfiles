# Continuity state format

Use this as the default shape for `.agent/continuity.md`. Keep sections concise and omit empty optional sections when that improves readability.

```markdown
# Project Continuity

## Continuity metadata

- Privacy protection: `<pre-existing ignore / local exclude managed by workflow / non-Git>`
- Managed exclude entry: `</.agent/continuity.md / none>`
- Containing directory: `<created by workflow / pre-existing>`

## Objective

One or two sentences describing the tracked outcome.

## Current phase

The phase another session should resume from.

## Completed

- Only verified work relevant to the current objective.

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

## Relevant files

- `path/to/file` - why it matters to the next session.

## Candidate durable knowledge

- Optional. Facts or rules that may deserve promotion to permanent/private project instructions, but have not been promoted yet.

## Verification

- Branch: `<branch or unknown>`
- HEAD: `<commit or unknown>`
- Working tree: `<clean / modified / concise description>`
- Last reconciled: `<ISO date/time when practical>`
```

## Maintenance rules

- Treat the continuity file's existence as the opt-in marker for active continuity.
- Preserve whether privacy protection was pre-existing or added by this workflow so final cleanup can reverse only workflow-owned setup.
- Preserve whether `.agent/` was created by this workflow or pre-existed. Never infer ownership later from whether the directory happens to be empty.
- Ignore only `.agent/continuity.md` for this workflow; never broaden privacy protection to the entire `.agent/` directory solely for continuity.
- Keep the file under about 120 lines when practical. Compact it by removing resolved history, duplicated context, superseded decisions, and details already durable in the repository before it grows past that.
- Treat the file as subject to concurrent edits from another session or client. Re-read it immediately before writing and compare against what was loaded earlier; merge non-conflicting changes automatically and ask the user only on an actual contradiction. Never overwrite a version that was not just re-read.
- Prefer current state over historical narrative.
- Replace superseded information instead of keeping both versions.
- Remove resolved blockers and completed TODOs from active sections.
- Keep completed items only while they help explain the current objective or prevent rediscovery; prune them when they no longer help.
- Label assumptions and unverified claims explicitly.
- Never use `Completed` for work that has not been checked against repository evidence.
- Keep implementation details in the repository rather than copying large code snippets here.
- Do not invent next actions when the tracked work is complete; ask about cleanup instead.
- Do not store secrets or credentials.
