# ADR-0051: Preserve app-written Git global settings

- Status: Accepted
- Date: 2026-10-06

## Context

`home/dot_gitconfig.tmpl` managed the complete `~/.gitconfig`. Git's `git config --global`
command writes additional user settings to that same file, so a routine `chezmoi apply` could
erase any key absent from the template. This is the same app-write ownership problem addressed
for editor and client configuration in ADR-0049.

Git supports including another configuration file from `~/.gitconfig`. The repository can keep
its portable values in a dedicated fragment while leaving the main file available for local
settings written by Git or edited by the user.

## Decision

- Move the repository's global Git settings to
  `home/.chezmoitemplates/git/global-config.ini`. Both ownership tracking and the included
  target fragment are rendered from this single source.
- Manage `~/.config/git/dotfiles` as the repository-owned fragment and include it from a marked
  block at the end of `~/.gitconfig`.
- Use `modify_dot_gitconfig` to preserve unrelated lines, remove main-file entries only for keys
  currently named in the shared fragment, and maintain exactly one marked include block.
- Keep app-added keys outside the fragment in `~/.gitconfig`. Because Git reads included values
  at the include location, repository values win collisions with earlier main-file entries.
- Keep the existing user identity, core paths, and branch policy in the shared fragment. The
  retired worktree aliases are removed from the fragment and from legacy main-file entries only
  when they still point to the repository's deleted `git-worktree-provision` helpers.

## Alternatives considered

- **Keep managing the complete `~/.gitconfig`:** rejected because `git config --global` edits
  the target that chezmoi would replace wholesale.
- **Use a create-once target:** rejected because source changes would no longer reach machines
  where Git had already created the file.
- **Round-trip the INI file through a modify template:** rejected because the file is mixed
  app/user state and a parser-based rewrite would reformat unrelated content. Git's native
  include mechanism provides a smaller ownership boundary.

## Consequences

New and existing Git settings absent from the shared fragment survive apply. Repository-owned
keys remain portable and win collisions. The first apply migrates the current managed values out
of the main file into the included fragment and adds the include block. The modify template
preserves other text and appends the block so repository values keep precedence. During this
workflow retirement, it also removes legacy aliases that invoke the deleted repository helpers;
same-named aliases with other commands remain user-owned.

## Reconsider when

- Git changes how it reads include paths or processes included values.
- The key-extraction logic no longer recognizes a key format emitted by Git.
- A source-managed key requires different per-machine ownership from the current fragment.

## Related files and verification

- [`home/.chezmoitemplates/git/global-config.ini`](../../home/.chezmoitemplates/git/global-config.ini)
- [`home/dot_config/git/dotfiles.tmpl`](../../home/dot_config/git/dotfiles.tmpl)
- [`home/modify_dot_gitconfig`](../../home/modify_dot_gitconfig)
- [`docs/chezmoi-workflow.md`](../chezmoi-workflow.md#applications-that-write-their-own-configuration)
- [Git configuration documentation](https://git-scm.com/docs/git-config)

Preview both targets with `chezmoi diff ~/.gitconfig ~/.config/git/dotfiles`. After applying,
verify the effective `user`, `core`, and `branch` values with `git config --global`, confirm no
alias invokes a deleted helper, and confirm unrelated entries remain in `~/.gitconfig`.
