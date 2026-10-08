# ADR-0054: Verify native starting points for routine tasks

- Status: Accepted
- Date: 2026-10-08

## Context

After the native-first refactor, `run-task-end-to-end` still required a named base or target and
a task branch before editing. An ordinary local request without `base` or `target` therefore
paused despite those inputs being described as optional. Codex can
start a managed worktree detached and create a branch later; other clients and existing checkouts
also provide a visible starting commit.

## Decision

For routine work without an explicit starting point, use the suitable current checkout or the
client-selected worktree start. Verify and record its Git root, branch or detached state, and
exact commit before editing. Honor an explicit base, destination, and repository branch policy.
Create a branch before editing when policy requires it; otherwise create one when the client or
delivery needs it. Never infer a publication target from the current branch or its upstream.
Keep the base-freshness and user-choice gate in [ADR-0026](./0026-integrate-current-base-before-publishing.md).

## Alternatives considered

- Require an explicit base and early branch for every task. This protects the starting point but
  interrupts ordinary requests even when the selected workspace already exposes that point.
- Infer the publication target from the current branch or remote default. This can publish to an
  unintended destination, so publication still needs a target from the request or repository policy.

## Consequences

Routine tasks need fewer prompt fields. Agents must still reject a mismatched explicit base,
protect unrelated changes, and obey policy-required branch identifiers. Native worktree defaults
can vary by client and version, so verification uses the actual workspace state.

## Reconsider when

Revisit this rule if observed tasks repeatedly start from the wrong commit despite the checkout
verification, or if a repository needs a stricter project-specific base policy.

## Related files and verification

- `home/.chezmoitemplates/skills/run-task-end-to-end/SKILL.md`
- `scripts/tests/test-ai-configuration-profiles.sh`
- `README.md` and `README.zh-TW.md`

Render both AI contexts and review the skill in each before applying live configuration.
