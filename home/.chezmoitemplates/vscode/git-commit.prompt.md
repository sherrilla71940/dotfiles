---
description: 'Create a Conventional Commit from the current git diff with safe staging and message selection.'
name: 'Git Commit'
argument-hint: '[draft|commit] [en|zhtw] [last-chat-edit|all-chat-edits|recent-last|recent-all] optional type, scope, description, or files'
agent: 'agent'
tools: ['execute']
---

# Git Commit

Create one standardized git commit using the Conventional Commits format. Analyze the actual repository state before choosing the commit message.

## Mission

Create one safe Conventional Commit from the current logical diff, or draft the commit message when requested. Prefer the actual diff over user-provided hints when they disagree.

## Arguments

Parse trailing slash-command text as optional flags and hints. Defaults are `draft` mode and `en` language.

- Mode flags:
  - `draft`: return the proposed commit message in chat without staging or committing. This is the default.
  - `commit`: create the commit.
- Language flags:
  - `en`: write the generated commit description or body in English. This is the default.
  - `zhtw`: write the generated commit description or body in Traditional Chinese. Keep type and trailers in English, scope can be in English or Chinese depending on what fits better.
  - Keep Conventional Commit type/scope tokens and trailers such as `feat`, `fix`, and `BREAKING CHANGE:` in English.
- Scope flags:
  - `last-chat-edit`: fastest scope. Use the latest assistant edit batch from this conversation as the primary commit scope. Assume the user staged it. Inspect staged file names/stat first and avoid full patch reads unless needed.
  - `all-chat-edits`: fast scope. Use all assistant-made edits from this conversation as the primary commit scope. Assume the user staged them. Inspect staged file names/stat first and avoid full patch reads unless needed.
  - `recent-last`: alias for `last-chat-edit`.
  - `recent-all`: alias for `all-chat-edits`.
  - Do not use plain `recent`; it is ambiguous. Ask the user whether they mean `recent-last` or `recent-all`.
- Treat all remaining arguments as hints for type, scope, description, file selection, or commit grouping.

## Workflow

1. Parse arguments to determine mode, language, scope flags, and any commit hints.
2. Inspect repository state with `git status --porcelain`.
3. When `last-chat-edit`, `recent-last`, `all-chat-edits`, or `recent-all` is provided, use the fast chat-context path:
   - For `last-chat-edit` or `recent-last`, use only the latest assistant edit batch as the logical commit scope.
   - For `all-chat-edits` or `recent-all`, use all assistant-made edits in the current conversation as the logical commit scope.
   - Assume the user staged that scope. Run `git diff --cached --name-status` and `git diff --cached --stat` before drafting.
   - Do not inspect full patches unless staged files are missing, ambiguous, secret-like, unexpected, or the user requests a detailed commit body.
   - If staged files do not match the expected chat-edited scope, inspect only targeted diffs for the expected files before deciding whether to draft, ask, stage, or stop.
4. In `draft` mode without a fast scope flag, inspect staged changes with `git diff --cached --name-status` and `git diff --cached --stat`. If staged changes exist, draft from those summaries and inspect full staged patches only when filenames/stat are insufficient for an accurate message. If nothing is staged, inspect unstaged changes with `git diff --name-status` and `git diff --stat`, then inspect full unstaged patches only when needed. Do not stage files, run commit checks, or create a commit.
5. In `commit` mode without a fast scope flag, inspect staged changes with `git diff --cached --name-status` and `git diff --cached --stat`. If staged changes exist, draft from those summaries and inspect full staged patches only when needed. If nothing is staged, inspect unstaged changes with `git diff --name-status` and `git diff --stat`, inspect full unstaged patches only when needed, then stage the files that belong to one logical change. In fast scope mode, stage only files that match the selected chat-edited scope unless the user explicitly expands the scope.
6. Check relevant filenames for obvious secrets or private credentials, including `.env`, private keys, credential JSON, tokens, and generated secret dumps.
7. Choose a Conventional Commit message using the rules below:
   - `feat`: new feature
   - `fix`: bug fix
   - `docs`: documentation only
   - `style`: formatting without behavior changes
   - `refactor`: code change without feature or bug fix
   - `perf`: performance improvement
   - `test`: tests only
   - `build`: build system or dependencies
   - `ci`: CI/config automation
   - `chore`: maintenance or repository housekeeping
   - `revert`: revert a prior commit
8. Keep the description imperative, present tense, and under 72 characters when practical.
9. Use a body only when it clarifies a non-obvious change, breaking change, migration note, or multi-area commit.
10. In `draft` mode, respond with the proposed commit message in a fenced `text` block, mention that no commit was created, and stop.
11. In `commit` mode, run `git diff --cached --check` before committing.
12. Commit with `git commit -m "<type>[optional scope]: <description>"` or a multi-line message when needed.
13. Finish with `git status --short` and report the commit hash and message.

## Additional Conventional Commit Rules

- Use `!` after the type/scope or a `BREAKING CHANGE:` footer only when the diff clearly introduces a breaking API, configuration, or behavior change.
- If one diff contains unrelated commit types, split it into separate commits when practical.
- Use footers only for useful trailers such as `BREAKING CHANGE:`, `Refs:`, or `Closes:`.

## Safety Rules

- Never update git config.
- Never run destructive commands such as `git reset --hard`, `git clean`, or force operations unless the user explicitly asks.
- Never use `--no-verify` unless the user explicitly asks.
- Never force push to `main` or `master`.
- Never commit obvious secrets. Stop and explain what needs review if a secret-like file is staged.
- Never stage files or create commits in `draft` or `paste` mode.
- If hooks fail, fix the reported issue and create a normal commit. Do not amend unless the user asks.

## Message Examples

```text
feat(auth): add password reset flow
```

```text
fix(api): handle empty search results
```

```text
docs(readme): clarify sync workflow
```

```text
chore(sync): archive unused copilot assets
```

```text
feat(api)!: require explicit project id

BREAKING CHANGE: config files must now include projectId.
```

