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
# Only --worktree sessions receive a branch on stdin, so ask git directly. The
# query is scoped to the session's directory because this script's own working
# directory is not necessarily the project.
function Get-CurrentBranch {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) { return "" }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return "" }

    # git writes to stderr for ordinary conditions such as "not a repository",
    # and the script-wide Stop preference would turn that into a thrown error,
    # so relax it only around these calls.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git -C $Directory rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return "" }

        $branch = (& git -C $Directory branch --show-current 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($branch)) { return $branch.Trim() }

        # Detached HEAD reports no branch, so fall back to a parenthesised short
        # SHA the way git's own shell prompt does.
        $revision = (& git -C $Directory rev-parse --short HEAD 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($revision)) { return "($($revision.Trim()))" }

        return ""
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Get-UsageColor {
    param([double]$Percentage)

    if ($Percentage -ge 90) { return $red }
    if ($Percentage -ge 70) { return $yellow }
    return $green
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
        $gitBranch = Get-CurrentBranch -Directory $currentDirectory
        if (-not [string]::IsNullOrWhiteSpace($gitBranch)) {
            $directorySegment += "$minorSeparator$magenta$iconBranch $gitBranch$reset"
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
    $fiveHourPercentage = [math]::Floor([double]$fiveHourUsage)
    $limitValues += "$(Get-UsageColor -Percentage $fiveHourPercentage)5h $fiveHourPercentage%$reset"
}

if ($null -ne $sevenDayUsage) {
    $sevenDayPercentage = [math]::Floor([double]$sevenDayUsage)
    $limitValues += "$(Get-UsageColor -Percentage $sevenDayPercentage)7d $sevenDayPercentage%$reset"
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
