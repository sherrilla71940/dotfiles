---
description: Reverse-engineer a frontend project to understand it, then generate bilingual resume and interview material backed by evidence.
argument-hint: [output-dir]
---

Reverse-engineer the current project so I can understand how it works, explain it well, and describe my work on it honestly. Teaching me the system matters more than summarizing the code. Resume and interview material is a by-product of that understanding, not the goal.

## Before you start: where do outputs go?

Output directory: `$ARGUMENTS`

If that is empty, ask me for a path and wait for my answer. Do not pick one yourself, and do not write generated files into the repository being analyzed unless I ask for that.

Once you have a path, create `<output-dir>/<project-name>/` and write every generated file there.

## Investigate in phases

Work through these in order. Explain *why* things exist, not just which libraries are present.

1. **Discovery** — What does the project do, who uses it, and what problem does it solve? Read `package.json`, `README`, config files, and route definitions to infer the domain and the main user workflows.

2. **Architecture** — Map the frontend: framework and language, component organization, routing, global and server state, form handling, API style (REST/GraphQL/WebSocket), the client data layer, auth, and any backend-for-frontend pieces that affect the frontend.

3. **Engineering complexity and ownership** — Find the non-trivial work: domain modules (maps/GIS, charts, real-time, canvas/WebGL, rich media), complex forms and validation, performance work (virtualization, code-splitting, memoization, workers), and quality systems (RBAC, i18n, design system, accessibility). For each, say whether I built the foundation or extended something that already existed.

4. **Git forensics** — Use history as *evidence*, not proof. Filter out lockfiles, build output, and generated files so contribution volume is not distorted. Useful commands:
   - `git shortlog -sn --no-merges -n 10 -- src/`
   - `git log --oneline --grep="feat" --grep="refactor" -n 30 -- src/`
   - high-churn files under `src/`, excluding `package-lock`, `yarn`, `pnpm`, generated, and `.d.ts`
   Treat a single massive commit as a likely squash merge or initial import — flag it for me to confirm rather than assuming I wrote all of it. Avoid repository-wide `git blame`.

5. **Memory recovery** — Ask me 3–5 focused questions that code cannot answer: which large commits I actually authored, why a given approach was chosen over a simpler one, which module took the most time and why, and the hardest bug or backend integration I resolved.

## Generate the outputs

Write these files into `<output-dir>/<project-name>/`:

- `project-summary` — domain, purpose, problem solved
- `architecture` — system design, state, routing, API patterns
- `business` — workflows, user personas, domain rules
- `interview` — STAR stories and technical Q&A notes
- `resume` — space-optimized, high-ownership bullets
- `linkedin` — project showcase narrative
- `career-portal.zh-TW.md` — entry tuned for a regional (Taiwan) career profile
- `glossary.md` — domain terms alongside their English tech equivalents

Produce English and Traditional Chinese (zh-TW) versions of the first six (e.g. `resume.en.md`, `resume.zh-TW.md`). Write each language for its own audience — the English is for global recruiters and tech leads, the zh-TW is for the local ecosystem and PM/backend collaboration. Neither is a literal translation of the other.

### Terminology

- Keep a business or government term in Traditional Chinese when that is where it came from, and add English in parentheses on first use — for example, `115年國土署 GIS 規範 (Taiwan National Land Administration GIS Specification)`.
- Keep standard technical terms in English: React Query, Design System, CI/CD, GraphQL, state machine.

### Resume rules

Assume my full resume holds 10–12 projects, so space is tight:

- Flagship projects: 2–3 dense bullets.
- Secondary projects: 1–2 bullets.
- Minor projects: exactly 1 bullet.

Lead with ownership verbs I can defend — Architected, Owned, Spearheaded, Overhauled — not "assisted with" or "helped build". Label every claim with its evidence strength: `[High Confidence]`, `[Medium Confidence]`, `[Low Confidence]`, or `[Needs Confirmation]`. Never inflate ownership past what the git history and code support.
