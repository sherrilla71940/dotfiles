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

Application and project repositories use the active AI context's default comment language:
personal context uses English, while company context uses Traditional Chinese (`zh-TW`).
Repository and project instructions take precedence. User-level configuration—such as dotfiles,
editor settings, personal skills, instructions, and AI configuration—uses English unconditionally.
The split prevents a company-project convention from leaking into personal configuration and
keeps personal files consistent with their surrounding ecosystem.

Reconsider if the preferred language changes for either repository category; do not collapse
the distinction accidentally while editing the global rule.

### Explicit cross-client handoffs

Client-native conversation resume and worktree features cover same-client continuation and code
isolation. When work moves between different clients, a short handoff prompt carries only the facts
needed to restart; the receiving agent checks the objective, checkout, Git diff, decisions,
verification, blockers, materials, and next action against current sources. A transcript export can
provide context, but it is not proof of repository state.

This keeps handoff overhead proportional to the work and avoids a second, custom state machine
that must track every client lifecycle. Reconsider if observed cross-client handoffs repeatedly
lose decisions that cannot be recovered from Git, project instructions, durable issues, or a concise
handoff.

### Company flow before branch creation

The company profile keeps a short branch-policy trigger because the task skill is explicit: direct
branch creation does not load it. The global pre-push hook rejects non-flow branches under
`company-flow`. A repository that needs an ongoing exception records
`branch.policy=project-exception` in its local Git config.

### Approved artifact differences

Classifying a difference from an approved artifact is a completion decision. Record an unresolved
decision or deferred dependency in its durable issue or handoff record, with an owner, rather than
relying on conversation history.

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

### Files the agent authors

The authored-file rule once said such files were never written unless the user asked. The
principle it protected is real — a handoff note restating an MR description diverges from it —
but authorship turned out to be the wrong test. What predicts staleness is whether the content
has a canonical home, and a prompt written for another agent has none: no MR, no ticket, only a
paste buffer. Defaulting that case to chat cost a round trip whenever the content was long
enough to need copying, which is most of the time. The rule now keys on the canonical home
rather than on who wrote the file, and it asks a filed handoff to name what it is pinned to,
because the snapshot problem is the one genuine cost of writing the file at all.

## JavaScript instructions

### PascalCase functions and globals

PascalCase for VanillaJS/VanillaTS functions and globals is a company convention, not a baseline
JavaScript convention. The shared JavaScript rule sets `camelCase` as the default; the company
profile in `home/.chezmoitemplates/profiles/company.md` overrides it for company application and
project repositories. The convention does not apply to user-level configuration or customization
sources.

Reconsider when the company convention changes. Do not broaden it to personal configuration for the
sake of uniform wording.
