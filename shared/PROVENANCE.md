# Why some shared rules exist

Maintainer notes for `shared/rules/`. **This file is never linked into any assistant's
configuration**, so nothing here costs context.

That matters: Claude Code strips block-level HTML comments from `CLAUDE.md` and rules
before injecting them, but Codex and Copilot do **not** — a `<!-- note -->` inside
`shared/core.md` would be read verbatim by both, wasting Codex's 32 KiB
`project_doc_max_bytes` budget. So maintainer notes for shared files go here, and only
Claude-only files (`claude/CLAUDE.md`) keep inline HTML comments.

## core.md

- **"Be concise and actionable."** — provenance: kept because artifacts have claimed work
  was done that wasn't. Replace this note with the real incident. This is a template;
  copy the pattern for other hard-won rules.
- **"Never assert an action that hasn't happened"** and **"Verify before claiming done"**
  are a pair. The second is what makes the first enforceable rather than aspirational;
  don't trim one without the other.
- **"Verify version-sensitive tooling details before acting."** — the tool-neutral form of
  a rule that started as a Claude-only instruction. `claude/CLAUDE.md` keeps the sharper
  Claude version naming the `claude-code-guide` agent.
- **Shell commands on Windows** — the neutral version lives here because Codex and Copilot
  also run shell commands on Windows. The Claude Code version, which names the Bash and
  PowerShell *tools* and the `CLAUDE_CODE_USE_POWERSHELL_TOOL` setting, stays in
  `claude/CLAUDE.md`.

## javascript.md

- The **PascalCase for VanillaJS/VanillaTS functions and globals** bullet is a company
  standard, not a general JS convention. It was previously isolated in a
  `company-coding-style.instructions.md` file; folded in here so there is one JS source.

## Merge history

`shared/rules/` was created from two independently maintained trees that had drifted:
`claude/rules/*.md` (`paths:`) and `copilot/instructions/*.instructions.md` (`applyTo:`).

**Claude Code is the base.** Its files are the canonical text and its frontmatter is the
source of truth — the `paths:` globs here are Claude's originals, unchanged. Copilot's
copies contributed only material Claude's lacked and that carries real information: the
DOM/browser-APIs section, debounce-vs-throttle, `requestAnimationFrame`, the
`isFinite('123') === true` pitfall, and the loading/empty/success/failure state rule.
Everything else Copilot carried was baseline hygiene — `prefer const`, `never var`,
template literals, strict equality, `Object.hasOwn`, avoid `eval`, ESM imports, brace
style — and was dropped. Current models do those by default; always-on rules should spend
context on what differs from the default.

The test for adding a bullet: would a competent developer using a current model do this
anyway? If yes, leave it out. Keep pitfalls, judgment calls, company standards, and
project conventions.

**No reworded twins.** A rule that names Claude machinery lives in `claude/CLAUDE.md` only
and is absent from `core.md`; it is never rewritten into a tool-neutral duplicate. Three
rules are Claude-only for that reason — the `claude-code-guide` verification rule, the
`Agent`/subagent parallelization rules, and the Bash-vs-PowerShell tool preference — so
Codex and Copilot do not receive them. Generalizing one means deliberately editing the
shared file, not copying it.

**Single ownership, not imports, between rule files.** Where two rule files cover the same
ground, one owns it and the other cross-references in prose: `core.md` owns comment and
JSDoc policy, `html-css.md` owns the `data-*` / `id` convention, and `javascript.md` points
at both. Imports are used only across *tools* (Claude's file imported by Copilot), never to
stitch shared rules together — Codex cannot follow them, and in Claude Code an import
doesn't reduce context because imported files load at launch anyway.
