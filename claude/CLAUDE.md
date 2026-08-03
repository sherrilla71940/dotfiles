# CLAUDE.md

## Core Principles

### Scope and priority

- Apply rules in this order when conflicts occur: language/framework-specific > file-type-specific > general.
- Edit source-of-truth files, not generated output (for example: `.ts` over `.js`, `.scss` over `.css`). Only compile or generate output if explicitly requested.

### Response behavior

- Always respond in English. This instruction wins over any language-specific rule in a conflict.
- Be concise and actionable.
- **Never assert an action that hasn't happened.** In any artifact — MR/PR descriptions,
  commit messages, docs, messages to others — do not write that something was asked,
  reported, fixed, or agreed unless it actually was at the time of writing. Use "pending"
  or "suggested" phrasing for anything not yet done.
- **Handling missing/ambiguous information:** if any input needed for a task — source files, specs, data, or these instructions themselves — is incomplete, unreadable, ambiguous, or missing, do not guess or silently fill the gap. Instead:
  1. State what is unclear/missing and where (file, line number, section, field/parameter name, or whatever locator fits).
  2. State what's needed from the user to resolve it.
  3. Prefix the flag with `⚠️ Needs clarification:` so it's easy to spot.
  - If other parts of the task are unaffected by the gap, implement those and clearly separate what's done from what's blocked.
  - **Minor, low-stakes ambiguity** (e.g., a formatting preference with no real consequence) can be resolved with a stated default instead — say what was assumed and why.
  - The bar: if a wrong guess would break something, change output correctness, or require rework, flag it. Otherwise, assume and proceed.
  - Before flagging, try to resolve it yourself from the code, data, or history. Only flag
    what survives a genuine attempt, and say what you tried. Do not record something as an
    open question when one search would settle it.
- **Scope of in-conversation requests:** a request that specifies how to answer — language, format, length, tone — applies to that one response unless it's phrased as a standing instruction ("from now on", "always", "for the rest of this session"). Do not promote a one-off request into a default. If unsure whether a request was one-off or standing, follow it once and ask.
- After non-trivial implementation (multiple files, a shared module, or meaningful
  architectural impact), summarize what changed, why, and any assumptions or remaining
  risks. Scale the summary to the change.

### Standing pending-items list

For multi-step or multi-session work, end each response with a short list of things identified but not yet done. Keep it to ~5 lines, one line per item, no re-explanation. Group as:

- **Ready now** — mine to do
- **Blocked** — waiting on a person, a merge, data, or access (name which)
- **Watching** — noted deliberately, no action intended

Rules:

- **The list is a view, not the store.** Anything that still matters after this conversation ends must also be written to project memory. The list renders what is already durable elsewhere; it is never the only copy. This is precisely what makes it safe to omit.
- Drop items the moment they are resolved — do not accumulate ✅ entries.
- Skip the list for one-off questions, quick lookups, and purely conversational turns.
- If the list would exceed ~5 lines, treat that as a signal to collapse finished threads into memory, not to write a longer list.

### Engineering principles

- Keep changes minimal, scoped, and architecture-aware.
- Prefer root-cause fixes over surface-level patches.
- Before changing shared modules, inspect their callers and preserve existing contracts. If dependent files must change, identify them in the plan and update them together.
- Avoid over-engineering. Do not introduce abstractions, layers, or utilities until they are clearly justified by duplication, variation, or complexity.
- Apply Clean Code principles pragmatically:
  - Favor SRP, DRY, low coupling, and high cohesion.
  - Prefer intentional duplication over premature abstraction when it keeps the code easier to read and change.
- Reuse existing utilities, services, and shared modules before creating new ones.
- When you do write something new, match the conventions of the surrounding code —
  pick by meaning, not proximity, and confirm anything you reference (a utility, class, or
  stylesheet) is actually available in that context. Name the precedent you followed, or say there wasn't one.
- Handle errors explicitly — no silent catches; either handle meaningfully or propagate with context. Validate inputs at trust boundaries, and don't leak internals (stack traces, internal messages) in user-facing errors.
- Flag any change that breaks a public API, wire format, config schema, or persisted-data shape, and describe the migration/compatibility path. Prefer additive, backward-compatible changes; make schema migrations reversible.
- When git hooks report issues, fix the reported issues instead of bypassing the hooks.
- Don't commit unless asked. When asked, keep commits atomic and scoped to one logical change, and follow Conventional Commits (see the git-commit-reference skill). Stage deliberately — never blind `git add -A`. When the tree holds more than one logical change, state the proposed commit grouping before committing, and split unrelated changes that share a file with patch staging.

### Security

- Prevent common web vulnerabilities (XSS, injection, unsafe deserialization, CSRF gaps).
- Treat client-side validation and escaping as defense-in-depth, not a trust boundary.
- Never rely on client-side checks for authorization or critical validation.
- Escape or sanitize user-generated content whenever bypassing a framework's built-in protections (e.g., React `dangerouslySetInnerHTML`, direct `innerHTML`, or raw template output).
- Never hardcode secrets, API keys, or access tokens.

### Readability and documentation

- Prefer the clearest correct code over the shortest or cleverest code.
- Favor descriptive names and straightforward control flow over explanatory comments and clever abstractions.
- Use JSDoc (`/** */`) for exported/public APIs and non-obvious functions: explain purpose, usage constraints, parameters, and return values.
- Use inline `//` comments sparingly, for implementation notes that explain _why_ a non-obvious decision or workaround was made.
- Code comments are written in zh-tw — see Company Coding Style.

### Shell tool preference

- Prefer the **Bash tool** for standard operations (`mv`, `mkdir`, `ls`, `grep`, `git`, etc.) — Git Bash backs it and these are simpler and more portable than PowerShell equivalents. (`CLAUDE_CODE_USE_POWERSHELL_TOOL=0` in settings.json forces the Bash tool on Windows even when the PowerShell-tool rollout is active.)
- Use the **PowerShell tool** only when the task is genuinely Windows-specific: COM automation, registry access, or PowerShell-only cmdlets.
- If the Bash tool is unavailable, say so before falling back to PowerShell.

### Knowledge & reference-doc storage (all projects)

Three stores, each with a distinct job. Keep them separate — overlapping stores of the same facts is what causes drift.

1. **Atomic facts / rules / decisions → memory** (Claude Code's built-in per-project memory). The default. One discrete fact per file. This is the single source of truth for any specific fact; when a fact changes, update the memory file.
2. **Narrative orientation → ONE memory file** (e.g. `project-overview.md`). For multi-week / multi-session projects, keep a single narrative file that gives the _arc_ — what the work is, the sequence, the current front line — and **points to** the atomic fact files via `[[links]]`. Critical rule: it restates **no facts of its own**, only sequences and links them. Because it holds no facts, it can't go stale when a fact changes. Do NOT maintain a separate standalone overview document outside memory (e.g. a hand-written `MASTER.md`) — a second live copy of the facts drifts. If one exists, retire it (stop referencing it) rather than dual-maintaining.
   - **When to update it:** only on _arc-level_ events — a task/phase changes status (blocked → active → done), a new task/phase appears, or the "current front line / next action" moves. NOT for individual fact changes (those go in the atomic file the overview points to). Since it auto-loads every session, also reconcile it opportunistically: if what you're doing this session contradicts the arc it describes, update the arc. The user can always say "update the overview" to force a refresh.
   - **State it when you update the arc:** whenever you change the overview, tell the user in one line what changed (e.g. "Updated the overview — Task B is now active"). Never edit it silently — the user should always know its current state and be able to correct a wrong arc.
3. **Non-text reference docs I may need to read (Word, PDF, Excel, etc.) → `C:\Users\Aaron.Sherrill\Documents\personal\reference-docs\{projectName}\`** — where `{projectName}` is the current working directory / repo name (e.g. `taoyuansewer2`). If that folder doesn't exist, create it. Single home per project; don't scatter these files elsewhere. To read/work with them, use the dedicated **office skills** (`xlsx`, `docx`, `pdf`, `pptx`) — they trigger on the file type and extract content properly (tables, tracked changes, formulas). Plain images: the Read tool.

---

## Company Coding Style

- Use PascalCase for VanillaJS/VanillaTS function names and globals (company standard), and for React component names only. Use camelCase for all other identifiers.
- All code comments should be in zh-tw — inline `//`, block `/* */`, and JSDoc `/** */` alike. This governs code comments only; chat responses stay English per Response behavior.
