# ADR-0013: Ignore personal AI instructions globally

- Status: Accepted
- Date: 2026-09-14

## Context

Claude Code and Codex support project-local instruction files that are useful to one developer
but should not be committed with the team's source. Claude Code calls this file
`CLAUDE.local.md`; Codex uses `AGENTS.override.md` as a more-specific local override. Claude's
local settings file, `.claude/settings.local.json`, is already covered by the managed global
ignore. The ignore file also needs an explicit `core.excludesFile` setting: relying on Git's
environment-dependent default is not reliable across Windows PowerShell, Git Bash, and macOS.

Copilot's personal instruction files live outside a repository under the user's home directory.
Its repository instruction files, such as `.github/copilot-instructions.md`,
`.github/instructions/**/*.instructions.md`, and `AGENTS.md`, are team-visible inputs and must
remain trackable.

## Decision

Manage the global Git ignore at `~/.config/git/ignore` and explicitly point Git at it from the
managed `~/.gitconfig`:

```gitconfig
[core]
    excludesFile = {{ .chezmoi.homeDir }}/.config/git/ignore
```

The file contains these patterns:

```gitignore
**/.claude/settings.local.json
**/CLAUDE.local.md
**/AGENTS.override.md
```

Keep shared `AGENTS.md`, `CLAUDE.md`, and Copilot repository instruction files out of the global
ignore. The patterns protect personal files from accidental tracking in every repository on
machines that apply this dotfiles configuration.

Global Git ignore is only a tracking safeguard. It does not make a file available to an AI client,
copy it into a worktree, or replace a repository's `.worktreeinclude` policy.

## Alternatives considered

- **Ignore the files separately in each repository:** rejected. It requires modifying every team
  repository and is easy to omit in a new clone.
- **Ignore all AI instruction files or the entire `.claude` directory:** rejected. This would hide
  team-shared instructions and project configuration from Git.
- **Add Copilot repository instruction filenames to the global ignore:** rejected. Those files are
  the supported shared Copilot customization surface, while personal Copilot instructions already
  live outside Git.
- **Use only each clone's `.git/info/exclude`:** rejected as the primary policy. It is local to a
  clone and is not carried by the dotfiles configuration to new repositories or machines.
- **Rely on Git's default global-ignore path:** rejected. The default depends on environment
  variables such as `HOME`; explicitly configuring the path keeps PowerShell, Git Bash, and macOS
  on the same managed file.

## Consequences

Personal Claude and Codex instruction files no longer appear as untracked files in repositories
that use this global ignore. If a repository ever intentionally needs to track one of these exact
filenames, it must override the global rule deliberately, for example with `git add -f`.

The policy applies broadly to the user's repositories, including repositories where a maintainer
has chosen to use one of these names for a shared file. The explicit filenames and local semantics
are preferred over a broad `*.local.*` rule to keep that risk visible and narrow.

## Reconsider when

- Claude Code or Codex changes the documented filename or local-instruction behavior.
- Copilot adds a repository-local personal instruction filename that should be protected.
- A maintained repository needs to version one of these names as shared project configuration.

## Related files and verification

- [`home/dot_config/git/ignore`](../../home/dot_config/git/ignore)
- [`home/dot_gitconfig.tmpl`](../../home/dot_gitconfig.tmpl)
- [`docs/worktree-provisioning.md`](../worktree-provisioning.md)
- [`docs/customization-support.md`](../customization-support.md)
- Apply with `chezmoi diff` and `chezmoi apply`, then verify with `git check-ignore -v`.
