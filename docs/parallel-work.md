# Work across projects in parallel

[繁體中文](./parallel-work.zh-TW.md)

Use a separate native client task or session for each independent workstream. Before editing, verify that each task is attached to its intended repository and workspace. Different repositories can progress independently.

For concurrent changes in the same repository, use separate worktrees when its policy allows them. Avoid concurrent edits to the same checkout. Each worktree has its own files, index, and HEAD; Git refs and project services such as ports, databases, and caches remain shared. Follow the project's runtime setup for those services. If a repository requires one checkout, coordinate changes in that checkout instead of creating a worktree against its policy.

Keep each task's context with that task. Follow its repository instructions and checks; use a [personal task record](./task-record.md) when work spans sessions or needs durable decisions. Use the [end-to-end task guide](./run-task-end-to-end.md) when invoking the implementation skill for an individual task. Use the client's native task and worktree features where available, or ordinary Git worktrees when the repository allows them. No central scheduler is required.
