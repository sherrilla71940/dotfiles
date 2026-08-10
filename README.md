# Dotfiles

Personal Repository for managing dotfiles and keeping configuration consistent
across machines. It currently includes Claude Code, Codex, GitHub Copilot,
VS Code, and shell configuration.

Managed with [chezmoi](https://www.chezmoi.io). One `chezmoi init --apply <repo-url>` gets a
new Mac or Windows machine working; only chezmoi and git need to exist first.

## The idea

An instruction used by more than one assistant is written **once**, and each tool receives a
real file in **its own** format. That indirection exists for one reason: the three tools
disagree about how to scope an instruction, and Codex can neither import another file nor
path-scope at all — so no single shared file can serve all three.

```
home/.chezmoitemplates/rules/javascript.md   <-- the body, written once
home/.chezmoidata.yaml                       <-- the glob, written once

  -> ~/.claude/rules/javascript.md                        paths: "**/*.{js,jsx,ts,tsx}"
  -> ~/.copilot/instructions/javascript.instructions.md   applyTo: "**/*.{js,jsx,ts,tsx}"
```

Anything used by only one tool is a plain file in that tool's folder, with no templating at
all. Nothing is ever reworded into a tool-neutral twin.

## Layout

```
home/                            chezmoi source state
  .chezmoidata.yaml              rule globs, one place
  .chezmoitemplates/             SHARED bodies (core.md, rules/, vscode/)
  dot_claude/                    CLAUDE.md, rules, settings, hooks, commands, agents
  dot_codex/                     AGENTS.md, config.toml  (skills come from dot_agents)
  dot_copilot/                   instructions, agents, skills (Copilot-only ones)
  dot_agents/skills/             SHARED skills -> ~/.agents/skills, read by all three
  .README.md                     how to read this tree (repo-only, never deployed)
  dot_zshrc.tmpl  dot_bashrc     shells
  AppData/ · Library/            VS Code, one per OS
scripts/bootstrap-*.{sh,ps1}     one-time new-machine setup (run by hand)
scripts/git-hooks/pre-commit     validates the source state before each commit
scripts/vscode-extensions.txt    extension manifest (installed on request)
```

## Where to go next

| I want to… | Read |
| --- | --- |
| Set up a machine, or understand what happens if an app isn't installed | [docs/setup.md](./docs/setup.md) |
| Add, change or **remove** an instruction, skill or config file | [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) |
| Know why a particular shared rule exists before trimming it | [docs/rules-provenance.md](./docs/rules-provenance.md) |
| Let a coding agent work in this repo | [AGENTS.md](./AGENTS.md) |

`AGENTS.md` is the one file here written for a machine rather than a person: Codex and the
Copilot CLI load it automatically, and the root `CLAUDE.md` imports it so Claude Code gets
the same constraints. It stays deliberately short, since it costs context in every agent
session — procedures live in the workflow guide instead.
