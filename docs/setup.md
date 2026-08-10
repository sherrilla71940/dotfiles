# Dotfiles setup

This repository tracks durable configuration for Claude Code, Codex, GitHub Copilot,
VS Code and shells across Windows and macOS, managed with [chezmoi](https://www.chezmoi.io).
Credentials, sessions, caches, logs, memory and workspace state stay local.

`home/` is the chezmoi source state; `.chezmoiroot` points chezmoi at it so the repo root
stays readable.

## Onboarding a new machine

> **`chezmoi apply` overwrites existing configuration without asking.** It does not merge
> and it does not prompt by default. If this machine already has a `~/.claude/CLAUDE.md`,
> `~/.bashrc`, VS Code settings or similar, they will be replaced by this repo's versions.
> Follow the safe path below rather than `chezmoi init --apply`.

You do **not** clone this repo by hand — `chezmoi init` clones it for you into chezmoi's
source directory. Only chezmoi and git need to exist first.

### Step 1 — install chezmoi

```bash
sh -c "$(curl -fsLS get.chezmoi.io)"          # macOS/Linux
```

```powershell
winget install twpayne.chezmoi                # Windows, then restart the shell
```

> **Note for Git Bash users:** Winget installs executables into WinGet's `Links` directory. If Git Bash reports `bash: chezmoi: command not found`, add the path to your `~/.bashrc`:
>
> ```bash
> echo 'export PATH="$PATH:$HOME/AppData/Local/Microsoft/WinGet/Links"' >> ~/.bashrc
> source ~/.bashrc
> ```

### Step 2 — clone, without applying

```bash
chezmoi init <repo-url>
```

This clones the repository and writes nothing to your home directory yet. `chezmoi cd`
opens a shell in the clone.

### Step 3 — see exactly what would change

```bash
chezmoi diff
```

Read this properly on a machine that is already in use. Every line removed is configuration
you are about to lose. Back up anything you want to keep, or fold it into the source first.

### Step 4 — apply

```bash
chezmoi apply -v
```

Safer variants when the machine already has config:

| Flag                  | Behaviour                                       |
| --------------------- | ----------------------------------------------- |
| `--dry-run --verbose` | show what would happen, change nothing          |
| `--interactive`       | prompt for every change                         |
| `--less-interactive`  | prompt only for changed or pre-existing targets |

Restart each application afterwards — editors and CLIs read these files at startup.

### On a genuinely fresh machine

If nothing is configured yet, steps 2–4 collapse into one command:

```bash
chezmoi init --apply <repo-url>
```

Use this **only** when you are certain there is nothing to lose.

### What if an app isn't installed?

**Nothing breaks.** chezmoi writes plain files and directories; it never checks whether an
application exists. With no Codex installed, `~/.codex/AGENTS.md` is still created and Codex
picks it up the first time it runs. The same holds for Claude Code, Copilot and VS Code.

So both orders work: apply first and install apps later (each finds its configuration
already in place), or install first and apply after (lets you verify immediately, but that
is exactly the case where the overwrite warning above applies).

### Optional extras

The bootstrap scripts install baseline tools (git, jq, chezmoi). They live _inside_ the
repo, so they can only run after step 2:

```bash
bash scripts/bootstrap-macos.sh                    # from the clone; chezmoi cd gets you there
powershell -File scripts/bootstrap-windows.ps1
```

VS Code extensions are kept out of the bootstrap because the manifest holds 114 of them:

```bash
grep -v '^#' scripts/vscode-extensions.txt | grep . | xargs -n1 code --install-extension --force
```

```powershell
Get-Content scripts/vscode-extensions.txt | Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object { code --install-extension $_ --force }
```

## Enable the pre-commit check

One command per clone:

```bash
git config core.hooksPath scripts/git-hooks
```

`scripts/git-hooks/pre-commit` renders the source state into a temporary directory and
refuses the commit if:

1. a template fails to render,
2. the skill file count changes between source and render — the symptom of a filename
   colliding with a chezmoi attribute prefix,
3. a shared rule is missing its Claude or Copilot template, or renders different bodies,
4. `~/.codex/AGENTS.md` gains YAML frontmatter, which Codex would display as text.

It never touches your home directory and passes `--exclude=scripts`, so validating never
installs software. If chezmoi is not on PATH the hook warns and lets the commit through
rather than blocking work.

Each check exists because that failure has actually occurred here: four skills were
silently dropped in one refactor, and the office skills' empty `__init__.py` package
markers were omitted in another. Neither was visible in `git diff`.

## Daily workflow

| Task                                             | Command                            |
| ------------------------------------------------ | ---------------------------------- |
| Preview pending changes                          | `chezmoi diff`                     |
| Apply                                            | `chezmoi apply -v`                 |
| Edit a managed file                              | `chezmoi edit ~/.claude/CLAUDE.md` |
| Capture an edit you made directly to a live file | `chezmoi re-add ~/.bashrc`         |
| Pull another machine's changes                   | `chezmoi update -v`                |
| Open the source repo                             | `chezmoi cd`                       |

You can edit live files directly instead of using `chezmoi edit` — but chezmoi will not
notice, and the next `apply` overwrites your change unless you `chezmoi re-add` it. That
works for plain files; for **templates** `re-add` silently skips the file and your edit is
lost. See
[Editing something already managed](./chezmoi-workflow.md#editing-something-already-managed)
for which files are templates and which route is safe.

### Working from a custom directory (~/dotfiles)

If you prefer your repository to live in `~/dotfiles` rather than chezmoi's default location (`~/.local/share/chezmoi`), create a symbolic link so chezmoi discovers `.chezmoiroot` automatically without needing machine-specific `sourceDir` configuration:

```bash
mkdir -p ~/.local/share
ln -s ~/dotfiles ~/.local/share/chezmoi
```

## Adding a file

1. `chezmoi add ~/.some-config` — chezmoi copies it into `home/` with the right name.
2. `chezmoi cd`, then `git add` and `git commit`.

Naming rules that bite, all handled by chezmoi's source-state attributes:

| Situation                                                       | Source name           |
| --------------------------------------------------------------- | --------------------- |
| Target starts with `.`                                          | `dot_name`            |
| Target name really starts with `create_`, `run_`, `symlink_`, … | `literal_create_name` |
| Target must exist but be empty (e.g. `__init__.py`)             | `empty___init__.py`   |
| Write once, never overwrite (the app owns the file)             | `create_name`         |
| Needs templating                                                | `name.tmpl`           |

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
- **Copilot** — _Chat: Open Customizations_ lists 9 instruction files. _Chat → Diagnostics_
  shows `javascript` and `typescript` applying for a `.ts` file and not for a `.css` file.
- **Bodies match across tools:**

  ```bash
  diff <(sed '1,/^---$/d;1,/^---$/d' ~/.claude/rules/javascript.md)        <(sed '1,/^---$/d;1,/^---$/d' ~/.copilot/instructions/javascript.instructions.md)
  ```

## Copilot reads more folders than you think

VS Code discovers user-level instructions from several harness-agnostic folders at once,
including `~/.copilot/instructions` **and** `~/.claude/rules`. Because this repo renders the
same rules into both, Copilot listed every shared rule twice — once with a description from
its own `.instructions.md`, once bare from Claude's `.md`.

Worse, `chat.useClaudeMdFile` made Copilot ingest `~/.claude/CLAUDE.md`, whose lower half is
Claude Code-only: `Agent` calls, the `claude-code-guide` agent, and the Bash-vs-PowerShell
_tools_. Those instructions are wrong for Copilot.

Both are switched off in `vscode/settings.json`:

```jsonc
"chat.instructionsFilesLocations": {
  ".github/instructions": true,
  ".claude/rules": true,
  "~/.copilot/instructions": true,
  "~/.claude/rules": false
},
"chat.useClaudeMdFile": false
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
