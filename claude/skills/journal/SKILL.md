---
name: journal
description: "Personal continuity journal for major refactors — a cross-session pickup point the user and Claude both read to resume with full context. Not a team artifact. /journal read to load context; /journal write [topic] to append; /journal list to see entry titles."
argument-hint: "read [focus] — load context | write [topic] — append an entry | list — show entry titles"
user-invocable: true
---

# Project Journal Skill

## What this is

A **personal continuity journal** for major refactors and architecture restructures on existing projects. The **user** and **Claude** both write to it and read from it, so either side can **pick up where the last session left off** with the full reasoning intact — the decisions made, what was corrected, what architecture was discovered, and what's still open.

It is **not a team artifact**. It lives in personal storage outside the project repo, so it is a continuity aid between the user and Claude across sessions — not a channel for communicating to teammates. Durable decisions that a *team* needs belong in the project repo (e.g. an ADR or in-repo doc), not here.

The point: on a big refactor spanning many sessions (and possibly days apart), context is easy to lose. Git shows *what* changed but not *why*; memory holds current facts but discards the reasoning path. The journal is the one place where the user and Claude can reload the story of the work and continue without re-deriving or relitigating settled decisions.

It is read at the **start** of a refactor session to load context, and written at the **end** to record what happened.

## When it's worth it (and when to skip)

The value is narrow and real. It pays off when **all** of these hold; if they don't, skip it and lean on commits + tickets.

| ✅ Worth it when… | ❌ Skip it when… |
| --- | --- |
| Long, multi-session refactor or migration | One-off fix or a task you finish in one sitting |
| A lot of the *why* lives **off-git** — PM/BE calls, spec docs, verbal decisions | Everything is already captured in commits / tickets |
| **AI-assisted** work where the assistant loses context between sessions | You have strong ADR / PR / ticket discipline that already covers it |
| You resume days apart and would otherwise re-derive context | Routine or purely mechanical changes |

**Sweet-spot pattern:** a multi-week, AI-assisted refactor where the source of truth keeps shifting — a spec doc that gets revised, plus PM/stakeholder clarifications you copy-paste in from chat, email, or a call summary. None of that lands in a commit, and it can't (it's not code — it's context, and it changes mid-project). Without somewhere to persist it, every session either re-asks the same questions or silently drifts when the spec updates. The journal is where that pasted context and its revision history lives, so a session days later still knows which version of the requirement is current and why it changed.

**Not worth it:** a typical CRUD feature sprint finished in a day — the commit messages and ticket say everything; a journal would just be ceremony.

## Quick reference

| When | User types | What happens |
| --- | --- | --- |
| **See what's recorded** | `/journal list` | Claude prints just the entry titles (date — topic), newest first — a table of contents, no summarizing. Answers "what are the N entries?" |
| **Start of session** | `/journal read` | Claude reads the whole journal and summarizes all still-active context: decisions in effect, open BLOCKED/DEFERRED items, architecture notes, prior corrections. |
| **Start — but only one thread** | `/journal read <focus>` | Same read, but Claude surfaces **only** entries/sections relevant to `<focus>` (e.g. `/journal read 115 spec property renames`) and skips the rest. |
| **During the session** | *(nothing)* | Just work — decisions, PM/BE clarifications, discoveries. |
| **End of session** | `/journal write` | Claude writes a structured entry (infers the topic) and commits it. |
| **End — control the label** | `/journal write <topic>` | Same, but uses your `<topic>` as the heading + commit subject. |

Actions take an explicit verb (`read` / `write` / `list`). A bare `/journal` with no verb does **not** act — Claude asks which you meant, so a write (which commits) never fires by accident.

## What this is NOT — how it differs from memory

Memory and the journal look similar (both capture "why") but do opposite jobs:

| | Memory | Journal |
| --- | --- | --- |
| **Loaded** | Automatically, every session | Only when you run `/journal read` |
| **Shape** | One fact per file, deduplicated, overwritten in place | Append-only, timestamped, chronological |
| **Holds** | *Current truth* — what is true now | *Narrative* — how we got here, including what was wrong before |
| **On change** | Old fact is overwritten/deleted; history is discarded | A `Correction:` entry is added; the old reasoning stays visible |

**Memory answers "what is true now?" The journal answers "how did we get here, and what did we already try that was wrong?"**

The journal is where correction chains survive — e.g. "we hardcoded X → BE said don't touch → reverted → moved to FE." Memory keeps only the endpoint of that chain; the journal keeps the path. That path is what lets a later session avoid relitigating a settled question.

## Commands

- `/journal read [focus]` — Mode A. Load prior context. Optional free-text `focus` narrows the summary to one thread.
- `/journal write [topic]` — Mode B. Append a new entry and commit. Optional `topic` labels it; Claude infers one if omitted.
- `/journal list` — Mode C. Print entry titles only (date — topic), newest first. A quick index; no summarizing, no reconciliation.
- `/journal` (no verb) — ambiguous; do **not** act. Ask the user whether they meant `read`, `write`, or `list`. This guard exists because `write` commits — it must never fire by accident.

### Avoiding drift between the two

Because both can hold a "why," they can fall out of sync. One rule prevents that:

**Memory is the single authority for any *current fact*. The journal records the *narrative* and never restates a fact as if it owns it.**

- Do **not** copy a memory fact wholesale into a journal entry. Reference it briefly for narrative continuity, but the authoritative copy stays in memory.
- When a fact later changes, update **memory** (the authority). In the journal, do **not** go back and edit the old entry — add a new `Correction:` line pointing to what changed. The old entry stays as the historical record; memory reflects the new truth.
- **When correcting a fact in one memory file, grep all memory files for the same claim/keyword before finishing.** Memory is not one file — a project typically has several (`feedback-*`, `project-*`, `reference-*`). A corrected rule can leave a stale, contradicting copy in a different file that nothing else points at. Search (`grep -rn "<keyword>"` across the project's memory folder) and fix every instance found, not just the one you started with.
- Net effect: a fact lives in exactly one place (memory); the journal holds only the story of how it got there and what was tried. No double-maintenance, no drift.

## When to use

- **Major refactors / architecture restructures on existing projects** — not trivial fixes or one-off changes
- Use `/journal read` at the start, before making changes, to load prior reasoning
- Use `/journal write` at the end, when the session resolved a non-obvious decision, corrected a wrong assumption, or discovered structure worth carrying forward

### The `[topic]` argument (optional)

`[topic]` is a short kebab-case tag naming the theme of the entry — e.g. `spec-v2-migration`, `field-rename`, `auth-restructure`. It becomes the entry's heading and the commit message subject, so entries are easy to scan and find later.

- **Optional.** If the user omits it (`/journal write` with no topic), Claude infers a concise topic from what the session was about and states the chosen topic in the report-back.
- The user only needs to supply one when they want to control the label — otherwise let Claude pick.

## Example workflow (a multi-session refactor)

This is how a big refactor — like a spec migration spanning weeks, where requirements evolve via pasted PM/stakeholder notes — flows across sessions:

1. **Start of session** → user runs `/journal read`. Claude loads the journal and summarizes: decisions still in effect, open BLOCKED/DEFERRED items, architecture notes, and any prior corrections. Both sides start aligned. (On the very first session there's nothing to read yet — skip.)
2. **Do the work** → make changes, hit decisions, get clarifications from PM/BE, discover structure.
3. **End of session** → user runs `/journal write` (or `/journal write <topic>` to control the label). Claude writes a structured entry capturing what was decided, what was corrected, what was learned, and what's still pending — then commits it.
4. **Next session (hours or days later)** → back to step 1. `/journal read` replays the accumulated story so neither the user nor Claude has to reconstruct it from memory or git.

`read` and `write` are always explicit. Bare `/journal` never acts on its own — Claude asks which you meant — so an end-of-session `write` (which commits) can't fire by accident at the start.

## Proactive write offers (the real "auto-draft")

There is deliberately **no background auto-writer**, because one cannot work: at session end no model is running, and the journal's value is the *why*, which cannot be reconstructed from git diffs after the fact. The *why* must be captured **during** the session, by Claude.

So the automation is behavioral, injected by the SessionStart hook:

- When a journal exists for the project, the hook tells Claude (in the session context) to **proactively offer `/journal write`** when the session wraps up journal-worthy work — a resolved decision, a correction, a discovered structure — while the reasoning is still fresh. Especially offer when the user signals they're done ("that's all", "done for today").
- Offer; do not auto-write. The user confirms, and can adjust the topic/content.
- Do **not** offer for trivial or purely mechanical sessions — that just creates noise. The bar is the same as `## When to use`.

The hook is also **drift-aware**: it compares the journal's newest entry date to the code repo's commits and escalates its reminder to ⚠️ when the journal has fallen behind (work happened without a `/journal write`). That, plus the read-mode reconciliation step, is how drift is surfaced without a background writer.

## Setup and location

The journal root is not hardcoded — it is stored in a config file and remembered across sessions:

```
~/.claude/skills/journal/config.json
```

Config shape:
```json
{ "journalRoot": "C:\\Users\\Aaron.Sherrill\\Documents\\personal\\project-logs" }
```

**Resolving the journal path (do this at the start of every invocation):**

1. Read `~/.claude/skills/journal/config.json`.
2. If it exists and `journalRoot` points to a directory that exists → use it. Skip to normal Read/Write flow.
3. If it is missing, OR `journalRoot` does not exist on disk → run **First-time setup** below.

Once resolved, the per-project journal lives at:
```
<journalRoot>\<project>\logs\project-journal.md
```

`<project>` is the working directory's repo name (last segment of `git rev-parse --show-toplevel`, or cwd name if not a git repo). E.g. `c:\...\work\my-app` → `my-app`. Create `<journalRoot>\<project>\logs\` automatically if missing — do not ask again once setup is done.

### Two sibling folders — `archive/` (frozen) and `references/<topic>/` (active)

A project can accumulate detail too granular to inline in journal entries — per-field change tables, verification how-tos, meeting minutes, exported data, diagrams. Two folders hold this, with **different lifecycles**, both as siblings of `logs/`:

```
<journalRoot>\<project>\
├── logs\
│   └── project-journal.md
├── archive\                    ← FROZEN — historical, pre-journal docs. Never written to again.
│   └── README.md               ← index of what's inside and why
└── references\                 ← ACTIVE — one folder per refactor/topic, grows over time
    └── <topic>\
        ├── README.md           ← entry point: what this covers, why it exists
        └── (anything else)     ← other .md files, data exports, diagrams, subfolders — no fixed shape
```

**`archive/`** is a one-time historical relic (e.g. from a pre-journal era of this project). Never write to it. Only read it.

**Before filing anything into `archive/` (or leaving it there during a reorg), verify the underlying work is actually finished** — check the journal for any BLOCKED/DEFERRED pending item that references the same topic/fields/files. If an open pending item still depends on this content, it belongs in `references/<topic>/`, not `archive/`, no matter how old the file is. "Old" and "done" are not the same thing — a doc can predate the journal and still describe work that hasn't landed yet.

**`references/<topic>/`** is where NEW deep-dive detail goes, created *as part of doing a refactor*, going forward. Each topic gets its own folder (not a flat file) so it can hold whatever the work produced — a full field-mapping table, a verification methodology doc, a screenshot, exported data — without being forced into one file. `README.md` is the required entry point per topic; everything else inside is unconstrained.

**Copy in primary source documents too, not just your own analysis.** If a spec file, Excel, Word doc, PDF, or exported data is being actively referenced for ongoing work — not just a markdown summary *about* it — copy the actual file into the relevant `references/<topic>/` folder so the topic is self-contained. Don't leave the real source sitting only in an unrelated personal working folder while the topic folder holds nothing but notes referencing it by path — a future reader (or session) should find everything needed, source and analysis together, in one place. Note in the `README.md` when a file was copied in and from where.

**Discovery is structural, not a manual per-project pointer.** At the start of both Mode A (Read) and Mode C (List), check whether `<journalRoot>\<project>\archive\` and `<journalRoot>\<project>\references\` exist. If either does:
- Read `archive/README.md` and/or list the topic folders under `references/` (read each topic's `README.md`).
- **Produce a "reference map" for the user — not just that folders exist, but what each is FOR and when to consult it.** Each topic README carries a `**Consult this when:**` line for exactly this; surface it. Example map:
  > - `references/115yr-field-mapping/` — **consult when** verifying field lists / column validation against the spec (holds the Excel source of truth + full per-layer table).
  > - `references/fe-be-field-sync/` — **consult when** syncing FE↔BE JSON names after Jacky's commits (holds the 欄位VS對照 preview).
  > - `archive/` — historical, pre-journal shipped work.
- If the user's question maps to one of these, open that reference directly (reading binary files per "Reading reference files" above) and cite what's found — do not guess or claim detail doesn't exist without checking.

This map is the point of the whole system: the journal (`logs/`) is the index that tells you *where things are and what to look at when* — `references/` holds the depth, and the journal + each README route you to the right one.

If neither folder exists, say nothing about them — most projects won't have either yet.

**Creating a `references/<topic>/` folder (judgment call, always offer first):** When a session's work produces detail too extensive to inline in a journal entry (full tables, multi-file mappings, methodology writeups), offer to create `references/<topic>/README.md` (plus whatever other files fit) rather than doing it silently — same bar and pattern as offering `/journal write` itself. If the user agrees, write the files, then link it from the journal entry via the `**Reference:**` field (see entry format in Mode B). Do not create one for every entry — only when the detail genuinely doesn't fit in the journal's structured format.

Every `references/<topic>/README.md` should include, near the top:
- a `**Consult this when:**` line — the trigger/situation that should send a future session here (this is what the read-mode "reference map" surfaces);
- a list of the files inside with a one-line purpose each;
- for any binary file (`.xlsx`/`.docx`/etc.), the one-line command to read it (see "Reading reference files").

**Whenever moving a file into, out of, or between `archive/` and `references/<topic>/`, grep the moved file's own content and any sibling index (`README.md` in either folder) for relative-path language or "this folder" phrasing that assumed the old location.** Fix every stale reference in the same operation — a move is not complete until cross-references are updated, not just the file's physical location.

### Reading reference files (any format — this is what makes the pointers usable)

A reference is only useful if it can actually be opened. When the journal or a `README.md` points at a file, read it — do not claim you can't without trying. By format:

- **Markdown / txt / csv / json / code** → the Read tool directly.
- **PDF** → the Read tool directly (it renders pages; use the `pages` param on large files).
- **Images / screenshots (PNG, JPG)** → the Read tool directly (it views them).
- **Excel `.xlsx`** → the Read tool CANNOT open these. Use Python `openpyxl`. **Always set `PYTHONIOENCODING=utf-8`** or non-ASCII (CJK) text crashes on Windows:
  ```bash
  PYTHONIOENCODING=utf-8 python -c "
  import openpyxl
  wb = openpyxl.load_workbook('FILE.xlsx', read_only=True, data_only=True)
  print(wb.sheetnames)
  ws = wb[wb.sheetnames[0]]
  for row in ws.iter_rows(values_only=True):
      print([c for c in row if c is not None])
  "
  ```
- **Word `.docx`** → also NOT readable by the Read tool. Use Python `python-docx`:
  ```bash
  PYTHONIOENCODING=utf-8 python -c "
  import docx
  d = docx.Document('FILE.docx')
  for p in d.paragraphs:
      if p.text.strip(): print(p.text)
  for t in d.tables:
      for r in t.rows: print([c.text.strip() for c in r.cells])
  "
  ```
- **Fallback** if `openpyxl` / `python-docx` are missing: both formats are ZIP archives — `unzip -p FILE.xlsx xl/worksheets/sheet1.xml` or `unzip -p FILE.docx word/document.xml` and parse the XML. Try `pip install openpyxl python-docx` first.

If a `references/<topic>/` folder holds a binary file, its `README.md` should note the one-liner for reading it (so a session that lands on the folder without this skill loaded still knows how).

### First-time setup

Only runs when no valid config exists. Ask the user, then persist the answer so it is never asked again:

1. **Ask for the base directory** (free text) — e.g. the user answers `C:\Users\Aaron.Sherrill\Documents\personal\`. Append `project-logs` to it: `journalRoot = <answer>\project-logs`.
2. **Ask whether to `git init`** the `journalRoot` as its own repo (recommended, so journals + test files are versioned separately from project repos).
3. Create `<journalRoot>` if it does not exist. If the user chose git, run `git init` there.
4. Write `journalRoot` to `~/.claude/skills/journal/config.json`.
5. Confirm the resolved location back to the user, then continue with the requested Read/Write action.

If `config.json` exists but its `journalRoot` directory is gone (e.g. moved machines), re-run this setup rather than failing.

## Language rule

Write in English. If the project's technical terms are in another language — field/table/entity names, spec document titles, directive or ticket numbers — quote them as-is; do not translate or anglicize them. These are code literals and spec identifiers, not descriptions, and a translation makes them un-searchable against the actual codebase or documents.

**When citing an external document (a spec file, DOCX, Excel, ticket) inside a journal entry or a `references/<topic>/` file, always name the exact file — including any version-distinguishing suffix (date, version number).** Never write a generic placeholder like "the spec," "the docx," or "per the DOCX" more than once without the concrete filename nearby — a project can accumulate multiple versions of the same-titled document over time, and "the docx" becomes ambiguous the moment a second version exists. If the version being cited might not match the project's current confirmed source of truth (check memory/journal for a "source of truth" fact), flag that explicitly rather than silently assuming they match.

---

## Mode A — Read (`/journal read` or `/journal read <focus>`)

**When:** At the start of a refactor session, before making changes.

Any argument after `read` is an optional **focus** — a free-text description of the thread the user cares about (e.g. `read 115 spec property renames`). It is NOT a fixed tag; match it loosely against entry topics and content.

**Steps:**

1. Resolve the journal root from config (run First-time setup if needed), then determine project name and journal path (see Setup and location)
2. If the file does not exist, say so and stop — no prior context exists
3. Read the full journal (always read the whole file — it is one file; focus only narrows the *output*, not the read). Also check for sibling `archive\` and `references\` folders (see "Two sibling folders" above); read `archive/README.md` if present, and list `references/<topic>/` folders (reading each topic's `README.md` for a one-line description).
4. **Drift check (offer a catch-up, do not block).** Take the newest entry's date. In the *code* repo (cwd), run `git log --since=<that date> --oneline` and check for uncommitted changes. If there are commits/changes since the last entry, the journal is likely behind. Tell the user plainly **and explain the trade-off so they can decide**, e.g.:

   > The journal's newest entry is `<date>`, but there have been N commit(s) in the code since — so it's probably missing recent work. Two options:
   > - **`/journal write` a catch-up now** — worth it *only if you still remember the reasoning* behind those changes. The journal's whole value is the *why*; if I write it now while it's fresh in your head, it's real context. 
   > - **Skip it** — if the reasoning is already gone, a catch-up reconstructed from git diffs alone would be hollow (git shows *what* changed, not *why*), so it's not worth faking. I'll just proceed and reconcile the pending items against current code.
   > Which would you like?

   Then continue regardless of their choice — never withhold the read.
5. Summarize to the user:
   - **No focus given** → summarize all still-active context: decisions in effect, open BLOCKED/DEFERRED items, architecture notes, corrections
   - **Focus given** → surface only entries/sections relevant to the focus term; note briefly how many other entries were skipped so the user knows there's more
6. Explicitly flag any SUPERSEDED entries so they are not acted on
7. If `archive/` and/or `references/<topic>/` folders were found in step 3, mention them briefly (one line each) so the user knows more granular detail exists
8. **Reconcile pending items against current state.** Treat BLOCKED / DEFERRED / pending items as *point-in-time*, not live truth — work may have happened in sessions where `/journal write` was skipped. For any pending item that would drive action now, quickly verify against current code/git (grep, `git log`, read the file) before presenting it as still-open, and flag any that look already-done or stale. This is the same check that caught the stale `用戶接管` "NEEDS FIX" — it defends against journal-vs-reality drift. If a pending item turns out done, tell the user (they may then want `/journal write` to record the catch-up).

---

## Mode C — List (`/journal list`)

**When:** The user wants to see *what* is recorded without a full summary — e.g. after the SessionStart reminder says "N entries."

**Steps:**

1. Resolve the journal root from config, then determine project name and journal path (see Setup and location)
2. If the file does not exist, say so and stop
3. Extract every heading matching `^## \d{4}-\d{2}-\d{2} — <topic>` and print them as a numbered index, newest first, e.g.:
   ```
   my-app journal — 3 entries
   1. 2026-07-16 — display-path-pending
   2. 2026-07-16 — spec-migration-foundation
   3. 2026-07-16 — spec-migration-corrections
   ```
4. Do **not** summarize content or reconcile — this is a table of contents only. Tell the user they can `/journal read <topic>` to expand any one.
5. Also check for sibling `archive\` and `references\` folders (see "Two sibling folders"). If present, add one line each noting what exists — `archive/` from its README, `references/` as a count of topic folders with their names.

---

## Mode B — Write (`/journal write` or `/journal write <topic>`)

**When:** At the end of a major refactor session. Requires the explicit `write` verb — never triggered by a bare `/journal`.

### Step 1: Resolve journal root and project name
Resolve `journalRoot` from config (run First-time setup if no valid config). Determine project name from `git rev-parse --show-toplevel` (last segment), or cwd name.

### Step 2: Create path if needed
If `<journalRoot>\<project>\logs\` does not exist, create it. If the journal file does not exist, create it empty.

### Step 3: Check for duplicate
Read the journal and find the first line matching `^## \d{4}-\d{2}-\d{2}` — the most recent entry's date and topic. If an entry for today and the same topic exists, confirm with the user before adding another.

### Step 4: Synthesize entry
Extract from the conversation:
- **Changes/Decisions** — what was decided (not code details — those are in git)
- **Reason** — spec source, BE/PM clarification, or constraint behind it
- **Correction** — if a prior entry is being superseded, the old claim and the actual outcome
- **Architecture notes** — non-obvious structural findings
- **Pending** — open items, labelled BLOCKED (waiting on someone/event) or DEFERRED (chose to wait)
- **Related files** — affected files, briefly

### Step 5: Offer a `references/<topic>/` folder if the detail warrants it
If the session produced detail too extensive to inline (a full field-by-field table, multi-file mapping, a methodology writeup, exported data, a diagram) — **offer** to create `references/<topic>/README.md` (plus any other files that fit) before finalizing the entry. Do not create it silently, and do not create one for ordinary entries — only when inlining would bloat the entry past what's scannable. If the user agrees, write the files under `<journalRoot>\<project>\references\<topic>\`, then include a `**Reference:**` line in the entry (Step 6).

### Step 6: Prepend entry (newest first)

```md
## YYYY-MM-DD — <topic>

**Changes/Decisions:**
- <item>

**Reason:**
<source — spec name, BE/PM confirmation, constraint>

**Correction:** (omit section if nothing is being superseded)
Prior entry YYYY-MM-DD stated: "<what was wrong>". Actual outcome: "<what is correct>". Cause: <why the first pass was wrong>.

**Architecture notes:** (omit section if no structural finding)
<non-obvious structural fact — e.g. zone separation, shared model, deferred-rename rule>

**Reference:** (omit section if no references/ folder was created for this entry)
`references/<topic>/` — <one-line description of what's in it>

**Pending:**
- BLOCKED: <item> — waiting on <person/event>
- DEFERRED: <item> — decided to wait until <condition>
(omit section if nothing pending)

**Related files:** (omit section if not useful)
- path/to/file

---
```

### Step 7: Commit
Only if the journal root was set up as a git repo (see First-time setup). From `<journalRoot>`:
```bash
cd "<journalRoot>"
git add <project>/logs/project-journal.md
git add <project>/references/<topic>/   # if a references folder was created this write
git commit -m "journal(<project>): <topic> YYYY-MM-DD"
```
If the journal root is not a git repo, skip the commit.

### Step 8: Report back
- One-line summary of what was recorded
- Total entry count
- Whether the directory or file was newly created
- If a `references/<topic>/` folder was created, its path

## Rules

- Do not journal what git commits already describe — only the *why* and *context*
- Do not journal code details (snippets, diffs)
- Do not journal secrets, tokens, or personal data
- Do not translate technical terms in another language — quote them directly (e.g. field/table names, spec titles)
- If nothing worth recording happened, say so rather than writing a thin entry
- Never write to `archive/` — it is frozen and historical only; new detail goes in `references/<topic>/`
- When reading, explicitly flag superseded entries so they are not acted on
