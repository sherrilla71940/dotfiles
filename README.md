# Dotfiles

Personal Repository for managing dotfiles and keeping configuration consistent
across machines. It currently includes Claude Code, Codex, GitHub Copilot,
VS Code, and shell configuration.

Managed with [chezmoi](https://www.chezmoi.io). One `chezmoi init` gets a new Mac or
Windows machine working.

## The idea

An instruction that applies to more than one assistant is written **once**. Each tool then
receives a real file in **its own** format, because the three disagree about how to scope
instructions:

| Tool | Scoping | Imports other files? |
| --- | --- | --- |
| Claude Code | `paths:` frontmatter | yes (`@path`) |
| GitHub Copilot | `applyTo:` frontmatter | only via Markdown links, same directory |
| Codex | **none** | **no** |

Because Codex can neither import nor path-scope, a single shared file cannot serve all
three. chezmoi's templates solve it: the body lives once, and each tool's file is rendered
with the frontmatter that tool actually understands.

```
home/.chezmoitemplates/rules/javascript.md   <-- the body, written once
home/.chezmoidata.yaml                       <-- the glob, written once

  -> ~/.claude/rules/javascript.md                        paths: "**/*.{js,jsx,ts,tsx}"
  -> ~/.copilot/instructions/javascript.instructions.md   applyTo: "**/*.{js,jsx,ts,tsx}"
```

The core working agreement is shared by **all three**: Claude gets it inlined in
`CLAUDE.md`, Codex verbatim as `AGENTS.md` with no frontmatter, Copilot as
`core-principles.instructions.md`. The five language rules are shared by Claude and Copilot
only — Codex has no path-scoping, so per-language rules would be always-on against its
32 KiB budget.

## Layout

```
home/                            chezmoi source state
  .chezmoidata.yaml              rule globs, one place
  .chezmoitemplates/             shared bodies (core.md, rules/, vscode/)
  dot_claude/                    CLAUDE.md, rules, settings, hooks, commands, agents
  dot_codex/                     AGENTS.md, config.toml  (skills come from dot_agents)
  dot_copilot/                   instructions, agents, skills (Copilot-only ones)
  dot_agents/skills/             17 portable skills -> ~/.agents/skills, read by all three
  dot_zshrc.tmpl  dot_bashrc     shells
  AppData/ · Library/            VS Code, one per OS
docs/chezmoi-workflow.md         where files go, how to add and remove them
docs/rules-provenance.md         why individual shared rules exist
scripts/bootstrap-*.{sh,ps1}     one-time new-machine setup (run by hand)
vscode-extensions.txt            extension manifest (installed on request)
```

Tool-exclusive material stays in that tool's folder — `dot_copilot/skills/` holds skills
that only make sense in Copilot, and `dot_claude/CLAUDE.md.tmpl` holds rules that depend on
Claude Code features. Nothing is reworded into a tool-neutral twin.

## Daily use

```bash
chezmoi edit ~/.claude/CLAUDE.md   # edit the source
chezmoi diff                       # preview
chezmoi apply -v                   # write it out
chezmoi update -v                  # pull and apply on another machine
chezmoi cd                         # open the source repo
```

**Where do the per-tool folders differ?** Skills live once in `home/dot_agents/skills`
(Codex and Copilot read it natively; Claude reaches it through the single symlink), Codex
has no rules folder because it cannot path-scope, and Copilot's prompt file belongs to the
VS Code profile rather than `~/.copilot`. [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md)
explains each case.

- [docs/setup.md](./docs/setup.md) — installing, onboarding, secrets, verification
- [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) — adding, changing and **removing** files
- [AGENTS.md](./AGENTS.md) — always-on constraints for coding agents working in this repo.
  Codex and the Copilot CLI load it automatically; the root `CLAUDE.md` imports it so Claude
  Code gets the same rules
