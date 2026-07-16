# CLAUDE.md

## Core Principles

### Scope and priority

- Apply rules in this order when conflicts occur: language/framework-specific > file-type-specific > general.
- Edit source-of-truth files, not generated output (for example: `.ts` over `.js`, `.scss` over `.css`). Only compile or generate output if explicitly requested.

### Response behavior

- Always respond in English. This instruction wins over any language-specific rule in a conflict.
- Be concise and actionable.
- **Handling missing/ambiguous information:** if any input needed for a task — source files, specs, data, or these instructions themselves — is incomplete, unreadable, ambiguous, or missing, do not guess or silently fill the gap. Instead:
  1. State what is unclear/missing and where (file, line number, section, field/parameter name, or whatever locator fits).
  2. State what's needed from the user to resolve it.
  3. Prefix the flag with `⚠️ Needs clarification:` so it's easy to spot.
  - If other parts of the task are unaffected by the gap, implement those and clearly separate what's done from what's blocked.
  - **Minor, low-stakes ambiguity** (e.g., a formatting preference with no real consequence) can be resolved with a stated default instead — say what was assumed and why.
  - The bar: if a wrong guess would break something, change output correctness, or require rework, flag it. Otherwise, assume and proceed.
- After implementation, summarize:
  - What changed
  - Why it changed
  - Any assumptions or remaining risks

### Engineering principles

- Keep changes minimal, scoped, and architecture-aware.
- Prefer root-cause fixes over surface-level patches.
- Before changing shared modules, inspect their callers and preserve existing contracts. If dependent files must change, identify them in the plan and update them together.
- Avoid over-engineering. Do not introduce abstractions, layers, or utilities until they are clearly justified by duplication, variation, or complexity.
- Apply Clean Code principles pragmatically:
  - Favor SRP, DRY, low coupling, and high cohesion.
  - Prefer intentional duplication over premature abstraction when it keeps the code easier to read and change.
- Reuse existing utilities, services, and shared modules before creating new ones.
- When git hooks report issues, fix the reported issues instead of bypassing the hooks.

### Security

- Prevent common web vulnerabilities (XSS, injection, unsafe deserialization, CSRF gaps).
- Treat client-side validation and escaping as defense-in-depth, not a trust boundary.
- Never rely on client-side checks for authorization or critical validation.
- Escape or sanitize user-generated content whenever bypassing framework protections (e.g., `dangerouslySetInnerHTML` or `innerHTML`).
- Never hardcode secrets, API keys, or access tokens.

### Readability and documentation

- Prefer the clearest correct code over the shortest or cleverest code.
- Favor descriptive names and straightforward control flow over explanatory comments and clever abstractions.
- Use JSDoc for exported/public APIs and non-obvious functions: explain purpose, usage constraints, parameters, and return values.
- Use standard comments sparingly, for implementation notes that explain *why* a non-obvious decision or workaround was used.

### Shell tool preference

- On Windows with Git for Windows installed, **prefer the Bash tool** for standard operations (`mv`, `mkdir`, `ls`, `grep`, `git`, etc.). It is simpler and more portable.
- Use PowerShell only when the task is genuinely Windows-specific: COM automation, registry access, or PowerShell-only cmdlets.

---

## Company Coding Style

- Use PascalCase for VanillaJS/VanillaTS function names and globals (company standard), and for React component names only. Use camelCase for all other identifiers.
- All code comments should be in zh-tw.
