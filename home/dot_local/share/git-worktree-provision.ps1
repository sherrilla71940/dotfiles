# Managed by the dotfiles repository. Provides the implementation behind the Windows-only
# `git wt-add` and `git wt-copy` aliases.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$script:GitExecutable = (Get-Command git.exe -ErrorAction Stop).Source
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:PathComparison = [StringComparison]::OrdinalIgnoreCase

function Format-DisplayText {
    param([AllowEmptyString()][string] $Text)

    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Text.ToCharArray()) {
        if ([char]::IsControl($character)) {
            [void]$builder.Append("?")
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString()
}

function Write-ProvisionRecord {
    param(
        [string] $Category,
        [string] $Path,
        [string] $Detail = ""
    )

    $safePath = Format-DisplayText $Path
    $suffix = if ($Detail) { ": $(Format-DisplayText $Detail)" } else { "" }
    Write-Host "[$Category] $safePath$suffix"
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string] $Value)

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashCount = 0

    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashCount++
            continue
        }

        if ($character -eq '"') {
            if ($backslashCount -gt 0) {
                [void]$builder.Append((([string][char]92) * ($backslashCount * 2)))
            }
            [void]$builder.Append('\"')
            $backslashCount = 0
            continue
        }

        if ($backslashCount -gt 0) {
            [void]$builder.Append((([string][char]92) * $backslashCount))
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }

    if ($backslashCount -gt 0) {
        [void]$builder.Append((([string][char]92) * ($backslashCount * 2)))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-GitCapture {
    param(
        [string] $WorkingDirectory,
        [string[]] $Arguments
    )

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $script:GitExecutable
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join " ")
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.StandardOutputEncoding = $script:Utf8NoBom
    $processInfo.StandardErrorEncoding = $script:Utf8NoBom

    # A shell Git alias exports repository-local variables from the invoking worktree. If they
    # reach a nested `git -C <other-worktree>` call, GIT_DIR wins over -C and makes Git inspect
    # the wrong index. Clear only repository-local variables; user-level Git configuration and
    # authentication remain available normally.
    foreach ($variableName in @(
        "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_DIR", "GIT_GRAFT_FILE",
        "GIT_IMPLICIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_INTERNAL_SUPER_PREFIX",
        "GIT_NO_REPLACE_OBJECTS", "GIT_OBJECT_DIRECTORY", "GIT_PREFIX",
        "GIT_REPLACE_REF_BASE", "GIT_SHALLOW_FILE", "GIT_WORK_TREE"
    )) {
        [void]$processInfo.EnvironmentVariables.Remove($variableName)
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    if (-not $process.Start()) {
        throw "Could not start Git."
    }

    try {
        $standardOutput = $process.StandardOutput.ReadToEndAsync()
        $standardError = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $standardOutput.Result
            Stderr = $standardError.Result
        }
    } finally {
        $process.Dispose()
    }
}

function Invoke-GitChecked {
    param(
        [string] $WorkingDirectory,
        [string[]] $Arguments,
        [string] $FailureMessage
    )

    $result = Invoke-GitCapture $WorkingDirectory $Arguments
    if ($result.ExitCode -ne 0) {
        $detail = $result.Stderr.Trim()
        if (-not $detail) { $detail = $result.Stdout.Trim() }
        if ($detail) {
            throw "$FailureMessage`n$detail"
        }
        throw $FailureMessage
    }
    return $result.Stdout
}

function Get-RepositoryRoot {
    param([string] $Path)

    $root = Invoke-GitChecked $Path @("rev-parse", "--show-toplevel") "Not inside a Git working tree."
    return [IO.Path]::GetFullPath($root.Trim())
}

function Get-CommonGitDirectory {
    param([string] $RepositoryRoot)

    $path = Invoke-GitChecked $RepositoryRoot `
        @("rev-parse", "--path-format=absolute", "--git-common-dir") `
        "Could not resolve the repository's common Git directory."
    return [IO.Path]::GetFullPath($path.Trim())
}

function Test-SamePath {
    param([string] $Left, [string] $Right)
    return [string]::Equals(
        [IO.Path]::GetFullPath($Left).TrimEnd("\", "/"),
        [IO.Path]::GetFullPath($Right).TrimEnd("\", "/"),
        $script:PathComparison
    )
}

function Test-PathInsideRoot {
    param([string] $Root, [string] $Path)

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $fullPath = [IO.Path]::GetFullPath($Path)
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    return $fullPath.StartsWith($prefix, $script:PathComparison)
}

function Split-NulOutput {
    param([AllowEmptyString()][string] $Text)
    return @($Text.Split([char[]]@([char]0), [StringSplitOptions]::RemoveEmptyEntries))
}

function Get-WorktreePaths {
    param([string] $RepositoryRoot)

    $output = Invoke-GitChecked $RepositoryRoot `
        @("worktree", "list", "--porcelain", "-z") `
        "Could not list Git worktrees."
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($field in (Split-NulOutput $output)) {
        if ($field.StartsWith("worktree ", [StringComparison]::Ordinal)) {
            $paths.Add([IO.Path]::GetFullPath($field.Substring(9)))
        }
    }
    return $paths.ToArray()
}

function Get-NewWorktreePath {
    param(
        [string[]] $Before,
        [string[]] $After
    )

    $known = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $Before) { [void]$known.Add([IO.Path]::GetFullPath($path)) }
    $added = @($After | Where-Object { -not $known.Contains([IO.Path]::GetFullPath($_)) })
    if ($added.Count -ne 1) {
        throw "Git created the worktree, but the new path could not be identified safely (found $($added.Count) new entries)."
    }
    return $added[0]
}

function Get-ReparsePoint {
    param(
        [string] $Root,
        [string] $Path,
        [bool] $IncludeLeaf
    )

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-PathInsideRoot $fullRoot $fullPath)) {
        return $fullPath
    }

    $relative = $fullPath.Substring($fullRoot.Length).TrimStart("\", "/")
    $segments = @($relative -split '[\\/]')
    if (-not $IncludeLeaf -and $segments.Count -gt 0) {
        $segments = @($segments[0..($segments.Count - 2)])
    }

    $current = $fullRoot
    foreach ($segment in $segments) {
        if (-not $segment) { continue }
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { continue }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $current
        }
    }
    return $null
}

function Get-PatternRejectionReason {
    param([string] $Pattern)

    $candidate = $Pattern
    if ($candidate.StartsWith("!", [StringComparison]::Ordinal)) {
        $candidate = $candidate.Substring(1)
    }
    if ($candidate.StartsWith("/", [StringComparison]::Ordinal)) {
        $candidate = $candidate.Substring(1)
    }

    if ($candidate -match '^[A-Za-z]:[\\/]' -or $candidate -match '^[/\\]{2}') {
        return "absolute filesystem paths are not allowed"
    }
    if ($candidate -match '(^|/)\.\.(/|$)') {
        return "parent-directory traversal is not allowed"
    }
    return $null
}

function Get-FileRejectionReason {
    param([string] $RelativePath)

    $path = "/" + $RelativePath.Replace("\", "/").TrimStart("/")
    $lower = $path.ToLowerInvariant()
    $segments = @($lower.Trim("/") -split "/")
    $blockedDirectories = @(
        ".git", ".project-continuity", "node_modules", "packages", "bin", "obj", ".vs",
        ".cache", "coverage", "dist"
    )
    foreach ($segment in $segments) {
        if ($blockedDirectories -contains $segment) {
            return "blocked directory '$segment'"
        }
    }

    if ($lower -match '^/\.claude/(worktrees|logs|agent-memory-local)(/|$)') {
        return "Claude session state is never copied"
    }
    if ($lower -match '^/\.codex(/|$)') {
        return "Codex local state is never copied"
    }

    $name = [IO.Path]::GetFileName($lower)
    if ($name -in @(".env.production", ".env.production.local")) {
        return "production environment files are never copied"
    }
    if ($name -in @(".npmrc", "nuget.config", "credentials.json", "auth.json", "id_rsa", "id_ed25519")) {
        return "credential or authentication files are never copied"
    }

    $extension = [IO.Path]::GetExtension($name)
    if ($extension -in @(".pem", ".key", ".pfx", ".p12", ".cer", ".crt")) {
        return "private keys and certificates are never copied"
    }
    if ($extension -in @(".bak", ".db", ".sqlite", ".sqlite3")) {
        return "database backups and local data stores are never copied"
    }
    return $null
}

function Get-ManifestPatterns {
    param([string] $ManifestPath)

    $patterns = @()
    foreach ($line in [IO.File]::ReadAllLines($ManifestPath, $script:Utf8NoBom)) {
        if (-not $line -or $line.StartsWith("#", [StringComparison]::Ordinal)) { continue }
        $patterns += $line
    }
    return $patterns
}

function Get-IgnoredFileSet {
    param(
        [string] $RepositoryRoot,
        [string[]] $ExcludeArguments
    )

    $arguments = @("ls-files", "--others", "--ignored") + $ExcludeArguments + @("-z", "--")
    $output = Invoke-GitChecked $RepositoryRoot $arguments "Git could not enumerate ignored files."
    $set = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::Ordinal)
    foreach ($path in (Split-NulOutput $output)) { [void]$set.Add($path) }
    Write-Output -NoEnumerate $set
}

function Get-ProvisionSelection {
    param([string] $SourceRoot)

    $manifestPath = Join-Path $SourceRoot ".worktreeinclude"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return [pscustomobject]@{
            ManifestPresent = $false
            Files = @()
            MissingPatterns = @()
            RejectedPatterns = @()
        }
    }

    $manifestReparse = Get-ReparsePoint $SourceRoot $manifestPath $true
    if ($manifestReparse) {
        throw ".worktreeinclude is or traverses a symbolic link or Windows reparse point."
    }

    $tracked = Invoke-GitCapture $SourceRoot @("ls-files", "--error-unmatch", "--", ".worktreeinclude")
    if ($tracked.ExitCode -ne 0) {
        throw ".worktreeinclude must be tracked before it can authorize copying ignored files."
    }

    $patterns = Get-ManifestPatterns $manifestPath
    $rejectedPatterns = @()
    foreach ($pattern in $patterns) {
        $reason = Get-PatternRejectionReason $pattern
        if ($reason) {
            $rejectedPatterns += [pscustomobject]@{ Pattern = $pattern; Reason = $reason }
        }
    }

    $standardIgnored = Get-IgnoredFileSet $SourceRoot @("--exclude-standard")
    $manifestMatched = Get-IgnoredFileSet $SourceRoot @("--exclude-from=.worktreeinclude")
    $files = @($manifestMatched | Where-Object { $standardIgnored.Contains($_) } | Sort-Object)

    $missingPatterns = @()
    foreach ($pattern in $patterns) {
        if ($pattern.StartsWith("!", [StringComparison]::Ordinal)) { continue }
        if (Get-PatternRejectionReason $pattern) { continue }

        $temporaryPatternFile = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllText($temporaryPatternFile, "$pattern`n", $script:Utf8NoBom)
            $matchedByPattern = Get-IgnoredFileSet $SourceRoot @("--exclude-from=$temporaryPatternFile")
            $hasEligibleMatch = $false
            foreach ($match in $matchedByPattern) {
                if ($standardIgnored.Contains($match)) {
                    $hasEligibleMatch = $true
                    break
                }
            }
            if (-not $hasEligibleMatch) { $missingPatterns += $pattern }
        } finally {
            Remove-Item -LiteralPath $temporaryPatternFile -Force -ErrorAction SilentlyContinue
        }
    }

    return [pscustomobject]@{
        ManifestPresent = $true
        Files = $files
        MissingPatterns = @($missingPatterns)
        RejectedPatterns = @($rejectedPatterns)
    }
}

function Assert-SameRepository {
    param([string] $SourceRoot, [string] $TargetRoot)

    $sourceCommon = Get-CommonGitDirectory $SourceRoot
    $targetCommon = Get-CommonGitDirectory $TargetRoot
    if (-not (Test-SamePath $sourceCommon $targetCommon)) {
        throw "Source and target are not worktrees of the same Git repository."
    }
}

function Invoke-ProvisionFiles {
    param(
        [string] $SourceRoot,
        [string] $TargetRoot,
        [switch] $DryRun
    )

    Assert-SameRepository $SourceRoot $TargetRoot
    $selection = Get-ProvisionSelection $SourceRoot
    if (-not $selection.ManifestPresent) {
        Write-ProvisionRecord "skipped" ".worktreeinclude" "manifest not found in source worktree"
        return [pscustomobject]@{ Success = $true; Copied = 0; Conflicts = 0; Rejected = 0; Missing = 0 }
    }

    foreach ($pattern in $selection.MissingPatterns) {
        Write-ProvisionRecord "missing" $pattern "no present Git-ignored source file matched"
    }
    foreach ($entry in $selection.RejectedPatterns) {
        Write-ProvisionRecord "rejected" $entry.Pattern $entry.Reason
    }

    $copied = 0
    $conflicts = 0
    $rejected = $selection.RejectedPatterns.Count

    foreach ($relativePath in $selection.Files) {
        $reason = Get-FileRejectionReason $relativePath
        if ($reason) {
            Write-ProvisionRecord "rejected" $relativePath $reason
            $rejected++
            continue
        }

        $platformRelativePath = $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $sourcePath = [IO.Path]::GetFullPath((Join-Path $SourceRoot $platformRelativePath))
        $targetPath = [IO.Path]::GetFullPath((Join-Path $TargetRoot $platformRelativePath))
        if (-not (Test-PathInsideRoot $SourceRoot $sourcePath) -or -not (Test-PathInsideRoot $TargetRoot $targetPath)) {
            Write-ProvisionRecord "rejected" $relativePath "resolved path escapes a worktree root"
            $rejected++
            continue
        }

        $sourceReparse = Get-ReparsePoint $SourceRoot $sourcePath $true
        if ($sourceReparse) {
            Write-ProvisionRecord "rejected" $relativePath "source path traverses a symbolic link or Windows reparse point"
            $rejected++
            continue
        }

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            Write-ProvisionRecord "missing" $relativePath "source file no longer exists or is not a regular file"
            continue
        }

        $targetReparse = Get-ReparsePoint $TargetRoot $targetPath $false
        if ($targetReparse) {
            Write-ProvisionRecord "rejected" $relativePath "target path traverses a symbolic link or Windows reparse point"
            $rejected++
            continue
        }

        if (Test-Path -LiteralPath $targetPath) {
            Write-ProvisionRecord "conflict" $relativePath "target already exists; not overwritten"
            $conflicts++
            continue
        }

        if ($DryRun) {
            Write-ProvisionRecord "would-copy" $relativePath
            $copied++
            continue
        }

        try {
            $targetDirectory = Split-Path -Parent $targetPath
            [IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
            $targetReparse = Get-ReparsePoint $TargetRoot $targetPath $false
            if ($targetReparse) {
                throw "target parent became a symbolic link or Windows reparse point"
            }
            [IO.File]::Copy($sourcePath, $targetPath, $false)
            Write-ProvisionRecord "copied" $relativePath
            $copied++
        } catch {
            Write-ProvisionRecord "rejected" $relativePath $_.Exception.Message
            $rejected++
        }
    }

    Write-Host "Summary: copied=$copied conflicts=$conflicts missing=$($selection.MissingPatterns.Count) rejected=$rejected"
    return [pscustomobject]@{
        Success = ($rejected -eq 0)
        Copied = $copied
        Conflicts = $conflicts
        Rejected = $rejected
        Missing = $selection.MissingPatterns.Count
    }
}

function Open-WorktreeInCode {
    param([string] $WorktreePath)

    $codeCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
    if (-not $codeCommand) { $codeCommand = Get-Command code -ErrorAction SilentlyContinue }
    if (-not $codeCommand) {
        throw "VS Code's 'code' command is not available on PATH."
    }

    & $codeCommand.Source --new-window $WorktreePath
    if ($LASTEXITCODE -ne 0) {
        throw "VS Code could not open the worktree."
    }
}

function Show-HandoffReminder {
    param([string] $WorktreePath)

    Write-Host "Handoff reminder: continuity and uncommitted changes stay in this worktree."
    Write-Host "Open this exact path in Claude Code, Codex, or Copilot:"
    Write-Host "  $(Format-DisplayText $WorktreePath)"
    Write-Host "Then say: Continue from project continuity."
}

function Show-AddUsage {
    Write-Host "Usage: git wt-add [--dry-run] [--skip-copy] [--open-code] -- <git worktree add arguments>"
}

function Show-CopyUsage {
    Write-Host "Usage: git wt-copy [--dry-run] [--source <existing-worktree-path>]"
}

function Invoke-AddCommand {
    param([string[]] $CommandArguments)

    if ($CommandArguments -contains "--help" -or $CommandArguments -contains "-h") {
        Show-AddUsage
        return 0
    }

    $separatorIndex = [Array]::IndexOf($CommandArguments, "--")
    if ($separatorIndex -lt 0) {
        throw "Use -- to separate wrapper options from native 'git worktree add' arguments."
    }

    $wrapperArguments = if ($separatorIndex -eq 0) { @() } else { @($CommandArguments[0..($separatorIndex - 1)]) }
    $gitArguments = if ($separatorIndex -eq $CommandArguments.Count - 1) { @() } else { @($CommandArguments[($separatorIndex + 1)..($CommandArguments.Count - 1)]) }
    if ($gitArguments.Count -eq 0) {
        throw "Native 'git worktree add' arguments are required after --."
    }

    $dryRun = $false
    $skipCopy = $false
    $openCode = $false
    foreach ($argument in $wrapperArguments) {
        switch ($argument) {
            "--dry-run" { $dryRun = $true }
            "--skip-copy" { $skipCopy = $true }
            "--open-code" { $openCode = $true }
            default { throw "Unknown wt-add option: $(Format-DisplayText $argument)" }
        }
    }

    $sourceRoot = Get-RepositoryRoot (Get-Location).Path
    if ($dryRun) {
        Write-Host "[dry-run] git worktree add arguments accepted; Git will not be executed."
        if (-not $skipCopy) {
            $selection = Get-ProvisionSelection $sourceRoot
            if (-not $selection.ManifestPresent) {
                Write-ProvisionRecord "skipped" ".worktreeinclude" "manifest not found in source worktree"
            } else {
                foreach ($path in $selection.Files) { Write-ProvisionRecord "eligible" $path }
                foreach ($pattern in $selection.MissingPatterns) {
                    Write-ProvisionRecord "missing" $pattern "no present Git-ignored source file matched"
                }
                foreach ($entry in $selection.RejectedPatterns) {
                    Write-ProvisionRecord "rejected" $entry.Pattern $entry.Reason
                }
                if ($selection.RejectedPatterns.Count -gt 0) { return 2 }
            }
        }
        if ($openCode) { Write-Host "[dry-run] VS Code will not be opened." }
        return 0
    }

    $before = Get-WorktreePaths $sourceRoot
    $gitResult = Invoke-GitCapture $sourceRoot (@("worktree", "add") + $gitArguments)
    if ($gitResult.Stdout) { [Console]::Out.Write($gitResult.Stdout) }
    if ($gitResult.Stderr) { [Console]::Error.Write($gitResult.Stderr) }
    if ($gitResult.ExitCode -ne 0) { return $gitResult.ExitCode }

    $after = Get-WorktreePaths $sourceRoot
    $targetRoot = Get-NewWorktreePath $before $after
    Write-Host "Worktree: $(Format-DisplayText $targetRoot)"

    if ($skipCopy) {
        Write-ProvisionRecord "skipped" ".worktreeinclude" "copying disabled by --skip-copy"
    } else {
        $result = Invoke-ProvisionFiles $sourceRoot $targetRoot
        if (-not $result.Success) { return 2 }
    }

    if ($openCode) { Open-WorktreeInCode $targetRoot }
    Show-HandoffReminder $targetRoot
    return 0
}

function Get-PrimaryWorktreeRoot {
    param([string] $TargetRoot)

    $commonDirectory = Get-CommonGitDirectory $TargetRoot
    if ($env:GIT_WORKTREE_PROVISION_DEBUG) {
        [Console]::Error.WriteLine("debug common Git directory: $(Format-DisplayText $commonDirectory)")
    }
    foreach ($worktreePath in (Get-WorktreePaths $TargetRoot)) {
        if (-not (Test-Path -LiteralPath $worktreePath -PathType Container)) { continue }
        $gitDirectoryOutput = Invoke-GitCapture $worktreePath @("rev-parse", "--path-format=absolute", "--git-dir")
        if ($gitDirectoryOutput.ExitCode -ne 0) { continue }
        $gitDirectory = [IO.Path]::GetFullPath($gitDirectoryOutput.Stdout.Trim())
        if ($env:GIT_WORKTREE_PROVISION_DEBUG) {
            [Console]::Error.WriteLine("debug worktree Git directory: $(Format-DisplayText $worktreePath) -> $(Format-DisplayText $gitDirectory)")
        }
        if (Test-SamePath $gitDirectory $commonDirectory) { return $worktreePath }
    }
    return $null
}

function Invoke-CopyCommand {
    param([string[]] $CommandArguments)

    if ($null -eq $CommandArguments) { $CommandArguments = @() }

    if ($CommandArguments -contains "--help" -or $CommandArguments -contains "-h") {
        Show-CopyUsage
        return 0
    }

    $dryRun = $false
    $sourceArgument = $null
    for ($index = 0; $index -lt $CommandArguments.Count; $index++) {
        $argument = $CommandArguments[$index]
        switch ($argument) {
            "--dry-run" { $dryRun = $true }
            "--source" {
                $index++
                if ($index -ge $CommandArguments.Count) { throw "--source requires a path." }
                $sourceArgument = $CommandArguments[$index]
            }
            default { throw "Unknown wt-copy option: $(Format-DisplayText $argument)" }
        }
    }

    $targetRoot = Get-RepositoryRoot (Get-Location).Path
    if ($sourceArgument) {
        $sourcePath = if ([IO.Path]::IsPathRooted($sourceArgument)) {
            [IO.Path]::GetFullPath($sourceArgument)
        } else {
            [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $sourceArgument))
        }
        $sourceRoot = Get-RepositoryRoot $sourcePath
    } else {
        $sourceRoot = Get-PrimaryWorktreeRoot $targetRoot
        if (-not $sourceRoot -or (Test-SamePath $sourceRoot $targetRoot)) {
            throw "The source worktree is ambiguous. Supply --source <existing-worktree-path>."
        }
    }

    Assert-SameRepository $sourceRoot $targetRoot
    if (Test-SamePath $sourceRoot $targetRoot) {
        throw "Source and target must be different worktrees."
    }
    Write-Host "Source worktree: $(Format-DisplayText $sourceRoot)"
    Write-Host "Target worktree: $(Format-DisplayText $targetRoot)"

    $result = Invoke-ProvisionFiles $sourceRoot $targetRoot -DryRun:$dryRun
    if (-not $result.Success) { return 2 }
    return 0
}

try {
    if ($args.Count -eq 0) {
        Write-Host "Usage: git-worktree-provision.ps1 <add|copy> [arguments]"
        exit 2
    }

    $command = $args[0]
    $commandArguments = if ($args.Count -eq 1) { @() } else { @($args[1..($args.Count - 1)]) }
    $exitCode = switch ($command) {
        "add" { Invoke-AddCommand $commandArguments; break }
        "copy" { Invoke-CopyCommand $commandArguments; break }
        default { throw "Unknown command: $(Format-DisplayText $command)" }
    }
    exit $exitCode
} catch {
    [Console]::Error.WriteLine("git-worktree-provision: $($_.Exception.Message)")
    if ($env:GIT_WORKTREE_PROVISION_DEBUG) {
        [Console]::Error.WriteLine($_.ScriptStackTrace)
    }
    exit 2
}
