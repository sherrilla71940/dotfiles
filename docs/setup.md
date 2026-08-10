# Dotfiles setup

This repository tracks durable configuration for Claude Code, Codex, GitHub Copilot,
VS Code and shells across Windows and macOS, managed with [chezmoi](https://www.chezmoi.io).
Credentials, sessions, caches, logs, memory and workspace state stay local.

`home/` is the chezmoi source state; `.chezmoiroot` points chezmoi at it so the repo root
stays readable.

## Onboarding a new machine

### What to install first

**Only chezmoi and git are required.** Everything else is optional, and the order does not
matter — see [What if an app isn't installed](#what-if-an-app-isnt-installed) below.

| Step | macOS | Windows |
| --- | --- | --- |
| 1. Package manager | [Homebrew](https://brew.sh) | App Installer (winget), preinstalled on Win 11 |
| 2. Baseline tools | `bash scripts/bootstrap-macos.sh` | `powershell -File scripts/bootstrap-windows.ps1` |
| 3. Apply the dotfiles | `chezmoi init --apply <repo-url>` | `chezmoi init --apply <repo-url>` |
| 4. The apps themselves | Claude Code, Codex, VS Code, Copilot — any subset, any time | same |

The bootstrap script installs git, jq and chezmoi, and is safe to re-run. If you would
rather not run it, install chezmoi directly:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo-url>
```

```powershell
winget install twpayne.chezmoi
chezmoi init --apply <repo-url>
```

`init --apply` clones the repo, renders every template for this OS, and writes the files.

### What if an app isn't installed?

**Nothing breaks.** chezmoi writes plain files and directories; it never asks whether an
application exists. If you have no Codex, `~/.codex/AGENTS.md` is still created, and Codex
picks it up the first time you run it. The same is true for Claude Code, Copilot and
VS Code.

That means the two orders both work:

- **Apply first, install apps later** — each app finds its configuration already in place
  on first launch. This is the simpler path on a fresh machine.
- **Install apps first, then apply** — lets you verify immediately (see [Verify](#verify)),
  at the cost of `--migrate`-style cleanup if an app already wrote its own defaults.

Two caveats worth knowing:

- **`chezmoi apply` overwrites an app's own edits** to any managed file. If Claude Code or
  VS Code has already written `settings.json`, applying replaces it with this repo's
  version. Run `chezmoi diff` first to see exactly what would change. `~/.codex/config.toml`
  is exempt — it uses `create_`, so it is written once and never overwritten.
- **Restart each application after applying.** Editors and CLIs read these files at
  startup, so a running session will not see them.

### VS Code extensions

Kept out of the bootstrap because the manifest holds 114 of them. Restore on request:

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
| Preview pending changes | `chezmoi diff` |
| Apply | `chezmoi apply -v` |
| Edit a managed file | `chezmoi edit ~/.claude/CLAUDE.md` |
| Capture an edit you made directly to a live file | `chezmoi re-add ~/.bashrc` |
| Pull another machine's changes | `chezmoi update -v` |
| Open the source repo | `chezmoi cd` |

You can edit live files directly instead of using `chezmoi edit` — but chezmoi will not
notice, and the next `apply` overwrites your change unless you `chezmoi re-add` it. That
works for plain files; for **templates** `re-add` silently skips the file and your edit is
lost. See
[Editing something already managed](./chezmoi-workflow.md#editing-something-already-managed)
for which files are templates and which route is safe.

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

## Adding, changing and removing files

See [docs/chezmoi-workflow.md](./chezmoi-workflow.md) — it covers where a file belongs,
why the per-tool folders look uneven, and how to remove something properly (deleting the
source is not enough; the rendered file survives until `chezmoi destroy` or
`.chezmoiremove`).

The short version for a shared instruction: body in
`home/.chezmoitemplates/rules/<name>.md` with no frontmatter, glob in
`home/.chezmoidata.yaml`, then one thin `.tmpl` per consuming tool.

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

## Copilot reads more folders than you think

VS Code discovers user-level instructions from several harness-agnostic folders at once,
including `~/.copilot/instructions` **and** `~/.claude/rules`. Because this repo renders the
same rules into both, Copilot listed every shared rule twice — once with a description from
its own `.instructions.md`, once bare from Claude's `.md`.

Worse, `chat.useClaudeMdFile` made Copilot ingest `~/.claude/CLAUDE.md`, whose lower half is
Claude Code-only: `Agent` calls, the `claude-code-guide` agent, and the Bash-vs-PowerShell
*tools*. Those instructions are wrong for Copilot.

Both are switched off in `vscode/settings.json`:

```jsonc
"chat.instructionsFilesLocations": {
  ".github/instructions": true,
  ".claude/rules": true,
  "~/.copilot/instructions": true,
  "~/.claude/rules": false
},
"chat.useClaudeMdFile": false,
```

Copilot gets the shared rules from its own `~/.copilot/instructions` copies, which carry
`applyTo:` and a description. **This affects VS Code only** — Claude Code still reads
`~/.claude/rules` itself, and the Copilot CLI reads `~/.copilot/instructions`, so neither
loses anything.

Confirm with **Chat: Open Customizations**: each rule should appear once, with its
description, and no `CLAUDE.md` under Agent Instructions.

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
