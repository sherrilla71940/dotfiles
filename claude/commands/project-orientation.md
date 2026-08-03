---
description: Generate a project orientation brief — quick high-level overview or comprehensive onboarding & architecture knowledge base.
argument-hint: [quick | comprehensive] [output-dir]
---

# Project Orientation

## Mode selection

Parse `$ARGUMENTS`:

- If the first token is `quick`, run **Quick mode** only and stop.
- Otherwise run **Comprehensive mode** (default).
- Any remaining argument is treated as `{output-dir}`.

### Quick mode

Give an overview of this codebase: architecture, key directories, and how the pieces connect.

Do not write any files.

### Comprehensive mode

Continue with the instructions below.

---

## Goals

Analyze this repository to create a concise, factual engineering knowledge base to accelerate onboarding and reverse engineering.

Understand:

- What this system does and why it exists
- How it is structured at a high level
- Critical architectural and engineering decisions that still constrain work today
- Key code locations, hot spots, and domain logic

Do not create exhaustive API or code-level internal documentation. Focus on high-leverage architectural clarity.

---

## Output location

Write output to:

```
{output-dir}/{project-name}/
```

Where:

- `{output-dir}` — remaining argument after mode (if provided); otherwise use `C:\Users\Aaron.Sherrill\Documents\work\summaries`
- `{project-name}` — repository root folder name

Create the directory if it does not exist. **Never write into the analyzed repository.**

---

## Phase 1 — Project identity & stack discovery

Identify the core technologies and runtime environment.

Inspect common manifest files (e.g., `package.json`, `*.csproj`, `pom.xml`, `go.mod`, `Gemfile`, `requirements.txt`).

Determine:

- Primary languages & frameworks
- Application type (e.g., CLI, monolith, microservice, event consumer)
- Rendering model / API style
- Build tooling & deployment targets
- Entry points and core source directories

Avoid assuming conventions without codebase evidence.

---

## Phase 2 — Domain & business logic mapping

Understand why this software exists and how business rules map to code.

Document:

- **Core Problem & Purpose**: What business or operational problem does this solve?
- **Key Workflows**: Primary user journeys or system processing pipelines
- **Domain Terminology**: Essential concepts, data models, or ubiquitous language used in the code
- **External Dependencies**: Third-party APIs, databases, message brokers, or legacy integrations
- **System Constraints**: Regulatory, performance, or operational constraints affecting design

Focus on structural understanding without copying confidential/proprietary data.

---

## Phase 3 — Architecture & data flow

Construct a high-level system overview focusing on key components and interaction models.

Document:

- Major System Boundaries (frontend, backend, background workers, storage)
- Data Flow & Persistence: How data enters, transforms, and persists
- Authentication & Authorization mechanisms
- Key Design Patterns & Technical Decisions still visible in the code (e.g., event-driven, CQRS, repository pattern)

**Non-Goal**: Do not document every individual route, controller, file, or implementation detail.

---

## Phase 4 — Codebase topology & hot spots

Use Git history to locate complexity and risk.

### Identify Key Modules & Hot Spots

Run Git log checks to identify high-churn areas (files changed frequently or involved in complex fixes):

```bash
git log --format=format: --name-only | sort | uniq -c | sort -n -r | head -n 20
```

Group core technical areas by:

- **Active / Maintained** – core logic with ongoing changes
- **Legacy / High-risk** – frequent patches, complex history
- **Stable utility / Shared foundations** – low churn, broadly depended on

---

## Phase 5 — Current constraints, debt & tradeoffs

Identify areas where the current implementation carries non-obvious constraints, technical debt, or design tradeoffs that a new developer must understand before making changes.

For each key area capture:

- **Module / Subsystem**
- **Current Context**: Constraints, complex integrations, or non-obvious logic that still affects work today
- **Technical Approach**: How the problem is currently solved in code
- **Tradeoffs & Pitfalls**: Edge cases, debt, or performance caveats that will bite during modifications

Base summaries strictly on code structures, inline comments, ADRs, or Git history. Do not speculate about original intent.

---

## Phase 6 — Clarification & gaps

If critical system behaviors cannot be deduced from code or configuration, compile a focused list of questions for the current team/maintainers.

Examples:

- Is [Module X] actively used in production or deprecated?
- How are environment variables/secrets managed across environments?
- Are there undocumented operational constraints around [component]?

Ask questions in small, digestible batches.

---

## Phase 7 — File generation

Generate the following output files:

```
{project-name}/
├── system-overview.md
├── architecture-and-decisions.md
└── developer-onboarding.md
```

### system-overview.md

High-level context for new team members.

- Project Purpose & User Personas
- Domain Dictionary (key domain concepts mapped to code folders)
- Tech Stack & Tooling Summary
- Primary Workflows

### architecture-and-decisions.md

Technical blueprint for reverse engineering the codebase.

- High-Level Component Architecture
- Data Flow & Storage Strategy
- Key Architectural Decisions & Tradeoffs (that still matter)
- Known Technical Debt & High-Risk Areas

### developer-onboarding.md

Practical guide for developer productivity on this repo.

- Codebase Topology (where core logic vs. entry points live)
- Common Development Tasks & Hot Spots
- Open Questions for Team Leads

---

## Quality & Security Rules

- **Fact Over Assumption**: Only state what can be proven by code or Git history.
- **Confidentiality**: Exclude tokens, credentials, production endpoints, customer PII, or internal secrets.
- **Scannability**: Prefer bulleted summaries, tables, and short diagrams over text walls.
