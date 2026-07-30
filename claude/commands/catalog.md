---
description: Build an evidence-based engineering knowledge base for an unfamiliar project, focusing on architecture, domain understanding, and verified personal contributions.
argument-hint: [output-dir]
model: claude-sonnet-5
---

# Build project knowledge base

Analyze this project and create a concise engineering knowledge base.

The goal is to understand:

- what this system does
- why it exists
- how it works at a high level
- what engineering decisions matter
- what my verified contributions were

The intended use:

- regain context on past projects
- prepare resume content
- prepare technical interviews
- accurately explain engineering decisions

Do not create exhaustive internal documentation.

Prioritize:

- important engineering decisions
- meaningful contributions
- interview-relevant knowledge
- evidence-backed claims

Keep everything factual.

Do not optimize for marketing language.

---

## Output location

Write output to:

```text
{output-dir}/{project-name}/
```

Where:

- `{output-dir}` — `$ARGUMENTS` if provided; otherwise use `C:\Users\Aaron.Sherrill\Documents\work\summaries`
- `{project-name}` — repository root folder name

Create the directory if it does not exist.

Never write into the analyzed repository unless explicitly requested.

---

## Phase 1 — Understand the project

Identify the project type.

Check common project files:

- `package.json`
- `*.csproj` / `*.sln`
- `pom.xml`
- `go.mod`
- `Gemfile`
- `requirements.txt`
- `composer.json`

Determine:

- languages
- frameworks
- application type
- rendering model
- build tooling
- deployment approach
- important source directories

Do not assume:

- React
- SPA
- npm
- REST APIs

Only document details that help understand the system.

---

## Phase 2 — Understand purpose and domain

Understand why the software exists.

Document:

- What problem does the system solve?
- Who uses it?
- What are the main workflows?
- What domain concepts matter?
- What external systems exist?
- What constraints affect design?

For enterprise/government systems, pay attention to:

- regulations
- approval processes
- important business rules
- domain terminology

Avoid copying confidential business details.

Focus on general understanding.

---

## Phase 3 — Understand architecture

Create a high-level architecture overview.

Include only:

- major system components
- frontend/backend relationship
- data flow
- authentication approach
- API communication style
- persistence approach
- important technical decisions

Do not document:

- every folder
- every component
- every endpoint
- every service
- every implementation detail

Limit architecture documentation to what is useful for:

- understanding the system
- explaining design decisions
- preparing interviews

---

## Phase 4 — Investigate my involvement

Use Git history as evidence.

Do not assume ownership from:

- current files
- code presence
- commit messages alone

Verify through:

- commit history
- diffs
- changed files

### Identify Git identities

Check:

```bash
git config user.email
git config user.name
```

Look for:

- alternate emails
- usernames
- work/personal identities

Normalize identities before evaluating contribution.

### Find meaningful contributions

Search:

```bash
git log --all --oneline --no-merges --author="{identity}"
```

Inspect meaningful changes only.

Prioritize:

- feature development
- architecture changes
- difficult debugging
- integrations
- migrations
- validation logic
- reusable components
- reliability improvements
- accessibility improvements
- security improvements

Ignore:

- generated files
- build output
- dependency updates
- formatting-only commits
- large imports

Group changes by feature or engineering area.

Do not list every commit.

### Ownership classification

Every meaningful contribution must be classified:

- **Authored** — created by me
- **Extended** — expanded existing functionality
- **Restructured** — significantly reorganized existing code
- **Patched** — bug fix or maintenance change
- **Untouched** — exists only for context

Do not use vague terms:

- worked on
- helped with
- contributed to

### Confidence level

Every ownership claim requires:

- High Confidence
- Medium Confidence
- Low Confidence
- Needs Confirmation

---

## Phase 5 — Identify interview-worthy engineering work

Find work worth remembering.

Prioritize:

- difficult technical problems
- important design decisions
- legacy constraints
- complex integrations
- domain-specific logic
- debugging challenges
- reusable solutions

For each item capture:

- Problem
- Existing situation
- My role
- Technical approach
- Tradeoffs
- Evidence
- Why it matters

Only include outcomes when supported by evidence.

Do not invent:

- metrics
- scale
- performance improvements
- business impact

---

## Phase 6 — Optional memory context

If Claude project memory exists, use it only as additional context.

Rules:

- memory is not evidence
- do not use memory alone to prove ownership
- prioritize repository and Git evidence
- ignore outdated information

---

## Phase 7 — Ask for missing context

Only ask questions that cannot be determined from:

- code
- Git history
- documentation
- configuration

Ask only questions that materially improve understanding.

Examples:

- Why was this approach chosen?
- Was this feature primarily yours?
- What was the hardest technical challenge?
- What tradeoff influenced this decision?

Ask questions in small batches.

---

## Phase 8 — Generate files

Create:

```text
{project-name}/
├── overview.md
├── contributions.md
└── evidence.md
```

### `overview.md`

Purpose: help me quickly understand the project.

Include:

- **Project Purpose** — what the system does, who uses it, why it exists
- **Domain Context** — important concepts, important workflows, relevant constraints
- **Technology Overview** — frontend technologies, backend technologies, database/storage, deployment approach, important integrations
- **Architecture Summary** (keep high-level) — major components, system relationships, data flow, important technical decisions

Do not include exhaustive implementation details. Keep this concise.

### `contributions.md`

Purpose: create interview and resume-ready engineering stories.

For each meaningful contribution include:

- Feature / Area
- Ownership — classification: Authored / Extended / Restructured / Patched
- Confidence: High / Medium / Low / Needs Confirmation
- Problem — what problem existed?
- My Role — what did I actually do?
- Technical Approach — how was it implemented?
- Tradeoffs — what decisions or constraints affected the solution?
- Why It Matters — why is this worth remembering?
- Evidence — reference the related section in `evidence.md`

Do not include unsupported impact claims.

### `evidence.md`

Purpose: be the source of truth.

Keep this factual and concise. For each contribution include:

- Feature / Area
- Classification
- Confidence
- Supporting commits
- Supporting files
- Relevant notes

Only include evidence needed to verify ownership. Do not repeat full explanations.

Future analysis should use this file instead of repeating Git investigation.

---

## Quality rules

- Accuracy over completeness.
- Evidence over assumptions.
- Preserve ownership boundaries.
- Avoid confidential details.
- Prefer useful summaries over exhaustive documentation.
- A small supported claim is better than an impressive unsupported claim.

---

## Confidentiality

Treat repository information as confidential.

Do not include:

- secrets
- credentials
- tokens
- API keys
- private URLs
- customer data
- contract details
- unpublished requirements

Do not copy source code.

Do not expose internal identifiers unless necessary.

Prefer describing architecture, engineering challenges, technical decisions, and general workflows rather than proprietary implementation details.
