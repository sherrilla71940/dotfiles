# ADR-0040: Require company flow branch identifiers

- Status: Accepted
- Date: 2026-09-24

## Context

Company application repositories use flow numbers as the shared task identity in branch names.
Creating a valid Git branch without the required flow identifier violates the team's review and
tracking convention. Inferring a flow number from prose, filenames, or an existing branch is unsafe.

The dotfiles repository is different: its root instructions deliberately override the machine's
`company` selector with effective `personal` context while the repository's own source is edited.
The company rule must not force a flow number onto this user-level configuration repository.

## Decision

Resolve branch policy from the effective context after repository instructions are applied:

- Effective `company` context uses `branch.policy=company-flow` for task branches. Require an
  explicit one-to-nine-digit flow number and a branch matching
  `^flow/[0-9]{1,9}(?:-[A-Za-z0-9_-]+)?$`. Never infer a flow number from task prose or materials.
- Effective `personal` context retains the repository-standard branch naming contract and does not
  require `flow=`.
- A deliberate project-wide exception must be recorded as
  `branch.policy=project-exception` in the repository's local Git config. A branch name cannot
  authorize its own exception.

## Alternatives considered

- Infer the flow number from the task prompt or attached materials. Rejected because branch identity
  would depend on untrusted or ambiguous text.
- Accept any explicit `branch=` as a project exception. Rejected because a branch name cannot
  authorize its own policy bypass.
- Require flow numbers globally. Rejected because personal repositories and user-level configuration
  do not share the company tracking convention.

## Consequences

Company task requests must identify the flow before an execution branch is created. Projects with
legitimate legacy branch conventions must configure an explicit local exception rather than relying
on agent inference. This repository continues to use its existing personal branch convention.

## Reconsider when

Revisit this decision if the company changes its branch convention, a project-tracker integration can
verify flow existence, or the profile model gains a first-class repository policy descriptor.

## Related files and verification

- [`home/.chezmoitemplates/profiles/company.md`](../../home/.chezmoitemplates/profiles/company.md)
- [`home/.chezmoitemplates/git-hooks/company-flow-pre-push.sh`](../../home/.chezmoitemplates/git-hooks/company-flow-pre-push.sh)
- [`scripts/tests/test-company-flow-policy.sh`](../../scripts/tests/test-company-flow-policy.sh)
