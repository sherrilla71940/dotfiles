# Dotfiles

Personal repository for keeping user-level configuration consistent across machines. Any
user-level configuration can live here; today that is the AI clients — Claude Code, Codex, and
GitHub Copilot — plus VS Code, the shell, and the bootstrap and validation tooling around them.

The problem it solves: three AI tools want the same instruction, but each in its own file and
its own shape. So an instruction is written **once** and rendered into whatever each client
accepts — and a single rendered file can carry shared and tool-specific content together.
`~/.claude/CLAUDE.md` is exactly that: the working agreement shared with Codex and Copilot,
then a Claude-only section below it, composed from two sources every time you apply. A symlink
cannot express that; it gives you one whole file or nothing.

Anything genuinely tool-specific stays in that tool's own directory, unshared and never
reworded into a neutral twin, so the line between shared and specific is declared rather than
assumed. The next two sections show how.

## How it works

[Chezmoi](https://www.chezmoi.io) renders all of it. The files under `home/` are the **source
state**: the desired configuration, which is what you edit and commit. The files chezmoi writes
into your home directory are **targets**, and that is what each application actually reads.

```text
home/dot_bashrc  ──chezmoi apply──▶  ~/.bashrc
```

So you change a file here and run `chezmoi apply`. Editing a target directly is not durable —
the next apply overwrites it. Filenames carry meaning too: `dot_` becomes a leading dot, and a
`.tmpl` file is rendered as a template, which is how one source supports both Windows and
macOS. [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) covers the day-to-day commands.

`chezmoi init` fetches this repository for you, so no separate `git clone` is required.

## Shared AI configuration

An instruction used by more than one assistant is written **once**, and each tool receives a
real file in **its own** format: a Claude rule carrying `paths:`, a Copilot
`.instructions.md` carrying `applyTo:`, and for Codex one literal file with no frontmatter,
because Codex can neither import another file nor path-scope at all. No single shared file can
serve all three.

```
home/.chezmoitemplates/rules/javascript.md   <-- the body, written once
home/.chezmoidata.yaml                       <-- the glob, written once

  -> ~/.claude/rules/javascript.md                        paths: "**/*.{js,jsx,ts,tsx}"
  -> ~/.copilot/instructions/javascript.instructions.md   applyTo: "**/*.{js,jsx,ts,tsx}"
```

Skills go the other way: one real copy serves all three, so they are shared as files rather
than rendered. Anything used by only one tool is a plain file in that tool's folder, with no
templating at all. Nothing is ever reworded into a tool-neutral twin.

## Choose a setup path

### Empty machine

Use this one-line setup only when no existing shell, editor, or AI-client configuration needs
to be preserved. On Windows, first enable Developer Mode or provide symbolic-link privileges as
described in [the setup prerequisites](./docs/setup.md#enable-windows-symlink-creation).

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply sherrilla71940
```

### Existing configuration

If any settings should survive—or you are unsure—initialize without applying:

```bash
chezmoi init sherrilla71940
git -C "$(chezmoi source-path)" rev-parse --show-toplevel   # must be this repository
chezmoi diff
```

Do not apply until you have adopted — copied into the repository — the values you want to keep. The
[existing-configuration guide](./docs/setup.md#existing-configuration) explains how to
preserve a complete plain file or selected settings from a template-backed file. If you use
a fork, replace `sherrilla71940` with the fork's URL.

## After setup

Work from the repository root — `~/dotfiles` if you kept the working tree there, or run
`chezmoi cd`, which launches a shell there; leave it with `exit`. Note that
`chezmoi source-path` points one level deeper, at the source directory rather than the root, so
it is not the way to find this folder.

### Changing your configuration

Edit the source, preview with `chezmoi diff`, run `chezmoi apply`, then commit.
`chezmoi status` is empty once the change has landed.

The exception is everything the repository does not manage, which is most of what an
application records about itself. Claude's `settings.json` is the clearest case: the repository
owns a few durable keys — environment, hooks, status line, update channel — while your model,
effort, theme, permissions, and enabled plugins stay on the machine. Change those with
`/config`, `/model`, `/effort`, `/permissions`, or `/plugin`, and there is nothing to apply or
commit.
`scripts/claude-settings-drift.sh` reports which keys fall on which side, and
[docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) covers the general procedure.

### Or describe what you want to an AI assistant

Use Claude Code, Codex, or VS Code with GitHub Copilot from the repository root. Describe the
result you want in ordinary language; you do not need to know chezmoi's encoded source
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

A session started anywhere else works too. The shared core instructions this repository
installs tell every assistant to resolve a configuration file with `chezmoi source-path`
before changing it, and to read this repository's `AGENTS.md` before editing anything in it —
so both the source-versus-target rule and the structural constraints apply even to an
assistant that has never seen this repository. Starting from the repository root is still
simplest, since each tool loads that guidance on its own.

## Copying only part of this repository

Lifting a single file out of `home/.chezmoitemplates/` will not work, because nothing there is
a target file — each one is a body that some wrapper renders. A VS Code body needs the
OS-specific wrapper under `home/AppData/` or `home/Library/`; a shared rule body deliberately
omits the frontmatter each client requires; the Claude durable-settings body does nothing
without `home/dot_claude/modify_settings.json` to merge it. Take the wrapper as well, or read
it to see what it supplies.

Skills under `home/dot_agents/skills/` are real files rather than bodies, so they copy
directly, but they assume Claude Code, Codex, and Copilot all read them. Check those
assumptions before dropping one into a single-client setup.

## Layout

```
home/                            chezmoi source state
  .chezmoidata.yaml              rule globs, one place
  .chezmoitemplates/             SHARED bodies (core.md, rules/, vscode/, claude/)
  dot_claude/                    CLAUDE.md, rules, settings, hooks, commands, agents
  dot_codex/                     AGENTS.md, config.toml  (skills come from dot_agents)
  dot_copilot/                   instructions, agents, skills (Copilot-only ones)
  dot_agents/skills/             SHARED skills -> ~/.agents/skills, read by all three
  .README.md                     how to read this tree (repo-only, never deployed)
  dot_bashrc  dot_zshrc.tmpl  dot_bash_profile   shells
  AppData/ · Library/            VS Code, one per OS
scripts/bootstrap-*.{sh,ps1}     one-time new-machine setup (run by hand)
scripts/install-claude-mcp.*     adds declared Model Context Protocol (MCP) servers to Claude
scripts/claude-settings-drift.sh lists Claude settings changed locally but not in the repo
scripts/git-hooks/pre-commit     validates the source state before each commit
scripts/vscode-extensions.txt    extension manifest (installed on request)
docs/decisions/                  architecture decisions and reconsideration triggers
```

## Where to go next

| I want to… | Read |
| --- | --- |
| Set up a machine, or see which applications you install yourself | [docs/setup.md](./docs/setup.md) |
| Add, change, or remove a general managed file | [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) |
| Add or change AI instructions, skills, agents, prompts, MCP servers, or plugins | [docs/customization-support.md](./docs/customization-support.md) |
| Understand why the repository is structured this way | [docs/decisions/README.md](./docs/decisions/README.md) |
| Know why a particular rule exists before trimming it | [docs/rule-rationale.md](./docs/rule-rationale.md) |
| Let a coding agent work in this repo | [AGENTS.md](./AGENTS.md) |

`AGENTS.md` is the one file here written for a machine rather than a person: Codex and the
Copilot command-line interface (CLI) load it automatically, and the root `CLAUDE.md` imports
it so Claude Code gets the same constraints. It stays deliberately short, since it costs
context in every agent session; procedures live in the task-specific guides instead.
