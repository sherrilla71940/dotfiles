# Dotfiles

Personal cross-platform configuration system for dotfiles and AI development tooling. Managed
configuration lives in Git, and [chezmoi](https://www.chezmoi.io) renders and applies it so
each machine's live configuration matches the repository's desired state, with support for
machine-specific, shared, and tool-specific configuration across environments.

It solves three problems:

- **Configuration drifts between machines, and the same setting lives at a different path on
  each operating system.** Templates keep one managed configuration consistent across those
  differences, and a new machine picks all of it up from the same source in one command —
  installing the tools themselves stays a separate, deliberate step.
- **Three AI tools need overlapping configuration, but each expects it in a different file and
  format.** Shared content is written once and rendered into the form each client accepts,
  while tool-specific content stays separate. `~/.claude/CLAUDE.md`, for example, combines the
  working agreement shared with Codex and Copilot with an additional Claude-only section at
  render time. Where the exact same file can serve multiple tools, as with shared skills, the
  repository uses symlinks instead of rendering copies.
- **Some managed files are also rewritten by the applications that consume them.** One settings
  file can hold both what should follow your machines and what the application records about
  itself, so writing it wholesale destroys the second. Take Claude Code's `settings.json`:
  the repository owns a handful of durable keys and merges them over whatever Claude wrote,
  leaving your model, effort and theme untouched.

None of that is taken on trust. A commit hook re-renders the staged source and fails if shared
rule bodies diverge between clients, a skill disappears because of a filename attribute,
Codex's file gains frontmatter, a cross-reference points to a missing heading, or the bash and
PowerShell status lines produce different output — one of the few pieces intentionally
maintained as two implementations.

## How it works

Chezmoi turns this repository into the live files your applications read. The files under
`home/` are the **source state**: the desired configuration, which is what you edit and
commit. What chezmoi writes into your home directory are **targets**.

```text
home/dot_bashrc  ──chezmoi apply──▶  ~/.bashrc
```

So you change a file here and run `chezmoi apply`, which makes the targets match the source
state. Editing a target directly is not durable — the next apply overwrites it. Filenames
carry meaning too: `dot_` becomes a leading dot, and a `.tmpl` file is rendered as a template,
which is how one source supports both Windows and macOS.
[docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) covers the day-to-day commands.

`chezmoi init` fetches this repository for you, so no separate `git clone` is required.

## Shared AI configuration

Each tool receives a real file in **its own** format: a Claude rule carrying `paths:`, a
Copilot `.instructions.md` carrying `applyTo:`, and for Codex one literal file with no
frontmatter, because Codex can neither import another file nor path-scope at all. No single
shared file can serve all three, which is why the body is rendered rather than linked.

```
home/.chezmoitemplates/rules/javascript.md   <-- the body, written once
home/.chezmoidata.yaml                       <-- the glob, written once

  -> ~/.claude/rules/javascript.md                        paths: "**/*.{js,jsx,ts,tsx}"
  -> ~/.copilot/instructions/javascript.instructions.md   applyTo: "**/*.{js,jsx,ts,tsx}"
```

Skills go the other way, because nothing about them needs to differ per client. One real copy
lives in `~/.agents/skills`, which Codex and Copilot read directly; Claude Code looks only in
`~/.claude/skills`, so a symlink bridges it there. Nothing is rendered and nothing is copied.

A skill or instruction meant for one tool alone is a plain file in that tool's own folder —
`~/.copilot/skills`, for instance — with no templating and no link. Nothing is ever reworded
into a tool-neutral twin: a rule only one tool can follow either stays in that tool's file, or
says plainly which tool it applies to.

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

You can do this from anywhere. Chezmoi uses its configured source directory whatever your
current folder is, so `chezmoi edit`, `chezmoi diff`, `chezmoi apply` and `chezmoi git` all
work without changing directory first. The repository root — `~/dotfiles` if you kept the
working tree there, or `chezmoi cd` to open a shell in it — is just where plain `git` and the
repository's own scripts are convenient.

### Changing your configuration

Edit the source, preview with `chezmoi diff`, run `chezmoi apply`, then commit.
`chezmoi status` is empty once the change has landed.

The exception is everything the repository does not manage, which is most of what an
application records about itself. Claude's `settings.json` is the clearest case: the repository
owns the keys that should be identical everywhere, and leaves the rest — your model, theme,
permissions and the like — on the machine. Change those from inside the client, with `/config`
or `/model` or `/plugin`, and there is nothing to apply or commit. Run
`scripts/claude-settings-drift.sh` for the current split;
[docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) covers the general procedure.

### Or describe what you want to an AI assistant

Describe the result you want to Claude Code, Codex, or VS Code with GitHub Copilot in ordinary
language; you do not need to know chezmoi's encoded source filenames or commands first. For
example:

- "Guide me through managing my dotfiles with this repository."
- "Add React instructions shared by Claude Code and Copilot, and explain what Codex can support."
- "Add this instruction only for Claude Code."
- "I edited my live `.bashrc`; help me preserve that change in the repository."
- "Set my VS Code font size to 14, commit the source change, and then safely apply it with chezmoi."

The repository-level [`AGENTS.md`](./AGENTS.md) tells each assistant how to translate the
request into a safe source-state change, explain what will happen, and distinguish editing,
applying, and committing. Claude receives it through [`CLAUDE.md`](./CLAUDE.md); Codex and
Copilot can read it directly.

Starting the session at the repository root is simplest, because each tool loads that guidance
on its own. It holds from anywhere else too: the shared core instructions this repository
installs tell every assistant to resolve a configuration file with `chezmoi source-path` before
changing it, and to read this repository's `AGENTS.md` before editing anything in it — so both
the source-versus-target rule and the structural constraints reach an assistant that has never
seen this repository.

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
