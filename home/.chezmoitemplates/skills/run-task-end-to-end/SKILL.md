---
name: run-task-end-to-end
description: Take an implementation task from intake through verification and requested delivery, using the repository's rules and the active client's workspace behavior.
disable-model-invocation: true
---

# Run a task end to end

Use this skill when the user asks you to implement a repository change through verification and delivery.

## Resolve the request

Accept a task in ordinary language, with attached or named materials and any clear choices such as `phase=plan|execute`, `base=<branch-or-commit>`, `target=<branch>`, `branch=<name>`, `workspace=current|worktree`, or `verification=agent|balanced|user`. These names are optional shorthand, not a required command grammar. The active repository and profile policies determine any additional required inputs. Treat provided values as user prompt text, not as a separate command interface.

Before reading project files, follow the repository-identity preflight in the active instructions. Read the repository instructions and determine which supplied materials are available and authoritative. Preserve unrelated local changes.

- A plan or review request ends with findings and a recommended next action; do not edit files.
- `base` is an explicit branch or commit to start from. `target` is the pull-request or merge-request destination. If the user supplies only `target`, use it as `base` unless repository instructions say otherwise. Without either value, use a suitable current checkout or the active client's native worktree starting point and record its exact commit. Do not infer a publication target from the current branch, its upstream, or the remote default.
- Follow the repository's branch policy. Resolve a supplied or policy-required task branch before editing. Otherwise, a suitable current branch or native detached worktree can hold the work; create a branch when the client or delivery requires one. If a new name is needed and no repository rule applies, derive a lowercase `<type>/<short-ascii-slug>` branch from the change type and task summary (for example, `docs/handoff-skill`). Ask for policy-required input that is missing and validate the proposed name. Do not infer policy-required identifiers from prose, materials, or an existing branch, or add a per-task policy bypass.
- A supplied `target` requests delivery through a pull request or merge request after verification. Without a target or explicit request to publish, complete locally.
- Honor an explicit `workspace=current` or `workspace=worktree`. Otherwise continue in the active checkout. Ask before isolating only when a separate checkout is needed to protect unrelated work or enable requested parallel work.
- Default verification to `balanced` when publication is requested and `agent` for local delivery. The user can choose another verification policy.

When invoked without a task, ask for the outcome and only the missing decisions needed to proceed. Use the active client's question interface when available; otherwise ask in one concise message.

## Establish the workspace

Apply the repository's branch policy before creating or switching branches. Follow its branch naming, profile, and exception rules; do not copy a company's branch rules into this skill.

When a worktree is requested, let the active client use its native worktree flow when available. If it is not available, use ordinary Git worktrees and enter the exact created directory before editing. Do not treat a shell `cd` as proof that an app chat moved. Before implementation, verify the actual Git root, branch or detached state, and starting commit. Stop if they do not match an explicit starting point or repository policy; otherwise record the client-selected start.

Follow project setup instructions and the active client's supported `.worktreeinclude` behavior for selected ignored files. Verify that required project instructions, skills, and setup files are available inside the task workspace; client versions differ in whether they read ignored files from the main checkout. Do not copy ignored, secret, or client-private files by hand. Report missing inputs without exposing their values.

A worktree isolates files and branch state; it does not guarantee separate ports, databases, caches, or external services. Use documented project setup for those resources. If a runtime collision prevents a trustworthy test, resolve it through the project's documented configuration or report the verification as blocked; do not claim a custom per-worktree runtime guarantee.

## Establish the starting point and branch

For an execution task, resolve an explicit `base` or `target` to an exact commit. Otherwise record the current checkout's HEAD or the native worktree's starting commit. For PR/MR delivery, fetch and verify the selected base on the intended remote. Record the starting ref and commit so the same point can be checked after workspace setup and before publication.

When a branch is required, use the active client's native branch controls if they can create it from the resolved starting commit; otherwise use Git inside the selected workspace. A native detached worktree can remain detached during implementation, but create the required branch before committing or publishing. If workspace setup already created the branch, verify its starting commit and continue there. Reuse an existing branch only when it is the user's selected current workspace or an explicit continuation whose task matches; never reset it or silently switch to unrelated work. Before switching a current checkout, check for unrelated uncommitted work. Preserve it, and ask to use a separate workspace or for a clear resolution if switching would mix or displace that work.

Before editing, verify the workspace Git root, branch or detached state, and starting commit. After any branch creation, verify the branch and commit again. Stop if the workspace or branch does not match the resolved task; do not repair a mismatch by resetting the checkout.

## Implement and verify

Use the supplied materials and the repository's own setup. Implement the requested outcome, review the full diff, and run the most useful available checks, including focused tests, lint, type checks, and a build when the project provides them. For user-facing changes, start the application and exercise relevant browser flows when the app and browser tools are available.

The verification policies define the human checkpoint:

- `agent`: run the broadest useful automated, runtime, and browser checks available. Ask the user only for checks that require their access or judgment.
- `balanced`: run those checks, then show the result and wait for the user's review before committing or publishing.
- `user`: run automated checks only, provide precise manual test steps, and wait for the user's result before committing or publishing.

If a check fails, investigate, make a scoped correction, and rerun the affected checks. Report the commands actually run and their results. Label checks that could not run as blocked or unverified; never turn a plan, source inspection, or setup report into a claim that runtime behavior passed.

## Deliver the requested result

Review the complete diff for scope, unintended changes, and secrets. Before creating a commit, load `git-commit-action` and follow its profile-aware message and staging rules. This skill invocation authorizes the local task commit after its verification gate passes.

When `target` or an explicit publish request is present, check the repository's publish policy and record the remote identities, starting base ref, and base commit. If the target base advanced, stop for an explicit merge-or-rebase choice; prefer merge for a branch already published. Rebasing published history requires separate explicit approval and `--force-with-lease`; never use plain force-push. After integration, rerun the applicable checks and recheck the remote and base before pushing. Do not use an implicit `git pull`, merge the request, or enable auto-merge.

After the verification and any selected user-review gate pass, push the task branch and create the request against the resolved `target`. If the host or credentials prevent publication, keep the verified local result and report the exact safe next step.

Report the checkout, branch, changed behavior, checks and outcomes, blockers, commit, and request URL when created. When another session must continue, use `task-handoff`; the receiving session verifies its claims against current files and Git.
