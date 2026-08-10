# Dotfiles

Personal Repository for managing dotfiles and keeping configuration consistent
across machines. It currently includes Claude Code, Codex, GitHub Copilot,
VS Code, and shell configuration.

**Claude Code is the base.** Its files are the canonical text; the other tools import them
rather than keeping reworded copies. Nothing is generated and there is no build step.

| Canonical source | Content |
| --- | --- |
| `shared/core.md` | The working agreement (Claude's `CLAUDE.md` prose) |
| `shared/rules/*.md` | Path-scoped language rules (Claude's `paths:` frontmatter) |
| `skills/` | Portable skills |

How each tool reaches them:

- **Claude Code** — `CLAUDE.md` opens with `@~/.claude/shared/core.md`; rules and skills
  link straight at `shared/rules` and `skills`.
- **Codex** — `~/.codex/AGENTS.md` *is* `shared/core.md`. Codex has no import mechanism, so
  it needs one literal file.
- **Copilot** — `copilot/instructions/*.instructions.md` are thin importers carrying
  Copilot's own `applyTo:` and importing the Claude file.

Modular but scoped: only genuinely portable material lives in `shared/` and `skills/`.
Anything exclusive to one assistant stays in that assistant's folder — `claude/CLAUDE.md`,
`copilot/skills/`, `copilot/instructions/`.

[`links.tsv`](./links.tsv) is the single table of managed symlinks; both installers read it,
so a path is added in one place and the platforms can't drift.

See [dotfiles-setup.md](./dotfiles-setup.md) for installation and why each file lives where
it does, and [shared/PROVENANCE.md](./shared/PROVENANCE.md) for why individual shared rules
exist.
