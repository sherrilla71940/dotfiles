---
description: Orient me to an unfamiliar project by analyzing its purpose, architecture, domain, and my verified involvement history.
argument-hint: [output-dir]
---

# Orient me to this project

Analyze this project and create an engineering knowledge base.

The goal is to understand:

- what this system does
- how it works
- why it exists
- what my role and contributions were

The intended audience is someone who needs to regain context on this project, understand the architecture, and understand important implementation decisions.

Keep everything factual and evidence-based. Do not optimize for polished descriptions or marketing language.

---

## Output location

Output directory: `$ARGUMENTS`

If empty, ask me for a path and wait. Do not choose a location yourself.

Do not write into the repository being analyzed unless explicitly requested.

Create:

```text
{output-dir}/{project-name}/
```

---

## Phase 1 — Understand the project

First identify what kind of project this is.

Look for:

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
- rendering model
- build tooling
- deployment approach
- real source directories

Do not assume React, SPA, npm, or REST APIs.

---

## Phase 2 — Understand the business context

Document:

- What does the system do?
- Who uses it?
- What problem does it solve?
- What workflows does it support?
- What are the important business rules?
- What external systems exist?
- What regulations or constraints affect the design?

For enterprise/government systems, pay attention to:

- domain concepts
- compliance requirements
- approval flows
- data lifecycle
- terminology

Explain why the software exists, not only how it is built.

---

## Phase 3 — Understand the architecture

Document:

- major directories
- application structure
- frontend architecture
- backend interaction
- routing
- state management
- forms and validation
- authentication/authorization
- API communication
- data flow
- persistence layer
- deployment/build process

For each major area explain:

- what it does
- why it exists
- how it connects to other parts

---

## Phase 4 — Investigate my involvement

Use Git history as evidence.

Do not assume ownership from:

- current files
- commit messages alone
- code presence

Verify through history and diffs.

### Git investigation

Identify my Git identities:

```bash
git config user.email
git config user.name
```

Check for aliases:

- work email
- personal email
- alternate usernames
- machine identities

Normalize identities before judging contribution volume.

Inspect all branches:

```bash
git branch -a
```

Search commits:

```bash
git log --all --oneline --no-merges --author="{identity}"
```

Inspect relevant changes:

```bash
git log --author="{identity}" --no-merges --name-only --format="--- %h %s" {branch}
```

Group changes by feature or area, not individual commits.

Ignore misleading volume from:

- generated files
- compiled output
- build artifacts
- large imports
- squash merges

### Validate ownership

Use diffs to confirm important claims.

Commit messages describe intent, not necessarily actual behavior.

Do not claim specific fixes, performance improvements, security improvements, or bug behavior unless the code supports it.

### Ownership classification

Every meaningful area must be classified:

- **Authored** — created by me.
- **Restructured** — existing code significantly reorganized or rewritten by me.
- **Extended** — existing capability expanded by me.
- **Patched** — bug fix or maintenance without structural change.
- **Untouched** — exists for context only.

Do not use vague terms like:

- worked on
- helped with
- contributed to

### Confidence

Every ownership statement needs one of:

- High Confidence
- Medium Confidence
- Low Confidence
- Needs Confirmation

---

## Phase 5 — Identify meaningful engineering work

Identify areas worth preserving because they represent important engineering effort.

Look for:

- difficult debugging
- complex integrations
- architecture decisions
- reusable components
- migrations
- performance improvements
- security improvements
- accessibility improvements
- testing improvements
- automation
- difficult domain rules
- workflow improvements
- reliability improvements

For each item record:

- what exists
- technical problem
- implementation approach
- engineering tradeoffs
- my involvement
- evidence
- outcome or value when supported by evidence
- why it is significant
- confidence

Do not exaggerate impact.

---

## Phase 6 — Optional context

If Claude project memory exists, it may be used as additional context.

Rules:

- memory is not evidence
- do not use it alone to prove ownership
- prefer repository and Git evidence
- ignore outdated information

---

## Phase 7 — Ask for missing context

Only ask questions that cannot be determined from:

- code
- Git history
- documentation
- configuration

Prioritize questions that change understanding:

- Did I author or extend this?
- Why was this approach chosen?
- What problem was this solving?
- Which area required the most effort?

Ask questions in small batches.

---

## Phase 8 — Generate files

Create the following files.

### `overview.md`

Include:

- project purpose
- users
- problem solved
- workflows
- technology overview
- my overall involvement

### `architecture.md`

Include:

- directory structure
- system components
- data flow
- frontend/backend relationship
- APIs
- state
- authentication
- important technical decisions

### `domain.md`

Include:

- business concepts
- terminology
- rules
- workflows
- external dependencies

### `contributions.md`

For each meaningful contribution include:

- Feature/area
- What exists
- My classification
- Confidence
- Supporting commits
- Supporting files
- Technical details
- Why it matters
- Unknowns

### `evidence.md`

This is the source of truth.

Every contribution must include:

- Feature/area
- Ownership classification
- Confidence
- Supporting commits
- Supporting files
- Evidence
- Notes

Future analysis should use this file rather than repeating investigation.

---

## Quality rules

- Accuracy over completeness.
- Evidence over assumptions.
- Preserve ownership boundaries.
- Capture business context.
- Explain systems, not just files.
- Do not invent metrics, scale, or impact.
- A modest claim supported by evidence is better than an impressive unsupported claim.

---

## Confidentiality

Treat all repository information as confidential.

When generating documentation:

- Do not include secrets, credentials, tokens, API keys, private URLs, or personal data.
- Do not copy large sections of source code.
- Do not include client data, contract details, or unpublished requirements.
- Do not expose internal system names or identifiers unless necessary for understanding.
- Avoid documenting client-specific business processes beyond what is needed to understand the system.
- Prefer describing general concepts, architecture, engineering decisions, and technical challenges rather than proprietary implementation details.
- When describing business workflows, use a generalized description unless the specific detail is publicly available or necessary.
