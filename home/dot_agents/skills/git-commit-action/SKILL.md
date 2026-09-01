---
name: git-commit-action
description: "Create one or more Conventional Commits from the current git diff — batches unrelated changes into separate atomic commits by default, with safe per-group staging. Use when the user asks to commit changes, draft commit messages, or invokes /git-commit-action. Supports draft vs. commit modes, batch vs. single grouping, scope filters (all/staged), and English or Traditional Chinese messages."
argument-hint: "[commit|draft] [batch|single] [all|staged] [en|zhtw] optional type, scope, description, or files"
---

# Git Commit Action

Create one or more standardized commits in Conventional Commits format from the current repository state. By default, group unrelated changes into separate atomic commits (batch). Always analyze the actual repository state before choosing messages.

Automatic invocation is allowed, and the skill creates commits by default. Use `draft` only when the user asks to preview the commit plan without changing the repository.

For the Conventional Commit type table, description/body rules, bullet-body and breaking-change/footer conventions, and message examples, see the `git-commit-reference` skill — this file only covers the `/git-commit-action` workflow itself.

## Mission

Turn the current logical diff into atomic Conventional Commits — one per logical change by default (`batch`), or a single commit when asked (`single`). Draft the plan for review, or create the commits. Prefer the actual diff over user-provided hints when they disagree.

## Options

`$ARGUMENTS` contains the full trailing text typed after `/git-commit-action`. Flags are **not positional** — scan the whole string for recognized tokens; anything unrecognized is a hint (type, scope, description, or file selection). Each axis is independent, and any axis you omit falls to its default.

| Axis         | Options            | Default  | Answers                                             |
| ------------ | ------------------ | -------- | --------------------------------------------------- |
| **Mode**     | `commit` · `draft` | `commit` | Actually create commits, or only preview?           |
| **Grouping** | `batch` · `single` | `batch`  | One commit per logical change, or one commit total? |
| **Scope**    | `all` · `staged`   | `all`    | Which files are candidates?                         |
| **Language** | `en` · `zhtw`      | `en`     | Message description/body language?                  |

Example invocations (0–4 flags, any order):

| Typed                                     | Behaves as                                                   |
| ----------------------------------------- | ------------------------------------------------------------ |
| `/git-commit-action`                      | Create atomic commits for all changes                        |
| `/git-commit-action draft`                | Draft a batched multi-commit plan for all changes            |
| `/git-commit-action commit staged single` | Commit exactly the staged files as one commit (classic path) |

### Mode

- `commit` (default): create the commit(s).
- `draft`: show the proposed plan — each group's files plus its message — without staging or committing, then stop. End the draft with the exact command to run next, e.g. `/git-commit-action commit <same flags>`, so the user can execute without re-deriving flags.

### Grouping

- `batch` (default): partition the candidate changes into logical groups and create one Conventional Commit per group. If the candidates form a single logical change, this naturally yields one commit. Always state the proposed grouping before committing.
- `single`: create exactly one commit from all candidate changes, even when they span multiple logical changes.

### Scope (which files are candidates)

- `all` (default): the whole working tree — staged, unstaged, and untracked.
- `staged`: only files already staged. Respects a deliberately curated index and ignores unstaged/untracked changes. Combine with `single` for "commit exactly what I staged, as one commit."

### Language

- `en` (default) — aliases `eng`, `english`. Description/body in English.
- `zhtw` — aliases `zh-tw`, `chinese`, `mandarin`, `mandarin chinese`, `chin`. Description/body in **Traditional** Chinese (zh-TW, Taiwan). The `git-commit-reference` skill, which step 6 loads anyway, carries the zh-TW rules for a commit message; no second skill load is needed.

## Workflow

1. Parse `$ARGUMENTS` for Mode, Grouping, Scope, Language, and hints. Apply defaults for omitted axes (`commit`, `batch`, `all`, `en`).
2. Inspect repository state with `git status --porcelain`.
3. Determine the candidate file set from Scope:
   - `all`: staged + unstaged + untracked.
   - `staged`: `git diff --cached --name-status` only.
     Inspect with `--name-status` and `--stat` first; read full patches only when names/stat are insufficient for an accurate message, or a file looks secret-like, ambiguous, or unexpected.
4. Check candidate filenames for obvious secrets or private credentials (`.env`, private keys, credential JSON, tokens, generated secret dumps). Stop and explain if any is present.
5. Group the candidates:
   - `batch`: partition into logical changes by concern/type/area. Prefer fewer cohesive commits — don't split a single coherent change just because it spans multiple files; split on distinct concern/type, not on file count. One logical change can span files of different types or folders — e.g. a rule moved from one file to another is **one** commit even across folders, while files that merely share a folder aren't automatically one commit. Group by *why it changed*, not *where it lives*. Everything that is one logical change is one group. Prefer whole-file grouping; only reach for `git add -p` when one file's hunks genuinely belong to different groups.
   - `single`: one group containing all candidates.
6. Load the `git-commit-reference` skill and compose a Conventional Commit message for each group, following its type table, description/body rules, bullet-body guidance, and breaking-change/footer conventions.
7. **Draft mode** — present the plan: for each group, list its files and show its proposed message in a fenced `text` block. State that nothing was staged or committed. End with the exact next command, e.g. `Next: run /git-commit-action commit <same flags>` to create these. Stop here.
8. **Commit mode** — create the commit(s). Git has a single index, so batch commits are made by staging and committing **one group at a time**; git will not partition changes on its own. For each group, in order:
   1. Stage exactly that group's files (prefer the most targeted approach):
      ```bash
      git add path/to/file1 path/to/file2   # specific files for this group
      git add 'src/components/*'            # by pattern
      git add -p path/to/file               # when one file's hunks span groups
      git rm path/to/deleted-file           # stage a deletion
      ```
   2. Run `git diff --cached --check`.
   3. Commit — single-line, or a heredoc for a body:

      ```bash
      git commit -m "$(cat <<'EOF'
      <type>[scope]: <description>

      <optional body>
      <optional footer>
      EOF
      )"
      ```

      Then move to the next group. Never mix files from different groups in one commit.

9. Finish with `git status --short` and report each commit's hash and message.

## Safety Rules

### Never, whatever is asked

- Never commit a real secret. Confirmation does not unlock this: a secret in history is effectively permanent, needing both a history rewrite and a credential rotation, so the only safe outcome is not writing it.
- When a candidate only *looks* secret-like — a template, an example, a fixture — stop and say which file and why, rather than deciding for yourself that it is fine.
- Never bypass a failing hook, with `--no-verify` or otherwise. Fix what it reported and commit normally. In `batch` mode a hook failure does not roll back the groups already committed: fix the issue, then continue with the rest.

### Mode contract

Overriding these creates no danger; it makes the result meaningless, because the mode stops describing what happened. There is no confirmation that unlocks them.

- Never stage files or create commits in `draft` mode.
- In `batch` mode, stage and commit one group at a time; never combine files from different logical groups in a single commit.

Rewriting or discarding existing history — `git commit --amend`, `git reset --hard`, `git clean`, force-pushing — is outside this skill. It creates commits; it does not undo them.
