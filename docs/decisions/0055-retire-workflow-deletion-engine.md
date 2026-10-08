# ADR-0055: Retire the workflow deletion engine

- Status: Accepted
- Date: 2026-10-08

## Context

After the native-first workflow migration, one manifest remained under
`scripts/manifests/workflows/`. The deletion engine, test, skill, guide, and manifest together
required about 628 lines to retire an occasional workflow. The engine still depended on a person
to identify owned source, shared dependencies, and generated targets correctly. Git already
preserves tracked source, while chezmoi requires explicit target removal.

This decision supersedes ADR-0046's retained deletion engine and the clause in ADR-0053 that
kept that tool. ADR-0053's native workflow and handoff decisions remain active.

## Decision

Retire the workflow deletion skill, engine, manifest, focused test, and separate guide. Keep a
short procedure in `docs/chezmoi-workflow.md`: inspect direct references, list exact owned and
shared files, resolve rendered targets, delete only owned source, and queue retired targets in
`home/.chezmoiremove`. Review both Git and chezmoi diffs before applying. Keep removal entries
until every managed machine has applied them. Use Git history for source recovery.

Retire the unused browser collaboration and prompt optimization skills in the same cleanup.
Keep the useful human-assisted browser-testing principle in the shared core. Keep focused
accessibility review as a smaller skill that refers to authoritative standards rather than
maintaining a local standards catalogue.

## Alternatives considered

- Keep the engine for future workflow retirements. Its validation is useful, but maintaining the
  parser, manifest, test, client skill, and guide costs more than a reviewed manual procedure for
  the remaining personal workflow set.
- Delete sources without target entries. Rejected because previously rendered skills would remain
  on managed machines after source deletion.
- Retire the accessibility skill. Rejected because accessibility review still benefits from a
  focused interaction and verification workflow.

## Consequences

Workflow retirement now relies on an agent's reviewed inventory rather than a manifest parser.
The source diff and target removal list remain explicit. There is no automatic rollback of a
partial manual deletion; Git restores tracked source, and live target changes require a separate
reviewed `chezmoi apply`.

The retired skills may remain installed until each machine applies the queued removal entries.
No ignored task records or application-owned settings are removed by this decision.

## Reconsider when

Reintroduce a helper only if repeated workflow retirements show a specific inventory or target
cleanup error that a small, tested tool can prevent.

## Related files and verification

- `docs/chezmoi-workflow.md`
- `docs/customization-support.md`
- `home/.chezmoiremove`
- `home/.chezmoitemplates/core.md`
- `home/dot_agents/skills/accessibility-review/SKILL.md`

Check direct references, render counts, the focused profile tests, and `chezmoi diff` before
applying target cleanup.
