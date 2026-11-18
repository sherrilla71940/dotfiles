# Task record format

Keep one Markdown file at `~/Documents/task-records/{repo}/{task-key}.md`. Use the verified remote repository name for `{repo}` unless a confirmed collision requires the stable, qualified folder key in shared guidance; do not rename existing records automatically. A task key is a verified issue/task ID or a stable descriptive slug. The file is personal task context, not a replacement for Git or the original request. Team-owned decisions, gaps, and follow-ups belong in the project's canonical artifacts; link them here by purpose.

```markdown
# <task title>

- Task key: <stable ID or slug>
- Aliases: <other names or IDs, if useful for discovery>
- Repository: <verified remote repository name>
- Repository identity: <credential-free remote host/namespace/repository>
- Source request: <original message or document link, or unavailable>
- Created: <date and timezone>
- Last updated: <date and timezone>
- Status: active | blocked | complete

## Objective

<requested outcome and material scope>

## Next action

<one concrete first unfinished action, or none when complete>

## Questions and answers

- Q1: <question>; owner: <known owner or unassigned>; asked: <date and source>.
  Answer: <answer or pending>; received: <date and source, or pending>.

## Decisions

- D1 (<date>; active): <chosen behavior>. Why: <reasoning and evidence; refer to Q1 rather than repeating its answer>.
  Owner: <known owner or unassigned>. Implemented by: <commit/PR/path or pending>.
- D2 (<date>; superseded by D3): <earlier choice and its original rationale>.

## Verification

- <check>: <observed result or pending>; <date>; <commit or working-tree state>.

## Related artifacts

- Task material: <path or link> — <purpose, provenance, and availability>.
- Test input: <path or link> — <purpose; pin observed results under Verification>.
- Human-facing handoff: <path or link> — <recipient or owner and status>.
- Issue or PR/MR: <URL> — <purpose>.
- Repository reference: <path or commit> — <why it matters>.
- Session reference: <client, ID or URL, date, and context it helps locate>.

## Delivery and follow-ups

- Outcome: <commit/PR/MR or pending>.
- Open follow-up: <owner, reopening trigger, and external pointer when one exists, or none>.
- Publication checkpoint, when needed: <redacted remote, base ref and commit, intended target>.
```

Omit empty optional entries and add detail only when it helps another session continue or explains a consequential decision. At material updates, revise the existing summary rather than append a session log; preserve decision rationale and compress completed implementation details to outcomes and links. On resumption, check Git and cited sources before acting; the record is not live status. Do not store routine branch, HEAD, or clean/dirty snapshots. Keep a dated checkpoint only when another checkout, uncommitted work, or an in-progress publication changes the next action. At completion, retain the final outcome and decision-relevant verification, condense redundant interim checks, and omit details that no longer explain the result or an open follow-up. Keep status and verification current while retaining answered questions and the rationale of superseded decisions. Pending questions remain in Questions and answers; Follow-ups list only actionable post-delivery work or externally owned dependencies, referring to question IDs when useful. Team-facing decisions and actionable gaps live in project-owned issues, ADRs, documentation, or handoffs; keep the personal record concise and link to those sources instead of duplicating their contents. A verified task or issue ID identifies the record. Record a client session reference only when it helps locate material context not preserved in the record; do not maintain an exhaustive session history or treat the ID alone as proof. If an answer is the entire decision, use one sourced entry instead of duplicating it across sections. Do not copy a full transcript, credentials, or confidential source material into the record.
