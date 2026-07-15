---
name: claude-dotfiles
description: Automated cross-platform symlink deployment playbook for Claude configurations.
disable-model-invocation: true
argument-hint: "[git-bash | wsl | powershell | mac]"
---

# Claude Dotfiles Deployment Playbook

## Selected Runtime Setup: \$target-environment

You have explicitly targeted the **\$target-environment** configuration path. Follow only the logic branches matching your chosen environment below.

---

## 1. Local Workspace Initialization
Execute these setup commands in your active shell window:
```bash
mkdir -p ~/dotfiles/claude
cd ~/dotfiles
git init
```

---

## 2. Directory Relocation and Symlink Execution

### Condition: If \$target-environment is 'git-bash'
```bash
# 1. Copy (not move) active user configurations into your dotfiles directory
cp -r ~/.claude ~/dotfiles/claude/.claude
cp "$APPDATA/Claude/claude_desktop_config.json" ~/dotfiles/claude/

# 2. Rename the originals aside (recoverable) rather than deleting them
mv ~/.claude ~/.claude.bak
mv "$APPDATA/Claude/claude_desktop_config.json" "$APPDATA/Claude/claude_desktop_config.json.bak"

# 3. Deploy Symbolic Links (Relaunch Git Bash as Admin if permission is denied)
ln -s ~/dotfiles/claude/.claude ~/.claude
ln -s ~/dotfiles/claude/claude_desktop_config.json "$APPDATA/Claude/claude_desktop_config.json"

# 4. Verify the symlinks resolve before discarding the backups
ls -la ~/.claude "$APPDATA/Claude/claude_desktop_config.json"
# Once verified working, remove the backups:
# rm -rf ~/.claude.bak "$APPDATA/Claude/claude_desktop_config.json.bak"
```

### Condition: If \$target-environment is 'wsl'
```bash
# 1. Copy (not move) Linux-native CLI configurations inside the container
cp -r ~/.claude ~/dotfiles/claude/.claude

# 2. Copy your host Windows-side desktop settings via the file mount
cp /mnt/c/Users/$USER/AppData/Roaming/Claude/claude_desktop_config.json ~/dotfiles/claude/

# 3. Rename the originals aside (recoverable) rather than deleting them
mv ~/.claude ~/.claude.bak
mv /mnt/c/Users/$USER/AppData/Roaming/Claude/claude_desktop_config.json /mnt/c/Users/$USER/AppData/Roaming/Claude/claude_desktop_config.json.bak

# 4. Create absolute system tracking bridges
ln -s ~/dotfiles/claude/.claude ~/.claude
ln -s ~/dotfiles/claude/claude_desktop_config.json /mnt/c/Users/$USER/AppData/Roaming/Claude/claude_desktop_config.json

# 5. Verify the symlinks resolve before discarding the backups
ls -la ~/.claude /mnt/c/Users/$USER/AppData/Roaming/Claude/claude_desktop_config.json
# Once verified working, remove the backups:
# rm -rf ~/.claude.bak /mnt/c/Users/$USER/AppData/Roaming/Claude/claude_desktop_config.json.bak
```

### Condition: If \$target-environment is 'powershell'
```powershell
# 1. Copy (not move) folder structures utilizing Windows-native cmdlets
Copy-Item -Recurse -Path "$HOME\.claude" -Destination "$HOME\dotfiles\claude\.claude"
Copy-Item -Path "$env:APPDATA\Claude\claude_desktop_config.json" -Destination "$HOME\dotfiles\claude\"

# 2. Rename the originals aside (recoverable) rather than deleting them
Rename-Item -Path "$HOME\.claude" -NewName ".claude.bak"
Rename-Item -Path "$env:APPDATA\Claude\claude_desktop_config.json" -NewName "claude_desktop_config.json.bak"

# 3. Deploy local symbolic links via PowerShell Core
New-Item -ItemType SymbolicLink -Path "$HOME\.claude" -Target "$HOME\dotfiles\claude\.claude"
New-Item -ItemType SymbolicLink -Path "$env:APPDATA\Claude\claude_desktop_config.json" -Target "$HOME\dotfiles\claude\claude_desktop_config.json"

# 4. Verify the symlinks resolve before discarding the backups
Get-Item "$HOME\.claude", "$env:APPDATA\Claude\claude_desktop_config.json"
# Once verified working, remove the backups:
# Remove-Item -Recurse -Force "$HOME\.claude.bak", "$env:APPDATA\Claude\claude_desktop_config.json.bak"
```

### Condition: If \$target-environment is 'mac'
```bash
# 1. Copy (not move) standard macOS structural directories
cp -r ~/.claude ~/dotfiles/claude/.claude
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json ~/dotfiles/claude/

# 2. Rename the originals aside (recoverable) rather than deleting them
mv ~/.claude ~/.claude.bak
mv ~/Library/Application\ Support/Claude/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json.bak

# 3. Deploy standard POSIX symlinks
ln -s ~/dotfiles/claude/.claude ~/.claude
ln -s ~/dotfiles/claude/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json

# 4. Verify the symlinks resolve before discarding the backups
ls -la ~/.claude ~/Library/Application\ Support/Claude/claude_desktop_config.json
# Once verified working, remove the backups:
# rm -rf ~/.claude.bak ~/Library/Application\ Support/Claude/claude_desktop_config.json.bak
```

---

## 3. Local Isolation Logic (.gitignore)
Generate an active path ignore manifest to lock down tokens. Use an **allowlist** rather than a blocklist — new or renamed files default to untracked, so a config path you didn't anticipate can't leak secrets into the repo:
```bash
nano ~/dotfiles/claude/.gitignore
```

Ensure these lines are inserted:
```text
# Ignore everything by default; only explicitly allowed paths below are tracked
*
!*/

# Known-safe configuration files/directories — extend this list deliberately
!.claude/settings.json
!.claude/CLAUDE.md
!.claude/skills/**
!.claude/commands/**
!.gitignore

# Never track these, even if a broader pattern above would otherwise include them
.claude/sessions/
.claude/keys/
.claude/login/
.claude/history/
.claude/*.local.json
```

---

## 4. Line Normalization and Baseline Staging
```bash
# Normalize terminal line breaks to prevent text mismatches across machines
git config core.autocrlf true

# Stage, clean, and run your first tracking commit
cd ~/dotfiles
git add claude/
git commit -m "chore: track configuration snapshots for environment: \$target-environment"
```
