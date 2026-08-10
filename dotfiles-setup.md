# Dotfiles setup

This repository tracks durable configuration for Claude Code, Codex, GitHub Copilot,
VS Code and shells across Windows and macOS, managed with [chezmoi](https://www.chezmoi.io).
Credentials, sessions, caches, logs, memory and workspace state stay local.

`home/` is the chezmoi source state; `.chezmoiroot` points chezmoi at it so the repo root
stays readable.

## Onboarding a new machine

**macOS**

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-repo-url>
```

**Windows** (PowerShell)

```powershell
winget install twpayne.chezmoi
chezmoi init --apply <your-repo-url>
```

`init --apply` clones the repo, renders every template for this OS, and writes the files.
Restart each application afterwards — editors and CLIs read these files at startup.

VS Code extensions are kept out of the automatic bootstrap because the manifest holds 114
of them. Restore them on request:

```bash
grep -v '^#' vscode-extensions.txt | grep . | xargs -n1 code --install-extension --force
```

```powershell
Get-Content vscode-extensions.txt | Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object { code --install-extension $_ --force }
```

## Migrating a machine that used the old symlink installer

Earlier revisions symlinked live paths into this repo. chezmoi writes **real files**, and
applying over a surviving symlink would write *through* it and modify the repo. Remove the
old links first, then confirm the diff is clean:

```bash
for p in ~/.claude/dotfiles ~/.claude/CLAUDE.md ~/.claude/commands ~/.claude/rules \
         ~/.claude/shared ~/.claude/settings.json ~/.claude/skills ~/.codex/AGENTS.md \
         ~/.agents/skills ~/.copilot/agents ~/.copilot/instructions ~/.copilot/skills \
         ~/.bashrc ~/.bash_profile; do
  [ -L "$p" ] && rm -f "$p"
done
chezmoi diff        # additions only, and no path inside the repo
chezmoi apply -v
```

The VS Code profile links (`settings.json`, `keybindings.json`, `mcp.json`, `prompts`)
need the same treatment under `%APPDATA%\Code\User` or
`~/Library/Application Support/Code/User`.

## Daily workflow

| Task | Command |
| --- | --- |
| Edit a managed file | `chezmoi edit ~/.claude/CLAUDE.md` |
| Preview pending changes | `chezmoi diff` |
| Apply | `chezmoi apply -v` |
| Pull another machine's changes | `chezmoi update -v` |
| Adopt an edit made directly to a live file | `chezmoi re-add ~/.zshrc` |
| Open the source repo | `chezmoi cd` |

Because chezmoi copies rather than links, editing a live file directly does **not** show up
in `git status`. Either edit through `chezmoi edit`, or make the change live and pull it
back with `chezmoi re-add`.

## Adding a file

1. `chezmoi add ~/.some-config` — chezmoi copies it into `home/` with the right name.
2. `chezmoi cd`, then `git add` and `git commit`.

Naming rules that bite, all handled by chezmoi's source-state attributes:

| Situation | Source name |
| --- | --- |
| Target starts with `.` | `dot_name` |
| Target name really starts with `create_`, `run_`, `symlink_`, … | `literal_create_name` |
| Target must exist but be empty (e.g. `__init__.py`) | `empty___init__.py` |
| Write once, never overwrite (the app owns the file) | `create_name` |
| Needs templating | `name.tmpl` |

Two of these are load-bearing here. `literal_create_validation_image.py` in the pdf skill
would otherwise lose its `create_` prefix, and the empty `__init__.py` package markers in
the office skills would otherwise not be created at all, breaking their imports. Both were
caught by comparing file counts between the source tree and a rendered copy — worth
repeating after any bulk move.

## Adding a shared instruction

This is the one workflow worth memorising, because a missed step silently drops a tool.

1. Write the body in `home/.chezmoitemplates/rules/<name>.md` — **no frontmatter**.
2. Add the glob to `home/.chezmoidata.yaml` under `rules:`.
3. Add one thin template per consuming tool:
   - `home/dot_claude/rules/<name>.md.tmpl` — `paths:` + `includeTemplate`
   - `home/dot_copilot/instructions/<name>.instructions.md.tmpl` — `applyTo:` + `includeTemplate`
4. `chezmoi diff`, then confirm both render with identical bodies.

Codex is deliberately absent from that list: it has no path-scoping, so per-language rules
would be always-on against its 32 KiB `project_doc_max_bytes` budget. Codex receives only
the always-on core, as `~/.codex/AGENTS.md`.

Do not put a rule in both a shared body and a tool's own file. Anything that names one
tool's machinery belongs only in that tool's file — `CLAUDE.md.tmpl` keeps the
`claude-code-guide` rule, the `Agent`/subagent rules and the Bash-vs-PowerShell tool
preference, and none of them appear in the shared core.

## OS differences

Handled three ways, in order of preference:

1. **`{{ if eq .chezmoi.os "windows" }}`** inside a template — used by
   `dot_claude/settings.json.tmpl` for the PowerShell-vs-bash hook commands and the
   Windows-only env vars, replacing two hand-synced settings files.
2. **`.chezmoiignore`** — VS Code stores user files under `AppData/Roaming/Code/User` on
   Windows and `Library/Application Support/Code/User` on macOS. Both trees exist in the
   source state and the wrong one is ignored per OS. The bodies live once in
   `.chezmoitemplates/vscode/`, so nothing is duplicated.
3. **Whole-file gating** — `dot_zshrc.tmpl` renders empty on Windows, and chezmoi does not
   create empty files, so no `.zshrc` appears there.

Paths derive from `{{ .chezmoi.homeDir }}` rather than being hardcoded, so nothing carries
a machine-specific path. `CLAUDE_CODE_GIT_BASH_PATH` used to hardcode a user directory and
is now templated.

## Secrets

Nothing in this repo contains a secret, and it should stay that way.

`mcp.json` references `${input:figma-api-key}` — a VS Code **prompt definition**, not a
value. VS Code renders the prompt and caches the token itself. That is why `mcp.json` stays
in the VS Code profile directory rather than `~/.copilot/mcp-config.json`, which is
documented for servers needing no interactive input.

If a real secret is ever required, use a chezmoi secret source (`onepasswordRead`,
`bitwarden`, or an environment variable read in a template) rather than committing a value.

## What chezmoi deliberately does not own

- **`~/.codex/config.toml`** uses the `create_` prefix: written only if absent, never
  overwritten, because Codex stores project trust, marketplace data and runtime executable
  paths in the same file. To reapply a durable change, edit
  `home/dot_codex/create_config.toml.tmpl` and merge by hand.
- **`~/.copilot/config.json`, `ide/`, `logs/`** are Copilot runtime state.
- **`~/.claude/skills`** is the only symlink in the setup, pointing at `~/.agents/skills`.
  Claude Code reads personal skills from that one directory and has no setting to add
  another (`--add-dir` works; `permissions.additionalDirectories` explicitly does not), so
  the shared tree is linked in rather than copied twice.

## Verify

```bash
chezmoi status     # empty output means everything is applied
chezmoi doctor     # environment sanity
```

Then per tool:

- **Claude Code** — `/context` shows `CLAUDE.md` with the core text inlined. The five
  language rules are path-scoped and will **not** appear on a fresh session; open a `.ts`
  file and re-check. `/skills` lists 17.
- **Codex** — `~/.codex/AGENTS.md` starts with `# Core Principles` and contains **no** YAML
  frontmatter. `/skills` lists the shared set.
- **Copilot** — *Chat: Open Customizations* lists 9 instruction files. *Chat → Diagnostics*
  shows `javascript` and `typescript` applying for a `.ts` file and not for a `.css` file.
- **Bodies match across tools:**

  ```bash
  diff <(sed '1,/^---$/d;1,/^---$/d' ~/.claude/rules/javascript.md) \
       <(sed '1,/^---$/d;1,/^---$/d' ~/.copilot/instructions/javascript.instructions.md)
  ```

## Version-sensitive details

Confirm these against current documentation rather than assuming; they have changed before:

- Claude Code: `~/.claude/rules` and `~/.claude/skills` discovery, and whether unknown
  frontmatter keys are ignored.
- Copilot: `~/.copilot/instructions` versus the VS Code profile directory own different
  customization types, and `*.instructions.md` does **not** support `@` includes.
- Codex: custom prompts (`~/.codex/prompts`) are **deprecated** in favour of skills.
- `disable-model-invocation: true` stops `git-commit-action` auto-running; Codex has no
  documented equivalent, so verify before relying on that guard there.

## Not yet managed

PowerShell profile, Windows Terminal, `.gitconfig`, broader package manifests, secrets
integration, and a work-versus-personal split. The structure supports each without rework.

## References

- [chezmoi quick start](https://www.chezmoi.io/quick-start/) ·
  [source state attributes](https://www.chezmoi.io/reference/source-state-attributes/) ·
  [special files](https://www.chezmoi.io/reference/special-files/)
- [Claude Code memory and rules](https://code.claude.com/docs/en/memory) ·
  [skills](https://code.claude.com/docs/en/skills)
- [Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) ·
  [config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [VS Code custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions) ·
  [agent skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Copilot CLI custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)
