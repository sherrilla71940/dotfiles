# Dotfiles

Personal repository for tracking dotfiles and keeping configuration consistent
across machines. It currently includes Claude Code, Codex, GitHub Copilot,
VS Code, and shell configuration.

See [dotfiles-setup.md](./dotfiles-setup.md) for installation and managed paths.

## TODO

- Introduce a shared source-of-truth folder for reusable agent instructions,
  skills, and workflows. Claude Code is currently the source from which the
  Codex setup was derived; refactor the Claude Code, Codex, and GitHub Copilot
  setups to consume the relevant shared material while keeping tool-specific
  configuration separate.
