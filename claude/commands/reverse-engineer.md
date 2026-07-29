---
description: Reverse-engineer a project to understand it, then generate bilingual resume and interview material backed by evidence.
argument-hint: [output-dir]
---

# Reverse-engineer this project

Reverse-engineer the current project so I can understand how it works, explain it well, and describe my work on it honestly. Teaching me the system matters more than summarizing the code. Resume and interview material is a by-product of that understanding, not the goal.

**Do not inflate my ownership.** I would rather have three bullets I can defend under questioning than eight that collapse when an interviewer probes. When evidence is thin, say so.

## Before you start: where do outputs go?

Output directory: `$ARGUMENTS`

If that is empty, ask me for a path and wait for my answer. Do not pick one yourself, and do not write generated files into the repository being analyzed unless I ask for that.

Once you have a path, create `<output-dir>/<project-name>/` and write every generated file there.

## Investigate in phases

Work through these in order. Explain _why_ things exist, not just which libraries are present.

### 0. Orient to the stack before assuming one

Do not assume npm/React/SPA. Identify what this actually is first:

- Look for `package.json`, `*.csproj`/`*.sln`, `pom.xml`, `go.mod`, `Gemfile`, `requirements.txt`, `composer.json`.
- **Find the real source directory.** It may not be `src/`. Common: `src/`, `app/`, `lib/`, or a project-named folder (e.g. `MyApp/`). Every git command below needs this path — get it right before running any of them.
- Note the rendering model: SPA, server-rendered templates, hybrid, or static. This determines which architecture questions even apply.

If it is server-rendered (Razor/Blade/ERB/Django templates/JSP), then routing, global state, and client data-layer questions mostly do not apply — say so rather than forcing a SPA vocabulary onto it. Ask instead: how is per-page script organized, is there a bundler or hand-compiled output, how do pages get data (form POST vs AJAX vs API).

### 1. Discovery

What does the project do, who uses it, and what problem does it solve? Read manifests, README, config, and route/controller definitions to infer the domain and main user workflows.

For domain-heavy or government/enterprise systems, the domain rules matter more than the tech. Dig for the non-obvious ones — regulatory constraints, calendar/locale quirks, dual-state data models, multi-tenant or contract-based data segregation.

### 2. Architecture

Map the system: language and framework, code organization, routing, state, form handling, API style, data layer, auth, and any backend pieces that affect the frontend. Include the persistence layer if it shapes the frontend (e.g. spatial types, denormalized read models).

### 3. Engineering complexity and ownership

Find the non-trivial work: domain modules (maps/GIS, charts, real-time, canvas/WebGL, rich media), complex forms and validation, performance work, and quality systems (RBAC, i18n, design system, accessibility).

For each, classify my involvement explicitly as one of:

- **Authored** — I created it; it did not exist before
- **Restructured** — it existed; I substantially reorganized or rewrote it
- **Extended** — it existed; I added capability within its existing shape
- **Patched** — I fixed bugs in it without changing its structure
- **Untouched** — it is context for the interview, not my work

Never leave this ambiguous. "Worked on" is not a classification.

### 4. Git forensics

Use history as _evidence_, not proof. `$SRC` below means the real source directory found in phase 0.

**Sweep all branches, not just the current one.** This is the most common failure mode of this whole exercise: the checked-out branch shows a fraction of my work and the resume comes out understated. Do this first:

```bash
git branch -a                                    # enumerate everything
git log --all --oneline --no-merges --author="<me>" | wc -l   # my true total
```

Then per-branch, for any branch with my commits:

```bash
git log --oneline --no-merges --author="<me>" <branch>
git log --author="<me>" --no-merges --name-only --format="--- %h %s" <branch>
```

**Resolve my identity first.** Start from `git config user.email` and `git config user.name`, then check for aliases — people commit from work email, personal email, and bare machine names. Search each variant. Undercounting my own commits is the failure this prevents.

**Normalize other contributors too** before drawing any volume conclusion. One person routinely appears as 3–4 identities (work email, gmail, `DESKTOP-XXX\name`, differently-cased name). Group by person, not by string:

```bash
git log --format="%ae %an" --no-merges -- "$SRC" | sort | uniq -c | sort -rn | head -15
```

**Correct `shortlog` usage.** `git shortlog -sn -n 10` fails with `fatal: bad revision '10'` — in shortlog `-n` means _sort numerically_, not _limit_. `-sn` is already summary + numeric sort. To limit, pipe:

```bash
git shortlog -sn --no-merges -- "$SRC" | head -15
```

**Exclude generated and compiled output from volume counts.** Beyond lockfiles and `dist/`: many repos commit compiled output alongside source (`.ts` → a checked-in `.js`, `.scss` → `.css`, generated clients, `.d.ts`). If so, every commit touches each file twice and apparent volume doubles. Count source only, and note in the output that you did.

**Flag single massive commits** as likely squash merges or initial imports. Ask me to confirm rather than assuming I wrote them.

Avoid repository-wide `git blame`.

### 4.5 Read the written project record before asking me

Check `~/.claude/projects/<mangled-cwd>/memory/` (cwd with `/`→`-`, `:` dropped). Read `MEMORY.md` first — it is an index; follow only the entries that look relevant rather than reading every file.

This is where decisions, rejected alternatives, and defect post-mortems live. Mine it specifically for what code cannot show:

- Why a harder approach was chosen over the obvious one
- What was deliberately NOT done, and why (negative knowledge — the highest-value interview material and the least recoverable from a repo)
- Bugs found, their failure mode, and how they were found
- Ownership boundaries (which teammate owned what)

Three rules, no exceptions:

- **Memory is a lead, not evidence.** Same standing as a subagent report in phase 5. Every claim it suggests must still trace to a commit before it enters `evidence.md`.
- **Memory says "I" about the assistant, not about me.** It describes sessions I directed; it does not establish that I authored the code. Any ownership classification drawn from it starts at **Needs Confirmation** and must be confirmed in phase 6.
- **Prefer the latest state.** Entries marked CORRECTED / SUPERSEDED / WRONG are superseded — do not surface them as current claims. A belief that was later disproved is retrospective material, not a resume bullet.

If no memory directory exists, say so in one line and continue.

### 5. Sanity gate — before you generate anything

Stop and check the evidence against plausibility:

- Does my commit count match how involved I say I was? If I describe months of work and you found a handful of commits, **you have not found all my work** — go back to the branch sweep, check for other identities, check for squashed PRs.
- Is the person with the most commits someone other than me? Then this is not "my project" and no output file may imply otherwise.
- Did a subagent hand you a "resume summary" or "competencies demonstrated" section? **Discard it.** Subagent reports are research input, not evidence — they routinely attribute a whole system's tech surface to whoever asked. Every ownership claim must trace to a commit you personally verified.

### 6. Memory recovery — ask me what code cannot answer

Ask only what phase 4.5 did not already answer — do not make me re-answer what is already written down. Confirming an ownership classification that memory only hinted at is exactly the right use of these questions.

Ask in batches of **3–4 questions per call** (the question tool rejects more than 4 at once). Batch again if needed.

Prioritize questions whose answers change the output:

- For each significant module: did I author it, restructure it, extend it, or patch it?
- Which large or ambiguous commits are genuinely mine?
- Why was a harder approach chosen over the obvious simpler one?
- Which module cost the most time, and what made it expensive?
- The hardest bug or integration I resolved, and how I found it.

Offer the honest/deflationary option as a real choice, not a token one. If I pick a modest framing, respect it in every output file.

### 7. Evidence synthesis

Before writing any output file, consolidate everything gathered in phases 1–6 — including my answers from phase 6 — into a single evidence inventory, and write it to `<output-dir>/<project-name>/evidence.md`. For each significant feature or module, record:

- What exists (one line)
- Who owned it originally, if not me
- My classification (Authored / Restructured / Extended / Patched / Untouched)
- Confidence (High / Medium / Low / Needs Confirmation)
- Supporting commits (hashes or "none — interview evidence only")
- Supporting files (paths)

This file is the single source of truth for every output below. Every ownership claim, confidence label, and resume verb must trace back to an evidence entry. — do not reclassify or re-judge confidence independently per file. If a later output needs a claim that isn't in the inventory yet, add it to the inventory first, then use it from there. This is what keeps the resume, interview, LinkedIn, and career-portal files consistent with each other instead of each one re-interpreting the same evidence slightly differently.

## Generate the outputs

Every output file must derive its ownership claims, confidence labels, and citations from `evidence.md` (phase 7) — not re-derive them from scratch.

Write these into `<output-dir>/<project-name>/`:

- `project-summary` — domain, purpose, problem solved, and a plain statement of my role
- `architecture` — system design, state, routing, API and data patterns
- `business` — workflows, user personas, domain rules (especially the non-obvious ones)
- `interview` — STAR stories, technical Q&A, and the four sections below
- `resume` — space-optimized bullets, evidence-labeled
- `linkedin` — project showcase narrative
- `career-portal.zh-TW.md` — entry tuned for a regional (Taiwan) career profile
- `glossary.md` — domain terms alongside their English tech equivalents

Produce English and Traditional Chinese (zh-TW) versions of the first six (e.g. `resume.en.md`, `resume.zh-TW.md`). Write each language for its own audience — the English is for global recruiters and tech leads, the zh-TW is for the local ecosystem and PM/backend collaboration. Neither is a literal translation of the other. Keep the factual content equivalent across languages, while adapting tone and wording for the intended audience — a claim, confidence label, or "what not to claim" boundary must not appear in one language and not the other.

### The interview file must also include

These come up constantly and are not derivable from code:

1. **What I would do differently** — real retrospective, tied to something concrete in the codebase. A structural weakness I hit, a shortcut I took, or a bug class that better design would have prevented. Senior interviews test this directly.
2. **Why this stack, not the modern alternative** — the honest answer for legacy or enterprise stacks (existing codebase, contract constraints, team skills, migration cost), plus what I would choose greenfield.
3. **Questions I should ask the interviewer** — 4–6, drawn from this project's real tensions (e.g. how spec changes mid-sprint are handled, migration plans off an EOL framework, how they test what has no test suite). Good questions signal domain fluency.
4. **Probing questions I cannot fully answer** — name the parts of the system I did not build, so I can say "I did not own that layer, but here is how it works and here is who did." Being caught bluffing costs more than admitting a boundary.

### Terminology

- Keep a business or government term in Traditional Chinese when that is where it came from, and add English in parentheses on first use — for example, `115年國土署 GIS 規範 (Taiwan National Land Administration GIS Specification)`.
- Keep standard technical terms in English: React Query, Design System, CI/CD, GraphQL, state machine.

### Resume rules

Assume my full resume holds 10–12 projects, so space is tight. This section is canonical: `resume-consolidate.md` (the second-stage command that condenses across every project into paste-ready entries) applies these same two tables rather than restating them — if either table changes, change it here.

| Tier | Bullets | When |
| --- | --- | --- |
| Flagship | 2–3 | Full architecture ownership, long tenure; 1–2 projects max on a resume |
| Standard | 1–2 | Meaningful contribution, not the centerpiece |
| Minor / feature contributor | 1–2 | Feature-level work on a mature system; use 2 only if two genuinely distinct contributions each warrant a line |
| Brief mention | 0 (header only) | Very small scope; header tells the whole story |

State which tier this project is and why, based on the evidence. Bullet count is proportional to ownership depth — never let a feature-contributor project end up with more bullets than a full-ownership project.

**Match the verb to the evidence.** Do not reach for the top tier by default — an indefensible verb is worse than a modest one, because it invites exactly the question that exposes it:

| Evidence                                                   | Verbs                                            |
| ---------------------------------------------------------- | ------------------------------------------------ |
| I created the system or its architecture                   | Architected, Owned, Spearheaded                  |
| I created a module or feature within someone else's system | Authored, Built, Implemented, Delivered          |
| I substantially reorganized existing code                  | Refactored, Restructured, Overhauled, Modernized |
| I added capability to existing code                        | Extended, Integrated, Migrated                   |
| I fixed defects                                            | Resolved, Diagnosed, Hardened                    |

Avoid "assisted with" and "helped build" — they undersell real work. But if the top-tier verbs do not fit, say so plainly rather than stretching one.

Label every claim with evidence strength: `[High Confidence]`, `[Medium Confidence]`, `[Low Confidence]`, or `[Needs Confirmation]`. Apply these in the interview file too, not just the resume — a STAR story built on weak evidence is a liability in the room.

**End the resume file with an explicit "what not to claim" list** — the specific overreaches available on this project and who actually did that work. This is often the most valuable part of the output: it is what stops me over-claiming under interview pressure, when the temptation is highest.
