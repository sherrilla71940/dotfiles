# Working in this repo with chezmoi

Practical guide: where a file goes, how to change it, and how to remove it.

`home/` is the chezmoi **source state**. Files there are not live config — `chezmoi apply`
renders them into your home directory. `.chezmoiroot` (containing `home`) is what points
chezmoi at that subdirectory, so the repo root stays readable.

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
| `dot_claude/` | `rules/` | *symlink* | `agents/` | `commands/` |
| `dot_copilot/` | `instructions/` | `skills/` | `agents/` | *VS Code profile* |
| `dot_codex/` | `AGENTS.md.tmpl` | *shared tree* | — | *none* |
| shared | `.chezmoitemplates/` | `dot_agents/skills/` | — | — |

### Why a folder is missing

- **`dot_claude/skills/` cannot exist.** `~/.claude/skills` is already claimed by
  `symlink_skills.tmpl`, which points at the shared tree. Adding the folder makes chezmoi
  fail with `.claude/skills: inconsistent state`. Claude reads personal skills from that
  one path only, so a Claude-exclusive skill has nowhere to go without abandoning the
  symlink and merging per skill instead. If that need ever arises, that is the trade to
  reopen.
- **`dot_codex/skills/` would be wrong.** `~/.codex/skills` holds Codex's own bundled
  `.system` skills. User skills belong in `~/.agents/skills`, which Codex scans natively —
  that is what `dot_agents/skills/` is.
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

Edit the **source**, not the rendered file, and never re-add a template:

| You want to | Do this | Not this |
| --- | --- | --- |
| Change a shared rule's text | edit `.chezmoitemplates/rules/<name>.md` | `chezmoi add` |
| Change a glob | edit `.chezmoidata.yaml` | `chezmoi add` |
| Change a single-tool rule | edit the plain file in that tool's folder | `chezmoi add` |
| Adopt a brand-new file | `chezmoi add ~/.newfile` | — |

`chezmoi add` on a managed template prompts
`would remove template attribute, continue?` — answering yes flattens the template into a
literal copy and loses both the shared body and the single-source glob. Use `chezmoi edit`.

## Adding a skill

Portable skill → `home/dot_agents/skills/<name>/SKILL.md`. Tool-exclusive → that tool's
`skills/` folder. Nothing else to wire: the whole tree is copied, so a new skill needs no
registration anywhere.

Check the body for harness-specific tool names ("the Read tool", "the Edit tool") before
putting a skill in the shared tree — those read wrong in the other assistants.

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

Use `--exclude=scripts` for any test render.

## OS differences

1. `{{ if eq .chezmoi.os "windows" }}` inside a template — see
   `dot_claude/settings.json.tmpl`.
2. `home/.chezmoiignore` — excludes the VS Code tree for the other OS.
3. A template that renders empty is not written at all — that is how `dot_zshrc.tmpl`
   produces no `.zshrc` on Windows.

Derive paths from `{{ .chezmoi.homeDir }}`; never hardcode a user directory.
