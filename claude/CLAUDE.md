# CLAUDE.md

## Core Principles

### Scope and priority

- Apply rules in this order when conflicts occur: explicit in-conversation user instruction > language/framework-specific > file-type-specific > general.
- Edit source-of-truth files, not generated output (for example: `.ts` over `.js`, `.scss` over `.css`). Only compile or generate output if explicitly requested.

### Response behavior

- Respond in English by default — this overrides any language-specific rule in a conflict. But an explicit in-conversation request (e.g. "answer in Chinese") overrides it for that response (see Scope of in-conversation requests).
- Be concise and actionable.
  <!-- Personal Notes: -->
  <!-- - provenance: kept because artifacts have claimed work was done that wasn't. Edit this note with the real incident; it's stripped before context (zero tokens), so it's for human maintainers only. This is a template — copy the pattern above other hard-won rules. -->
  <!-- - source (block-level HTML comments are stripped before context = zero token cost): code.claude.com/docs/en/memory → "How CLAUDE.md files load" — "Block-level HTML comments … are stripped before the content is injected into Claude's context." Comments inside code blocks are preserved. -->
- **Never assert an action that hasn't happened.** In any artifact — MR/PR descriptions,
  commit messages, docs, messages to others — do not write that something was asked,
  reported, fixed, or agreed unless it actually was at the time of writing. Use "pending"
  or "suggested" phrasing for anything not yet done.
- **Verify before claiming done.** Before calling a change complete, check it: re-read the edited file, run typecheck/lint/tests scoped to the changed files when the project supports scoping, and review the `git diff`. Run a full build/test suite only when explicitly asked or when scoped verification isn't possible. If you couldn't verify something, say what you didn't run. This is what makes "never assert an action that hasn't happened" enforceable rather than aspirational.
- **Claude Code / Agent SDK / API specifics need verification, not memory.** For configuration or procedural details (CLI flags, `settings.json` keys, defaults, hook event names, slash command syntax) about Claude Code, the Claude Agent SDK, or the Claude API, verify via the `claude-code-guide` agent or current docs rather than answering from recall — these drift across releases, and a wrong answer here corrupts the user's own config files.
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

When a response leaves unresolved work (follow-up actions, blockers, or deliberate deferrals), end with a short list of things identified but not yet done. Keep it brief—target ~5 lines where possible, but allow more if a complex task requires it. One line per item, no re-explanation. Group as:

- **Ready now** — mine to do
- **Blocked** — waiting on a person, a merge, data, or access (name which)
- **Watching** — noted deliberately, no action intended

Rules:

- **The list is a view, not the store; `MEMORY.md` is.** Anything durable beyond this conversation must be written there — reconcile against `MEMORY.md`'s open TODOs (not just recent turns) before rendering the list, and never silently drop what the store holds. When an item is blocked, persist _what it's blocked on_ (person, merge, data, access) inside its `MEMORY.md` entry — the list's Blocked/Watching status is ephemeral and won't survive the session.
- Drop items the moment they resolve — do not accumulate ✅ entries. Omit the list entirely when nothing remains to track (one-off questions, quick lookups, purely conversational turns, fully completed work). If it grows long across tasks, collapse finished threads into memory rather than piling up minor items.

### Engineering principles

- Keep changes minimal, scoped, and architecture-aware.
- Prefer root-cause fixes over surface-level patches.
- Before changing shared modules, inspect their callers and preserve existing contracts. If dependent files must change, identify them in the plan and update them together.
- Before replacing or deleting existing code, understand why it was written that way — code that looks redundant, dead, or overly defensive often encodes a subtle constraint, bug workaround, or edge case.
- Avoid over-engineering. Do not introduce abstractions, layers, or utilities until they are clearly justified by duplication, variation, or complexity.
- Apply Clean Code principles pragmatically:
  - Favor SRP, DRY, low coupling, and high cohesion.
  - Prefer intentional duplication over premature abstraction when it keeps the code easier to read and change.
- Reuse existing utilities, services, and shared modules before creating new ones.
- When you do write something new, match the conventions of the surrounding code —
  pick by meaning, not proximity, and confirm anything you reference (a utility, class, or
  stylesheet) is actually available in that context. Say so when you had to introduce a new pattern rather than follow an existing one.
- Handle errors explicitly — no silent catches; either handle meaningfully or propagate with context. Validate inputs at trust boundaries, and don't leak internals (stack traces, internal messages) in user-facing errors.
- Flag any change that breaks a public API, wire format, config schema, or persisted-data shape, and describe the migration/compatibility path. Prefer additive, backward-compatible changes; make schema migrations reversible.
- When git hooks report issues, fix the reported issues instead of bypassing the hooks.
- Don't commit unless asked. When asked, keep commits atomic — one logical change each — and follow Conventional Commits (see the git-commit-reference skill). Stage deliberately (never blind `git add -A`); when the tree holds several logical changes, state the proposed grouping before committing. The `/git-commit-action` skill executes this (batch grouping by default).

### Parallelizing independent work

- When a task decomposes into independent units with no shared state (e.g., the same operation repeated across multiple worktrees, branches, files, or subsystems), default to running them via parallel `Agent` calls rather than working through them one at a time inline. Don't wait to be told "in parallel" or "use agents" — treat independence itself as the trigger.
  <!-- Personal Notes: -->
  <!-- - Subagents do NOT inherit the parent session's auto memory (confirmed via Claude Code docs — the exception is a fork, which inherits the parent conversation). Any project fact, decision, or history a subagent needs must be written into its prompt explicitly; don't assume it can look this up itself. -->
  <!-- - Worktree isolation for parallel subagents is opt-in, not automatic — request it explicitly (`isolation: 'worktree'` on the Agent call, or ask Claude to "use worktrees for your agents") whenever the parallel agents will write to overlapping files. Nothing creates a worktree silently. -->
- This applies mid-task too: if work started sequentially and the remaining steps turn out to be independent, switch to parallel for what's left rather than finishing serially out of momentum.
- Reserve sequential inline work for cases with a real dependency (each step needs the previous step's output or a decision made along the way) or where the work is small enough that writing a self-contained agent prompt would cost more time than it saves.

### Security

- Never trust the client for authorization or critical validation — enforce it server-side; client-side checks are defense-in-depth only.
- When bypassing a framework's built-in escaping (React `dangerouslySetInnerHTML`, direct `innerHTML`, raw template output, string-built SQL), sanitize or parameterize the input yourself — this is where XSS and injection actually get in.
- Don't deserialize untrusted input into live objects, and guard state-changing requests against CSRF (anti-CSRF token or `SameSite` cookies) — neither is caught by the escaping rule above.
- Never hardcode or commit secrets, API keys, or access tokens.

### Readability and documentation

- Prefer the clearest correct code over the shortest or cleverest code.
- Favor descriptive names and straightforward control flow over explanatory comments and clever abstractions.
- Use JSDoc (`/** */`) for exported/public APIs and non-obvious functions: explain purpose, usage constraints, parameters, and return values.
- Use inline `//` comments sparingly, for implementation notes that explain _why_ a non-obvious decision or workaround was made.
- Code comments are written in zh-tw — inline `//`, block `/* */`, and JSDoc `/** */` alike (code comments only; chat responses stay English).

### Git worktrees and auto memory (confirmed gap, Windows work PC)

Auto memory sharing across git worktrees, and where `autoMemoryDirectory`/`settings.local.json` actually take effect, has a confirmed, live-tested gap on the Windows work PC — including the working fix, the reproducible verification test, and how session-launch location interacts with subagents/Agent View. When troubleshooting Claude Code worktree memory or `autoMemoryDirectory` behavior — or deciding whether a subagent/Agent View session will have memory access — use the `claude-worktree-memory` skill instead of relying on memory.

### Shell tool preference

Windows only — on macOS/Linux, Bash is the only shell tool and this section doesn't apply.

- Prefer the **Bash tool** for standard operations (`mv`, `mkdir`, `ls`, `grep`, `git`, etc.) — Git Bash backs it and these are simpler and more portable than PowerShell equivalents. (`CLAUDE_CODE_USE_POWERSHELL_TOOL=0` in settings.json forces the Bash tool on Windows even when the PowerShell-tool rollout is active.)
<!-- source (CLAUDE_CODE_USE_POWERSHELL_TOOL=0): code.claude.com/docs/en/setup → Windows setup — "Set CLAUDE_CODE_USE_POWERSHELL_TOOL=1 to opt in or 0 to opt out." Also verified empirically this session: the PowerShell tool became unavailable once =0 took effect. -->
- Use the **PowerShell tool** only when the task is genuinely Windows-specific: COM automation, registry access, or PowerShell-only cmdlets.
- If the Bash tool is unavailable, say so before falling back to PowerShell.

### Knowledge & reference-doc storage (all projects)

Use three distinct stores. Keep them separate to avoid duplicate sources of truth.

1. **Facts, rules, and decisions → auto memory.** This is the single source of truth for any specific fact. Update the existing memory file when a fact changes. (The harness injects the memory mechanics—one fact per file and the `MEMORY.md` index—every session, so they aren't restated here.)
2. **Narrative arc → `MEMORY.md`** (the only memory file that auto-loads at session start). For multi-week or multi-session work, keep the work sequence, current front line, and project narrative here, linking to topic files instead of duplicating facts. `MEMORY.md` should contain **no facts of its own**, only narrative and references. When the narrative changes, record it in one line rather than editing it silently. Do not create separate overview files (such as `project-overview.md` or `MASTER.md`); if one already exists, fold its contents into `MEMORY.md` and remove it.
<!-- source (only MEMORY.md auto-loads; 200-line/25KB cap; topic files load on demand): code.claude.com/docs/en/memory → Auto memory / How it works — "The first 200 lines of MEMORY.md, or the first 25KB, whichever comes first, are loaded at the start of every conversation." -->
3. **Non-text reference documents (Word, PDF, Excel, etc.) → `~/Documents/personal/reference-docs/{projectName}/`** (under your home directory — resolve `~` per machine), where `{projectName}` is the current working directory or repository name (for example, `taoyuansewer2`). If the folder doesn't exist, create it. Keep a single location per project. Use the dedicated office skills (`xlsx`, `docx`, `pdf`, `pptx`) to read and work with these files. Use the Read tool for plain images (standalone image files, or images already extracted from a container document) — not as a substitute for the office skill on the container file itself.
