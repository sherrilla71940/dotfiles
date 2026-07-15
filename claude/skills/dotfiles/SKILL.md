---
name: dotfiles
description: Modular Windows dotfiles manager — track any tool's config (Claude, VSCode, Git, …) in one git repo via symlinks.
disable-model-invocation: true
argument-hint: "[tool ...]"
---

# Dotfiles Deployment Playbook (Windows)

> **⚠️ Windows only.** This skill uses **PowerShell** (default) with a **cmd** fallback. Git Bash was unreliable and mac/WSL paths cannot be verified from this machine — they are **not** covered. If you are on mac or Linux, stop and use a different guide.

`$ARGUMENTS` names the tool module(s) to set up (e.g. `claude-code`, `claude-code vscode`). If empty, you'll be asked which tools to track.

> **Roadmap — OS support.** Today everything below is **Windows** (paths, PowerShell/cmd, Developer Mode). Planned: a **required leading `os`/environment argument** (`windows` | `linux` | `mac`) so usage becomes `/dotfiles <os> [tool ...]`. When that lands, each module's managed-items table gains per-OS path columns and the engine picks commands per OS; the current single-column tables are the Windows column. Nothing here needs to change to prepare — just don't hardcode Windows assumptions into new module *content* beyond the paths.

---

## How this works (mental model)

You keep **one** git repo — `%USERPROFILE%\dotfiles` — that holds the **real** configuration files for every tool you track. Each tool's live config location is replaced with a **link** that points into that repo.

The payoff: you edit configs normally in their usual place, but you're really editing files inside the git repo, so `git status` sees every change and you can commit/push a history and restore it on another machine.

This `SKILL.md` is the **tool-agnostic engine**. The per-tool specifics — *which* paths, *what's* safe to track, *which* app must be closed before relinking — live in small module files under [`references/`](references/). Adding a new tool = drop one more module file (copy [`references/_template.md`](references/_template.md)).

Available modules today:
- [`references/claude-code.md`](references/claude-code.md) — Claude Code + Claude Desktop.

> **Module naming rule:** module files are `references/<tool>.md`, but **never name one `claude.md`** — Claude Code auto-loads any file case-insensitively matching `CLAUDE.md` as instructions, and on Windows/macOS (case-insensitive filesystems) `claude.md` collides with it. That's why the Claude module is `claude-code`.

---

## Orchestration workflow (follow in order)

### A. Pick the mode
Check for `%USERPROFILE%\dotfiles\.git`, then choose:

| Situation | Mode | What happens |
|-----------|------|--------------|
| Repo missing locally, **you have a remote** (pushed from another machine) | **Restore** (B1) | Clone the repo, then **link only** — the configs are already committed. |
| Repo missing locally, no remote | **First-time** (B2) | Init a fresh repo, snapshot configs into it, link. |
| Repo already present locally | **Add / reuse** (B3) | Reuse it — snapshot & link any new tool. |

Ask the user which fits if it isn't obvious (e.g. "Do you already have a dotfiles repo pushed somewhere?").

### B. Get the `~/dotfiles` repo in place

#### B1 — Restore from an existing remote (new computer)
Clone your repo to the standard location, then discover what it already tracks:
```powershell
git clone <your-repo-url> "$env:USERPROFILE\dotfiles"
Get-ChildItem -Directory "$env:USERPROFILE\dotfiles" |
  Where-Object Name -ne '.git' | Select-Object -ExpandProperty Name
```
Each listed folder is a tracked tool (matching a `references/<tool>.md` module). These are your targets — confirm the set with the user. For each, run the per-tool procedure but **skip Steps 2–3** (the snapshot and allowlist are already in the repo). Run **Step 1** (enable symlinks) → **Step 4** (close apps) → **Step 5** → **Step 6**.

> **Key restore detail:** on a fresh machine the tool has usually already created a *default* config at the live path (e.g. a new `~\.claude`). Step 5 renames **that default aside to `.bak`** before linking — so you fall back onto your repo's tracked version, not the stock one. Your committed config wins; the machine default becomes the recoverable backup.

No new commit is needed after a pure restore unless you change something.

#### B2 — First-time setup (no repo yet)
Initialize the repo + a base allowlist `.gitignore`:

**PowerShell**
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\dotfiles" | Out-Null
git -C "$env:USERPROFILE\dotfiles" init
@'
# Ignore everything by default; only explicitly allowed paths below are tracked.
# Each tool module appends its own !allow lines under its folder.
*
!*/
!.gitignore
'@ | Set-Content -Encoding utf8 "$env:USERPROFILE\dotfiles\.gitignore"
git -C "$env:USERPROFILE\dotfiles" config core.autocrlf true
```

**cmd**
```cmd
mkdir "%USERPROFILE%\dotfiles"
git -C "%USERPROFILE%\dotfiles" init
git -C "%USERPROFILE%\dotfiles" config core.autocrlf true
```
> In cmd, create the base `.gitignore` with the same three-line allowlist header (`*`, `!*/`, `!.gitignore`) using your editor.

**Connect a remote now** (so you can push and later restore elsewhere — this is the other half of the round-trip). Create an **empty** repo on GitHub/GitLab first (no README), then:
```powershell
git -C "$env:USERPROFILE\dotfiles" remote add origin <your-repo-url>
git -C "$env:USERPROFILE\dotfiles" branch -M main
```
Then run the full per-tool procedure (Steps 1–7) for each chosen tool.

#### B3 — Repo already exists locally (add a tool / re-run)
Reuse it as-is. Run the full per-tool procedure for the new tool(s); Steps 2–3 snapshot the new tool into its own subfolder.

**Verify (any mode):** `git -C "%USERPROFILE%\dotfiles" status` runs cleanly.

### C. Resolve which tools
- **Restore (B1):** the tools discovered in the clone (confirm with the user).
- **First-time / add (B2, B3):** from `$ARGUMENTS` if given (each must match a `references/<tool>.md`); if empty, list the modules in [`references/`](references/) (ignore `_template.md`) and **ask** which to set up. If the user names a tool with **no** module yet, help them author one from [`references/_template.md`](references/_template.md) first.

For every chosen tool, **open and read its module file now** — you need its managed-items table, allowlist lines, and close-before-relink app(s) before touching anything. Each tool lives in its own repo subfolder: `%USERPROFILE%\dotfiles\<tool>\`.

### D. Push and summarize
After links verify and any new snapshots are committed, push if a remote is set:
```powershell
git -C "$env:USERPROFILE\dotfiles" push -u origin main
```
Then give the user the **closing summary** (last section).

---

## Shared symlink engine

Run these per tool, substituting the module's paths.

### Step 1 — Enable the ability to create symlinks

Creating symlinks on Windows normally needs elevation. **Developer Mode** grants it to your normal (non-admin) account.

**Turn it on:** `Settings → System → For developers → Developer Mode → On`.

**Verify** (non-elevated — should succeed and print a link entry):

**PowerShell**
```powershell
New-Item -ItemType SymbolicLink -Path "$env:TEMP\dotfiles-symlink-test" -Target "$env:USERPROFILE" | Out-Null
Get-Item "$env:TEMP\dotfiles-symlink-test" | Select-Object Name, LinkType, Target
Remove-Item "$env:TEMP\dotfiles-symlink-test"
```

**cmd**
```cmd
mklink /D "%TEMP%\dotfiles-symlink-test" "%USERPROFILE%"
dir "%TEMP%" | findstr dotfiles-symlink-test
rmdir "%TEMP%\dotfiles-symlink-test"
```

> **If Developer Mode is greyed out or blocked by org policy** (or the test fails with a privilege error): don't fight it. Use the **cmd fallback in Step 6b** — a directory **junction** + file **hardlink** need neither admin nor Developer Mode.

### Step 2 — Snapshot the config into the repo (COPY, never move)

**Copy** the tool's live config(s) into `%USERPROFILE%\dotfiles\<tool>\`. Copying — not moving — means your originals stay fully intact if anything goes wrong. Nothing destructive happens here.

**PowerShell** (directory example)
```powershell
Copy-Item -Recurse -Force "<LIVE_PATH>" "$env:USERPROFILE\dotfiles\<tool>\<name>"
```

**cmd** (directory example — `robocopy` returns non-zero on success; that's normal)
```cmd
robocopy "<LIVE_PATH>" "%USERPROFILE%\dotfiles\<tool>\<name>" /E
```
For a **single file**, use `Copy-Item -Force` / `copy` instead.

**Verify** the copy — compare recursive file counts (they should match):
```powershell
(Get-ChildItem -Recurse "<LIVE_PATH>").Count
(Get-ChildItem -Recurse "$env:USERPROFILE\dotfiles\<tool>\<name>").Count
```

### Step 3 — Add the module's allowlist lines and commit

Append the tool module's `!allow` and never-track lines to `%USERPROFILE%\dotfiles\.gitignore` (paths are relative to the repo root, e.g. `!<tool>/settings.json`). The allowlist means new/renamed files stay untracked by default, so an unanticipated path can't leak secrets.

Then stage and commit — safe to do **while the tool is still open**, since the repo is a separate copy not yet linked:
```powershell
git -C "$env:USERPROFILE\dotfiles" add -A
git -C "$env:USERPROFILE\dotfiles" commit -m "chore: snapshot <tool> config"
```

### ⛔ Step 4 — CHECKPOINT: close every app that holds this tool's files open

**Do not skip.** Step 5 renames the live config aside and replaces it with a link. Any running app that holds those files open (the module lists which — e.g. Claude Desktop, VSCode) will corrupt state or make the link silently fail if you relink while it's live.

**What the user must do:**
1. **Read the Step-5 commands below** and copy the block they'll use (5a or 5b) into a note — the app may include the one they're using to read this.
2. **Fully quit** every app named in the module's *close-before-relink* list, including any Claude Code session running this skill.
3. Open a **brand-new** PowerShell or cmd window.
4. Run the copied Step-5 block there.
5. Reopen and continue at Step 6.

> **Agent note:** stop here. Do **not** run Step 5 in the live session — hand the exact commands to the user and let them run them in a fresh terminal after closing everything. Resume at Step 6 when they return.

### Step 5 — Back up the original and create the link

Both paths first rename the original aside to `.bak` (recoverable — don't delete until Step 6 confirms it works). Use **5a** if Developer Mode is on, **5b** if it's blocked. Link type (directory vs file) comes from the module's table.

#### 5a — Developer Mode (PowerShell symlinks)
```powershell
# Directory:
Rename-Item "<LIVE_PATH>" "<name>.bak"
New-Item -ItemType SymbolicLink -Path "<LIVE_PATH>" -Target "<REPO_PATH>"

# File: same pattern; New-Item -ItemType SymbolicLink works for files too.
```

#### 5b — cmd fallback, no admin / no Developer Mode
Junction (`/J`) for a **directory**, hardlink (`/H`) for a **file** — neither needs elevation.
```cmd
rem Directory:
ren "<LIVE_PATH>" "<name>.bak"
mklink /J "<LIVE_PATH>" "<REPO_PATH>"

rem File:
rem ren "<LIVE_FILE>" "<name>.bak"
rem mklink /H "<LIVE_FILE>" "<REPO_FILE>"
```

**Verify each link resolves to the repo:**
```powershell
Get-Item "<LIVE_PATH>" | Select-Object Name, LinkType, Target
```
(cmd: `dir` shows `<SYMLINKD>` / `<JUNCTION>` with the target.)

### Step 6 — Smoke test, then drop the backup
1. **Reopen the tool.** Confirm it loads its config exactly as before.
2. **Confirm the link is live** — an edit through the live path reaches the repo:
   ```powershell
   Get-Item "<LIVE_PATH>" | Select-Object LinkType, Target
   git -C "$env:USERPROFILE\dotfiles" status
   ```
   Make a trivial edit to a tracked file and re-run `git status` — the change should appear.
3. **Only once it works,** delete the recoverable backup (deliberate — the one destructive command):
   ```powershell
   # Remove-Item -Recurse -Force "<name>.bak"
   ```

### Step 7 — Commit
```powershell
git -C "$env:USERPROFILE\dotfiles" add -A
git -C "$env:USERPROFILE\dotfiles" commit -m "chore: link <tool> config"
```

---

## Living with `dotfiles` (the ongoing workflow)

Once set up, you don't repeat the linking steps.

**Day-to-day editing.** Edit configs normally in their usual location — because it's a link into the repo, you're editing the repo directly.

**Snapshot a change (commit + push):**
```powershell
cd "$env:USERPROFILE\dotfiles"
git add -A
git commit -m "feat: tweak <tool> settings"
git push        # if you've added a remote
```

**Quick smoke test right now:**
```powershell
Get-Item "$env:USERPROFILE\.claude" | Select-Object LinkType, Target   # substitute any tracked live path
git -C "$env:USERPROFILE\dotfiles" status
```
`LinkType` should be `SymbolicLink` (5a) or `Junction` (5b) pointing into `...\dotfiles\<tool>\`. If `git status` shows recent edits, it's wired correctly.

**Add another tool later.** Author `references/<tool>.md` from [`references/_template.md`](references/_template.md), then run `/dotfiles <tool>`.

**Set up a new machine / restore from your remote.** This is **Mode B1** — clone your pushed repo, let the skill discover the tracked tools from its subfolders, and link only (Steps 1, 4, 5, 6; snapshot/init are skipped because the configs are already committed). See [Orchestration → B1](#b1--restore-from-an-existing-remote-new-computer) for the exact commands and the "back up the machine default aside" detail.

**Hardlink caveat (only if you used 5b for a *file*).** A hardlink stays in sync only while the file is edited in place. If the owning app **rewrites** the file (writes new + renames over the old), the hardlink breaks and the repo copy silently stops updating. Periodically re-run the smoke test on file links and re-create them if they desync — or use the Dev-Mode symlink (5a) when you can. Directory **junctions** have no such issue.

---

## Closing summary the agent should give the user

When you finish a run, report back with:
1. **What changed** — repo at `~\dotfiles` (created or reused); which tool(s) now link into it; commits made.
2. **Which mechanism** — Dev-Mode symlinks (5a) or cmd junction/hardlink fallback (5b), and why.
3. **How to verify** — the two-command smoke test above.
4. **Going forward** — point at the "Living with `dotfiles`" section (edit in place, commit to snapshot, add tools via the template, hardlink caveat if 5b was used for a file).
