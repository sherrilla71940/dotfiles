# Push and open the request

Read this at step 10 of `frontend-task-workflow`, after `git-commit-action` has created the
commits.

If the invocation used `mode=draft`, `git-commit-action` created nothing. Stop here, show its plan,
and say that nothing was pushed.

## 1. Detect the forge before pushing

```bash
git remote get-url origin
```

The host decides both how to push and how to open the request, so resolve it first.

| `origin` host | Push | Open the request |
| --- | --- | --- |
| `github.com` or GitHub Enterprise | plain | `gh pr create` |
| Any GitLab host, GitLab MCP available | plain | `mcp__gitlab__create_merge_request` |
| Any GitLab host, no MCP | with `merge_request.*` push options | the push itself opens it |

`glab` is not installed on this machine. Do not reach for it without checking
`command -v glab` first.

## 2. Compose the title and description

Follow the repository's own template when one exists — `.github/pull_request_template.md`, or
`.gitlab/merge_request_templates/*.md`.

- **Title**: the primary commit's Conventional Commit subject.
- **Description**: what changed and why, the scope covered, and anything deliberately left out.
  Link the requirements file or issue when the task named one.
- **Language**: the resolved `lang` value. For `zhtw`, load `natural-zhtw` first and follow
  it — a merge request description is exactly the register it targets.
- **Attribute each kind of testing to whoever did it, and report both.** Name the checks you
  actually ran and what they showed, then state separately that the user ran the manual test and
  reported it passing — for example「已執行 typecheck、lint 與相關單元測試並通過；手動測試由
  使用者操作確認」. Omitting your own verification understates the work as surely as claiming the
  user's overstates it.
- Never present something you only read as something you exercised: a UI flow, an integration, or
  any runtime behavior counts as tested only if a tool actually drove it. Do not write that
  anything was reviewed, approved or deployed unless it was.

## 3. Push

```bash
git push -u origin HEAD
```

Never force-push. If the push is rejected because the remote branch moved, stop and report it.

For a GitLab host with no MCP server available, carry the request in the same push instead:

```bash
git push -u origin HEAD -o merge_request.create -o merge_request.target=<base> -o merge_request.title="<title>"
```

GitLab prints the merge request URL in the push output — capture it. Push options only take
effect on a push that actually updates the remote, so use this form on the first push of the
branch, not after a plain push has already succeeded.

## 4. Open the request

**GitHub:**

```bash
gh pr create --base "<base>" --head "<branch>" --title "<title>" --body-file <file>
```

**GitLab with MCP:** load the tool with `ToolSearch` using
`select:mcp__gitlab__create_merge_request`, then call it with `id` as the URL-encoded project
path from the `origin` URL (`group%2Fsubgroup%2Fproject`), `source_branch` as the task branch,
`target_branch` as the original base, plus the title and description.

Target the base branch supplied at invocation — not the repository's default branch, and not
whatever the forge preselects.

Then stop. Do not merge it, do not enable auto-merge, do not approve it, and do not add the
"delete source branch" option beyond whatever the project already defaults to.

## 5. Report

```text
Branch:  fix/recycle-water-inspection-pm/frontend
Commits: <sha> <subject>
Target:  feat/RecycleWaterInspection
Request: <url>
```

List every commit when `git-commit-action` created more than one. If a step could not be
completed — no forge tooling, an authentication failure, an existing request — say exactly which,
and give the command or URL the user can finish it with.
