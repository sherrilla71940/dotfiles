# Working in this repo with chezmoi

Practical guide: where a file goes, how to change it, and how to remove it.

`home/` is the chezmoi **source state**. Files there are not live config — `chezmoi apply`
renders them into your home directory. `.chezmoiroot` (containing `home`) is what points
chezmoi at that subdirectory, so the repo root stays readable.

## Source vs target — the distinction everything else rests on

| | Path | Purpose |
| --- | --- | --- |
| **Source** | `home/.chezmoitemplates/core.md`, `home/dot_claude/…` | what you edit and commit |
| **Target** | `~/.claude/CLAUDE.md`, `~/.bashrc` | what the tools read |

`chezmoi apply` turns source into target. The two never swap roles, which decides every
command you use:

- **Edited a source file** (anything under `home/`) → just `chezmoi apply`. There is nothing
  to "add"; it is already in the source state.
- **Edited a target file** (something in your home directory) → `chezmoi re-add` to pull it
  back, and note that this silently skips templates.

**`chezmoi add` always takes a target path, never a source path.** `chezmoi add ~/.bashrc`
is correct; `chezmoi add home/.chezmoitemplates/core.md` is meaningless — it would try to
manage a repo file as if it were one of your dotfiles.

## Where does my file go?

Start here whenever you add something.

```
How many tools consume it?
├── ONE  → a plain file in that tool's folder. Write the frontmatter yourself.
│           home/dot_claude/    home/dot_codex/    home/dot_copilot/
└── MANY → body in home/.chezmoitemplates/
            + one thin .tmpl per consuming tool
```

Templating exists for exactly one reason: **the three tools disagree about how to scope an
instruction**, so one shared file cannot satisfy all of them.

| Tool | Scopes with | Imports other files? |
| --- | --- | --- |
| Claude Code | `paths:` frontmatter | yes (`@path`) |
| GitHub Copilot | `applyTo:` frontmatter | Markdown links only, same directory |
| Codex | **nothing** | **no** |

Which tools share what today:

| Shared body | Consumed by |
| --- | --- |
| `.chezmoitemplates/core.md` | **all three** — Claude inlines it in `CLAUDE.md`, Codex renders it as `AGENTS.md` with no frontmatter, Copilot as `core-principles.instructions.md` |
| `.chezmoitemplates/rules/*.md` | Claude and Copilot — Codex is excluded because it cannot path-scope |
| `.chezmoitemplates/vscode/*` | one body, two OS-specific VS Code profile locations |

## Where each customization type lives

Folders that exist are ready to use. Folders that are **absent are absent on purpose** —
each one is listed below with the reason, so a future you does not "helpfully" recreate a
broken one.

| | Instructions | Skills | Subagents | Prompts / commands |
| --- | --- | --- | --- | --- |
| `dot_claude/` | `rules/` | `skills/` | `agents/` | `commands/` |
| `dot_copilot/` | `instructions/` | `skills/` | `agents/` | *VS Code profile* |
| `dot_codex/` | `AGENTS.md.tmpl` | *shared tree* | `agents/` | *none* |
| shared | `.chezmoitemplates/` | `dot_agents/skills/` | — | — |

### Why a folder is missing

- **`dot_claude/skills/` contains both kinds.** A regular skill directory is Claude-only.
  Each `symlink_<name>.tmpl` entry points to one portable skill in `~/.agents/skills`, so
  shared and Claude-only skills can coexist without copying skill bodies.
- **`dot_codex/skills/` would be wrong.** `~/.codex/skills` holds Codex's own bundled
  `.system` skills and is not a documented personal-skill location. Codex user skills
  normally belong in `~/.agents/skills`, which Copilot also scans. This repository therefore
  treats them as portable shared skills. If a skill must be Codex-only, verify the current
  Codex-supported isolation options before adding it; do not assume a plugin is required.
- **`dot_codex/prompts/` is deliberately unused.** Custom prompts (`~/.codex/prompts`) are
  deprecated by OpenAI in favour of skills. Write a skill instead.
- **`dot_copilot/prompts/` would do nothing.** VS Code reads `*.prompt.md` from the
  **profile** directory, not `~/.copilot`. The body lives in `.chezmoitemplates/vscode/`
  and renders into `home/AppData/...` and `home/Library/...`.
- **`dot_codex/rules/` is impossible.** Codex has no path-scoping mechanism at all.

### Placeholders

`dot_claude/agents/` ships empty, holding only a `.gitkeep`. chezmoi ignores files starting
with `.`, but still creates the directory, so `~/.claude/agents/` exists before a session
starts — the docs note that a running session will not pick up an `agents` directory
created part-way through. Use the same pattern for any future folder: create it with a
`.gitkeep` rather than waiting until you need it.

## Adding an instruction

### Case 1 — only one tool needs it (the simple case)

Drop a **plain file** into that tool's folder and write the frontmatter yourself. No
template, no data entry, no `.tmpl` suffix — chezmoi copies it verbatim.

`home/dot_claude/rules/python.md`
```markdown
---
paths:
  - "**/*.py"
---

# Python Guidelines

- ...
```

`chezmoi apply`, and it lands at `~/.claude/rules/python.md` byte-for-byte. Copilot and
Codex never see it.

The Copilot equivalent is `home/dot_copilot/instructions/<name>.instructions.md` with
`applyTo:`. Claude-only rules that belong with the others can also go straight into
`home/dot_claude/CLAUDE.md.tmpl`, below the `# Claude Code only` marker.

**Use this whenever the rule names one tool's machinery** — `Agent` calls, the
`claude-code-guide` agent, the Bash-vs-PowerShell *tools*. Those must not be paraphrased
into the shared body.

### Case 2 — more than one tool needs it

Now the frontmatter differs per tool, so the body is shared and each tool gets a thin
wrapper.

1. **Body** → `home/.chezmoitemplates/rules/<name>.md`. **No frontmatter.**
2. **Glob** → `home/.chezmoidata.yaml`:
   ```yaml
     <name>:
       glob: "**/*.{ts,tsx}"
       title: Your Topic
   ```
3. **One thin template per consuming tool:**

   `home/dot_claude/rules/<name>.md.tmpl`
   ```
   ---
   paths:
     - "{{ (index .rules "<name>").glob }}"
   ---

   {{ includeTemplate "rules/<name>.md" -}}
   ```

   `home/dot_copilot/instructions/<name>.instructions.md.tmpl`
   ```
   ---
   applyTo: "{{ (index .rules "<name>").glob }}"
   description: '{{ (index .rules "<name>").title }} rules, shared with Claude Code.'
   ---

   {{ includeTemplate "rules/<name>.md" -}}
   ```
4. `chezmoi diff`, then confirm the bodies match:
   ```bash
   diff <(sed '1,/^---$/d;1,/^---$/d' ~/.claude/rules/<name>.md)         <(sed '1,/^---$/d;1,/^---$/d' ~/.copilot/instructions/<name>.instructions.md)
   ```

**Do not add a Codex wrapper for a language rule.** Codex has no path-scoping, so it would
be always-on against its 32 KiB `project_doc_max_bytes` budget. Codex participates in the
shared **core** only, via `dot_codex/AGENTS.md.tmpl`.

**Never write the same rule twice.** A rule that names one tool's machinery belongs in that
tool's file only, never paraphrased into a "neutral" copy in the shared body.

### Why the template looks like it has no frontmatter

In `home/dot_claude/rules/accessibility.md.tmpl`, line 1 is a Go template comment, so `---`
sits on line 2 — and editors only highlight YAML frontmatter when `---` is the very first
line. The `{{-` and `-}}` trim markers strip the comment and its newline, so the rendered
file starts with `---` on line 1. The frontmatter is real; only the glob is substituted.

## Editing something already managed

**You do not have to use chezmoi commands.** Editing a file directly in your home
directory works — but chezmoi does not notice, so the source becomes older than the target
and your next `chezmoi apply` overwrites the edit. You have to bring it back.

Which route is safe depends on whether the file is a template:

| The file | Edit live, then… | Or edit the source |
| --- | --- | --- |
| **Not a template** — `dot_bashrc`, skills, a single-tool rule | `chezmoi re-add ~/.bashrc` ✅ captures it | `chezmoi edit ~/.bashrc` |
| **A template** — `.tmpl` files: shared rules, `CLAUDE.md`, `settings.json` | `chezmoi re-add` **silently skips it** ⚠️ | `chezmoi edit` opens the `.tmpl` |

`chezmoi re-add` is safe against templates by design — its help says *"chezmoi will not
overwrite templates"*. The danger is the opposite of what you might expect: it does not
destroy your template, it **ignores your live edit**, which then vanishes on the next
apply with no warning. Verified by test.

`chezmoi add` on a template is the destructive one. It prompts
`would remove template attribute, continue?`, and answering yes flattens the template into
a literal copy, losing the shared body and the single-source glob.

Rules of thumb:

- **Templated file** → always `chezmoi edit`, or edit the source under `home/` directly.
  Remember that for a shared rule the text lives in `.chezmoitemplates/`, not in the
  `.tmpl` wrapper.
- **Plain file** → edit live if you prefer, then `chezmoi re-add`. Run `chezmoi diff` first
  to see what will change.
- **Brand-new file** → `chezmoi add ~/.newfile`.

Which files are templates? `chezmoi managed` lists everything; anything whose source name
ends in `.tmpl` is one. In this repo that is: all shared rules, `CLAUDE.md`,
`settings.json`, `AGENTS.md`, `config.toml`, the Copilot instruction wrappers, the VS Code
files and `dot_zshrc`.

### Apps that write their own config

Applications can update the same files that contain portable preferences. Ownership differs
by client, so use the matching workflow:

| Live file | Ownership policy | Preserve a UI or CLI change |
| --- | --- | --- |
| VS Code `settings.json` | managed template | edit `home/.chezmoitemplates/vscode/settings.json`; `re-add` skips it |
| Claude `~/.claude/settings.json` | managed template, including the selected model, effort, theme, and TUI | edit `home/dot_claude/settings.json.tmpl`; `/model`, `/effort`, `/theme`, and similar live changes are temporary until added there |
| Copilot `~/.copilot/settings.json` | plain managed file | run `chezmoi diff`, then `chezmoi re-add ~/.copilot/settings.json` and review the source diff |
| Codex `~/.codex/config.toml` | create-once mixed state | merge only missing durable declarations manually; never replace the complete live file |

Claude's current durable model is `opus[1m]` with high effort. Changing either through the
UI does not update the template, so a later apply restores the repository values unless the
source is updated.

## Editing the working agreement (the common case)

`~/.claude/CLAUDE.md` is assembled from two sources, so "edit my CLAUDE.md" splits in two.
The rendered file carries a signpost at the top telling you which is which — Claude Code
strips block-level HTML comments before loading, so that note costs no context.

| Your change | Edit | Shortcut | Reaches |
| --- | --- | --- | --- |
| Above the `# Claude Code only` marker | `home/.chezmoitemplates/core.md` | `dotf-core` | Claude + Codex + Copilot |
| Below the marker | `home/dot_claude/CLAUDE.md.tmpl` | `dotf-claude` | Claude only |

Then `dotf-diff` and `dotf-apply`.

The test for which half: **would this sentence still be correct if Codex or Copilot read
it?** Yes → shared body. No, it names a Claude feature → below the marker.

⚠️ `chezmoi edit ~/.claude/CLAUDE.md` opens the *Claude-only* template. It cannot open the
shared body, because that text is not in that file — it is pulled in by `includeTemplate`.
Use `dotf-core` for shared changes.

The aliases are defined in `home/dot_bashrc` and `home/dot_zshrc.tmpl`:
`dotf` (cd to source), `dotf-core`, `dotf-claude`, `dotf-diff`, `dotf-apply`.

## Adding a skill

Portable skill → `home/dot_agents/skills/<name>/SKILL.md`, plus
`home/dot_claude/skills/symlink_<name>.tmpl` pointing to
`{{ .chezmoi.homeDir }}/.agents/skills/<name>`.

Claude-only skill → `home/dot_claude/skills/<name>/SKILL.md`.

Copilot-only skill → `home/dot_copilot/skills/<name>/SKILL.md`.

Codex personal skills normally live in `~/.agents/skills`, which Copilot also scans. This
repository therefore treats them as portable shared skills. If a skill must be Codex-only,
verify the current Codex-supported isolation options before adding it; do not assume a plugin
is required.

Check the body for harness-specific tool names ("the Read tool", "the Edit tool") before
putting a skill in the shared tree — those read wrong in the other assistants.

Because these are source-state edits, run `chezmoi apply`; do not run `chezmoi add`.
`chezmoi add` is only for importing a brand-new file created at its target path under the
home directory, and it happens before committing so the source-state change can be
reviewed and committed.

## Installing a third-party plugin

Installing a marketplace plugin and reproducing that installation on another machine are
different operations. Port the desired marketplace and plugin declarations; do not port the
downloaded plugin files:

| Client | What follows machines today | When installing another plugin |
| --- | --- | --- |
| Claude Code | known marketplaces and enabled plugin IDs in `home/dot_claude/settings.json.tmpl` | add the plugin to `enabledPlugins`; applying the managed settings lets Claude resolve it from the declared marketplace |
| Codex | marketplace and enabled-plugin defaults in `home/dot_codex/create_config.toml.tmpl`, but only when the live config does not exist yet | update the template for new machines; for an existing app-owned config, compare first and merge only missing declarations |
| GitHub Copilot | plugin support, default marketplaces, and declarative plugin IDs in `home/dot_copilot/settings.json` | add the plugin specification to `enabledPlugins`; Copilot CLI auto-installs it and VS Code discovers the installation |

"Declarative" here means that the source state records the desired plugin ID and enablement;
the client still downloads and owns the plugin cache.

`chezmoi apply` does not remove locally installed plugins for any client. Do not copy plugin
caches or installed-plugin directories into `home/`; those are runtime state. Add marketplace
declarations, desired plugin identifiers, or an explicit bootstrap step instead when an
installation needs to be reproducible.

If an interactive Copilot installation changed live `~/.copilot/settings.json`, run
`chezmoi diff` and `chezmoi re-add ~/.copilot/settings.json` before the next apply, then review
the source diff. Prefer adding the declaration to the source file first.

For agents, prompts, plugins, and MCP configuration across all clients, use the complete
[customization support matrix](./customization-support.md).

## Removing something

This is the part that is easy to get wrong, because deleting the source file is usually
**not** enough — the rendered file stays on disk.

| Goal | Command |
| --- | --- |
| Stop managing it, keep the live file | `chezmoi forget ~/.some-config` |
| Remove it from the source **and** your machine | `chezmoi destroy ~/.some-config` |
| Remove it on **every** machine on next apply | add the target path to `home/.chezmoiremove` |

Practical sequence for retiring a shared rule:

1. Delete `home/.chezmoitemplates/rules/<name>.md` and both thin templates.
2. Delete its entry from `home/.chezmoidata.yaml`.
3. Add `.claude/rules/<name>.md` and `.copilot/instructions/<name>.instructions.md` to
   `home/.chezmoiremove` so other machines clean up too.
4. `chezmoi apply`, then delete the `.chezmoiremove` lines once every machine has applied.

If you simply `git rm` the source, your own machine keeps the stale rendered file until you
delete it by hand — and other machines keep it indefinitely.

## Daily commands

```bash
chezmoi source-path                  # must resolve inside this repository
chezmoi edit ~/.claude/CLAUDE.md   # edit the source behind a live path
chezmoi diff                        # preview
chezmoi apply -v                    # write
chezmoi re-add ~/.zshrc             # pull a direct live edit back into the source
chezmoi update -v                   # git pull + apply, on another machine
chezmoi cd                          # open the source repo
chezmoi status                      # empty means fully applied
```

Because chezmoi copies rather than links, editing a live file directly does **not** appear
in `git status`. Use `chezmoi edit`, or `chezmoi re-add` afterwards.

## Filename rules that will bite you

chezmoi reads attributes off the front of filenames, so real names can be transformed
silently. All of these are load-bearing here:

| Situation | Source name | Consequence if missed |
| --- | --- | --- |
| Target starts with `.` | `dot_zshrc` | file lands as `zshrc` |
| Real name starts with `create_`, `run_`, `symlink_`, … | `literal_create_validation_image.py` | prefix eaten |
| Empty file must still exist | `empty___init__.py` | not created; Python imports break |
| App owns the file, never overwrite | `create_config.toml.tmpl` | Codex's machine state clobbered |
| Needs rendering | `name.tmpl` | template text shipped verbatim |

Files starting with `.` in the source state are ignored entirely by chezmoi — which is why
a repo-only `.gitignore` inside a managed tree is never deployed.

**After any bulk move, check file-count parity**, because these transformations are silent:

```bash
chezmoi apply --destination="$(mktemp -d)" --exclude=scripts
# compare counts against home/dot_agents/skills
```

Use `--exclude=scripts` for any test render. The flag excludes chezmoi script entry types,
not the repository's top-level `scripts/` directory.

## OS differences

1. `{{ if eq .chezmoi.os "windows" }}` inside a template — see
   `dot_claude/settings.json.tmpl`.
2. `home/.chezmoiignore` — excludes the VS Code tree for the other OS.
3. A template that renders empty is not written at all — that is how `dot_zshrc.tmpl`
   produces no `.zshrc` on Windows.

Derive paths from `{{ .chezmoi.homeDir }}`; never hardcode a user directory.
