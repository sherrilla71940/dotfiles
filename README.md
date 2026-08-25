# Dotfiles

Personal repository for keeping user-level configuration consistent across machines. It
manages shell configuration, VS Code, Claude Code, Codex, GitHub Copilot, and supporting
bootstrap and validation tools.

[Chezmoi](https://www.chezmoi.io) stores the desired configuration in this repository and
writes that configuration to the home directory. No separate `git clone` is required.

## Choose a setup path

### Empty machine

Use this one-line setup only when no existing shell, editor, or AI-client configuration
needs to be preserved:

On Windows, first enable Developer Mode or provide symbolic-link privileges as described in
[the setup prerequisites](./docs/setup.md#enable-windows-symlink-creation).

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply sherrilla71940
```

### Existing configuration

If any settings should survive—or you are unsure—initialize without applying:

```bash
chezmoi init sherrilla71940
chezmoi source-path
chezmoi diff
```

Do not apply until you have adopted the existing values you want to keep. The
[existing-configuration guide](./docs/setup.md#existing-configuration) explains how to
preserve a complete plain file or selected settings from a template-backed file. If you use
a fork, replace `sherrilla71940` with the fork's URL.

## After setup

Work from the repository root: `~/dotfiles` if you kept the working tree there, or whatever
`chezmoi source-path` reports. `chezmoi cd` launches a shell in it when you are unsure where it
lives; leave that shell with `exit`.

### Changing your configuration

Edit the source in this repository, run `chezmoi apply` to update the live file, then commit.
Editing a live file directly achieves nothing durable, because the next apply overwrites it.
Preview with `chezmoi diff` first, and `chezmoi status` is empty once the change has landed.

The exception is everything the repository does not manage, which is most of what an
application records about itself. Claude's `settings.json` is the clearest case: the repository
owns a few durable keys — environment, hooks, status line, update channel — while your model,
effort, theme, permissions, and enabled plugins stay on the machine. Change those with
`/config`, `/model`, or `/effort`, and there is nothing to apply or commit.
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

## How it works

The `home/` directory is chezmoi's source state. Its filenames describe both the eventual
home-directory path and how chezmoi should handle the file. For example, `dot_bashrc` renders
to `~/.bashrc`, while a `.tmpl` file is rendered as a template. Editing this repository does
not change live configuration until `chezmoi apply` runs.

Templates and operating-system (OS) conditions let one source support Windows and macOS even
when applications store the same setting in different locations. Files used by only one
application stay in that application's source directory.

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

### Copying only part of this repository

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
  dot_zshrc.tmpl  dot_bashrc     shells
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
