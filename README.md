# Dotfiles

Personal repository for keeping user-level configuration consistent across machines. It
currently manages shell configuration, VS Code, Claude Code, Codex, GitHub Copilot, and the
supporting bootstrap and validation tools.

Managed with [chezmoi](https://www.chezmoi.io). On a new machine, chezmoi clones this
repository into its source directory; no separate `git clone` is required:

```bash
chezmoi init https://github.com/sherrilla71940/dotfiles.git
```

If you use a fork, replace the URL with your fork's URL. See the full
[new-machine setup guide](./docs/setup.md#onboarding-a-new-machine) before applying.

⚠️ On a machine that already has configuration, run `chezmoi diff` before `chezmoi apply`:
**apply overwrites existing files without prompting.** See
[docs/setup.md](./docs/setup.md#onboarding-a-new-machine).

## After setup: manage it with an AI assistant

After chezmoi has initialized the repository, open its source directory with `chezmoi cd`,
then use Claude Code, Codex, or VS Code with GitHub Copilot from that repository root. Describe
the result you want in ordinary language; you do not need to know chezmoi's encoded source
filenames or commands first. For example:

- "Guide me through managing my dotfiles with this repository."
- "Add React instructions shared by Claude Code and Copilot, and explain what Codex can support."
- "Add this instruction only for Claude Code."
- "I edited my live `.bashrc`; help me preserve that change in the repository."
- "Set my VS Code font size to 14, commit the source change, and then safely apply it with chezmoi."

The repository-level [`AGENTS.md`](./AGENTS.md) tells each assistant how to translate the
request into a safe source-state change, explain what will happen, and distinguish editing,
applying, and committing. Claude receives it through [`CLAUDE.md`](./CLAUDE.md); Codex and
Copilot can read it directly.

## How it works

The `home/` directory is chezmoi's source state. Its filenames describe both the eventual
home-directory path and how chezmoi should handle the file. For example, `dot_bashrc` renders
to `~/.bashrc`, while a `.tmpl` file is rendered as a template. Editing this repository does
not change live configuration until `chezmoi apply` runs.

Templates and OS conditions let one source support Windows and macOS even when applications
store the same setting in different locations. Files used by only one application stay in
that application's source directory.

### Shared AI configuration

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
scripts/install-claude-mcp.*     safely adds declared user-scoped MCP servers to Claude
scripts/git-hooks/pre-commit     validates the source state before each commit
scripts/vscode-extensions.txt    extension manifest (installed on request)
docs/decisions/                  architecture decisions and reconsideration triggers
```

## Where to go next

| I want to… | Read |
| --- | --- |
| Set up a machine, or understand what happens if an app isn't installed | [docs/setup.md](./docs/setup.md) |
| Add, change or **remove** an instruction, skill or config file | [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) |
| See what each AI client supports and where it belongs | [docs/customization-support.md](./docs/customization-support.md) |
| Understand why the repository is structured this way | [docs/decisions/README.md](./docs/decisions/README.md) |
| Know why a particular rule exists before trimming it | [docs/rule-rationale.md](./docs/rule-rationale.md) |
| Let a coding agent work in this repo | [AGENTS.md](./AGENTS.md) |

`AGENTS.md` is the one file here written for a machine rather than a person: Codex and the
Copilot CLI load it automatically, and the root `CLAUDE.md` imports it so Claude Code gets
the same constraints. It stays deliberately short, since it costs context in every agent
session — procedures live in the workflow guide instead.
