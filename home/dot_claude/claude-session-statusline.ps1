$ErrorActionPreference = "Stop"

# Windows PowerShell writes stdout using the console code page, which is not
# UTF-8 on every machine and mangles the icons below. Force UTF-8 before any
# output is produced.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    exit 0
}

try {
    $data = $inputJson | ConvertFrom-Json
} catch {
    Write-Error "Claude status line received invalid JSON: $($_.Exception.Message)"
    exit 1
}

# Icons and separators are built from code points instead of being written
# literally: Windows PowerShell parses a script without a byte order mark using
# the ANSI code page, which would corrupt literal multi-byte characters here.
$iconModel = [char]::ConvertFromUtf32(0x1F916)      # robot
$iconDirectory = [char]::ConvertFromUtf32(0x1F4C1)  # folder
$iconBranch = [char]::ConvertFromUtf32(0x1F33F)     # herb
$iconContext = [char]::ConvertFromUtf32(0x1F9E0)    # brain
$iconCost = [char]::ConvertFromUtf32(0x1F4B0)       # money bag
$iconLimits = [char]::ConvertFromUtf32(0x23F3)      # hourglass with flowing sand

# Basic ANSI codes only, so the terminal's own theme decides the exact hues.
$escape = [char]27
$dim = "$escape[90m"
$cyan = "$escape[36m"
$blue = "$escape[94m"
$magenta = "$escape[95m"
$green = "$escape[32m"
$yellow = "$escape[33m"
$red = "$escape[31m"
$reset = "$escape[0m"

# Two separator weights carry the hierarchy: the heavier rule divides unrelated
# scopes, the lighter dot joins values that belong to the same group.
$majorSeparator = "$dim  $([char]0x2502)  $reset"
$minorSeparator = "$dim $([char]0x00B7) $reset"

# Context fill and rate-limit fill share one threshold scale, so a given colour
# always carries the same meaning wherever it appears on the line.
# No branch is provided on stdin outside --worktree sessions, so ask git. A
# single porcelain v2 call answers all three questions at once — whether this is
# a repository, which branch is checked out, and what the work tree looks like —
# because spawning git costs about as much as git's own work here. The query is
# scoped to the session's directory since this script's working directory is not
# necessarily the project. Untracked files are excluded: they are not reported,
# and skipping them avoids the untracked scan.
function Get-GitSummary {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) { return "" }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return "" }

    # git reports ordinary conditions such as "not a repository" on stderr, and
    # the script-wide Stop preference would turn that into a thrown error, so
    # relax it only around the call.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = @(& git -C $Directory status --porcelain=v2 --branch --untracked-files=no 2>$null)
        if ($LASTEXITCODE -ne 0) { return "" }
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $branch = ""
    $objectId = ""
    $stagedCount = 0
    $modifiedCount = 0
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line.StartsWith("# branch.head ")) {
            $branch = $line.Substring(14).Trim()
        } elseif ($line.StartsWith("# branch.oid ")) {
            $objectId = $line.Substring(13).Trim()
        } elseif ($line.Length -ge 4 -and "12u".IndexOf($line[0]) -ge 0 -and $line[1] -eq ' ') {
            # Changed, renamed and unmerged entries all carry the two state
            # columns in the same position: index state then work-tree state.
            if ($line[2] -ne '.') { $stagedCount++ }
            if ($line[3] -ne '.') { $modifiedCount++ }
        }
    }

    # Detached HEAD reports no branch name, so fall back to a parenthesised short
    # object id the way git's own shell prompt does.
    if ($branch -eq "(detached)") {
        if ($objectId.Length -ge 7) { $branch = "($($objectId.Substring(0, 7)))" } else { $branch = "" }
    }
    if ([string]::IsNullOrWhiteSpace($branch)) { return "" }

    $summary = $branch
    if ($stagedCount -gt 0) { $summary += " +$stagedCount" }
    if ($modifiedCount -gt 0) { $summary += " ~$modifiedCount" }
    return $summary
}

# An absolute wall-clock time rather than a countdown: this script runs on
# events, and those go quiet while the session is idle, so a countdown would
# silently drift while a clock time stays correct however stale the render is.
function Get-ResetLabel {
    param([long]$Epoch)

    $moment = [DateTimeOffset]::FromUnixTimeSeconds($Epoch).ToLocalTime()

    # Beyond a day out the time of day alone is ambiguous, so name the weekday.
    $format = "HH:mm"
    if (($moment - [DateTimeOffset]::Now).TotalSeconds -ge 86400) {
        $format = "ddd"
    }

    # Invariant culture keeps the weekday identical to the bash copy.
    return $moment.ToString($format, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-UsageColor {
    param([double]$Percentage)

    if ($Percentage -ge 90) { return $red }
    if ($Percentage -ge 70) { return $yellow }
    return $green
}

# The reset time always accompanies the percentage, because the percentage alone
# cannot say whether a nearly full window clears in minutes or in hours.
function Get-LimitValue {
    param([string]$Label, [double]$Percentage, $ResetEpoch)

    $floored = [math]::Floor($Percentage)
    $text = "$(Get-UsageColor -Percentage $floored)$Label $floored%$reset"

    if ($null -ne $ResetEpoch) {
        $moment = Get-ResetLabel -Epoch ([long]$ResetEpoch)
        if (-not [string]::IsNullOrWhiteSpace($moment)) {
            $text += "$dim resets $moment$reset"
        }
    }

    return $text
}

$model = [string]$data.model.display_name
# Absent on models without a reasoning effort parameter; tracks /effort changes
# made mid-session.
$effortLevel = [string]$data.effort.level
$currentDirectory = [string]$data.workspace.current_dir
$usedPercentage = $data.context_window.used_percentage
# Client-side estimate only; resets to 0 when /clear starts a new session.
$sessionCost = $data.cost.total_cost_usd
# Rate limits are present only for Claude.ai Pro/Max sessions, and each window
# can be absent independently, so both are treated as optional.
$fiveHourUsage = $data.rate_limits.five_hour.used_percentage
$sevenDayUsage = $data.rate_limits.seven_day.used_percentage
$fiveHourReset = $data.rate_limits.five_hour.resets_at
$sevenDayReset = $data.rate_limits.seven_day.resets_at

# Line one is identity: rarely changes, so it stays out of the way of the meters.
$identitySegments = @()
# Effort qualifies the model rather than standing alone, so the two share a
# segment. It stays uncoloured: the threshold palette already means fill level.
if (-not [string]::IsNullOrWhiteSpace($model)) {
    $modelSegment = "$cyan$iconModel $model$reset"
    if (-not [string]::IsNullOrWhiteSpace($effortLevel)) {
        $modelSegment += "$minorSeparator$dim$effortLevel$reset"
    }
    $identitySegments += $modelSegment
} elseif (-not [string]::IsNullOrWhiteSpace($effortLevel)) {
    $identitySegments += "$dim$iconModel $effortLevel effort$reset"
}

# Branch joins the directory for the same reason effort joins the model: both
# answer "where am I", so they read as one group.
if (-not [string]::IsNullOrWhiteSpace($currentDirectory)) {
    $directoryName = Split-Path -Leaf $currentDirectory.TrimEnd("\", "/")
    if (-not [string]::IsNullOrWhiteSpace($directoryName)) {
        $directorySegment = "$blue$iconDirectory $directoryName$reset"
        $gitState = Get-GitSummary -Directory $currentDirectory
        if (-not [string]::IsNullOrWhiteSpace($gitState)) {
            $directorySegment += "$minorSeparator$magenta$iconBranch $gitState$reset"
        }
        $identitySegments += $directorySegment
    }
}

# Line two is everything that moves while you work.
$meterSegments = @()
if ($null -ne $usedPercentage) {
    $contextPercentage = [math]::Floor([double]$usedPercentage)
    $contextColor = Get-UsageColor -Percentage $contextPercentage
    $meterSegments += "$contextColor$iconContext $contextPercentage% of context$reset"
} else {
    # Null until the first API response of a session, and again after /compact.
    # A placeholder keeps this row on screen so the status line does not change
    # height once the first response lands.
    $meterSegments += "$dim$iconContext $([char]0x2014)% of context$reset"
}

if ($null -ne $sessionCost -and [double]$sessionCost -gt 0) {
    $meterSegments += '{0}{1} ${2:F2}{3}' -f $yellow, $iconCost, [double]$sessionCost, $reset
}

# Both windows share one labelled segment so the numbers read as a pair rather
# than as two unrelated percentages.
$limitValues = @()
if ($null -ne $fiveHourUsage) {
    $limitValues += Get-LimitValue -Label "5h" -Percentage ([double]$fiveHourUsage) -ResetEpoch $fiveHourReset
}

if ($null -ne $sevenDayUsage) {
    $limitValues += Get-LimitValue -Label "7d" -Percentage ([double]$sevenDayUsage) -ResetEpoch $sevenDayReset
}

if ($limitValues.Count -gt 0) {
    $meterSegments += "$dim$iconLimits limits$reset $($limitValues -join $minorSeparator)"
}

# Each row is emitted only when it has content, so an early session shows one
# line instead of a blank row.
if ($identitySegments.Count -gt 0) {
    Write-Output ($identitySegments -join $majorSeparator)
}

if ($meterSegments.Count -gt 0) {
    Write-Output ($meterSegments -join $majorSeparator)
}
