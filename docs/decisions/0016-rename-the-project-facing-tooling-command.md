# ADR-0016: Rename the project-facing tooling command

- Status: Accepted
- Date: 2026-09-15

## Context

The GitHub repository is being renamed from `dotfiles` to
`personal-agentic-dev-environment` because it manages a broader developer environment: AI-client
integrations, editor and terminal settings, shells, Git, bootstrap, diagnostics, and task
workflows. The repository-local diagnostic entry point was named `scripts/dotfiles`, which makes
the command sound narrower than the repository it serves.

The command is repository tooling, not a managed home-directory command. Its name should describe
the broader environment without forcing a long repository slug into every invocation. The rename
must also preserve chezmoi's source-state filename attributes and the deliberate local checkout
layout documented by ADR-0006.

## Decision

Rename the repository-local diagnostic command and implementation to:

```text
bash scripts/dev-env doctor
scripts/diagnostics/dev-env-doctor.sh
```

Keep the following unchanged:

- `home/dot_*` source names, because `dot_` is chezmoi syntax that renders a leading dot;
- the local checkout path `~/dotfiles`, because it is the deliberate source-working-tree layout;
- the `dotf`, `dotf-core`, `dotf-claude`, `dotf-diff`, and `dotf-apply` aliases, because they are
  concise user shortcuts for chezmoi and remain meaningful for dotfile editing; and
- generic uses of “dotfiles” when the word describes a configuration category rather than the
  repository's name.

Update repository documentation, source comments, tests, and the tooling ADR when the command
path is referenced. The GitHub repository slug and description are updated separately from the
local checkout path.

## Alternatives considered

- Keep `scripts/dotfiles`: familiar, but it makes the diagnostic surface carry the old and
  narrower repository identity.
- Use the full `personal-agentic-dev-environment` as the command name: accurately branded, but
  unnecessarily long for a repository-local diagnostic command.
- Rename every `dotf` alias and every `home/dot_*` source: rejected because those names describe
  stable chezmoi or user-interface concepts, not the GitHub repository slug.
- Rename the local checkout to match the GitHub slug: rejected for now because it would require a
  separate chezmoi source-link migration and would change an intentional path decision.

## Consequences

The diagnostic command now describes the complete developer environment and existing documentation
points to its new path. Callers that invoke `bash scripts/dotfiles doctor` must update. No managed
target changes or application-owned configuration changes are implied by this rename.

## Reconsider when

- the repository-local command grows beyond diagnostics and needs a different command namespace;
- a stable global command becomes preferable to a command invoked from a clone; or
- the local checkout path is intentionally migrated as a separate chezmoi change.

## Related

- [`docs/decisions/0015-organize-repository-tooling-by-purpose.md`](./0015-organize-repository-tooling-by-purpose.md)
- [`docs/decisions/0006-keep-the-working-tree-at-dotfiles.md`](./0006-keep-the-working-tree-at-dotfiles.md)
- [`README.md`](../../README.md)
- [`docs/setup.md`](../setup.md)
