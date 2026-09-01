## Project continuity

Decide whether continuity is needed before the first substantive repository action, and create
it only once the work has produced something material: implementation started, a change spanning
several files, a non-obvious investigation finding, a decision that constrains what follows, or
an unresolved dependency. Discussion, questions and a plan still being negotiated do not need
state — the user holds that context too. This is later activation, not optional activation: once
that point is reached, create it without asking. In the first progress update for such work,
state either `Continuity: enabled` or `Continuity: not needed — <reason>` so the decision cannot
be skipped silently. Reassess if a small task grows into one of those, and always use continuity
for an explicit handoff or resume and after conversation compaction.

If the working tree root contains `.project-continuity/state.md`, continuity is already active.
Read its `Objective` first and decide whether it describes the task you were just asked to do.
**State that belongs to a different unfinished task is never reconciled, merged into, or
replaced without asking** — reconciling is how you update the state of the task it already
tracks, not how you take the file over for a new one. If the task matches, use the
`project-continuity` skill and reconcile before substantive work. If it does not, answer the
new request without touching that file, and say it is still parked there. If the file is absent
and losing the conversation would cost materially more than re-reading the diff, use the skill
and initialize continuity before proceeding. If the client cannot resolve the skill by name,
read and follow `~/.agents/skills/project-continuity/SKILL.md` directly instead. Write that file
in English whatever language this conversation uses.

Skip initializing continuity, and the visible decision, for explanation-only questions, small
self-contained edits, formatting, and work the diff already explains. That exemption covers
starting continuity only. When `.project-continuity/state.md` already exists and tracks the
current task, still reconcile it before substantive work, and still offer cleanup once that task
is complete, however light the current turn is.
