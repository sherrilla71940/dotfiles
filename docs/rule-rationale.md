# Why selected rules exist

This file records the rationale for rules that are surprising, personal, or easy to remove
without understanding their purpose. It is not loaded into agent context.

Repository architecture belongs in [`docs/decisions/`](./decisions/README.md), and current
procedures belong in [`docs/chezmoi-workflow.md`](./chezmoi-workflow.md).

Only document a rule here when its reason is not obvious from the rule itself. Each entry
should explain why the rule exists and what would justify reconsidering it.

## Core instructions

### Completion claims and verification

The rules **"Never assert an action that hasn't happened"** and **"Verify before claiming
done"** are a pair. They were retained because generated artifacts had described requests and
fixes as completed before they actually occurred. Verification makes the reporting rule
enforceable rather than aspirational.

Reconsider only if an equivalent, mechanically enforced completion check replaces both
instructions.

### User-level configuration is generated output

The rule directing agents to resolve a live configuration file through `chezmoi source-path`
before editing it exists because the failure it prevents is silent. A session outside this
repository, asked to add a skill or a hook, writes to the tool's live directory and reports
success; the work is then unmanaged, reverted by the next `chezmoi apply` or absent
from the next machine. The concrete warning already lived in
`home/dot_claude/CLAUDE.md.tmpl`, but inside an HTML comment that Claude Code strips before
loading, so no agent ever read it.

Resolving through chezmoi rather than listing paths keeps the rule correct on both macOS and
Windows, and avoids a per-tool path table that would duplicate one instruction three times
and go stale. The rule is conditional, so it costs nothing on a machine chezmoi does not
manage.

Reconsider if this machine stops being chezmoi-managed, or if these tools gain a reliable way
to report that a configuration file is generated.

### Comment language by repository type

Application and project repositories use zh-tw comments, while user-level configuration—such
as dotfiles, editor settings, personal skills, instructions, and AI configuration—uses English.
The split prevents a company-project convention from leaking into personal configuration and
keeps personal files consistent with their surrounding ecosystem.

Reconsider if the preferred language changes for either repository category; do not collapse
the distinction accidentally while editing the global rule.

### Project continuity alongside native memory

The bootstrap rule that invokes `project-continuity` survives even though Claude Code and Codex
both ship memory of their own, because neither crosses the boundary the skill exists for.
Claude Code's auto memory is per-repository but stored under `~/.claude/`, machine-local and
readable only by Claude. Codex Memories is Codex-only, globally scoped rather than
per-repository, and off unless `[features] memories = true` is set. Nothing native gives the
two clients one repository-local, Git-reconciled record of where work stopped.

The rule is short and its subject sounds like something the clients already do, which makes it
an easy deletion for anyone who notices auto memory and stops there.

Reconsider if Codex Memories becomes per-repository, if either client gains a shared or
in-repository store the other can read, or if handoffs between Claude Code and Codex within one
repository stop happening in practice.

The activation decision is visible for work with concrete complexity signals because the
absence of `.project-continuity/state.md` otherwise leaves no observable event for the client
to react to. A task can grow through investigation until it is expensive to reconstruct while
the agent remains focused on its immediate implementation steps.

Claude's compaction lifecycle is the one reliable point where a deterministic backstop can act.
`PreCompact` creates an ignored emergency state when proactive activation was missed;
`PostCompact` stores the native compact summary without copying the transcript; and a one-retry
`Stop` guard asks the shared skill to reconcile and remove that temporary section. This remains
a backstop rather than the primary workflow: it cannot protect every crash or hard cutoff, and
only skill-driven checkpoints can preserve important reasoning before those failures. Codex and
Copilot need no matching Claude hook because they consume the same working-tree-local state.

Reconsider the visible decision only if clients gain a reliable built-in lifecycle event for
starting and maintaining cross-client task state.

### External project material

The project-material rule triggers after an external file materially informs the work, rather
than whenever a prompt happens to contain an external path. The agent often needs to inspect a
file before it can tell whether it is an authoritative source, a durable reference, a reusable
manual test input or a disposable attachment. Copying remains an explicit proposal because it
creates a second version that can diverge; moving remains exceptional because it can break the
user's existing workflow.

Folders use the remote repository name so every linked worktree converges on one location.
The remote owner is added only to resolve an actual same-name collision, avoiding unnecessary
migration of existing project folders.

## JavaScript instructions

### PascalCase functions and globals

PascalCase for VanillaJS/VanillaTS functions and globals is a company standard, not a general
JavaScript convention. It applies to application and project repositories and is explicitly
excluded from user-level configuration, where normal JavaScript naming and surrounding style
apply.

Reconsider when the company convention changes. Do not broaden it to personal configuration
for the sake of uniform wording.
