# Working in this repository

Read this before changing anything here. This repo configures Claude Code, Codex and
Copilot themselves, so a mistake silently changes how every future session behaves.

`home/` is the [chezmoi](https://www.chezmoi.io) source state. Files under it are **not**
live config — they are rendered into the home directory by `chezmoi apply`.

## Rules

**Never edit a live file to change this repo.** Editing `~/.claude/rules/javascript.md`
changes nothing durably; chezmoi will overwrite it on the next apply. Edit the source in
`home/`, or use `chezmoi re-add <live path>` to pull a live edit back in.

**Never duplicate a shared instruction.** Bodies live once in `home/.chezmoitemplates/`.
If a rule needs different frontmatter per tool, that is what the per-tool `.tmpl` files are
for — add a template, do not copy the text.

**Never reword a rule to make it "tool-neutral".** If a rule names one tool's machinery it
belongs in that tool's own file only. A neutral paraphrase living alongside the original is
the failure mode this structure exists to prevent.

**Codex cannot import and cannot path-scope.** `~/.codex/AGENTS.md` must stay one literal
file with no YAML frontmatter — Codex renders frontmatter as visible text and it counts
against `project_doc_max_bytes` (32 KiB). Do not add per-language rules for Codex.

**Do not commit secrets.** `${input:...}` in `mcp.json` is a prompt definition, not a
value. Keep it that way.

## Before you finish

Run these. The first two catch the failure modes that have actually happened here.

```bash
chezmoi diff                     # must not target any path inside this repo
chezmoi status                   # empty after apply
```

**File-count parity after any bulk move.** chezmoi's source-state naming silently
transforms filenames, and this has caused real loss:

```bash
chezmoi apply --destination="$(mktemp -d)" --exclude=scripts
# then compare file counts between home/dot_agents/skills and the rendered copy
```

Known traps, all already handled — preserve them:

| Trap | Handling |
| --- | --- |
| Real filename starts with an attribute prefix | `literal_create_validation_image.py` |
| Empty file must still exist | `empty___init__.py` (office skills' package markers) |
| App owns the file, must not be overwritten | `create_config.toml.tmpl` (Codex) |
| Dotfile inside a managed tree | `dot_security-scan-passed` |

Files beginning with `.` in the source state are ignored by chezmoi. That is why
`home/dot_agents/skills/.gitignore` stays a repo-only file and is not deployed.

**Do not put package installers in `home/.chezmoiscripts/`.** Anything there runs on every
`chezmoi apply`, so a routine apply — or a test render — installs software. That happened
once during this repo's migration. Bootstrap lives in `scripts/`, run by hand. Still pass
`--exclude=scripts` when test-rendering, in case a script is ever added.

## Adding a shared instruction

1. Body → `home/.chezmoitemplates/rules/<name>.md`, no frontmatter.
2. Glob → `home/.chezmoidata.yaml`.
3. One thin template per tool: `dot_claude/rules/<name>.md.tmpl` (`paths:`) and
   `dot_copilot/instructions/<name>.instructions.md.tmpl` (`applyTo:`).
4. Verify the rendered bodies are byte-identical apart from frontmatter.

## Verify against docs, not memory

Configuration details for these tools drift between releases — discovery directories,
frontmatter keys, deprecations. Check current official documentation before changing a
path or a key. `dotfiles-setup.md` lists the specific details known to be version-sensitive
and links the references.
