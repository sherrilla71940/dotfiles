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

# The link table lives in links.tsv so both installers read one source of truth.
# VS Code paths target the default profile. Named profiles keep their own storage
# under %APPDATA%\Code\User\profiles\<id>; see dotfiles-setup.md.
$links = Get-Content -LiteralPath (Join-Path $repositoryRoot "links.tsv") |
    Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith("#") } |
    ForEach-Object {
        $fields = $_ -split "`t"
        if ($fields.Count -lt 3) { throw "Malformed row in links.tsv (need 3 tab-separated columns): $_" }
        $platform = if ($fields.Count -ge 4) { $fields[3].Trim() } else { "" }
        $live = $fields[1].Trim().Replace("{HOME}", $env:USERPROFILE).Replace("{VSCODE_USER}", $vscodeHome)
        [pscustomobject]@{
            Component = $fields[0].Trim()
            Live      = Normalize-Path $live
            Source    = Normalize-Path (Join-Path $repositoryRoot $fields[2].Trim())
            # Keyed on the live path, not the source: two live paths can share one source
            # (both ~/.claude/skills and ~/.agents/skills point at skills/), and identical
            # backup names would collide in the same timestamped backup directory.
            Backup    = "$($fields[0].Trim())/$(Split-Path -Leaf $live)"
            Platform  = $platform
        }
    } |
    Where-Object { $_.Platform -eq "" -or $_.Platform -eq "windows" }

$unknownInTable = $links | Where-Object { $knownComponents -notcontains $_.Component }
if ($unknownInTable) {
    throw "links.tsv references unknown component(s): $(($unknownInTable.Component | Select-Object -Unique) -join ', ')"
}

$duplicateBackups = $links | Group-Object Backup | Where-Object { $_.Count -gt 1 }
if ($duplicateBackups) {
    throw "links.tsv rows produce colliding backup names: $(($duplicateBackups.Name) -join ', '). Rename a live path or add a component."
}
$duplicateLive = $links | Group-Object Live | Where-Object { $_.Count -gt 1 }
if ($duplicateLive) {
    throw "links.tsv maps the same live path more than once: $(($duplicateLive.Name) -join ', ')"
}


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
