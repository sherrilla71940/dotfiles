$ErrorActionPreference = "SilentlyContinue"

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    exit 0
}

try {
    $payload = $inputJson | ConvertFrom-Json
} catch {
    exit 0
}

$workingDirectory = [string]$payload.cwd
if ([string]::IsNullOrWhiteSpace($workingDirectory) -or -not (Test-Path -LiteralPath $workingDirectory -PathType Container)) {
    exit 0
}

$insideWorkTree = & git -C $workingDirectory rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0 -and $insideWorkTree -eq "true") {
    exit 0
}

$worktrees = @(
    Get-ChildItem -LiteralPath $workingDirectory -Directory -Force | Where-Object {
        $gitFile = Join-Path $_.FullName ".git"
        if (-not (Test-Path -LiteralPath $gitFile -PathType Leaf)) {
            return $false
        }

        $childInsideWorkTree = & git -C $_.FullName rev-parse --is-inside-work-tree 2>$null
        return $LASTEXITCODE -eq 0 -and $childInsideWorkTree -eq "true"
    }
)

if ($worktrees.Count -eq 0) {
    exit 0
}

$worktreeNames = ($worktrees | Select-Object -First 5 -ExpandProperty Name) -join ", "
$context = "Claude Code started in '$workingDirectory', which is not a git checkout but contains linked worktrees ($worktreeNames). Repository auto memory may not have loaded for this session. At the beginning of your first response, briefly tell the user and recommend restarting Claude inside the intended worktree. Do not repeat the reminder in later responses."

@{
    hookSpecificOutput = @{
        hookEventName = "SessionStart"
        additionalContext = $context
    }
} | ConvertTo-Json -Compress -Depth 3
