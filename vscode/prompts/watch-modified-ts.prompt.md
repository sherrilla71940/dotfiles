---
description: "Run one-off or permanent project-based tsc for changed TypeScript files (default: permanent)"
name: "Watch Modified TS"
argument-hint: "optional path filter, e.g. Scripts/FertilizerStation"
agent: "agent"
---
Create a terminal session to run project-based TypeScript checks for currently changed `.ts` files in mode <one-off | permanent>.

Input: one-off | permanent | fast (default: permanent)

Requirements:
- Work from the current git repository root.
- Collect candidate files from both staged and unstaged changes (tracked + untracked):
  - `git diff --name-only --diff-filter=AMR -- '*.ts' ':!*.d.ts'`
  - `git diff --name-only --cached --diff-filter=AMR -- '*.ts' ':!*.d.ts'`
  - `git ls-files --others --exclude-standard -- '*.ts' ':!*.d.ts'`
- Collect deleted tracked `.ts` files for reporting only (do not watch):
  - `git diff --name-only --diff-filter=D -- '*.ts' ':!*.d.ts'`
  - `git diff --name-only --cached --diff-filter=D -- '*.ts' ':!*.d.ts'`
- For each deleted `.ts` file, resolve its expected emitted `.js` path using the same mapping rules as the `Stage Corresponding JS` prompt:
  - prefer owning `tsconfig.json` + `compilerOptions.outDir`
  - use `rootDir` when available
  - otherwise, if the source file is under the parent folder of `outDir`, preserve the path relative to that parent
  - otherwise fall back to the `tsconfig.json` directory, then same-folder `.js`
- Check whether the preferred emitted `.js` file still exists and report it as `Orphan JS` if it does.
- Merge and deduplicate these paths.
- If an optional path filter is provided by the user, keep only files whose path includes that filter.
- Keep only files that still exist on disk.
- Exclude deleted/non-existent files from the watch command, but report them.
- For the remaining existing `.ts` files, find the nearest ancestor `tsconfig.json` for each file and group files by owning project.
- Prefer project-based `tsc` commands. Do not run `npx tsc <matched-ts-files...>` unless no usable owning `tsconfig.json` can be found.
- If zero files remain, do not run watch and explain why.

Mode behavior:
- Permanent mode:
  - Do not generate temporary `tsconfig` files.
  - Run as background watch for continuous feedback.
  - For each unique owning project, run exactly:
    - `npx tsc -p <tsconfig-path> --watch --pretty false`
- One-off mode:
  - Do not generate temporary `tsconfig` files.
  - For each unique owning project, run exactly:
    - `npx tsc -p <tsconfig-path> --pretty false`
  - Only if no usable owning `tsconfig.json` exists for a matched file, fall back to:
    - `npx tsc --pretty false <matched-ts-files...>`
- Alias handling:
  - If input is `fast`, treat it as `one-off`.
  - If input is empty, treat it as `permanent`.
- Use safe shell quoting for paths containing spaces.
- If multiple owning projects are detected, start one command per project and list them all in `Watch command`.
- If file argument length becomes too long for the shell during fallback file-mode execution, stop and report `No-op reason` with guidance to use project watch manually.

Run command:
- In `permanent` mode, start as a background terminal process.
- In `one-off` mode, run once and return the result (do not keep a watch process running).
- Prefer working command directory at the repository root. If using `-p <tsconfig-path>`, keep the command format exactly `npx tsc -p <tsconfig-path> --watch --pretty false` or `npx tsc -p <tsconfig-path> --pretty false`.

- Do not modify repository files.
- Do not run `git add`, `git commit`, or any destructive git command.

Output format:
1. `Mode`: `one-off` or `permanent` (input `fast` must resolve to `one-off`; empty input resolves to `permanent`).
2. `Matched TS`: total number of `.ts` files selected.
3. `Owning tsconfig`: list the resolved `tsconfig.json` file(s) used for execution, or `(none)` if fallback file mode was used.
4. `Watch command`: the exact command used.
5. `Ignored`: any changed `.ts` files excluded by filter or missing on disk.
6. `Deleted TS`: deleted tracked `.ts` files detected from git diff.
7. `Orphan JS`: existing `.js` files that correspond to deleted `.ts` files.
8. `No-op reason`: explain if watch was not started.

