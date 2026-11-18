# ADR-0061: Keep task records concise and project outputs canonical

- Status: Accepted
- Date: 2026-11-18

## Context

Long tasks that span sessions and repositories benefit from one personal record for decisions,
answers, and cross-repository rationale. The record can become a second project log when it carries
a lengthy Git status snapshot, session-by-session implementation history, or team-owned gap and
decision lists. Git status can change after the record is updated, while teammates cannot find or
maintain artifacts stored only in a personal Documents folder.

ADR-0057 already makes the record personal and requires receiving sessions to reconcile its claims
with Git and original sources. Its template still asks for checkout, branch, HEAD, and uncommitted
paths, which can encourage a stale duplicate of state that Git already owns.

## Decision

- Keep personal records for durable rationale, sourced questions and answers, verification, and
  the next meaningful resumption action. Do not store routine branch, HEAD, or clean/dirty snapshots.
  Recheck those facts from Git when resuming. Keep a dated checkpoint only when another checkout,
  uncommitted work, or an in-progress publication changes the next action. At material updates,
  revise the existing summary rather than append a session log; preserve decision rationale and
  compress completed implementation detail to a concise result and links.
- Put decisions, actionable gaps, and open work that teammates need to review or maintain in the
  project's canonical issues, ADRs, documentation, or human-facing handoff, following that
  repository's instructions. Keep the personal record as a concise index with purpose links and any
  cross-repository rationale those artifacts do not capture. Do not create a parallel team log; if
  the owner or canonical location is unclear, identify it before publishing.
- Continue updating records at material boundaries rather than automatically on every commit. Git
  remains authoritative for repository state; a commit hook would duplicate cross-repository state
  and add a write path that can race with shared checkouts.

## Alternatives considered

- Keep a full `Current state` section: rejected because branch, HEAD, and worktree status can go stale
  between material updates and should be checked directly when a session resumes.
- Update the record automatically on each commit: rejected because commits can occur in multiple
  repositories and worktrees, and an automatic writer would add synchronization and concurrency
  complexity to a personal context file.
- Keep team decisions and gap lists only in the personal record: rejected because teammates need a
  canonical location they can discover, review, and maintain.

## Consequences

Records carry less transient Git detail and avoid duplicating team-owned logs. A continuing session
must inspect the current checkout and sources before acting. Team-facing artifacts need clear
ownership and may require links from the record to preserve cross-repository context.

## Reconsider when

Revisit this decision if sessions repeatedly fail to find relevant uncommitted work without a
routine checkout snapshot, if Git checks on resume fail to catch stale assumptions, or if project
repositories lack usable locations for decisions and owned follow-ups.

## Related files and verification

- `home/dot_agents/skills/task-record/SKILL.md`
- `home/dot_agents/skills/task-record/references/record-format.md`
- `docs/task-record.md` and `docs/task-record.zh-TW.md`
- `docs/run-task-end-to-end.md` and `docs/run-task-end-to-end.zh-TW.md`
- `docs/decisions/0057-use-durable-personal-task-records.md`
- `scripts/tests/test-ai-configuration-profiles.sh`
