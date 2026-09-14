# Dotfiles

[English](README.md) · [繁體中文](README.zh-TW.md)

> **TL;DR:** A chezmoi-managed, cross-platform developer environment that renders one source into
> native configuration for AI clients—including instructions, skills, rules where supported, and
> client settings—as well as shells, editors, and tools. Each computer can choose personal or
> company AI conventions and independently enable private project handoff continuity. Shared skills
> stay canonical, while application-owned settings are preserved.

This repository is a personal, cross-platform AI development environment and developer-tooling
system managed with [chezmoi](https://www.chezmoi.io). It manages shell, editor, tool, and AI-client
configuration—including instructions, skills, rules, and settings—from one source across Windows and
macOS.

## What this repository provides

- **Claude Code, Codex, and GitHub Copilot share many of the same AI instructions and skills, but
  each expects them in different files and formats.** The repository writes shared content once
  and renders the client-specific wrapper each tool requires, while tool-specific content stays
  separate. `~/.claude/CLAUDE.md`, for example, combines the working agreement shared with Codex
  and Copilot with an additional Claude-only section at render time. Where the exact same file can
  serve multiple tools, as with shared skills, the repository uses symlinks instead of rendering
  copies.
- **One computer can support both personal and company work without maintaining two separate
  configuration sets.** Two machine-local selectors drive render-time composition: a shared baseline,
  either the personal or company context, and project-continuity instructions when enabled. The same
  canonical skills, instructions, and rules therefore produce the appropriate workflow for the current
  context, while thin client adapters render each tool's native format. `ai_context` controls
  context-specific conventions and artifact-language defaults. `ai_continuity` controls a separate
  feature: a private task-handoff mechanism stored in `.project-continuity/state.md`, whether its
  instructions are always loaded, and whether its session-start/session-stop helpers automatically
  report or update the handoff state. A new AI session can use that state to resume without
  reconstructing the task. When continuity is off, those automatic reports and updates stop, but the
  continuity skill remains available for explicit requests. Changing either selector affects newly
  rendered configuration and newly started sessions, while repository and project instructions still
  take precedence.
- **Configuration drifts between machines, and the same setting lives at a different path on
  each operating system.** Templates keep one managed configuration consistent across
  platforms. A new machine clones this repository and renders every managed file with a
  single chezmoi command; the tools those files configure are installed by their own scripts,
  kept out of the apply path so a routine apply never installs software.
- **Some settings files have two owners: the repository and the application that uses them.** A
  managed file is one that chezmoi renders from this repository, but the application may also
  write its own preferences into that same file. Replacing the file wholesale would erase those
  application-owned values. Claude Code's `settings.json` is the example: the repository manages
  only a small set of durable keys, and chezmoi merges those keys into the existing file while
  preserving Claude's model, effort level, theme, permissions, and other local settings.

## AI client architecture at a glance

This diagram focuses on the AI-client and profile-composition subsystem. It is not a complete
inventory of every managed target: shells, Git, Windows Terminal, general VS Code settings, and
repository tooling use the simpler source-to-target flow described after the diagram.

One source repository becomes coordinated configuration for four clients on Windows or macOS.
Read it left to right: canonical bodies, a thin adapter per client, rendered targets, then the
clients that read them.


Shared skills and rule bodies are canonical in one place. The adapters add only the client-specific
metadata header (`frontmatter`) or wrapper each client understands, which is why a rule that names
one tool's machinery never gets reworded into a tool-neutral twin.

```mermaid
flowchart LR
    subgraph sourceState["Canonical source"]
        core["core.md, context layer, continuity.md"]
        rules["rules bodies<br/>path-scoped"]
        vscodeBody["managed VS Code settings body"]
        sharedSkills["dot_agents/skills<br/>shared skills, one copy each"]
        clientSkills["client-only skills<br/>and client front doors"]
    end

    subgraph adapters["Thin adapters"]
        claudeAdapter["Claude<br/>CLAUDE.md, rules with paths:"]
        codexAdapter["Codex<br/>one literal AGENTS.md, no frontmatter"]
        copilotAdapter["Copilot<br/>instructions with applyTo:"]
        pathWrapper["OS path wrapper"]
        skillAdapter["symlink adapters"]
        clientSkillAdapter["per-client skill trees"]
    end

    subgraph renderedTargets["Rendered targets"]
        claudeTarget["~/.claude"]
        codexTarget["~/.codex<br/>config.toml stays app-owned"]
        copilotTarget["~/.copilot"]
        vscodeTarget["VS Code settings.json"]
        agentsTarget["~/.agents/skills"]
    end

    subgraph clients["Clients"]
        claudeClient["Claude Code"]
        codexClient["Codex"]
        copilotClient["GitHub Copilot"]
        vscodeClient["VS Code"]
    end

    core --> claudeAdapter
    core --> codexAdapter
    core --> copilotAdapter
    rules --> claudeAdapter
    rules --> copilotAdapter
    sharedSkills --> skillAdapter
    clientSkills --> clientSkillAdapter
    vscodeBody --> pathWrapper

    claudeAdapter --> claudeTarget
    codexAdapter --> codexTarget
    copilotAdapter --> copilotTarget
    skillAdapter --> agentsTarget
    skillAdapter -.->|"symlinks"| claudeTarget
    clientSkillAdapter --> claudeTarget
    clientSkillAdapter --> copilotTarget
    pathWrapper --> vscodeTarget

    claudeTarget --> claudeClient
    codexTarget --> codexClient
    copilotTarget --> copilotClient
    vscodeTarget --> vscodeClient
    agentsTarget --> codexClient
    agentsTarget --> copilotClient
```

The rest of the repository follows the same source-to-target path without an AI-client adapter:
shell sources render to `~/.bashrc`, `~/.zshrc`, and `~/.profile`; Git sources render to
`~/.gitconfig`; Windows Terminal sources render to its platform settings; and VS Code sources
render its keybindings, MCP configuration, and settings into the OS-specific user profile. The
OS-specific path wrappers only choose the destination; they do not duplicate those source bodies.

Note the edge that is deliberately missing: `rules` never reaches the Codex adapter. Codex has no
import mechanism and no path-scoping equivalent, so it receives the always-on core only, as one
literal file with no YAML frontmatter.

Skills come in three tiers, which is why the diagram has two skill sources:

- **Shared skills** live once in `home/dot_agents/skills` and render to `~/.agents/skills`. Codex
  and Copilot discover that directory directly; Claude reaches the same files through symlinks in
  `~/.claude/skills`, so there is still only one body to edit.
- **Client-specific entry points** exist where one capability needs a different entry point per
  client.
  `worktree-task-workflow` has a Codex-gated `SKILL.md` under `dot_agents` and a Claude `SKILL.md`
  under `dot_claude`, but both pull the same reference bodies out of `.chezmoitemplates`, so the
  guidance cannot drift even though the front matter differs.
- **Client-only skills** belong to one client and are never shared: `claude-worktree-memory` for
  Claude Code, `remember` for Copilot. Copilot also carries its own `.agent.md` agents.

Worktree workflow and worktree manifest stay independently available in every combination; neither
is a profile toggle. Shared helper scripts render to `~/.local/share` so Claude Code and Codex can
run the same file.

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

`chezmoi init` clones this repository for you, into a source directory of its own choosing.
Decide before that whether you want the working tree somewhere plain `git` and the repository's
scripts are convenient — this setup keeps it at `~/dotfiles`, which means cloning there yourself
first. [docs/setup.md](./docs/setup.md) has the ordering; the reason is in
[ADR-0006](./docs/decisions/0006-keep-the-working-tree-at-dotfiles.md).

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

Portable skills go the other way, because their instructions do not differ per client. One real
copy lives in `~/.agents/skills`, which Codex and Copilot read directly; Claude Code looks only in
`~/.claude/skills`, so a symlink bridges it there. A Codex-targeted exception can also live in
`~/.agents/skills`, but repository host gates keep Claude and Copilot from invoking it as a shared
workflow.

A skill or instruction meant for one tool alone is a plain file in that tool's own folder —
`~/.copilot/skills`, for instance — with no templating and no link. Nothing is ever reworded
into a tool-neutral twin: a rule only one tool can follow either stays in that tool's file, or
says plainly which tool it applies to.

## Choose the AI configuration profile

The rendered Claude Code, Codex, and managed VS Code Copilot configuration has two independent,
machine-local selectors in chezmoi's config file (`chezmoi edit-config`):

```toml
[data]
ai_context = "company"        # explicit work-machine selection
ai_continuity = "on"           # explicit continuity selection
```

The [machine-local selector guide](./docs/chezmoi-workflow.md#machine-local-ai-profile-selectors)
is the canonical reference for the four combinations, missing-key defaults, invalid-value behavior,
and the fact that selector values are local to each Windows or macOS machine.

The active context supplies artifact-language defaults: personal uses English (`en`) and company
uses Traditional Chinese (`zh-TW`, represented as `zhtw` where a command accepts that value).
Explicit language arguments, repository instructions, and direct user requests take precedence.
User-level dotfiles and AI configuration remain English in both contexts. Worktree skills remain
installed and independently available in both contexts; they may use continuity when it is on but
are not profile toggles.

A personal machine can omit `ai_context` entirely; a work machine sets it to `company` with
`chezmoi edit-config`. This dotfiles repository is the deliberate exception either way: its root
`AGENTS.md` is a repository instruction that forces the effective context to `personal`, so work
here remains English even on a machine explicitly set to `company`.

After changing a selector, preview the result with `chezmoi diff`, apply only after reviewing that
preview, and start new client sessions. Already-running sessions retain their startup context.
The selectors are machine-wide in v1, so simultaneous sessions on one machine cannot safely use
different context or continuity values. There is no profile CLI yet. Broad Copilot integration
(discovery, repository instructions, and agent plugins) is also outside this version's scope.

### What a selector changes

Both selectors are machine-local and are never committed. The resolver validates them, then feeds
three separate things: which context layer is composed in, whether project-continuity instructions
and automatic session-start/session-stop reporting or state updates are active, and which language
the supported artifacts default to.

```mermaid
flowchart TD
    config["chezmoi config file<br/>machine-local, never committed"]
    config --> context["ai_context<br/>personal or company, default personal"]
    config --> continuitySelector["ai_continuity<br/>on or off, default on"]

    context --> resolver["ai-profile.yaml<br/>validates; unsupported values fail the render"]
    continuitySelector --> resolver

    resolver --> layer["context layer<br/>profiles/personal.md or profiles/company.md"]
    resolver --> gate["continuity gate"]
    resolver --> language["artifact_language<br/>en or zhtw"]

    layer --> instructions["always-loaded instructions<br/>composed in core.md"]
    gate --> instructions
    gate --> helper["maintain-project-continuity.sh<br/>reports when on, no-op when off"]

    language --> commitSkill["git-commit-action"]
    language --> worktreeText["worktree invocation and publishing"]
    language --> vscodeCommit["VS Code Copilot commit messages"]

    repository["repository AGENTS.md or CLAUDE.md"] -.->|"outranks the machine context"| instructions
```

Three details in that picture are easy to get wrong:

- **Artifact language reaches skills and VS Code, not just the instruction files.** Those three
  leaves are the whole supported surface; an explicit `en` or `zhtw` argument still overrides them.
- **Continuity off changes instructions and helper behaviour, never hook wiring.** The hooks stay
  registered in both states, which keeps the independent worktree launch check active and keeps
  Codex's per-entry hook trust valid across a toggle.
- **Repository instructions outrank the machine context.** That is why this repository's own
  `AGENTS.md` pins the `personal` context for work performed here without touching the selector.

User-level configuration and customization comments stay English in both contexts, and continuity
state is written in English regardless of the conversation language.


## Choose a setup path

### Empty machine

Use this one-line setup only when no existing shell, editor, or AI-client configuration needs
to be preserved. On Windows, first enable Developer Mode or provide symbolic-link privileges as
described in [the setup prerequisites](./docs/setup.md#enable-windows-symlink-creation).

This command downloads and executes a remote installer; use it only after deciding that you trust
the source and have reviewed the URL/script policy for the machine.

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

Either path is one step of seven. What remains — the bootstrap helper that links the source
directory and enables the validation hook, installing and signing in to the applications, then
**running bootstrap a second time** so its plugin, extension and MCP steps find the CLIs they
depend on — is in [docs/setup.md](./docs/setup.md). Stopping here leaves a machine with the
files but none of the tooling.

## After setup

You can do this from anywhere. Chezmoi uses its configured source directory whatever your
current folder is, so `chezmoi edit`, `chezmoi diff`, `chezmoi apply` and `chezmoi git` all
work without changing directory first. The repository root — `~/dotfiles` if you kept the
working tree there, or `chezmoi cd` to open a shell in it — is just where plain `git` and the
repository's own scripts are convenient.

### Changing your configuration

Edit the source, preview with `chezmoi diff`, run `chezmoi apply`, then commit.
`chezmoi status` is empty once the change has landed.

From the repository root, run `bash scripts/dotfiles doctor` for one health report covering
chezmoi source identity, the resolved machine profile, unapplied target drift, Claude's shared-skill
links, and the required tool versions. It stays under `scripts/` because it diagnoses the source
checkout and live chezmoi state; it is repository tooling, not a configuration command rendered
into every home directory.

The exception is everything the repository does not manage, which is most of what an
application records about itself. Claude's `settings.json` is the clearest case: the repository
owns the keys that should be identical everywhere, and leaves the rest — your model, theme,
permissions and the like — on the machine. Change those from inside the client, with `/config`
or `/model` or `/plugin`, and there is nothing to apply or commit. Run
`scripts/diagnostics/claude-settings-drift.sh` for the current split;
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

Skills under `home/dot_agents/skills/` are real files rather than bodies, so they copy directly.
Most are portable; a source-only `.codex-only` marker identifies the host-gated exceptions.
Check that distinction before dropping one into a single-client setup.

## Layout

```
home/                            chezmoi source state
  .chezmoidata.yaml              rule globs, one place
  .chezmoitemplates/             SHARED bodies (core.md, profiles/, rules/, vscode/, claude/)
  dot_claude/                    CLAUDE.md, rules, settings, hooks, commands, agents,
                                 skills (Claude-only ones, plus links to the shared set)
  dot_codex/                     AGENTS.md, config.toml  (skills come from dot_agents)
  dot_copilot/                   instructions, agents, skills (Copilot-only ones)
  dot_agents/skills/             portable and host-gated Codex skills -> ~/.agents/skills
  .README.md                     how to read this tree (repo-only, never deployed)
  dot_bashrc  dot_zshrc.tmpl  dot_bash_profile   shells
  AppData/ · Library/            VS Code, one per OS
scripts/dotfiles                 repository tooling entry point (`bash scripts/dotfiles doctor`)
scripts/bootstrap/                one-time new-machine setup (run by hand)
scripts/install/                  Claude MCP installers
scripts/manifests/                MCP and VS Code extension manifests
scripts/diagnostics/              doctor, Claude settings drift, and session-usage reports
scripts/tests/                    profile, continuity, and worktree regression suites
scripts/git-hooks/pre-commit     validates the source state before each commit
scripts/git-hooks/markdown-anchors.awk  resolves documentation cross-references
docs/decisions/                  architecture decisions and reconsideration triggers
```

## Maintainer regression tests

The scripts below are durable regression suites. Keep each suite while the behavior it protects
remains supported; repeated passing runs do not make a regression test obsolete. Remove a suite
only when its feature is retired or equivalent coverage replaces it.

| Change | Run |
| --- | --- |
| Windows worktree provisioning implementation | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/tests/test-git-worktree-provision.ps1` |
| macOS worktree provisioning implementation | `bash scripts/tests/test-git-worktree-provision.sh` |
| Shared worktree provisioning contract or safety boundary | Both worktree provisioning suites |
| Project-continuity lifecycle hooks or recovery contract | `bash scripts/tests/test-project-continuity-hook.sh` |
| AI profile selectors, composition, language defaults, or continuity toggle | `bash scripts/tests/test-ai-configuration-profiles.sh` |
| `.chezmoiignore` OS gating, either VS Code settings tree, or either worktree helper | `bash scripts/tests/test-ai-configuration-profiles.sh` — it renders both the darwin and windows branches from whichever host you are on, so the other platform's templates are not left unchecked |

These suites create disposable repositories and run manually when their implementation or
contract changes. The pre-commit hook remains focused on fast source rendering and structural
checks.

## Where to go next

| I want to… | Read |
| --- | --- |
| Set up a machine, or see which applications you install yourself | [docs/setup.md](./docs/setup.md) |
| Add, change, or remove a general managed file | [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) |
| Add or change AI instructions, skills, agents, prompts, MCP servers, or plugins | [docs/customization-support.md](./docs/customization-support.md) |
| Understand how ignored local files reach new Git worktrees | [docs/worktree-provisioning.md](./docs/worktree-provisioning.md) |
| Understand why the repository is structured this way | [docs/decisions/README.md](./docs/decisions/README.md) |
| Know why a particular rule exists before trimming it | [docs/rule-rationale.md](./docs/rule-rationale.md) |
| Let a coding agent work in this repo | [AGENTS.md](./AGENTS.md) |

`AGENTS.md` is the one file here written for a machine rather than a person: Codex and the
Copilot command-line interface (CLI) load it automatically, and the root `CLAUDE.md` imports
it so Claude Code gets the same constraints. It stays deliberately short, since it costs
context in every agent session; procedures live in the task-specific guides instead.
