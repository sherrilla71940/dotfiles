---
name: git-commit-reference
description: 'Conventional Commit message conventions: type table, description formatting, breaking-change and footer rules, and message examples. Load this whenever drafting or writing a git commit message, whether committing organically or via /git-commit-action.'
user-invocable: false
---

# Git Commit Reference

Shared conventions for writing a Conventional Commit message. Both organic commits (Claude committing on its own judgment) and the `git-commit-action` skill draw from this file so the style stays in one place.

`user-invocable: false` is set deliberately: this skill is pure reference material with no workflow of its own, so it's hidden from the slash-command menu and only loads when Claude decides it's relevant (or via the Skill tool), never by the user typing a slash command for it.

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
feat(api)!: require explicit project id

BREAKING CHANGE: config files must now include projectId.
```
