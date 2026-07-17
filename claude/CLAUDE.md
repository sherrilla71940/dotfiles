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

### Knowledge & reference-doc storage (all projects)

Three stores, each with a distinct job. Keep them separate — overlapping stores of the same facts is what causes drift.

1. **Atomic facts / rules / decisions → memory** (Claude Code's built-in per-project memory). The default. One discrete fact per file. This is the single source of truth for any specific fact; when a fact changes, update the memory file.
2. **Narrative orientation → ONE memory file** (e.g. `project-overview.md`). For multi-week / multi-session projects, keep a single narrative file that gives the *arc* — what the work is, the sequence, the current front line — and **points to** the atomic fact files via `[[links]]`. Critical rule: it restates **no facts of its own**, only sequences and links them. Because it holds no facts, it can't go stale when a fact changes. Do NOT maintain a separate standalone overview document outside memory (e.g. a hand-written `MASTER.md`) — a second live copy of the facts drifts. If one exists, retire it (stop referencing it) rather than dual-maintaining.
3. **Non-text reference docs I may need to read (Word, PDF, Excel, etc.) → `C:\Users\Aaron.Sherrill\Documents\personal\reference-docs\{projectName}\`** — where `{projectName}` is the current working directory / repo name (e.g. `taoyuansewer2`). If that folder doesn't exist, create it. Single home per project; don't scatter these files elsewhere. To read/work with them, use the dedicated **office skills** (`xlsx`, `docx`, `pdf`, `pptx`) — they trigger on the file type and extract content properly (tables, tracked changes, formulas). Plain images: the Read tool.

---

## Company Coding Style

- Use PascalCase for VanillaJS/VanillaTS function names and globals (company standard), and for React component names only. Use camelCase for all other identifiers.
- All code comments should be in zh-tw.
