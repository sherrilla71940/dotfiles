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
success; the work is then unmanaged, reverted by the next `chezmoi apply` or simply absent
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

## JavaScript instructions

### PascalCase functions and globals

PascalCase for VanillaJS/VanillaTS functions and globals is a company standard, not a general
JavaScript convention. It applies to application and project repositories and is explicitly
excluded from user-level configuration, where normal JavaScript naming and surrounding style
apply.

Reconsider when the company convention changes. Do not broaden it to personal configuration
for the sake of uniform wording.
