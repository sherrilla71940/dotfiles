# ADR-0047: Enforce company-flow branches with an explicit bypass

- Status: Accepted
- Date: 2026-09-29

## Context

The task workflow already required a flow number in effective `company` context, but that rule lived
in client instructions. A direct Git push, another automation path, or an older client could bypass
the instruction without a repository-level signal. The user needs a strict default for company
application repositories and a deliberate escape hatch for exceptional branches.

This dotfiles repository is an explicit exception. Its root instructions force effective `personal`
context while its own source is edited, so the machine-wide company default must not block this
repository's normal branch policy.

## Decision

- Render the machine profile's effective context into global Git configuration as
  `branch.policy=company-flow` for `company` and `branch.policy=personal` for `personal`.
- Render a global pre-push hook that rejects non-flow branches under `company-flow` and accepts
  `flow/<digits>-<ascii-description>` branches.
- Allow repository-local `branch.policy=personal` or an explicitly documented
  `branch.policy=project-exception` to override the machine-wide default.
- Make `run-task-end-to-end --force branch=<branch>` the only normal workflow bypass. Reject it in
  personal context, reject it with `flow=`, and require effective continuity so the active state
  records `company-flow-bypassed` and `Policy bypass: --force`.
- Keep verification, base freshness, commit, publish authorization, and repository-specific safety
  checks mandatory when the bypass is used. The workflow must not rename a branch or silently repair
  a policy mismatch during publishing.
- Preserve the dotfiles repository's local `branch.policy=personal` setting in bootstrap procedures.

The pre-push hook is defense in depth, not a server-side policy boundary. Git hooks cannot reliably
infer why a user requested `git push --force`; a direct emergency hook bypass remains Git's standard
`--no-verify` option and must be separately reviewable. A forge-side branch rule remains stronger
when the company provides one.

## Alternatives considered

- **Keep instruction-only enforcement:** rejected because direct pushes and older clients can bypass
  it without a visible repository-level check.
- **Block every non-flow branch permanently:** rejected because legitimate documented project
  exceptions need a deliberate route.
- **Treat `git push --force` as the workflow bypass:** rejected because the Git hook cannot reliably
  distinguish that push option from unrelated history-rewrite intent.
- **Allow `--force` without continuity:** rejected because the exception would leave no durable local
  record for the push boundary to verify.

## Consequences

Company-context repositories receive a strict default after the rendered Git configuration and hook
are applied. Exceptional branches require an explicit branch name and leave an auditable continuity
record. Personal repositories and documented project exceptions remain usable, but their local policy
must be explicit. Hook enforcement depends on the global target being current; apply the selected
profile after changing it, and use forge-side enforcement when it exists.

## Reconsider when

Revisit this decision if the company supplies a server-side branch-policy integration, if Git gains a
portable hook API for distinguishing push intent, or if the profile schema gains a first-class
repository-policy registry.

## Related files and verification

- [`home/.chezmoitemplates/git/global-config.ini`](../../home/.chezmoitemplates/git/global-config.ini)
- [`home/.chezmoitemplates/git-hooks/company-flow-pre-push.sh`](../../home/.chezmoitemplates/git-hooks/company-flow-pre-push.sh)
- [`home/dot_config/git/hooks/executable_pre-push.tmpl`](../../home/dot_config/git/hooks/executable_pre-push.tmpl)
- [`home/.chezmoitemplates/skills/run-task-end-to-end/invocation.md`](../../home/.chezmoitemplates/skills/run-task-end-to-end/invocation.md)
- [`docs/worktree-provisioning.md`](../worktree-provisioning.md#company-flow-branch-policy)
- [`scripts/tests/test-company-flow-policy.sh`](../../scripts/tests/test-company-flow-policy.sh)

Verify with:

```bash
bash scripts/tests/test-company-flow-policy.sh
bash scripts/tests/test-run-task-end-to-end.sh
```
