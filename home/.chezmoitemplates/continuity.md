{{- $profile := includeTemplate "ai-profile.yaml" . | fromYaml -}}
{{- if and (eq $profile.ai_continuity "on") (eq $profile.ai_harness "managed") }}
## Task continuity

When `run-task-end-to-end` is active, including its legacy `task-workflow` and
`worktree-task-workflow` entry points, its resolved continuity policy governs the task.
`continuity=auto` inherits the rendered `ai_continuity` value; `on` and `off` are explicit
overrides. Do not apply a second task-size heuristic inside that workflow. The workflow owns
its intake provenance, branch-policy resolution, and corresponding continuity fields.

Outside that workflow, reassess continuity before substantive repository work and when the task
gains important findings, decisions, blockers, a feature transition, a handoff or resume need, or
conversation compaction. Initialize it when losing that state would cost materially more than
rereading the repository, diff, or other durable sources. Do not initialize it for discussion,
explanation-only questions, formatting, trivial self-contained edits, or work cheaply recoverable
from the diff. At a reassessment point, say `Continuity: enabled` once state exists, or
`Continuity: not needed — <reason>` when it remains unnecessary. Keep trivial work quiet.

If `.task-continuity/state.md` exists at the working-tree root, read its `Objective` before
substantive work. If it matches, invoke `task-continuity` and reconcile it before continuing.
State belonging to a different unfinished task is never reconciled, merged into, or replaced
without asking. Leave unrelated state untouched for lightweight work. Before starting another
continuity-requiring task in the same tree, use the skill to park unfinished state or transition
completed state; never overwrite either record.

If no active state exists, use the skill's branch-aware parked-state discovery before treating a
named branch as a new task. Branch name alone never selects a parked state. If legacy
`.project-continuity/` state exists, use the skill for migration; if both continuity directories
exist, stop and resolve the collision rather than merging them.

Use `task-continuity` for initialization, reconciliation, parking, resume, handoff, and cleanup.
If name resolution fails, read `~/.agents/skills/task-continuity/SKILL.md` directly. Before ending
with unfinished work, checkpoint enough to identify the first unfinished action. After a commit,
push, request creation, merge, rebase, manual-test result, or decision to pause publishing,
reconcile the delivery state before ending the response.

Apply the skill's completion gate before every final response after continuity was enabled or
touched, including unfinished or failed paths. For completed work, report whether cleanup was
completed, declined and recorded, or remains pending with the named state files. A lifecycle-hook
reminder does not replace reconciliation or the user's cleanup decision. Keep continuity cleanup
separate from worktree and branch cleanup.
{{- end }}