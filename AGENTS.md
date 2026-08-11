# Working in this repository

Always-on constraints for coding agents. This file is loaded into your context
automatically, so it stays short: it lists only what you could get **wrong**, not how to do
things. Procedures live in [docs/chezmoi-workflow.md](./docs/chezmoi-workflow.md) — read it
before adding, changing or removing anything.

This is a general user-level dotfiles repository. It manages editor, shell, tool, and AI
configuration; the AI files are especially sensitive because a mistake can silently change
how every future agent session behaves.

## The one thing to understand

`home/` is the [chezmoi](https://www.chezmoi.io) **source state**. Files there are not live
config — `chezmoi apply` renders them into the home directory. Editing a live file does not
change this repo, and editing this repo does not change anything until you apply.

## Helping someone operate this repository

Assume the user may know the outcome they want without knowing chezmoi terminology or source
filenames. Translate requests such as "change my VS Code setting" or "make this shell config
follow my machines" into the correct source-state edit and explain unfamiliar terms briefly.

- For questions, inspect the repository and answer without changing files unless a change was
  also requested.
- For changes, locate and edit the source of truth, identify the rendered home-directory
  target, and perform proportionate validation. Do not make the user map `dot_`, `.tmpl`, or
  other chezmoi attributes themselves.
- Before an operation could overwrite, remove, or stop managing live configuration, explain
  the effect in plain language and preview it when possible.
- At handoff, state separately what changed in the repository, whether it was applied to the
  home directory, whether it was committed, and the exact safe next command when one remains.
- Keep guidance task-focused. Link to the relevant guide for background instead of requiring
  the user to read the entire chezmoi manual before proceeding.

## Constraints

**Never duplicate a shared instruction.** Bodies live once in `home/.chezmoitemplates/`.
When a rule needs different frontmatter per tool, add a thin `.tmpl` wrapper — do not copy
the text.

**Never reword a rule to be "tool-neutral".** A rule that names one tool's machinery
belongs in that tool's file only. A paraphrase living alongside the original is the exact
failure this structure exists to prevent.

**Codex cannot import and cannot path-scope.** `~/.codex/AGENTS.md` must stay one literal
file with no YAML frontmatter — Codex renders frontmatter as visible text and it counts
against `project_doc_max_bytes` (32 KiB). Never add a per-language rule for Codex.

**Never overwrite a file an app owns.** `~/.codex/config.toml` uses the `create_` prefix
because Codex writes machine state into it. Keep it that way.

**Never put package installers in `home/.chezmoiscripts/`.** Anything there runs on every
`chezmoi apply`, so a routine apply — or a test render — installs software. That happened
once during this repo's migration. Bootstrap lives in `scripts/`, run by hand.

**Never commit secrets.** `${input:...}` in `mcp.json` is a prompt definition, not a value.

## Before you finish

```bash
chezmoi source-path  # MUST resolve inside this repository; otherwise stop
chezmoi diff         # ALWAYS preview before apply; apply overwrites without prompting
chezmoi status       # empty after apply
```

Never run `chezmoi apply` until the source-path check and diff both succeed. A plain chezmoi
command uses its configured source directory regardless of the current working directory.

**Check file-count parity after any bulk move.** chezmoi reads attributes off the front of
filenames, so real names are transformed silently and files can vanish. This has caused
real loss here twice — four skills dropped in one refactor, and empty `__init__.py` package
markers omitted in another.

```bash
chezmoi apply --destination="$(mktemp -d)" --exclude=scripts
# compare file counts against the source tree
```

Always pass `--exclude=scripts` when test-rendering. This excludes chezmoi-managed script
entry types; it does not refer to the repository's top-level `scripts/` directory.

## Verify against docs, not memory

Configuration details for these tools drift between releases — discovery directories,
frontmatter keys, deprecations. Check current official documentation before changing a path
or a key. [docs/setup.md](./docs/setup.md) lists the details known to be version-sensitive
and links the references.
