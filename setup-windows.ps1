[CmdletBinding()]
param(
    [string[]]$Components,
    [switch]$Migrate,
    [switch]$InstallVSCodeExtensions
)

$ErrorActionPreference = "Stop"

$knownComponents = @("claude", "codex", "copilot", "vscode", "shell")

function Resolve-Components([string[]]$Requested) {
    if (-not $Requested) { return $knownComponents }

    $names = $Requested |
        ForEach-Object { $_ -split "," } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { $_ }

    if (-not $names) { return $knownComponents }
    if ($names -contains "all") { return $knownComponents }

    $unknown = $names | Where-Object { $knownComponents -notcontains $_ }
    if ($unknown) {
        Write-Host "Unknown component: $($unknown -join ', ')" -ForegroundColor Red
        Write-Host "Valid components: $($knownComponents -join ', '), all"
        Write-Host "Example: .\setup-windows.ps1 -Components copilot,vscode"
        exit 2
    }

    return $names | Select-Object -Unique
}

$selectedComponents = Resolve-Components $Components

$repositoryRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeHome = Join-Path $env:USERPROFILE ".claude"
$codexHome = Join-Path $env:USERPROFILE ".codex"
$agentsHome = Join-Path $env:USERPROFILE ".agents"
$copilotHome = Join-Path $env:USERPROFILE ".copilot"
$vscodeHome = Join-Path $env:APPDATA "Code\User"
$backupRoot = Join-Path $env:USERPROFILE (".dotfiles-backups\" + (Get-Date -Format "yyyyMMdd-HHmmss"))

function Normalize-Path([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd("\", "/")
}

function Move-ToBackup([string]$LivePath, [string]$BackupName) {
    $destination = Join-Path $backupRoot $BackupName
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Move-Item -LiteralPath $LivePath -Destination $destination
    Write-Host "BAK $LivePath -> $destination"
    return $destination
}

function New-DotfilesSymbolicLink([string]$LivePath, [string]$SourcePath) {
    try {
        New-Item -ItemType SymbolicLink -Path $LivePath -Target $SourcePath -ErrorAction Stop | Out-Null
        return
    } catch {
        if (-not ("DotfilesNativeSymlink" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DotfilesNativeSymlink {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CreateSymbolicLink(string linkPath, string targetPath, int flags);
}
"@
        }

        $allowUnprivilegedCreate = 2
        $directoryFlag = if (Test-Path -LiteralPath $SourcePath -PathType Container) { 1 } else { 0 }
        $created = [DotfilesNativeSymlink]::CreateSymbolicLink(
            $LivePath,
            $SourcePath,
            ($allowUnprivilegedCreate -bor $directoryFlag)
        )
        if (-not $created) {
            $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw (New-Object ComponentModel.Win32Exception($errorCode))
        }
    }
}

function Ensure-SymbolicLink([string]$LivePath, [string]$SourcePath, [string]$BackupName) {
    $backupDestination = $null
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Missing repository source: $SourcePath"
    }

    $item = Get-Item -Force -LiteralPath $LivePath -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        $target = [string]($item.Target -join "")
        if ($item.LinkType -in @("SymbolicLink", "Junction") -and (Normalize-Path $target) -eq (Normalize-Path $SourcePath)) {
            Write-Host "OK  $LivePath -> $SourcePath"
            return
        }
        if (-not $Migrate) {
            throw "Refusing to replace existing path: $LivePath`nIt currently resolves to: $(if ($target) { $target } else { '(real file or directory)' })`nIntended source: $SourcePath`nRerun with -Migrate to move it into a timestamped backup first."
        }
        $backupDestination = Move-ToBackup -LivePath $LivePath -BackupName $BackupName
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LivePath) | Out-Null
    try {
        New-DotfilesSymbolicLink -LivePath $LivePath -SourcePath $SourcePath
        Write-Host "ADD $LivePath -> $SourcePath"
    } catch {
        if ($backupDestination -and -not (Test-Path -LiteralPath $LivePath) -and (Test-Path -LiteralPath $backupDestination)) {
            Move-Item -LiteralPath $backupDestination -Destination $LivePath
            Write-Warning "Restored $LivePath because link creation failed."
        }
        throw "Could not create symbolic link: $LivePath`nEnable Windows Developer Mode or run PowerShell as Administrator, then retry.`n$($_.Exception.Message)"
    }
}

Write-Host "Components: $($selectedComponents -join ', ')"

# Only the selected components' configuration directories are created.
$componentDirectories = @{
    claude  = @($claudeHome)
    codex   = @($codexHome, $agentsHome)
    copilot = @($copilotHome)
    vscode  = @($vscodeHome)
    shell   = @()
}

foreach ($component in $selectedComponents) {
    foreach ($directory in $componentDirectories[$component]) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
}

# VS Code paths below target the default profile. Named profiles keep their own
# storage under %APPDATA%\Code\User\profiles\<id>; see dotfiles-setup.md.
$links = @(
    @{ Component = "claude";  Live = Join-Path $claudeHome "dotfiles"; Source = Join-Path $repositoryRoot "claude"; Backup = "claude/dotfiles" },
    @{ Component = "claude";  Live = Join-Path $claudeHome "CLAUDE.md"; Source = Join-Path $repositoryRoot "claude/CLAUDE.md"; Backup = "claude/CLAUDE.md" },
    @{ Component = "claude";  Live = Join-Path $claudeHome "commands"; Source = Join-Path $repositoryRoot "claude/commands"; Backup = "claude/commands" },
    @{ Component = "claude";  Live = Join-Path $claudeHome "rules"; Source = Join-Path $repositoryRoot "claude/rules"; Backup = "claude/rules" },
    @{ Component = "claude";  Live = Join-Path $claudeHome "settings.json"; Source = Join-Path $repositoryRoot "claude/settings.json"; Backup = "claude/settings.json" },
    @{ Component = "claude";  Live = Join-Path $claudeHome "skills"; Source = Join-Path $repositoryRoot "claude/skills"; Backup = "claude/skills" },
    @{ Component = "codex";   Live = Join-Path $codexHome "AGENTS.md"; Source = Join-Path $repositoryRoot "codex/AGENTS.md"; Backup = "codex/AGENTS.md" },
    @{ Component = "codex";   Live = Join-Path $agentsHome "skills"; Source = Join-Path $repositoryRoot "agents/skills"; Backup = "agents/skills" },
    @{ Component = "copilot"; Live = Join-Path $copilotHome "agents"; Source = Join-Path $repositoryRoot "copilot/agents"; Backup = "copilot/agents" },
    @{ Component = "copilot"; Live = Join-Path $copilotHome "instructions"; Source = Join-Path $repositoryRoot "copilot/instructions"; Backup = "copilot/instructions" },
    @{ Component = "copilot"; Live = Join-Path $copilotHome "skills"; Source = Join-Path $repositoryRoot "copilot/skills"; Backup = "copilot/skills" },
    @{ Component = "vscode";  Live = Join-Path $vscodeHome "settings.json"; Source = Join-Path $repositoryRoot "vscode/settings.json"; Backup = "vscode/settings.json" },
    @{ Component = "vscode";  Live = Join-Path $vscodeHome "keybindings.json"; Source = Join-Path $repositoryRoot "vscode/keybindings.json"; Backup = "vscode/keybindings.json" },
    @{ Component = "vscode";  Live = Join-Path $vscodeHome "mcp.json"; Source = Join-Path $repositoryRoot "vscode/mcp.json"; Backup = "vscode/mcp.json" },
    @{ Component = "vscode";  Live = Join-Path $vscodeHome "prompts"; Source = Join-Path $repositoryRoot "copilot/prompts"; Backup = "copilot/prompts" },
    @{ Component = "shell";   Live = Join-Path $env:USERPROFILE ".bashrc"; Source = Join-Path $repositoryRoot "shell/bashrc"; Backup = "shell/bashrc" },
    @{ Component = "shell";   Live = Join-Path $env:USERPROFILE ".bash_profile"; Source = Join-Path $repositoryRoot "shell/bash_profile"; Backup = "shell/bash_profile" }
)

foreach ($link in $links) {
    if ($selectedComponents -notcontains $link.Component) { continue }
    Ensure-SymbolicLink -LivePath $link.Live -SourcePath $link.Source -BackupName $link.Backup
}

if ($selectedComponents -contains "copilot") {
    # Copilot writes these itself; they stay local and untracked.
    foreach ($runtimePath in @("config.json", "ide", "logs")) {
        $fullPath = Join-Path $copilotHome $runtimePath
        if (Test-Path -LiteralPath $fullPath) {
            Write-Host "LOCAL $fullPath (Copilot runtime state; intentionally not linked)"
        }
    }
}

if ($selectedComponents -contains "codex") {
    $codexConfig = Join-Path $codexHome "config.toml"
    if (Test-Path -LiteralPath $codexConfig) {
        Write-Host "LOCAL $codexConfig (kept local because Codex writes machine state here)"
    } else {
        $sharedConfig = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "codex/config.shared.toml")
        $windowsConfig = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "codex/config.windows.toml")
        [System.IO.File]::WriteAllText($codexConfig, ($sharedConfig.TrimEnd() + "`n`n" + $windowsConfig.TrimStart()), [System.Text.UTF8Encoding]::new($false))
        Write-Host "ADD $codexConfig (bootstrapped from tracked templates; intentionally not linked)"
    }

    $legacyHomeAgents = Join-Path $env:USERPROFILE "AGENTS.md"
    if (Test-Path -LiteralPath $legacyHomeAgents) {
        Write-Warning "$legacyHomeAgents is not managed. When working below your home directory it can duplicate ~/.codex/AGENTS.md; review and remove it manually if it is redundant."
    }
}

if ($InstallVSCodeExtensions) {
    if ($selectedComponents -notcontains "vscode") {
        throw "-InstallVSCodeExtensions requires the vscode component."
    }
    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code) {
        throw "VS Code's 'code' command is not available on PATH."
    }
    Get-Content -LiteralPath (Join-Path $repositoryRoot "vscode/extensions.txt") |
        Where-Object { $_ -and -not $_.StartsWith("#") } |
        ForEach-Object { & $code.Source --install-extension $_ --force }
}

Write-Host "Dotfiles setup is complete for: $($selectedComponents -join ', ')"
Write-Host "Restart the applications you just configured so they re-read the linked files."
