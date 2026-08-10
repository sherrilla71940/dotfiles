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

The same applies to the core working agreement: Claude gets it inlined in `CLAUDE.md`,
Codex gets it verbatim as `AGENTS.md` with no frontmatter, Copilot gets it as
`core-principles.instructions.md`.

## Layout

```
home/                            chezmoi source state
  .chezmoidata.yaml              rule globs, one place
  .chezmoitemplates/             shared bodies (core.md, rules/, vscode/)
  .chezmoiscripts/               bootstrap
  dot_claude/                    CLAUDE.md, rules, settings, hooks, commands
  dot_codex/                     AGENTS.md, config.toml
  dot_copilot/                   instructions, agents, skills
  dot_agents/skills/             17 portable skills
  dot_zshrc.tmpl  dot_bashrc     shells
  AppData/ · Library/            VS Code, one per OS
PROVENANCE.md                    why individual shared rules exist
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

See [dotfiles-setup.md](./dotfiles-setup.md) for onboarding a machine, adding a file,
handling OS differences and secrets, and the verification checklist. See
[AGENTS.md](./AGENTS.md) before letting a coding agent modify this repo.
