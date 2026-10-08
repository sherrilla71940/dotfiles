# My Personal Dotfiles and AI Configurations

**A versioned source of truth for the durable settings and shared AI guidance that shape my development environment.**

I built this repository to make my setup reproducible across machines and to keep the guidance I give coding agents consistent as I move between clients. The repository uses chezmoi to manage the configuration I choose to keep: I edit readable source files here, review the rendered changes, then apply them to my home directory.

This is my working personal setup, kept public so other developers can inspect the choices and adapt individual pieces. It is not a universal preset: application-owned state and credentials remain local, and machine-specific profile choices are not committed.

## Why I built it

Machines and tools change, and copies of the same AI instruction can drift between clients.

The design focuses on a few practical outcomes:

- **Repeatable setup:** bootstrap and chezmoi source files make durable preferences easier to reproduce on a new machine.
- **Consistent AI guidance:** one canonical source for shared rules and skills reduces drift across client-specific files.
- **Clear ownership:** templates identify what this repository manages and preserve application-owned values where possible.
- **Reviewable changes:** Git keeps source edits inspectable, and `chezmoi diff` previews machine-specific targets before applying them.

## How it fits together

```mermaid
flowchart LR
    subgraph source["Versioned configuration source"]
        dotfiles["Durable dotfiles"]
        shared["Shared AI rules and skills"]
        adapters["Thin client-specific wrappers"]
    end
    profile["Machine-local ai_context<br/>(not committed)"] --> render["chezmoi composition"]
    dotfiles --> render
    shared --> render
    adapters --> render
    render --> ai["Native AI configuration surfaces<br/>Claude Code · Codex · GitHub Copilot"]
    ai --> local["Client-owned state<br/>sessions · credentials · runtime"]
    render --> settings["Shell · Git · editor · terminal<br/>and other durable settings"]
```

chezmoi renders the versioned source with the machine-local profile. Each client continues to own its sessions, credentials, and runtime state.

## Workflows worth exploring

| Goal | Start with | What it does |
| --- | --- | --- |
| Share AI guidance across clients | [Customization support guide](./docs/customization-support.md) | Reusable rules and skills reach supported Claude Code, Codex, and GitHub Copilot surfaces; client-specific behavior stays scoped to the clients that support it. |
| Take a request to a reviewable change | [`run-task-end-to-end`](./home/.chezmoitemplates/skills/run-task-end-to-end/SKILL.md) | Guides a natural-language task through workspace checks, implementation, verification, and requested delivery. It can also return a plan or review without editing files. |
| Move work to another AI session | [`task-handoff`](./home/.chezmoitemplates/skills/task-handoff/SKILL.md) | Summarizes the current checkout, decisions, checks, materials, and next action for the receiving session to verify. |

For example: “Use `run-task-end-to-end` to implement the attached keyboard shortcut spec and verify it.” Add a starting point, worktree preference, or publication target only when needed. The skill uses the current suitable checkout or the client's native worktree starting point for routine work.

## Day-to-day conveniences and safeguards

These are the details I rely on to make agent sessions easier to follow and their changes easier to trust.

| Feature | What it does | Inspect |
| --- | --- | --- |
| Claude Code statusline (Bash and PowerShell) | A terminal-width-aware display shows the model and effort, an optional session name, project path and Git state, context use, and 5-hour or 7-day usage percentages with reset times when available. | [Bash](./home/dot_claude/claude-session-statusline.sh), [PowerShell](./home/dot_claude/claude-session-statusline.ps1), and [settings source](./home/.chezmoitemplates/claude/settings-durable.json). |
| Desktop notifications (Windows and macOS) | Shared scripts alert me when Claude Code needs input or an agent or subagent finishes, and when a Codex session ends. Each client has its own hook configuration. | [Windows script](./home/dot_local/share/show-agent-notification.ps1), [macOS script](./home/dot_local/share/show-agent-notification-macos.sh), [Claude settings](./home/.chezmoitemplates/claude/settings-durable.json), and [Codex hooks](./home/dot_codex/hooks.json.tmpl). |
| Local validation | The hook renders the staged source snapshot in a temporary directory without applying it. Its checks cover source identity, skill and shared-rule parity, statusline parity, and Markdown links; focused suites cover profile behavior, diagnostics, Git configuration, and company branch policy. | [Pre-commit hook](./scripts/git-hooks/pre-commit), [Bash test runner](./scripts/tests/run-git-bash-tests.ps1), and [setup guide](./docs/setup.md). |
| Personal or work AI setup | A machine-local `ai_context` lets me use the same repository for personal and work AI setups. It selects the corresponding agent guidance and defaults without committing the machine's choice. | [`ai-profile` skill](./home/dot_agents/skills/ai-profile/SKILL.md) and [profile setup](./docs/chezmoi-workflow.md#machine-local-ai-context). |
| File and artifact hygiene | Specs and references, reusable test inputs, and updateable handoffs have separate homes under `~/Documents/`. For tasks spanning several items, an issue, PR/MR, or one status note links them. Agents check material provenance before use. | [Project material rules](./home/.chezmoitemplates/core.md#project-material) and [ADR-0053](./docs/decisions/0053-native-first-ai-workflows.md). |
| Defensive engineering and evidence-first safeguards | Shared rules cover trust-boundary validation, output escaping, parameterized SQL, and secret hygiene. They also require agents to verify the checkout and material provenance and report only checks they actually ran, designed to reduce common security mistakes and unsupported completion claims. | [Shared core rules](./home/.chezmoitemplates/core.md) and [ADR-0024](./docs/decisions/0024-instruction-provenance-and-material-filing.md). |

**Statusline example.** The model and usage figures show one past session.

![Claude Code statusline showing the model and session, repository and Git branch, context use, and usage windows.](./docs/images/statusline.png)

## Where things live

| Path | What you will find |
| --- | --- |
| [`home/`](./home/) | The desired configuration state managed by chezmoi. |
| [`home/.chezmoitemplates/`](./home/.chezmoitemplates/) | Reusable settings, instruction bodies, and templates. |
| [`home/dot_agents/skills/`](./home/dot_agents/skills/) | Shared and client-gated AI skill sources. |
| `home/dot_<client>/` | Native client entry points and thin wrappers that connect shared guidance. |
| [`scripts/`](./scripts/) | Bootstrap, diagnostics, and validation tools. |
| [`docs/`](./docs/) | Setup steps, the customization source map, operating guides, and architecture decision records (ADRs). |

## Start here

- [Set up a machine](./docs/setup.md)
- [Understand how managed settings are edited and applied](./docs/chezmoi-workflow.md)
- [Find where an AI client setting or skill comes from](./docs/customization-support.md)
- [Review current architecture decisions](./docs/decisions/README.md)

Before applying anything to your home directory, review the setup guide and run `chezmoi diff` for your machine.
