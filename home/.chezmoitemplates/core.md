# Core Principles

## Scope and priority

- Apply rules in this order when conflicts occur: explicit in-conversation user instruction > language/framework-specific > file-type-specific > general.
- Edit source-of-truth files, not generated output (for example: `.ts` over `.js`, `.scss` over `.css`). Regenerate output only when the requested change or proportionate verification requires it.

## Response behavior

- Respond in English by default — this overrides any language-specific rule in a conflict. But an explicit in-conversation request (e.g. "answer in Chinese") overrides it for that response (see Scope of in-conversation requests).
- Be concise and actionable.
- **Never assert an action that hasn't happened.** In any artifact — MR/PR descriptions,
  commit messages, docs, messages to others — do not write that something was asked,
  reported, fixed, or agreed unless it actually was at the time of writing. Use "pending"
  or "suggested" phrasing for anything not yet done.
- **Verify before claiming done.** Before calling a change complete, check it: re-read the edited file, run typecheck/lint/tests scoped to the changed files when the project supports scoping, and review the `git diff`. Run a full build/test suite only when explicitly asked or when scoped verification isn't possible. If you couldn't verify something, say what you didn't run. This is what makes "never assert an action that hasn't happened" enforceable rather than aspirational.
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

## Session workflow

- When a response leaves unresolved work, end with a short list grouped as **Ready now**, **Blocked** (name what it waits on), or **Watching**. Omit the list when nothing remains.

## Engineering principles

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

## Security

- Never trust the client for authorization or critical validation — enforce it server-side; client-side checks are defense-in-depth only.
- When bypassing a framework's built-in escaping (React `dangerouslySetInnerHTML`, direct `innerHTML`, raw template output, string-built SQL), sanitize or parameterize the input yourself — this is where XSS and injection actually get in.
- Don't deserialize untrusted input into live objects, and guard state-changing requests against CSRF (anti-CSRF token or `SameSite` cookies) — neither is caught by the escaping rule above.
- Never hardcode or commit secrets, API keys, or access tokens.

## Readability and documentation

- Prefer the clearest correct code over the shortest or cleverest code.
- Favor descriptive names and straightforward control flow over explanatory comments and clever abstractions.
- Use JSDoc (`/** */`) for exported/public APIs and non-obvious functions: explain purpose, usage constraints, parameters, and return values.
- Use inline `//` comments sparingly, for implementation notes that explain _why_ a non-obvious decision or workaround was made.
- Code comments are written in zh-tw — inline `//`, block `/* */`, and JSDoc `/** */` alike (code comments only; chat responses stay English).

## Reference documents

- Store non-text project references in `~/Documents/reference-docs/{projectName}/`, using the repository or working-directory name for `{projectName}`. Keep one location per project. Use the dedicated office skills (`xlsx`, `docx`, `pdf`, `pptx`) for container documents and an ordinary file read for standalone or already-extracted images.
