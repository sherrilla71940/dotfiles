# ADR-0056: Limit the end-to-end skill to implementation

- Status: Accepted
- Date: 2026-10-08

## Context

The native-first refactor kept a plan/review route inside `run-task-end-to-end`. It added a
`phase` hint, a branch in the README diagram, and separate instructions for requests that do
not implement a change. Claude Code, Codex, and Copilot already accept ordinary planning and
review requests, so this route does not add a distinct workflow outcome.

## Decision

Use `run-task-end-to-end` for implementation through verification and requested delivery.
Handle plan-only and review-only requests as ordinary agent requests, without invoking the
skill. Remove the `phase` hint and plan/review branch from the skill and landing READMEs.
Keep the existing optional starting-point, branch, workspace, delivery, and verification
choices for implementation tasks.

## Alternatives considered

- Keep plan and review routes in the skill. This duplicates ordinary client behavior and
  makes the skill and documentation more complex without a separate handoff artifact or
  verification contract.
- Remove all explicit hints. They still help users specify meaningful implementation
  choices, while natural-language requests remain sufficient.

## Consequences

The skill has one entry path. Users can still ask any client to plan or review without file
edits. An older prompt using `phase=plan` or `phase=review` should be understood as an ordinary
plan or review request, not as an instruction to implement a change.

## Reconsider when

Add a separate analysis workflow only if recurring tasks need a concrete artifact or
verification contract that ordinary client planning and review cannot provide.

## Related files and verification

- `home/dot_agents/skills/run-task-end-to-end/SKILL.md`
- `README.md` and `README.zh-TW.md`

Render the managed skill in both AI contexts, review the bilingual README diagram and
example, and confirm no current source still advertises the `phase` hint.
