# Working in this repo with chezmoi

Practical guide: where a file goes, how to change it, and how to remove it.

`home/` is the chezmoi **source state**. Files there are not live config — `chezmoi apply`
renders them into your home directory. `.chezmoiroot` (containing `home`) is what points
chezmoi at that subdirectory, so the repo root stays readable.

## Where does my file go?

Start here whenever you add something.

```
Is it used by more than one assistant?
├── NO  → that tool's own folder:
│          home/dot_claude/    home/dot_codex/    home/dot_copilot/
└── YES → body in home/.chezmoitemplates/
           + one thin .tmpl per consuming tool
```

The split exists because the three tools disagree about scoping, so a single shared file
cannot serve all of them:

| Tool | Scopes with | Imports other files? |
| --- | --- | --- |
| Claude Code | `paths:` frontmatter | yes (`@path`) |
| GitHub Copilot | `applyTo:` frontmatter | Markdown links only, same directory |
| Codex | **nothing** | **no** |

## Why the per-tool folders look uneven

This trips people up, so it is written down:

| | Instructions | Skills | Prompts / commands |
| --- | --- | --- | --- |
| `dot_claude/` | `rules/` ✔ | — see below | `commands/` ✔ |
| `dot_copilot/` | `instructions/` ✔ | `skills/` ✔ (Copilot-only) | — see below |
| `dot_codex/` | `AGENTS.md.tmpl` only | — see below | — none, deprecated |

- **Skills live in `home/dot_agents/skills/`**, which becomes `~/.agents/skills`. Codex and
  Copilot read that path natively. Claude reads personal skills from `~/.claude/skills` and
  nowhere else, so `dot_claude/symlink_skills.tmpl` points that one path at the shared
  tree. That symlink is the only one in the whole setup.
- **`dot_copilot/skills/`** exists because four skills are Copilot-only (`prompt-builder`,
  `remember`, and the two `suggest-awesome-github-copilot-*`). There is no
  `dot_claude/skills/` because no skill is currently Claude-only.
- **Codex has no skills or prompts folder.** Skills come from `~/.agents/skills`; custom
  prompts (`~/.codex/prompts`) are deprecated by OpenAI in favour of skills, so this repo
  deliberately does not use them.
- **Copilot's prompt file is not under `dot_copilot/`.** VS Code reads `*.prompt.md` from
  the **profile** directory, not `~/.copilot`, so its body sits in
  `.chezmoitemplates/vscode/` and is rendered into `home/AppData/...` and
  `home/Library/...`.

## Adding a shared instruction

1. Body → `home/.chezmoitemplates/rules/<name>.md`. **No frontmatter.**
2. Glob → `home/.chezmoidata.yaml` under `rules:`.
3. One thin template per consuming tool:

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
   ---

   {{ includeTemplate "rules/<name>.md" -}}
   ```
4. `chezmoi diff`, then confirm both bodies render identically.

**Do not add Codex.** It has no path scoping, so a per-language rule would be always-on
against its 32 KiB `project_doc_max_bytes` budget. Codex gets the always-on core only.

**Never write the same rule twice.** If a rule names one tool's machinery it belongs in
that tool's file *only* — not paraphrased into a "neutral" copy in the shared body. That
duplication is the exact failure this structure removes.

## Adding a tool-specific instruction

Put it directly in that tool's folder as a normal file — no template needed unless it
varies by OS. Claude-only rules go in `home/dot_claude/CLAUDE.md.tmpl` below the
`# Claude Code only` marker.

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
