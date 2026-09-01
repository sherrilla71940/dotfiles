---
name: git-commit-reference
description: 'Conventional Commit message conventions: type table, description formatting, breaking-change and footer rules, and message examples. Load this whenever drafting or writing a git commit message, whether committing organically or via /git-commit-action.'
user-invocable: false
---

# Git Commit Reference

Shared conventions for writing a Conventional Commit message. Both organic commits (the agent committing on its own judgment) and the `git-commit-action` skill draw from this file so the style stays in one place.

`user-invocable: false` is set deliberately: this skill is pure reference material with no workflow of its own, so it's hidden from the slash-command menu and only loads when the agent decides it is relevant (or when invoked programmatically), never by the user typing a slash command for it.

## Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Choosing a type

| Type | Purpose |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting/style, no logic change |
| `refactor` | Code change without feature or bug fix |
| `perf` | Performance improvement |
| `test` | Add/update tests |
| `build` | Build system or dependencies |
| `ci` | CI/config automation |
| `chore` | Maintenance or repository housekeeping |
| `revert` | Revert a prior commit |

## Description and body

- Keep the description imperative, present tense, and under 72 characters when practical.
- Use a body only when it clarifies a non-obvious change, breaking change, migration note, or multi-area commit.
- Use `-` bullets in the body when listing multiple distinct changes; prose for a single explanatory point.
- If one diff contains unrelated commit types, split it into separate commits when practical.

## Breaking changes

Use `!` after the type/scope, or a `BREAKING CHANGE:` footer, only when the diff clearly introduces a breaking API, configuration, or behavior change:

```text
feat!: remove deprecated endpoint
```

```text
feat: allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```

## Footers

Use footers only for useful trailers such as `BREAKING CHANGE:`, `Refs:`, or `Closes:`.

## Traditional Chinese (zh-TW) messages

Keep the Conventional Commit type, the scope token and every trailer (`feat`, `fix`,
`BREAKING CHANGE:`, `Refs:`) in English. Write the description and body in Traditional Chinese
for Taiwan — never Simplified. A scope may be English or Chinese, whichever reads better.

A commit message is exactly the register where over-formal phrasing creeps in. Prefer the plain
word:

| Prefer | Over |
| --- | --- |
| `是` / `是因為` | `屬` |
| `這次` | `本次` |
| `在` | `於` |
| `如果` | `若` |
| `都` | `皆` / `全數` |
| `原本` / `現有` | `既有` |
| `問題` / `錯誤` | `勘誤` |
| a direct clause | a noun phrase ending in `者` |

Watch for clustering of `屬 於 若 皆 全數 之 者 既有 勘誤`. Any one may be natural; several
together make an ordinary commit read like a government report.

Use Taiwan terminology — `程式` not `程序`, `專案` not `項目`, `元件` not `組件`, `設定` not
`配置`, `回傳` not `返回` — and keep the English technical terms developers actually use
(`rebase`, `API`, `DB`, `PM`, `BE`, `FE`). Never translate code identifiers, filenames, or
branch names.

```text
fix(parser): 修正欄位不存在時的例外

原本的檢核邏輯沒有處理缺欄位的情況，115 年範本會直接中斷。
這次改成缺欄位就略過，其餘值域檢查維持不動。
```

That is the whole of it for a commit message. For longer zh-TW prose — a PR/MR description,
documentation, an issue body — load the `natural-zhtw` skill instead.

## Message examples

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
refactor(config): reorganize rule files and dedupe conventions

- move the JS/TS naming rule into the path-scoped javascript rule
- keep project comments in zh-tw and user-level configuration comments in English
- regroup the html-css guidelines under topic headings
```

```text
feat(api)!: require explicit project id

BREAKING CHANGE: config files must now include projectId.
```
