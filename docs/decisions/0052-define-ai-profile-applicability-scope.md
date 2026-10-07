# ADR-0052: Define AI profile applicability scope

- Status: Accepted
- Date: 2026-10-06

## Context

The AI profile resolver deterministically composes the shared baseline with either the personal or
company context. The authoring guidance did not make the same distinction explicit. Its skill table
used "scope" to mean which clients discover a skill, while `ai_context` selects which profile
guidance applies. A portable skill can be context-specific, and client reach alone cannot decide
whether its content belongs in the baseline.

The shared JavaScript rule also called a naming convention a "company standard" without a context
guard. The selected personal context therefore received that convention. The text indicates
company-only applicability, so this record moves it to the company context layer.

## Decision

- Classify reusable AI guidance on two independent axes: profile applicability and client reach.
- Use `baseline` for guidance that is valid in both personal and company contexts. Use `personal` or
  `company` only for guidance intended for that selected context. Keep project-specific guidance in
  project instructions; it is not an `ai_context` value.
- Keep client reach separate and name every receiving client; `portable` describes reach across
  multiple clients rather than replacing the exact client set. A portable skill can be baseline or
  context-specific. The existing native skill packages remain discoverable in both profiles; this
  decision does not add profile-based skill installation or removal.
- Store baseline guidance in the existing shared core, rule bodies, and skill packages. Store
  context-only global guidance in `profiles/personal.md` or `profiles/company.md`, included by the
  shared core's profile condition. Keep one skill package when a workflow remains available in both
  contexts, and resolve its context-dependent execution defaults from the effective context.
- Treat shared rule guidance as the default; a more-specific rule in the selected profile can
  override it for that context.
- Require every new or materially changed reusable AI artifact to state `Profile scope` and
  `Client reach` in its task or change plan. If intended applicability is unclear, ask before
  editing. Do not infer it from the current machine, client, or a filename.
- Render both contexts for staged changes to shared AI guidance, rules, or skills. The focused
  profile-scope check must confirm that baseline guidance appears in both contexts and that the
  company JavaScript naming convention appears only in the company context. Keep the full profile
  matrix suite for defaults, invalid values, language behavior, and harness combinations.

## Alternatives considered

- **Duplicate complete personal and company skill trees.** Rejected because duplicate procedures
  would drift and the current profile system does not filter native skill discovery by context.
- **Infer scope from the prose.** Rejected because static checks cannot determine whether an
  instruction is intended for one context or both. Authors must declare applicability, and render
  checks verify that declared placement.
- **Use client frontmatter for profile scope.** Rejected because native clients have different
  metadata schemas, and profile applicability is independent of client reach.

## Consequences

The shared core now tells agents to classify profile applicability separately from client reach.
The customization guide defines the canonical sources and requires both decisions in a task or
change plan. The pre-commit hook renders personal and company outputs from the staged source when
AI instruction, rule, or skill sources change. The company naming convention no longer leaks through
the shared JavaScript rule into the personal context.

The repository can verify the declared source path and rendered output. It cannot prove that an
author chose the correct semantic scope; ambiguous intent still requires a human decision. This
contract governs guidance applicability, not whether a skill package is discoverable in a context.

## Reconsider when

- The repository adds another AI context or changes the shared-baseline-plus-one-context model.
- A client supports reliable profile-based skill discovery and the repository needs context-specific
  skill availability.
- The company JavaScript naming convention is intentionally adopted as a baseline rule for personal
  context too.

## Related files and verification

- [`home/.chezmoitemplates/core.md`](../../home/.chezmoitemplates/core.md)
- [`home/.chezmoitemplates/profiles/company.md`](../../home/.chezmoitemplates/profiles/company.md)
- [`home/.chezmoitemplates/rules/javascript.md`](../../home/.chezmoitemplates/rules/javascript.md)
- [`docs/customization-support.md`](../customization-support.md#separate-profile-applicability-from-client-reach)
- [`scripts/tests/test-ai-profile-scope.sh`](../../scripts/tests/test-ai-profile-scope.sh)
- [`scripts/git-hooks/pre-commit`](../../scripts/git-hooks/pre-commit)

Run `bash scripts/tests/test-ai-profile-scope.sh <chezmoi-bin> <source-root>` for the focused
two-context check and `bash scripts/tests/test-ai-configuration-profiles.sh` for the full profile
matrix. The repository pre-commit hook runs the focused check against staged source when AI content
changes.
