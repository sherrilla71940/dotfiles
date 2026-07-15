---
name: dotfiles
description: Modular dotfiles manager — track any tool's config (Claude, VSCode, Git, …) in one git repo via symlinks. Supports Windows, macOS, Linux, and WSL.
disable-model-invocation: true
argument-hint: "<os> [tool ...]"
---

# Dotfiles Deployment Playbook

`$ARGUMENTS` — first token is `<os>` (`windows` | `mac` | `linux` | `wsl`), followed by optional tool module name(s) (e.g. `windows claude-code`, `mac claude-code vscode`). If `<os>` is missing, ask the user which environment they're on before proceeding. If tool names are missing, list the available modules and ask.

---

## Path conventions per OS

| OS | Repo root | Shell | Symlink method |
|----|-----------|-------|----------------|
| `windows` | `%USERPROFILE%\dotfiles` | PowerShell (primary) / cmd (fallback) | `New-Item SymbolicLink` / `mklink` — requires Developer Mode or elevation |
| `mac` | `~/dotfiles` | bash / zsh | `ln -s <target> <link>` — works without any setup |
| `linux` | `~/dotfiles` | bash | `ln -s <target> <link>` — works without any setup |
| `wsl` | `~/dotfiles` (WSL home) | bash | `ln -s` for WSL-side files; see [WSL note](#wsl-note) for Windows-side app configs |

> **WSL note.** WSL CLI tools (Claude Code, git, etc.) use their WSL-native home (`~`). Windows desktop apps (Claude Desktop, VSCode) keep their configs on the Windows side at `/mnt/c/Users/<winuser>/AppData/…`. Symlinks across that boundary (`ln -s /mnt/c/…`) exist within WSL but Windows apps won't follow them. For cross-boundary items either: (a) track only the WSL-side config and ignore the Windows desktop config, or (b) open a Windows cmd/PowerShell and use `mklink` for the Windows-side file separately. Module tables call this out per item.

---

## How this works (mental model)

You keep **one** git repo — `~/dotfiles` (or `%USERPROFILE%\dotfiles` on Windows) — that holds the **real** configuration files for every tool you track. Each tool's live config location is replaced with a **link** that points into that repo.

The payoff: you edit configs normally in their usual place, but you're really editing files inside the git repo, so `git status` sees every change and you can commit/push a history and restore it on another machine.

This `SKILL.md` is the **tool-agnostic engine**. The per-tool specifics — *which* paths, *what's* safe to track, *which* app must be closed before relinking — live in small module files under [`references/`](references/). Adding a new tool = drop one more module file (copy [`references/_template.md`](references/_template.md)).

Available modules today:
- [`references/claude-code.md`](references/claude-code.md) — Claude Code + Claude Desktop.
- [`references/vscode.md`](references/vscode.md) — VSCode settings, keybindings, and snippets.

> **Module naming rule:** module files are `references/<tool>.md`, but **never name one `claude.md`** — Claude Code auto-loads any file case-insensitively matching `CLAUDE.md` as instructions, and on Windows/macOS (case-insensitive filesystems) `claude.md` collides with it. That's why the Claude module is `claude-code`.

---

## Orchestration workflow (follow in order)

### A. Pick the mode
Check for a `dotfiles/.git` directory at the repo root for the current OS, then choose:

| Situation | Mode | What happens |
|-----------|------|--------------|
| Repo missing locally, **you have a remote** (pushed from another machine) | **Restore** (B1) | Clone the repo, then **link only** — the configs are already committed. |
| Repo missing locally, no remote | **First-time** (B2) | Init a fresh repo, snapshot configs into it, link. |
| Repo already present locally | **Add / reuse** (B3) | Reuse it — snapshot & link any new tool. |

Ask the user which fits if it isn't obvious (e.g. "Do you already have a dotfiles repo pushed somewhere?").

### B. Get the `~/dotfiles` repo in place

#### B1 — Restore from an existing remote (new computer)
Clone your repo to the standard location, then discover what it already tracks:

**Windows (PowerShell)**
```powershell
git clone <your-repo-url> "$env:USERPROFILE\dotfiles"
Get-ChildItem -Directory "$env:USERPROFILE\dotfiles" |
  Where-Object Name -ne '.git' | Select-Object -ExpandProperty Name
```

**Mac / Linux / WSL**
```bash
git clone <your-repo-url> ~/dotfiles
ls -d ~/dotfiles/*/
```

Each listed folder is a tracked tool (matching a `references/<tool>.md` module). Confirm the set with the user. For each, run the per-tool procedure but **skip Steps 2–3** (snapshot and allowlist are already in the repo). Run **Step 1** (enable symlinks) → **Step 4** (close apps) → **Step 5** → **Step 6**.

> **Key restore detail:** on a fresh machine the tool has usually already created a *default* config at the live path. Step 5 renames **that default aside to `.bak`** before linking — so your committed config wins and the machine default is the recoverable backup.

No new commit is needed after a pure restore unless you change something.

#### B2 — First-time setup (no repo yet)
Initialize the repo + a base allowlist `.gitignore`:

**Windows (PowerShell)**
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
git -C "$env:USERPROFILE\dotfiles" branch -M main
```

**Mac / Linux / WSL**
```bash
mkdir -p ~/dotfiles
git -C ~/dotfiles init
cat > ~/dotfiles/.gitignore << 'EOF'
# Ignore everything by default; only explicitly allowed paths below are tracked.
# Each tool module appends its own !allow lines under its folder.
*
!*/
!.gitignore
EOF
git -C ~/dotfiles branch -M main
```

**Connect a remote now** (so you can push and later restore elsewhere). Create an **empty** repo on GitHub/GitLab first (no README), then:

**Windows**
```powershell
git -C "$env:USERPROFILE\dotfiles" remote add origin <your-repo-url>
```

**Mac / Linux / WSL**
```bash
git -C ~/dotfiles remote add origin <your-repo-url>
```

Then run the full per-tool procedure (Steps 1–7) for each chosen tool.

#### B3 — Repo already exists locally (add a tool / re-run)
Reuse it as-is. Run the full per-tool procedure for the new tool(s); Steps 2–3 snapshot the new tool into its own subfolder.

**Verify (any mode):**

**Windows:** `git -C "$env:USERPROFILE\dotfiles" status`
**Mac / Linux / WSL:** `git -C ~/dotfiles status`

### C. Resolve which tools
- **Restore (B1):** the tools discovered in the clone (confirm with the user).
- **First-time / add (B2, B3):** from `$ARGUMENTS` if given (each must match a `references/<tool>.md`); if empty, list the modules in [`references/`](references/) (ignore `_template.md`) and **ask** which to set up. If the user names a tool with **no** module yet, help them author one from [`references/_template.md`](references/_template.md) first.

For every chosen tool, **open and read its module file now** — you need its managed-items table, allowlist lines, and close-before-relink app(s) before touching anything. Each tool lives in its own repo subfolder: `~/dotfiles/<tool>/`.

### D. Push and summarize
After links verify and any new snapshots are committed, push if a remote is set:

**Windows:** `git -C "$env:USERPROFILE\dotfiles" push -u origin main`
**Mac / Linux / WSL:** `git -C ~/dotfiles push -u origin main`

Then give the user the **closing summary** (last section).

---

## Shared symlink engine

Run these per tool, substituting the module's paths.

### Step 1 — Enable the ability to create symlinks

**Mac / Linux / WSL:** No setup needed. `ln -s` works without elevation. Quick test:
```bash
ln -s /tmp ~/dotfiles-test && ls -la ~/dotfiles-test && rm ~/dotfiles-test
```

**Windows:** Creating symlinks normally needs elevation. **Developer Mode** grants it to your normal (non-admin) account: `Settings → System → For developers → Developer Mode → On`.

Verify (non-elevated — should succeed and print a link entry):

**Windows (PowerShell)**
```powershell
New-Item -ItemType SymbolicLink -Path "$env:TEMP\dotfiles-symlink-test" -Target "$env:USERPROFILE" | Out-Null
Get-Item "$env:TEMP\dotfiles-symlink-test" | Select-Object Name, LinkType, Target
Remove-Item "$env:TEMP\dotfiles-symlink-test"
```

**Windows (cmd)**
```cmd
mklink /D "%TEMP%\dotfiles-symlink-test" "%USERPROFILE%"
dir "%TEMP%" | findstr dotfiles-symlink-test
rmdir "%TEMP%\dotfiles-symlink-test"
```

> **If Developer Mode is greyed out or blocked by org policy** (or the test fails with a privilege error): use the **cmd fallback in Step 5b** — a directory **junction** + file **hardlink** need neither admin nor Developer Mode.

> **Windows — `New-Item` vs `mklink`:** even with Developer Mode on, `New-Item -ItemType SymbolicLink` may fail inside some non-elevated shells due to how the privilege is inherited. If it errors with "Administrator privilege required", use `cmd /c mklink` instead — it correctly picks up the Developer Mode privilege. See Step 5a for the exact command.

### Step 2 — Snapshot the config into the repo (COPY, never move)

**Copy** the tool's live config(s) into the repo. Copying — not moving — means your originals stay fully intact if anything goes wrong.

**Windows (PowerShell)** — directory:
```powershell
Copy-Item -Recurse -Force "<LIVE_PATH>" "$env:USERPROFILE\dotfiles\<tool>\<name>"
```
Single file: `Copy-Item -Force "<LIVE_FILE>" "$env:USERPROFILE\dotfiles\<tool>\"`

**Mac / Linux / WSL** — directory:
```bash
cp -r "<LIVE_PATH>" ~/dotfiles/<tool>/<name>
```
Single file: `cp "<LIVE_FILE>" ~/dotfiles/<tool>/`

**Verify** the copy — file counts should match:

**Windows:** `(Get-ChildItem -Recurse "<LIVE_PATH>").Count` vs `(Get-ChildItem -Recurse "$env:USERPROFILE\dotfiles\<tool>\<name>").Count`

**Mac / Linux / WSL:** `find "<LIVE_PATH>" | wc -l` vs `find ~/dotfiles/<tool>/<name> | wc -l`

### Step 3 — Add the module's allowlist lines and commit

Append the tool module's `!allow` and never-track lines to the repo-root `.gitignore`. Then stage and commit — safe to do **while the tool is still open**, since the repo is a separate copy not yet linked:

**Windows:**
```powershell
git -C "$env:USERPROFILE\dotfiles" add -A
git -C "$env:USERPROFILE\dotfiles" commit -m "chore: snapshot <tool> config"
```

**Mac / Linux / WSL:**
```bash
git -C ~/dotfiles add -A
git -C ~/dotfiles commit -m "chore: snapshot <tool> config"
```

### ⛔ Step 4 — CHECKPOINT: close every app that holds this tool's files open

**Do not skip.** Step 5 renames the live config aside and replaces it with a link. Any running app that holds those files open will corrupt state or make the link silently fail.

**What the user must do:**
1. **Read the Step-5 commands below** and copy the block they'll use into a note — the app may include the one they're using to read this.
2. **Fully quit** every app named in the module's *close-before-relink* list, including any Claude Code session running this skill.
3. Open a **brand-new** terminal window.
4. Run the copied Step-5 block there.
5. Reopen and continue at Step 6.

> **Agent note:** stop here. Do **not** run Step 5 in the live session — hand the exact commands to the user and let them run them in a fresh terminal after closing everything. Resume at Step 6 when they return.

### Step 5 — Back up the original and create the link

Both paths first rename the original aside to `.bak` (recoverable — don't delete until Step 6 confirms it works).

#### Mac / Linux / WSL
```bash
mv "<LIVE_PATH>" "<LIVE_PATH>.bak"
ln -s "<REPO_PATH>" "<LIVE_PATH>"
```
Verify: `ls -la "<LIVE_PATH>"` — should show `l` prefix and `->` arrow pointing to the repo path.

#### Windows 5a — Developer Mode (`mklink` via cmd — preferred even when Dev Mode is on)
```cmd
rem Directory:
ren "<LIVE_PATH>" "<name>.bak"
mklink /D "<LIVE_PATH>" "<REPO_PATH>"

rem File:
ren "<LIVE_FILE>" "<name>.bak"
mklink "<LIVE_FILE>" "<REPO_FILE>"
```
Verify: `Get-Item "<LIVE_PATH>" | Select-Object Name, LinkType, Target`

#### Windows 5b — cmd fallback, no admin / no Developer Mode
Junction (`/J`) for a **directory**, hardlink (`/H`) for a **file** — neither needs elevation.
```cmd
rem Directory:
ren "<LIVE_PATH>" "<name>.bak"
mklink /J "<LIVE_PATH>" "<REPO_PATH>"

rem File:
ren "<LIVE_FILE>" "<name>.bak"
mklink /H "<LIVE_FILE>" "<REPO_FILE>"
```

### Step 6 — Smoke test, then drop the backup
1. **Reopen the tool.** Confirm it loads its config exactly as before.
2. **Confirm the link is live** — make a trivial edit to a tracked file and run:

   **Windows:** `Get-Item "<LIVE_PATH>" | Select-Object LinkType, Target` then `git -C "$env:USERPROFILE\dotfiles" status`

   **Mac / Linux / WSL:** `ls -la "<LIVE_PATH>"` then `git -C ~/dotfiles status`

   The change should appear in `git status`.
3. **Only once it works,** delete the recoverable backup:

   **Windows:** `Remove-Item -Recurse -Force "<name>.bak"`

   **Mac / Linux / WSL:** `rm -rf "<LIVE_PATH>.bak"`

### Step 7 — Commit
**Windows:** `git -C "$env:USERPROFILE\dotfiles" add -A && git -C "$env:USERPROFILE\dotfiles" commit -m "chore: link <tool> config"`

**Mac / Linux / WSL:** `git -C ~/dotfiles add -A && git -C ~/dotfiles commit -m "chore: link <tool> config"`

---

## Living with `dotfiles` (the ongoing workflow)

Once set up, you don't repeat the linking steps.

**Day-to-day editing.** Edit configs normally in their usual location — because it's a link into the repo, you're editing the repo directly.

**Snapshot a change (commit + push):**

**Windows:**
```powershell
cd "$env:USERPROFILE\dotfiles"
git add -A
git commit -m "feat: tweak <tool> settings"
git push
```

**Mac / Linux / WSL:**
```bash
cd ~/dotfiles
git add -A
git commit -m "feat: tweak <tool> settings"
git push
```

**Quick smoke test:**

**Windows:** `Get-Item "$env:USERPROFILE\.claude" | Select-Object LinkType, Target` then `git -C "$env:USERPROFILE\dotfiles" status`

**Mac / Linux / WSL:** `ls -la ~/.claude` then `git -C ~/dotfiles status`

`LinkType` (Windows) or the `l` prefix + `->` arrow (Mac/Linux/WSL) confirms the link is live.

**Add another tool later.** Author `references/<tool>.md` from [`references/_template.md`](references/_template.md), then run `/dotfiles <os> <tool>`.

**Set up a new machine / restore from your remote.** This is **Mode B1** — clone your pushed repo, let the skill discover the tracked tools from its subfolders, and link only (Steps 1, 4, 5, 6; snapshot/init are skipped because the configs are already committed).

**Hardlink caveat (Windows 5b — file hardlinks only).** A hardlink stays in sync only while the file is edited in place. If the owning app **rewrites** the file (writes new + renames over the old), the hardlink breaks and the repo copy silently stops updating. Re-create it periodically — or use the symlink (5a) when you can. Directory **junctions** have no such issue.

---

## Closing summary the agent should give the user

When you finish a run, report back with:
1. **What changed** — repo location; which tool(s) now link into it; commits made.
2. **Which mechanism** — `ln -s` (Mac/Linux/WSL), Dev-Mode `mklink` (Windows 5a), or junction/hardlink fallback (Windows 5b), and why.
3. **How to verify** — the two-command smoke test above.
4. **Going forward** — point at the "Living with `dotfiles`" section (edit in place, commit to snapshot, add tools via the template, hardlink caveat if 5b was used for a file).
