# dotfiles

Dotfiles manager: keep tool configs in git, symlink them into place.

The real config files live in this repo. Each tool's normal config location is replaced with a link that points back here, so editing a config in its usual place is really editing this repo — `git` sees every change, and I can restore the whole setup on another machine.

Windows for now. Currently the only built module is Claude Code; the design is modular, so other tools (VSCode, Git, …) can be added by dropping in a reference file.

## What's tracked

- **Claude Code** — the `~/.claude` config directory: `settings.json`, `CLAUDE.md`, `rules/`, and custom `skills/` (including the `dotfiles` manager itself).
- **Claude Desktop** *(optional)* — `claude_desktop_config.json`.

Secrets and session state (`sessions/`, `keys/`, `login/`, `history/`, `*.local.json`) are excluded by the allowlist in [`claude/.gitignore`](claude/.gitignore).

## How it works

- A git repo at `~/dotfiles` holds the real files under `claude/` (a mirror of `~/.claude`).
- `~/.claude` on the machine is a **symlink/junction** into `claude/`.
- On Windows this uses Developer Mode symlinks, with a no-admin `cmd` junction/hardlink fallback.

The whole procedure is automated by a Claude Code skill, so setup and restore are driven by a documented playbook rather than manual steps.

## Layout

```
dotfiles/
  claude/                         # mirror of ~/.claude
    CLAUDE.md, settings.json
    rules/
    skills/
      dotfiles/                   # the manager skill
        SKILL.md                  # setup / restore playbook
        references/
          claude-code.md          # Claude Code + Desktop module
          _template.md            # template for adding a new tool
      ...                         # other skills
```

## Getting started

**First-time setup** — snapshot your configs into the repo and link them:
Run the `dotfiles` skill in Claude Code (`/dotfiles claude-code`). It initializes the repo if needed, copies configs in, sets up the allowlist, and links them into place. Full steps and the Windows specifics are in [`claude/skills/dotfiles/SKILL.md`](claude/skills/dotfiles/SKILL.md).

**Restore on a new machine** — clone, then link:

```bash
git clone <this-repo-url> ~/dotfiles
```

Then run the `dotfiles` skill. It detects the tracked tools from the repo and links them into place (no re-snapshot needed). See the "Restore from an existing remote" mode in [`claude/skills/dotfiles/SKILL.md`](claude/skills/dotfiles/SKILL.md).

**Update an existing clone:**

```bash
cd ~/dotfiles && git pull
```

Re-run the skill only if a new tool was added.

## Adding another tool

Copy [`claude/skills/dotfiles/references/_template.md`](claude/skills/dotfiles/references/_template.md) to `references/<tool>.md`, fill in that tool's config paths and ignore rules, then run `/dotfiles <tool>`. The template includes worked examples for VSCode, GitHub Copilot, and Git.
