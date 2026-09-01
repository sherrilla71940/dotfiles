# SessionStart hook. Three independent checks may add context:
#   1. Another interactive session is already in this working directory, so both share one
#      working tree, one index and one HEAD. Claude Code takes no lock on a directory, and
#      git only refuses a duplicate checkout across worktrees, not across processes.
#   2. Claude started in a directory that merely contains worktrees, so repository auto
#      memory may not have loaded.
#   3. Project continuity is active, or its activation decision is due before substantive work.
# Checks 1 and 2 apply only at launch; check 3 also refreshes after clear or compaction.
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
$sessionId = [string]$payload.session_id
$source = [string]$payload.source
$isLaunch = $source -in @("startup", "resume", "fork")

$messages = @()

# Drive-letter case and separator style both vary between the hook payload and the agent
# listing on Windows, so compare normalised paths rather than raw strings.
function Get-NormalisedPath([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return "" }
    return $path.ToLowerInvariant().Replace("\", "/").TrimEnd("/")
}

if ($isLaunch -and (Get-Command claude -ErrorAction SilentlyContinue)) {
    $listing = & claude agents --json 2>$null
    if (-not [string]::IsNullOrWhiteSpace($listing)) {
        try {
            $here = Get-NormalisedPath $workingDirectory
            $siblings = @(
                ($listing | ConvertFrom-Json) | Where-Object {
                    $_.kind -eq "interactive" -and
                    [string]$_.sessionId -ne $sessionId -and
                    (Get-NormalisedPath ([string]$_.cwd)) -eq $here
                }
            )
        } catch {
            $siblings = @()
        }

        if ($siblings.Count -gt 0) {
            $messages += "$($siblings.Count) other interactive Claude Code session(s) are already running in '$workingDirectory'. They share this working tree, index and HEAD, so a git add or commit here can pick up their staged changes, and a checkout switches their branch too. At the beginning of your first response, tell the user and offer the two ways forward rather than picking one for them. Staying here means staging explicit paths instead of -A or . and checking git diff --cached for files this session did not touch before every commit. Isolating this session instead does not need a restart: the EnterWorktree tool moves it into its own worktree now, and 'claude --worktree <name>' is only the launch-time equivalent. Ask which they want and create nothing until they answer. If they choose a worktree, check first whether HEAD is ahead of its upstream, because worktree.baseRef defaults to 'fresh' and branches from the remote default branch, which would leave unpushed commits out; 'head' branches from local HEAD instead."
        }
    }
}

$insideWorkTree = & git -C $workingDirectory rev-parse --is-inside-work-tree 2>$null
$isInsideWorkTree = $LASTEXITCODE -eq 0 -and $insideWorkTree -eq "true"

if ($isLaunch -and -not $isInsideWorkTree) {
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

    if ($worktrees.Count -gt 0) {
        $worktreeNames = ($worktrees | Select-Object -First 5 -ExpandProperty Name) -join ", "
        $messages += "Claude Code started in '$workingDirectory', which is not a git checkout but contains linked worktrees ($worktreeNames). Repository auto memory may not have loaded for this session. At the beginning of your first response, briefly tell the user and recommend restarting Claude inside the intended worktree."
    }
}

if ($isInsideWorkTree) {
    $workingTreeRoot = [string](& git -C $workingDirectory rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($workingTreeRoot)) {
        $continuityState = Join-Path $workingTreeRoot ".project-continuity\state.md"
        if (Test-Path -LiteralPath $continuityState -PathType Leaf) {
            # Naming the tracked objective turns "is this the same task?" from something the model
            # has to remember to ask into a fact it has already been shown. Replacing an unfinished
            # task's state with an unrelated one is the failure this is here to prevent.
            $objective = ""
            $collecting = $false
            foreach ($line in (Get-Content -LiteralPath $continuityState)) {
                if ($line -match '^## Objective') { $collecting = $true; continue }
                if (-not $collecting) { continue }
                if ($line -match '^## ') { break }
                if ($line.Trim()) {
                    $objective = if ($objective) { "$objective $($line.Trim())" } else { $line.Trim() }
                } elseif ($objective) { break }
            }
            if ($objective) {
                if ($objective.Length -gt 200) { $objective = $objective.Substring(0, 200) + "..." }
                $messages += "Project continuity is active in '$workingTreeRoot' and tracks this objective: `"$objective`". If that is the task you were just asked to do, invoke the project-continuity skill and reconcile its state against Git before substantive work. If it is not, leave the file untouched, answer the new request, and say the other task is still parked there. State 'Continuity: enabled' in the first progress update."
            } else {
                $messages += "Project continuity is active in '$workingTreeRoot'. Before substantive work, invoke the project-continuity skill and reconcile its state against Git. State 'Continuity: enabled' in the first progress update."
            }
        } elseif ($source -eq "compact") {
            $messages += "This conversation was compacted without active project continuity in '$workingTreeRoot'. Before resuming substantive work, reassess continuity under the global rule and make the decision visible in the next progress update."
        } else {
            $messages += "Project continuity is not active in '$workingTreeRoot'. Before the first substantive repository action, apply the global continuity rule and make the activation decision visible in the first progress update. Skip this reminder for explanation-only or small self-contained work."
        }
    }
}

if ($messages.Count -eq 0) {
    exit 0
}

$context = ($messages -join " ") + " Do not repeat these reminders in later responses."

@{
    hookSpecificOutput = @{
        hookEventName = "SessionStart"
        additionalContext = $context
    }
} | ConvertTo-Json -Compress -Depth 3
