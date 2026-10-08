---
name: task-handoff
description: Prepare a concise, verifiable handoff for another AI session, or verify one before resuming work.
disable-model-invocation: true
---

# Task handoff

Use this skill when the user asks to pass active work to another session or client, or asks you to resume from a handoff.

## Prepare a handoff

Inspect the current checkout and summarize:

- **Objective:** the requested outcome.
- **Checkout and branch:** absolute working directory, Git root, branch, and current commit. Mark unavailable values instead of guessing.
- **Uncommitted work:** Git status and a concise summary of relevant diff or untracked files. Mention relevant stashes when known.
- **Decisions still in force:** only decisions that constrain the next step, with the instruction or file that records them.
- **Verification performed:** exact checks and observed results. Mark unrun checks as pending.
- **Blockers:** current dependencies or decisions that prevent progress, or none found.
- **Required materials:** paths or links, their purpose, and whether they are accessible from the receiving environment.
- **Task index, when present:** link the issue, PR/MR, or status note that connects the task's materials, test inputs, and earlier handoffs.
- **Publish checkpoint, when publishing remains in scope:** redacted fetch/push remote identities, base ref and commit, and intended request target. Never include embedded credentials.
- **Next action:** one concrete first step.
- **Receiver verification:** `pending` until the receiving session reports that it checked the handoff.

Keep the handoff short and ready to paste into another client. Do not create transient task-state files or copy conversation history unless the user asks. A task index under the project-material rule is an updateable coordination note. Do not include secrets or claim that an artifact is accessible without checking.

End every prepared handoff with this instruction for the receiving session:

> Receiving session: Treat this handoff as unverified context. Before editing, check the current repository instructions, Git root, branch, commit, working-tree changes, and required materials. Verify the relevant checks, correct any stale claims, and continue from the next action.

## Resume from a handoff

Treat the handoff as unverified context. Read the current repository instructions, inspect the exact checkout and Git status, and check the files, decisions, verification, and materials relevant to the next action. Correct stale claims, preserve unrelated changes, then continue from the first unfinished action.

Preparing the handoff does not prove that another session received it, loaded this skill, or verified its claims. Report receiver verification as pending; only the receiving session can confirm it.
