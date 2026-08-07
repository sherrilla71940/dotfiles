# Dotfiles symlink guide

This repository stores selected durable configuration files. Application state,
credentials, sessions, caches, logs, databases, and generated files stay local.

## Current Claude link map

| Live path | Repository source |
| --- | --- |
| `~/.claude/CLAUDE.md` | `claude/CLAUDE.md` |
| `~/.claude/commands` | `claude/commands` |
| `~/.claude/rules` | `claude/rules` |
| `~/.claude/settings.json` | `claude/settings.json` |
| `~/.claude/skills` | `claude/skills` |

Do not link the whole `~/.claude` directory. Claude owns the remaining files
and directories as local runtime state.

The linked `settings.json` invokes these repository scripts directly, so they
do not need separate links under `~/.claude`:

| Purpose | Repository source |
| --- | --- |
| Worktree launch check | `claude/hooks/check-worktree-launch.ps1` |
| Desktop notifications | `claude/hooks/show-claude-notification.ps1` |
| Session status line | `claude/claude-session-statusline.ps1` |

`%APPDATA%\Claude\claude_desktop_config.json` also remains local. It contains
Claude Desktop application state and is not Claude Code's shared settings file.

Codex configuration is not managed by this guide yet.

## Windows prerequisites

Enable Windows Developer Mode so an unelevated terminal can create symbolic
links. If that is unavailable, use directory junctions for directories and
understand that file hardlinks can break when an application replaces a file.

Test symbolic-link creation in PowerShell:

```powershell
$testLink = Join-Path $env:TEMP "dotfiles-symlink-test"
New-Item -ItemType SymbolicLink -Path $testLink -Target $env:USERPROFILE
Get-Item -LiteralPath $testLink | Select-Object LinkType, Target
Remove-Item -LiteralPath $testLink
```

## Relink one file safely on Windows

1. Fully close every application that may use the file.
2. Open a new PowerShell window.
3. Set the exact live and repository paths.
4. Move the live file to a recoverable `.bak` file.
5. Create and verify the symbolic link.
6. Reopen the application and smoke-test it.
7. Delete the backup only after the smoke test succeeds.

Example:

```powershell
$live = "$env:USERPROFILE\.claude\CLAUDE.md"
$source = "$env:USERPROFILE\dotfiles\claude\CLAUDE.md"
$backup = "$live.bak"

if (-not (Test-Path -LiteralPath $source)) {
  throw "Missing repository source: $source"
}
if (Test-Path -LiteralPath $backup) {
  throw "Backup already exists: $backup"
}

Move-Item -LiteralPath $live -Destination $backup
cmd /c mklink "$live" "$source"

if ($LASTEXITCODE -ne 0) {
  Move-Item -LiteralPath $backup -Destination $live
  throw "Link creation failed; the original file was restored."
}

Get-Item -LiteralPath $live | Select-Object FullName, LinkType, Target
```

Rollback before deleting the backup:

```powershell
$live = "$env:USERPROFILE\.claude\CLAUDE.md"
$backup = "$live.bak"

Remove-Item -LiteralPath $live
Move-Item -LiteralPath $backup -Destination $live
```

## Directory links

Use `mklink /D` for an individual managed directory after backing up the live
directory. Never use it for an entire application home such as `~/.claude` or
`~/.codex`.

```powershell
cmd /c mklink /D "C:\path\to\live-directory" "C:\path\to\repo-directory"
```

## Verification

Inspect every managed link:

```powershell
$paths = @(
  "$env:USERPROFILE\.claude\CLAUDE.md",
  "$env:USERPROFILE\.claude\commands",
  "$env:USERPROFILE\.claude\rules",
  "$env:USERPROFILE\.claude\settings.json",
  "$env:USERPROFILE\.claude\skills"
)

Get-Item -LiteralPath $paths | Select-Object FullName, LinkType, Target
git -C "$env:USERPROFILE\dotfiles" status --short
```

Every link target must exist inside this repository. A configuration edit made
through the live path should appear in `git status`.

## Adding another managed item

Before adding a link:

1. Confirm the file is durable user configuration rather than runtime state.
2. Check it for credentials, tokens, account identifiers, and machine-only data.
3. Copy it into a clearly owned repository directory.
4. Add the narrowest necessary allowlist entry to `.gitignore`.
5. Back up and link only that file or subdirectory.
6. Verify application behavior and rollback before deleting the backup.
