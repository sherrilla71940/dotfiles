# ADR-0053: Use native-first AI workflows and explicit handoffs

- Status: Accepted
- Date: 2026-10-08

## Context

This repository had grown a custom task-state system, cross-client lifecycle hooks, worktree
provisioning aliases, ignored-file classifiers, and per-worktree port allocation. Their contracts
were repeated across profile modes, skill adapters, tests, setup guides, and many ADRs. Current
clients now provide useful native conversation resume and worktree workflows: Claude Code can
resume and export conversations and create Git worktrees; Codex desktop can move a chat between a
local checkout and its managed worktree. Git remains the source of truth for files and branches.

Native behavior does not make a transcript or handoff trustworthy. Cross-client continuation still
needs a concise prompt, and the receiving client must verify the checkout and claims against Git and
current repository instructions.

Conversation transfer is asymmetric: [ChatGPT desktop and Codex CLI can import supported recent
Claude chats](https://learn.chatgpt.com/docs/import), while [Claude Code exports plain-text
conversations and imports configuration](https://code.claude.com/docs/en/commands). A transcript
can recover discussion, but it does not establish the current checkout or delivery state.

## Decision

- Keep one machine-local `ai_context` selector with `personal` and `company` values. Do not expose
  separate harness or continuity modes.
- Keep `run-task-end-to-end` as a concise implementation and verification skill. It follows the
  current client's workspace behavior and project instructions; it does not create or provision
  worktrees itself.
- Provide `task-handoff` as an explicit-only skill. It summarizes the objective, exact checkout and
  branch, uncommitted work, decisions still in force, verification, blockers, required materials,
  and next action. The receiving client checks those claims against current files and Git. Client
  transcript export may be included as optional context, never as repository evidence.
- Link related references, test inputs, and handoffs from an existing issue or PR/MR when a task
  uses several of them. Without a task record, use one updateable handoff/status note as a small
  index. Keep verification claims pinned to a date and commit; simple tasks need no index.
- Use native client or ordinary Git worktree features when isolation is useful. Keep `.worktreeinclude`
  as the client-supported way to share explicitly selected ignored files; project setup remains
  project-specific. Do not promise that worktree creation installs dependencies, copies arbitrary
  files, or isolates ports.
- Remove custom continuity state and lifecycle hooks, custom Git worktree provisioning and runtime
  allocation, their client adapters and aliases, fixtures, dedicated tests, and detailed guides.
  Keep notification hooks, the statusline, the general workflow deletion tool, native Claude
  worktree-memory guidance, and the global safety ignore for existing `.task-continuity/` data.
- Under `company-flow`, require an explicit flow branch and reject other branches at pre-push. A
  project-wide exception must be recorded as `branch.policy=project-exception` in that repository's
  local Git config. Remove the per-task bypass that depended on continuity state.
- After this migration, remove the listed superseded accepted ADRs from the active index and source.
  Git history remains the recovery record for those retired designs.

## Alternatives considered

- Keep the custom continuity and provisioning systems as optional modes. Rejected because the
  option matrix, lifecycle behavior, and client-specific adapters created recurring maintenance
  for a state that could be summarized and checked from Git when needed.
- Rely on a raw transcript alone for cross-client handoff. Rejected because conversation history
  cannot establish the current checkout, diff, verification, or material availability.
- Require one client or one worktree creation path. Rejected because supported clients and projects
  have different useful native workspaces, and Git is the shared interface.

## Consequences

Cross-client handoffs require a short, deliberate summary; there is no automatic repository-local
task state or completion hook. A receiving session can start stale if it skips the handoff checks.
Task indexes are navigation aids; the receiving session still checks their links and verification
claims against current files and Git.
Native worktree cleanup, branch movement, and ignored-file handling follow the selected client or
Git behavior and must be checked in that environment. Projects needing runtime isolation must use
their own documented setup.

Previously rendered continuity and provisioning targets are listed in `home/.chezmoiremove` so a
reviewed future `chezmoi apply` can remove them. This change does not apply live configuration.
Older local `ai_harness`, `ai_continuity`, and `ai_workflow` values are ignored by the simplified
resolver. The global ignore and workflow-deletion protections remain so old untracked task data is
not accidentally exposed or removed.

The retired ADRs are: 0011, 0012, 0014, 0017, 0021, 0022, 0023, 0025, 0029, 0030–0039, and
0041–0045, plus 0047. ADR-0024's instruction-provenance and material-filing decisions and ADR-0026's
base-integration policy remain active; their continuity-specific wording is updated. ADR-0040's
company flow identifier rule remains active.

## Reconsider when

Revisit the handoff if cross-client work repeatedly loses decisions that cannot be recovered from
Git, repository instructions, issues, or the concise handoff. Revisit native worktree reliance when
a supported client or project demonstrates a recurring failure that its native configuration cannot
address with an acceptably small repository-owned rule.

## Related files and verification

- `home/.chezmoitemplates/skills/task-handoff/SKILL.md`
- `home/.chezmoitemplates/skills/run-task-end-to-end/SKILL.md`
- `home/.chezmoitemplates/core.md`
- `home/.chezmoitemplates/ai-profile.yaml`
- `home/.chezmoitemplates/git-hooks/company-flow-pre-push.sh`
- `home/.chezmoiremove`
- `README.md` and `README.zh-TW.md`
- `scripts/tests/test-ai-configuration-profiles.sh`
- `scripts/tests/test-company-flow-policy.sh`

Verify both rendered contexts with `bash scripts/tests/test-ai-configuration-profiles.sh`, company
branch behavior with `bash scripts/tests/test-company-flow-policy.sh`, and review the resulting
`chezmoi diff` before applying configuration.
