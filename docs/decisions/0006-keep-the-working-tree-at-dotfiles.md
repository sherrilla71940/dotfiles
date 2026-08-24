# ADR-0006: Keep the working tree at `~/dotfiles`

- Status: Accepted
- Date: 2026-08-24

## Context

Chezmoi reads its source state from `~/.local/share/chezmoi` by default, and `chezmoi init`
clones straight into that directory. Following that default puts the Git working tree inside a
platform data directory.

This repository is not a passive store of dotfiles. Decision records, bootstrap scripts, a
pre-commit hook, a test-render workflow and the guides are all edited and committed
regularly, so the checkout is worked in daily rather than written once. On Windows,
`~/.local/share` is an XDG convention that chezmoi adopts rather than a native location, which
makes the default harder to reach on the platform this repository is most used from.

Nothing recorded why the source location was chosen. `docs/setup.md` presented `~/dotfiles`
under the heading "Using a manually cloned `~/dotfiles`" and opened by saying no link is
required, which reads as a recovery step for an accidental clone. A later session therefore
had to re-derive whether the layout was deliberate, and reasonably suspected it was a mistake.

## Decision

Keep the Git working tree at `~/dotfiles` and satisfy chezmoi's default source directory with
a symlink on macOS or a directory junction on Windows.

`.chezmoiroot` continues to select `home/`, so chezmoi reports `sourceDir` as
`~/.local/share/chezmoi/home` and `workingTree` as the repository root. Git operations run at
the root, where the non-dotfile content lives.

Document the layout as intended rather than as an accommodation, and verify it by Git identity
rather than by the displayed path.

## Alternatives considered

- **Clone into `~/.local/share/chezmoi` directly:** chezmoi's default, needing no link and no
  configuration, and the closest match to the documentation. Rejected because the checkout is
  edited daily and that location is awkward to reach, particularly on Windows.
- **Set `sourceDir` in `~/.config/chezmoi/chezmoi.toml`:** the documented way to relocate the
  source, and identical on every platform. Rejected because the repository ships no
  `.chezmoi.toml.tmpl`, so this trades the link for another unmanaged per-machine artifact
  that has to exist before chezmoi can do anything.
- **Let each machine differ:** rejected. The verification steps and the always-on agent
  instructions would both have to describe two layouts.

## Consequences

`cd ~/dotfiles` works and the repository sits where a developer would look for it.

Every chezmoi command reports the link path, not the working tree, so a check that compares
path strings misleads. Identity has to be verified through Git or the filesystem, which is why
`AGENTS.md` and `docs/setup.md` both say so and why the setup path runs
`git -C "$(chezmoi source-path)" rev-parse --show-toplevel`.

The link is not part of the source state, so `chezmoi apply` neither creates nor repairs it. A
machine whose link is missing silently uses whatever `~/.local/share/chezmoi` contains, so the
identity check belongs immediately after cloning rather than at first failure.

A new machine needs one step beyond cloning, and that step differs per operating system.

## Reconsider when

- The repository stops being actively developed and becomes a source state that is only
  applied, which removes the reason to keep the checkout convenient.
- Chezmoi resolves links when reporting paths, removing the string-comparison hazard.
- The repository gains a managed chezmoi configuration template, which would make `sourceDir`
  cheaper than maintaining the link.

## Related files and verification

- [`.chezmoiroot`](../../.chezmoiroot)
- [`docs/setup.md`](../setup.md#working-tree-at-dotfiles)
- [`AGENTS.md`](../../AGENTS.md)

```bash
chezmoi source-path                                        # ends in .local/share/chezmoi/home
git -C "$(chezmoi source-path)" rev-parse --show-toplevel  # the working tree
chezmoi data                                               # workingTree at the repository root
```
