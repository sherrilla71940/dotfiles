# CLAUDE.md

## Core Principles

### Scope and priority

- Apply rules in this order when conflicts occur: explicit in-conversation user instruction > language/framework-specific > file-type-specific > general.
- Edit source-of-truth files, not generated output (for example: `.ts` over `.js`, `.scss` over `.css`). Only compile or generate output if explicitly requested.

### Response behavior

- Respond in English by default — this overrides any language-specific rule in a conflict. But an explicit in-conversation request (e.g. "answer in Chinese") overrides it for that response (see Scope of in-conversation requests).
- Be concise and actionable.
  <!-- provenance: kept because artifacts have claimed work was done that wasn't. Edit this note with the real incident; it's stripped before context (zero tokens), so it's for human maintainers only. This is a template — copy the pattern above other hard-won rules. -->
  <!-- source (block-level HTML comments are stripped before context = zero token cost): code.claude.com/docs/en/memory → "How CLAUDE.md files load" — "Block-level HTML comments … are stripped before the content is injected into Claude's context." Comments inside code blocks are preserved. -->
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

### Git worktrees and auto memory (Windows-confirmed gap)

Docs say auto memory is shared across worktrees via a git-derived project key, and that `.claude/settings.local.json` at repo root "resolves through worktrees to the main checkout" (current per docs, re-confirmed 2026-08-05). On this Windows machine **both claims are empirically false for real linked worktrees** — confirmed by a live test, not just disk inspection, on 2026-08-05.

**Live-tested finding: root-only `autoMemoryDirectory` does NOT propagate into real worktrees here.** Test: pointed the repo-root setting at an obviously-fake marker path, then ran `claude -p "<probe>"` from three locations. The repo root itself picked up the marker (proving `-p` mode *does* apply local settings — rules out a trust-mode confound). A real linked worktree (confirmed via `git worktree list`) ignored the repo-root setting entirely and fell back to its own self-derived, wrong (case-mismatched) path. So the documented worktree-resolution behavior for `settings.local.json` is not functioning for real worktrees on this machine, at least in headless (`-p`) mode — true interactive-session behavior wasn't separately isolated and remains a small residual gap.

**Confirmed working remedy:** place a **local** `.claude/settings.local.json` with `autoMemoryDirectory` directly inside **every worktree's own folder** — not just the repo root. Verified on both of this repo's real worktrees on 2026-08-05 (probe returned the correct shared path only after adding the local file to each). This **inverts** the earlier guidance here about not duplicating the file into worktrees — that assumed the documented resolution actually works; empirically, on this machine, it doesn't, so duplication into each worktree is currently required, not redundant. The drive-letter case-sensitivity theory (main checkout's key lowercase `c--...`, worktree self-derived keys uppercase `C--...`) still holds as the likely reason the fallback derivation is wrong, but the more load-bearing fact is that resolution itself isn't happening at all.

Closer GitHub match: `anthropics/claude-code#34437` ("Worktrees should share the same project directory as the main repo," open as of 2026-08-05) describes this exact symptom. `#39920` (closed "not planned") describes the opposite symptom — worktrees collapsing INTO main (over-sharing) — and does not explain this.

Before troubleshooting a worktree memory issue, re-fetch **<https://code.claude.com/docs/en/memory#storage-location>** and **<https://code.claude.com/docs/en/settings>** directly (not from recall), and re-run the marker-path test below before trusting that a fix has shipped — this may be a live, unfixed bug.

<!--
provenance (2026-08-05): the marker-path test — temporarily set repo-root autoMemoryDirectory to `~/.claude/projects/ZZZ-TRUST-SKIP-TEST-MARKER/memory` (an obviously nonexistent path), then ran `claude -p "reply with only the exact absolute path of your auto-memory MEMORY.md shown in your startup context, or NO_MEMORY_PATH_SHOWN if none"` from three locations: (1) repo root → returned NO_MEMORY_PATH_SHOWN, proving it read and applied the marker (not a trust-skip artifact); (2) real worktree `taoyuansewer2.worktrees\feat-recycled-water-front-pr` → returned its own self-derived path `C--Users-...-taoyuansewer2\memory` (uppercase C, no worktree suffix this time — a third variant, distinct from both the marker and the disk-observed `C--...-worktrees-<branch>` folder found earlier the same day), proving it never read the repo-root file at all; (3) same worktree after adding a local `.claude/settings.local.json` with the correct (non-marker) value directly inside it → returned the correct shared lowercase `c--...` path. Restored the repo-root file to its correct value immediately after step 2. Repeated step 3's fix on the second real worktree (`feature-sewer-layer-check-115yr-spec`) with the same result. Both local files confirmed gitignored via the existing global `**/.claude/settings.local.json` rule. Independently verified by a separate claude-code-guide subagent pass same day, which also surfaced #34437 and confirmed #39920's actual symptom via GitHub API — see that pass for doc-quote-level detail on the parts of this note that remain doc-confirmed (the sharing claim, the three settings-resolution exceptions, the v2.1.211 version gate, the old-file precedence rule) as opposed to the live-tested finding above, which is disk/CLI evidence, not a doc claim.
-->

- **Procedure (per location that needs it — repo root, AND every real worktree, AND any non-git launch folder in use):**
  1. If `.claude/settings.local.json` doesn't exist yet in that location, create it; if it exists, merge in the key rather than overwriting the file.
  2. Add/update the `autoMemoryDirectory` key to point at the shared memory path (same value everywhere: `~/.claude/projects/<base-repo-encoded-path>/memory`).
  3. Check whether it's actually gitignored (`git status --porcelain .claude/settings.local.json` — no output means ignored or unchanged-and-tracked; check which). Don't assume a global gitignore rule covers it without checking.
  4. If it is **not** ignored, add `.claude/settings.local.json` to the repo's (or a personal) `.gitignore` — this file can contain machine-specific absolute paths and shouldn't be committed as-is.
  5. After editing `.gitignore`, remind the user to commit that `.gitignore` change (do not commit it yourself unless asked — see the standing "don't commit unless asked" rule).
  6. **Verify, don't assume** — re-run the marker-path test from the provenance comment for that specific location before trusting it's actually working.
- This is a real documented settings key, not a workaround hack (avoid directory junctions — they aren't Claude-Code-aware and can silently break on a future update).
- **If an old pre-2.1.211 `settings.local.json` is still sitting inside a worktree** (left over from before upgrading past that version): it isn't simply superseded. Per current docs, when both the old worktree-local file and the new repo-root file set the same key, the repo root's value wins for non-permission keys, but **permission rules from both files stay in effect** — don't assume the worktree-local file is safe to ignore or delete without checking its permission rules first.
- Value must be an absolute path or start with `~/`. In project/local settings it's honored only after the workspace-trust dialog is accepted for that folder — expect that prompt the first time a new session starts there.
- Per current docs (re-confirmed 2026-08-05), the file also stays local to the start directory (instead of any resolution) when the repo root **is** the home directory, or in **Agent SDK** sessions (not plain CLI sessions) — neither is likely to apply to normal repo work, but both are documented, and moot anyway now that per-location local files are the actual working approach.
- **When starting work in a new worktree** (of any repo, not just this one) and `MEMORY.md`/memory content looks unexpectedly empty: don't assume there's no history. Check sibling folders under `~/.claude/projects/` for one matching the same repo without a worktree-path suffix, read memory from there, and add a local `autoMemoryDirectory` entry to that worktree per the procedure above.

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
