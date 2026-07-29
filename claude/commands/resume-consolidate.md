---
description: Condense the per-project evidence files across a summaries directory into one paste-ready resume entry per repo.
argument-hint: [summaries-dir]
---

# Consolidate resume summaries

This is the second stage of the resume pipeline. `reverse-engineer.md` produces a rich, evidence-backed file set per repo. This command runs across every repo already in a summaries directory, compares them against each other, and writes one paste-ready `summary.md` per repo — a header line plus 1–3 bullets, sized to actually fit on a resume that holds ~10–12 projects.

## Context

I am a frontend developer at an outsourcing/consulting company, working mostly on Taiwan government web systems in the public-infrastructure and environmental-regulatory sectors, commissioned by municipal or central government agencies. My typical role is primary frontend contributor on a small team (2–10 people) — the backend dev is not necessarily the technical lead. My focus is the frontend/presentation layer (React, TypeScript, SCSS, and Razor views); when I touch .NET it's limited to the view layer plus basic controllers/routing, not backend business logic or full system architecture.

I have had real architecture ownership on the frontend side, so scoped frontend/subsystem architecture claims are legitimate — whole-system or backend architecture claims are not. Use "Built / Authored / Owned / Implemented / Refactored" freely; reserve "Architected / Designed" for frontend architecture I genuinely owned; avoid "Architected / Designed / Led / Spearheaded" for whole-system or backend claims.

## Before you start: where are the inputs?

Summaries directory: `$ARGUMENTS`

If that is empty, ask me for a path and wait for my answer. Do not guess one.

Each `<summaries-dir>/<repo-name>/` folder is expected to hold the output of `reverse-engineer.md`: `project-summary.en.md`, `resume.en.md`, `evidence.md`, `architecture.en.md`, `business.en.md`, `interview.en.md`, `linkedin.en.md`, `career-portal.zh-TW.md`, `glossary.md`, and zh-TW variants of most of these.

**Read order per repo** — stop once you have what you need:

1. `resume.en.md` — pre-vetted bullets with confidence tags and an explicit "what not to claim" section. Start here.
2. `project-summary.en.md` — role, dates, scale, tech stack context.
3. `evidence.md` — only if `resume.en.md` is ambiguous or a specific claim needs its commit/file citation checked.

Treat `resume.en.md`'s "what not to claim" section as binding. Never claim a teammate's work regardless of how the code reads — that section already resolved the ambiguity once; don't re-litigate it here.

## Workflow

1. Discover repos: list immediate subdirectories of the summaries directory (skip `.claude/`). Flag ambiguity with `⚠️ Needs clarification:`.
2. Spawn one subagent per repo, in parallel. Give each the repo path, this command's rules verbatim, and the instruction to read `resume.en.md` first.
3. Each subagent writes `<summaries-dir>/<repo-name>/summary.md`. If Write/Edit fail with a worktree-isolation error, fall back to PowerShell: `$content | Out-File -FilePath "<path>" -Encoding utf8` — use a single-quoted here-string (`@'...'@`) so `$` and backticks in the content aren't expanded, and close it at column 0.
4. Print every generated entry in chat and confirm the files were written. Flag anything unresolvable with `⚠️`.

## Rules

Apply the **tier/bullet-count table** and the **verb-to-evidence table** from `reverse-engineer.md`'s "Resume rules" section (same directory as this file) — do not restate or re-derive them here; that file is canonical. Bullet count is proportional to ownership depth: never give a feature-contributor project more bullets than a full-ownership project on the same resume.

**Bullet formula:** [past-tense action verb] → [what you built/owned/solved] → [technology where it reinforces the point] → [outcome: what it enabled, what problem it solved, what scale it operates at].

If no quantitative metric exists, use proxy metrics instead of inventing one: commit count/tenure, compliance standard names (e.g. WCAG AAA), system scale from the repo docs (controller count, tier count, population served), or process signals ("ahead of backend delivery", "zero structural rewrites across subsequent features").

**Include:** architectural decisions and what they enabled; ownership scope; cross-cutting concerns (accessibility, CI/CD, security, compliance); initiative signals; technology that is recognizable and reinforces the claim; mobile-responsive/mobile-first patterns with specifics; design-system integration framed as an architectural act.

**Cut:** internal implementation details that don't transfer as a skill — translate the mechanism to its benefit instead (e.g. "re-entrancy guards deduplicating 401/403" → "preventing duplicate logout side-effects under concurrent requests"); library minutiae (Zod, React Hook Form, SheetJS) unless the role requires them; version numbers in bullets (keep in the header only if they signal currency); "Responsible for" — always an action verb instead; a tech name already in the header, unless naming it does explanatory work the header didn't already do.

**Scope precision:** never overstate the layer owned. Frontend-only auth work is "authentication frontend" or "frontend auth implementation," never "authentication system." Check `resume.en.md`'s ownership boundaries before writing any bullet touching a full-stack concern (auth, payments, APIs).

**Header line format:**

```
**[Project Title]** — [one-line description: domain + scale + audience] | [4–5 ATS-standard technologies, most recognizable first] | [Role] | [Dates if known]
```

**Confidentiality:** government client names are public contracts — fine to list. Avoid proprietary business logic, internal system codes, client data, anything under NDA.

### Before finalizing each bullet

- Lead with the highest-value contribution — architecture decision, ownership, difficult problem, or scale. Not every bullet needs architecture language; ownership or outcome alone can be the lead.
- Every bullet must communicate why the work mattered, through the action itself or an explicit outcome — don't force a vague trailing clause ("reducing future development effort") when the achievement is already self-evident.
- Verbs span the full range — architected/built/shipped/optimized/refactored/migrated/resolved are equally strong when the evidence supports them. Don't reach for architecture verbs by default.
- When in doubt, use the more conservative verb. An undersell is recoverable in an interview; an oversell collapses under one question.
- A bullet in `summary.md` must never claim more than `resume.en.md` already supports — if it does, the compression went wrong, not the source.
- **Scope-limiting qualifiers are the most common casualty of compression, and dropping one is exactly how "the compression went wrong" happens in practice.** Words like "frontend" (vs. the whole feature/module), "authored" (vs. "shipped" — implies the backend half exists too), or "pending" / "not yet merged" (vs. implying it shipped to production) are load-bearing for honesty, not filler trimmed for space. This is not hypothetical: one pass compressed `resume.en.md`'s correctly-scoped "authored the complete **frontend** for X, backend pending" down to "shipped the complete **module**" — silently deleting the one word that made the claim true, and reintroducing an overclaim the source file had already ruled out. If a qualifier does not fit the space, cut a different clause instead of the word that keeps the claim honest.
