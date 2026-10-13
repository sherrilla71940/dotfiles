# ADR-0058: Parse skill frontmatter in staged-source validation

- Status: Accepted
- Date: 2026-10-13

## Context

The pre-commit hook renders staged chezmoi source and checks skill file counts, links, and
selected metadata fields with regular expressions. It accepted an unquoted `description` value
containing `: ` in `task-record/SKILL.md`. Chezmoi's YAML parser rejected that frontmatter, so
clients could load the skill without its description despite a successful commit hook.

## Decision

After rendering the staged source, parse the frontmatter of every rendered `SKILL.md` under
`.agents/skills`, `.claude/skills`, and `.copilot/skills` with chezmoi's `fromYaml`. Require
opening and closing delimiters and nonempty `name` and `description` fields. Keep the existing
host-gate and wrapper checks; they validate different contracts. Use the chezmoi binary the
hook already requires instead of installing another YAML parser.

## Consequences

Malformed skill metadata now blocks commits, including metadata produced by a template or a
client-specific wrapper. The check adds one chezmoi parser call per rendered skill to the
pre-commit run. A focused test covers a valid description containing a colon, the malformed
description that escaped the old hook, and a missing closing delimiter. The check reads only
the temporary staged render and does not apply changes to the home directory.
