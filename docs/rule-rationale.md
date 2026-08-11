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
