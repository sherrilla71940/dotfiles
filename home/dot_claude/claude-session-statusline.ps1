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
# Emoji carry their own colour, which no escape code can override, so they are
# chosen for contrast against their neighbours. The money bag is the same yellow
# as the folder but sits a row below it, far enough not to clash.
# The bookmark only clashed while the session name sat beside the folder on the
# identity row; on the meter row its red stands apart from the brain and the
# money bag. Its colour cannot match the label beside it, but neither can the
# herb's, so an emoji here keeps the row visually consistent.
$iconSession = [char]::ConvertFromUtf32(0x1F516)    # bookmark, red
$iconContext = [char]::ConvertFromUtf32(0x1F9E0)    # brain, pink
$iconCost = [char]::ConvertFromUtf32(0x1F4B0)       # money bag
$iconLimits = [char]::ConvertFromUtf32(0x23F3)      # hourglass with flowing sand

# Basic ANSI codes only, so the terminal's own theme decides the exact hues.
# Bright black is the separator colour and nothing else: on a dark theme it sits
# close to the background, which suits structure but loses any text put in it.
# Secondary text keeps the default foreground instead, the one colour guaranteed
# to stay legible whether the theme is light or dark.
$escape = [char]27
$dim = "$escape[90m"
$muted = "$escape[39m"
$cyan = "$escape[36m"
$blue = "$escape[94m"
$magenta = "$escape[95m"
$green = "$escape[32m"
$yellow = "$escape[33m"
$red = "$escape[31m"
$reset = "$escape[0m"

# Claude Code exports the terminal size before running this script, because output is
# captured rather than attached to the terminal and the usual width queries cannot see it.
# The fallback matters: an unset or non-numeric value must not make every session look narrow.
$terminalColumns = 80
$reportedColumns = 0
if ([int]::TryParse([string]$env:COLUMNS, [ref]$reportedColumns) -and $reportedColumns -gt 0) {
    $terminalColumns = $reportedColumns
}

# In a split pane the limit row is wider than the pane and its tail is cut, which loses the
# second window's reset entirely. Prose that reads well with room to spare is what costs the
# space, so it is what gets shortened; the values themselves are never abbreviated.
if ($terminalColumns -lt 60) {
    $majorSeparator = "$dim $([char]0x2502) $reset"
    $contextLabel = "ctx"
    # An arrow stands in for "resets": still directional, a seventh of the width.
    $resetPrefix = [char]0x2192
    $limitsLabel = $iconLimits
} else {
    $majorSeparator = "$dim  $([char]0x2502)  $reset"
    $contextLabel = "of context"
    $resetPrefix = " resets "
    $limitsLabel = "$iconLimits limits"
}

# The lighter dot joins values inside one group and is already narrow, so it does not change.
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
            $text += "$muted$resetPrefix$moment$reset"
        }
    }

    return $text
}

$model = [string]$data.model.display_name
# Absent on models without a reasoning effort parameter; tracks /effort changes
# made mid-session.
$effortLevel = [string]$data.effort.level
$currentDirectory = [string]$data.workspace.current_dir
# Only set by --name, /rename or an AI-generated title; the default my-app-3f
# style display name does not populate it, so most sessions have none.
$sessionName = [string]$data.session_name
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
        $modelSegment += "$minorSeparator$muted$effortLevel$reset"
    }
    $identitySegments += $modelSegment
} elseif (-not [string]::IsNullOrWhiteSpace($effortLevel)) {
    $identitySegments += "$muted$iconModel $effortLevel effort$reset"
}

# Branch joins the directory for the same reason effort joins the model: both
# answer "where am I", so they read as one group.
if (-not [string]::IsNullOrWhiteSpace($currentDirectory)) {
    # In the home directory the leaf is the account name, which reads as a
    # project that does not exist; the shell's own shorthand is clearer.
    $trimmedDirectory = $currentDirectory.TrimEnd("\", "/")
    $homeDirectory = [Environment]::GetFolderPath("UserProfile").TrimEnd("\", "/")
    if ($trimmedDirectory.Replace("/", "\") -ieq $homeDirectory.Replace("/", "\")) {
        $directoryName = "~"
    } else {
        $directoryName = Split-Path -Leaf $trimmedDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($directoryName)) {
        $directorySegment = "$blue$iconDirectory $directoryName$reset"
        $gitState = Get-GitSummary -Directory $currentDirectory
        if (-not [string]::IsNullOrWhiteSpace($gitState)) {
            $directorySegment += "$minorSeparator$magenta$iconBranch $gitState$reset"
        }
        $identitySegments += $directorySegment
    }
}


# Line two is session state: what this conversation has consumed so far.
$meterSegments = @()
if ($null -ne $usedPercentage) {
    $contextPercentage = [math]::Floor([double]$usedPercentage)
    $contextColor = Get-UsageColor -Percentage $contextPercentage
    $meterSegments += "$contextColor$iconContext $contextPercentage% $contextLabel$reset"
} else {
    # Null until the first API response of a session, and again after /compact.
    # A placeholder keeps this row on screen so the status line does not change
    # height once the first response lands.
    $meterSegments += "$muted$iconContext $contextLabel $([char]0x2014)$reset"
}

if ($null -ne $sessionCost -and [double]$sessionCost -gt 0) {
    # The culture is pinned so a comma-decimal machine cannot render this as
    # $25,04 and diverge from the bash copy.
    $costText = ([double]$sessionCost).ToString("F2", [System.Globalization.CultureInfo]::InvariantCulture)
    $meterSegments += "$yellow$iconCost `$$costText$reset"
}

# The session name belongs to this conversation rather than to identity, and it
# goes last because it is the one unbounded field: all length variance then lands
# at the end of the row, leaving every meter at a fixed column.
if (-not [string]::IsNullOrWhiteSpace($sessionName)) {
    $meterSegments += "$muted$iconSession $sessionName$reset"
}

# Line three is account state, which outlives this session. It earns its own row
# because both windows carrying a reset time overflows a shared line and the
# terminal truncates the tail.
$limitValues = @()
if ($null -ne $fiveHourUsage) {
    $limitValues += Get-LimitValue -Label "5h" -Percentage ([double]$fiveHourUsage) -ResetEpoch $fiveHourReset
}

if ($null -ne $sevenDayUsage) {
    $limitValues += Get-LimitValue -Label "7d" -Percentage ([double]$sevenDayUsage) -ResetEpoch $sevenDayReset
}

# Each row is emitted only when it has content, so no blank row is ever printed.
if ($identitySegments.Count -gt 0) {
    Write-Output ($identitySegments -join $majorSeparator)
}

if ($meterSegments.Count -gt 0) {
    Write-Output ($meterSegments -join $majorSeparator)
}

if ($limitValues.Count -gt 0) {
    Write-Output "$muted$limitsLabel$reset $($limitValues -join $minorSeparator)"
}
