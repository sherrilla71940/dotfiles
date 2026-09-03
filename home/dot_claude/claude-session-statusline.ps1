$ErrorActionPreference = "Stop"

# Windows PowerShell reads and writes through console code pages that are not
# UTF-8 on every machine. Claude sends UTF-8 JSON on stdin, and the status line
# emits Unicode icons on stdout, so force UTF-8 in both directions.
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
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
# The session label uses a text glyph rather than an emoji so its colour can be
# controlled consistently across terminals.
$iconSession = [char]0x25C6                         # diamond label marker
$iconContext = [char]::ConvertFromUtf32(0x1F9E0)    # brain, pink
$iconLimits = [char]::ConvertFromUtf32(0x23F3)      # hourglass with flowing sand
$iconAhead = [char]0x2191                         # ahead
$iconBehind = [char]0x2193                        # behind
$ellipsis = [char]0x2026
$majorSeparatorGlyph = [char]0x2502                # vertical line
$minorSeparatorGlyph = [char]0x00B7                # middle dot

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
$brightCyan = "$escape[96m"
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

# Below 90 columns, compact labels leave room for both rate-limit windows. A
# vertical separator remains readable at every width, while the long prose is
# replaced with the shorter form only when it saves meaningful space.
if ($terminalColumns -lt 90) {
    $majorSeparatorPlain = " $majorSeparatorGlyph "
    $majorSeparator = "$dim$majorSeparatorPlain$reset"
    $contextLabel = "ctx"
    $resetPrefix = [char]0x2192
    $limitsLabel = $iconLimits
} else {
    $majorSeparatorPlain = "  $majorSeparatorGlyph  "
    $majorSeparator = "$dim$majorSeparatorPlain$reset"
    $contextLabel = "of context"
    $resetPrefix = " resets "
    $limitsLabel = "$iconLimits limits"
}

$minorSeparatorPlain = " $minorSeparatorGlyph "
$minorSeparator = "$dim$minorSeparatorPlain$reset"

function Get-CodePointWidth {
    param([int]$CodePoint)

    if (($CodePoint -ge 0x0300 -and $CodePoint -le 0x036F) -or
        ($CodePoint -ge 0x1AB0 -and $CodePoint -le 0x1AFF) -or
        ($CodePoint -ge 0x1DC0 -and $CodePoint -le 0x1DFF) -or
        ($CodePoint -ge 0x20D0 -and $CodePoint -le 0x20FF) -or
        ($CodePoint -ge 0xFE20 -and $CodePoint -le 0xFE2F)) {
        return 0
    }

    if (($CodePoint -ge 0x1100 -and $CodePoint -le 0x115F) -or
        ($CodePoint -ge 0x2329 -and $CodePoint -le 0x232A) -or
        ($CodePoint -ge 0x2E80 -and $CodePoint -le 0xA4CF) -or
        ($CodePoint -ge 0xAC00 -and $CodePoint -le 0xD7A3) -or
        ($CodePoint -ge 0xF900 -and $CodePoint -le 0xFAFF) -or
        ($CodePoint -ge 0xFE10 -and $CodePoint -le 0xFE19) -or
        ($CodePoint -ge 0xFE30 -and $CodePoint -le 0xFE6F) -or
        ($CodePoint -ge 0xFF00 -and $CodePoint -le 0xFF60) -or
        ($CodePoint -ge 0xFFE0 -and $CodePoint -le 0xFFE6) -or
        ($CodePoint -ge 0x1F300 -and $CodePoint -le 0x1FAFF)) {
        return 2
    }

    return 1
}

function Get-VisibleWidth {
    param([string]$Text)

    if ($null -eq $Text) { return 0 }

    $plainText = [regex]::Replace($Text, "\x1B\[[0-9;]*[ -/]*[@-~]", "")
    $width = 0
    $index = 0
    while ($index -lt $plainText.Length) {
        $codePoint = [char]::ConvertToUtf32($plainText, $index)
        $characterLength = if ($codePoint -gt 0xFFFF) { 2 } else { 1 }
        $width += Get-CodePointWidth -CodePoint $codePoint
        $index += $characterLength
    }
    return $width
}

function Get-TextPrefixByWidth {
    param([string]$Text, [int]$MaxWidth)

    if ($null -eq $Text -or $MaxWidth -le 0) { return "" }

    $width = 0
    $index = 0
    while ($index -lt $Text.Length) {
        $codePoint = [char]::ConvertToUtf32($Text, $index)
        $characterLength = if ($codePoint -gt 0xFFFF) { 2 } else { 1 }
        $characterWidth = Get-CodePointWidth -CodePoint $codePoint
        if (($width + $characterWidth) -gt $MaxWidth) { break }
        $width += $characterWidth
        $index += $characterLength
    }
    return $Text.Substring(0, $index)
}

function Get-TextSuffixByWidth {
    param([string]$Text, [int]$MaxWidth)

    if ($null -eq $Text -or $MaxWidth -le 0) { return "" }

    $width = 0
    $index = $Text.Length
    while ($index -gt 0) {
        $characterStart = $index - 1
        if ($characterStart -gt 0 -and [char]::IsLowSurrogate($Text[$characterStart]) -and
            [char]::IsHighSurrogate($Text[$characterStart - 1])) {
            $characterStart--
        }
        $codePoint = [char]::ConvertToUtf32($Text, $characterStart)
        $characterWidth = Get-CodePointWidth -CodePoint $codePoint
        if (($width + $characterWidth) -gt $MaxWidth) { break }
        $width += $characterWidth
        $index = $characterStart
    }
    return $Text.Substring($index)
}

function Get-MiddleTruncatedText {
    param([string]$Text, [int]$MaxWidth)

    if ($null -eq $Text -or $MaxWidth -le 0) { return "" }
    if ((Get-VisibleWidth -Text $Text) -le $MaxWidth) { return $Text }
    if ($MaxWidth -eq 1) { return $ellipsis }

    $leftWidth = [math]::Floor(($MaxWidth - 1) / 2)
    $rightWidth = $MaxWidth - 1 - $leftWidth
    $left = Get-TextPrefixByWidth -Text $Text -MaxWidth $leftWidth
    $right = Get-TextSuffixByWidth -Text $Text -MaxWidth $rightWidth
    return "$left$ellipsis$right"
}

function Get-WrappedText {
    param([string]$Text, [int]$MaxWidth)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    if ($MaxWidth -le 0) { $MaxWidth = 1 }

    $lines = @()
    $current = ""
    $words = [regex]::Matches($Text.Trim(), "\S+")
    foreach ($match in $words) {
        $word = $match.Value
        if (-not [string]::IsNullOrEmpty($current) -and (Get-VisibleWidth -Text $word) -gt $MaxWidth) {
            $lines += $current
            $current = ""
        }
        while ((Get-VisibleWidth -Text $word) -gt $MaxWidth) {
            $piece = Get-TextPrefixByWidth -Text $word -MaxWidth $MaxWidth
            if ([string]::IsNullOrEmpty($piece)) {
                $piece = $word.Substring(0, 1)
            }
            $lines += $piece
            $word = $word.Substring($piece.Length)
        }

        if ([string]::IsNullOrEmpty($word)) { continue }
        $candidate = if ([string]::IsNullOrEmpty($current)) { $word } else { "$current $word" }
        if (-not [string]::IsNullOrEmpty($current) -and (Get-VisibleWidth -Text $candidate) -gt $MaxWidth) {
            $lines += $current
            $current = $word
        } else {
            $current = $candidate
        }
    }
    if (-not [string]::IsNullOrEmpty($current)) { $lines += $current }
    return $lines
}

# Context fill and rate-limit fill share one threshold scale, so a given colour
# always carries the same meaning wherever it appears on the line.
function Get-UsageColor {
    param([double]$Percentage)

    if ($Percentage -ge 90) { return $red }
    if ($Percentage -ge 70) { return $yellow }
    return $green
}

# No branch is provided on stdin outside --worktree sessions, so ask git. A
# single porcelain v2 call answers all three questions at once — whether this is
# a repository, which branch is checked out, and what the work tree looks like —
# because spawning git costs about as much as git's own work here. The query is
# scoped to the session's directory since this script's working directory is not
# necessarily the project. Normal untracked files are included because newly
# created artifacts are still work-tree changes worth showing.
function Get-GitSummary {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) { return $null }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = @(& git -C $Directory status --porcelain=v2 --branch --untracked-files=normal 2>$null)
        if ($LASTEXITCODE -ne 0) { return $null }
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $branch = ""
    $objectId = ""
    $aheadCount = 0
    $behindCount = 0
    $stagedCount = 0
    $modifiedCount = 0
    $untrackedCount = 0
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line.StartsWith("# branch.head ")) {
            $branch = $line.Substring(14).Trim()
        } elseif ($line.StartsWith("# branch.oid ")) {
            $objectId = $line.Substring(13).Trim()
        } elseif ($line.StartsWith("# branch.ab ")) {
            $abParts = $line.Substring(12).Trim() -split "\s+"
            if ($abParts.Count -ge 2) {
                if ($abParts[0] -match '^\+(\d+)$') { $aheadCount = [int]$matches[1] }
                if ($abParts[1] -match '^-(\d+)$') { $behindCount = [int]$matches[1] }
            }
        } elseif ($line.StartsWith("? ")) {
            $untrackedCount++
        } elseif ($line.Length -ge 4 -and "12u".IndexOf($line[0]) -ge 0 -and $line[1] -eq ' ') {
            # Changed, renamed and unmerged entries all carry the two state
            # columns in the same position: index state then work-tree state.
            if ($line[2] -ne '.') { $stagedCount++ }
            if ($line[3] -ne '.') { $modifiedCount++ }
        }
    }

    if ($branch -eq "(detached)") {
        if ($objectId.Length -ge 7) { $branch = "($($objectId.Substring(0, 7)))" } else { $branch = "" }
    }
    if ([string]::IsNullOrWhiteSpace($branch)) { return $null }

    return [pscustomobject]@{
        Branch = $branch
        AheadCount = $aheadCount
        BehindCount = $behindCount
        StagedCount = $stagedCount
        ModifiedCount = $modifiedCount
        UntrackedCount = $untrackedCount
    }
}

function Get-GitChangeSuffix {
    param($GitState)

    $changes = @()
    if ($GitState.StagedCount -gt 0) { $changes += "+$($GitState.StagedCount)" }
    if ($GitState.ModifiedCount -gt 0) { $changes += "~$($GitState.ModifiedCount)" }
    if ($GitState.UntrackedCount -gt 0) { $changes += "?$($GitState.UntrackedCount)" }
    if ($changes.Count -eq 0) { return "" }
    return " " + ($changes -join " ")
}

function Get-GitTrackingSuffix {
    param($GitState)

    $tracking = @()
    if ($GitState.AheadCount -gt 0) { $tracking += "$iconAhead$($GitState.AheadCount)" }
    if ($GitState.BehindCount -gt 0) { $tracking += "$iconBehind$($GitState.BehindCount)" }
    if ($tracking.Count -eq 0) { return "" }
    return " " + ($tracking -join " ")
}

function Get-GitLabel {
    param($GitState, [int]$MaxWidth)

    $prefix = "$iconBranch "
    $tracking = Get-GitTrackingSuffix -GitState $GitState
    $suffix = Get-GitChangeSuffix -GitState $GitState
    $branchWidth = $MaxWidth - (Get-VisibleWidth -Text $prefix) - (Get-VisibleWidth -Text $tracking) - (Get-VisibleWidth -Text $suffix)
    $branchDisplay = Get-MiddleTruncatedText -Text $GitState.Branch -MaxWidth ([math]::Max(1, $branchWidth))
    $plain = "$prefix$branchDisplay$tracking$suffix"
    $colored = "$magenta$prefix$branchDisplay$reset"
    if ($GitState.AheadCount -gt 0) { $colored += "$cyan $iconAhead$($GitState.AheadCount)$reset" }
    if ($GitState.BehindCount -gt 0) { $colored += "$blue $iconBehind$($GitState.BehindCount)$reset" }
    if ($GitState.StagedCount -gt 0) { $colored += "$green +$($GitState.StagedCount)$reset" }
    if ($GitState.ModifiedCount -gt 0) { $colored += "$yellow ~$($GitState.ModifiedCount)$reset" }
    if ($GitState.UntrackedCount -gt 0) { $colored += "$red ?$($GitState.UntrackedCount)$reset" }
    return [pscustomobject]@{
        Plain = $plain
        Colored = $colored
    }
}

function Get-DirectoryLabel {
    param([string]$DirectoryName, [int]$MaxWidth)

    $prefix = "$iconDirectory "
    $directoryWidth = $MaxWidth - (Get-VisibleWidth -Text $prefix)
    $directoryDisplay = Get-MiddleTruncatedText -Text $DirectoryName -MaxWidth ([math]::Max(1, $directoryWidth))
    $plain = "$prefix$directoryDisplay"
    return [pscustomobject]@{
        Plain = $plain
        Colored = "$blue$plain$reset"
    }
}

# An absolute wall-clock time rather than a countdown: this script runs on
# events, and those go quiet while the session is idle, so a countdown would
# silently drift while a clock time stays correct however stale the render is.
function Get-ResetLabel {
    param([long]$Epoch)

    $moment = [DateTimeOffset]::FromUnixTimeSeconds($Epoch).ToLocalTime()
    $format = "HH:mm"
    if (($moment - [DateTimeOffset]::Now).TotalSeconds -ge 86400) {
        $format = "ddd"
    }
    return $moment.ToString($format, [System.Globalization.CultureInfo]::InvariantCulture)
}

# The reset time always accompanies the percentage, because the percentage alone
# cannot say whether a nearly full window clears in minutes or in hours.
function Get-LimitPlainValue {
    param([string]$Label, [double]$Percentage, $ResetEpoch)

    $floored = [math]::Floor($Percentage)
    $text = "$Label $floored%"
    if ($null -ne $ResetEpoch) {
        $moment = Get-ResetLabel -Epoch ([long]$ResetEpoch)
        if (-not [string]::IsNullOrWhiteSpace($moment)) {
            $text += "$resetPrefix$moment"
        }
    }
    return $text
}

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
# Rate limits are present only for Claude.ai Pro/Max sessions, and each window
# can be absent independently, so both are treated as optional.
$fiveHourUsage = $data.rate_limits.five_hour.used_percentage
$sevenDayUsage = $data.rate_limits.seven_day.used_percentage
$fiveHourReset = $data.rate_limits.five_hour.resets_at
$sevenDayReset = $data.rate_limits.seven_day.resets_at

# Build the identity line first. Claude's display_name is authoritative: some
# models already include their context capacity, so adding it from another field
# would duplicate text such as "(1M context)".
$modelPlain = ""
$modelColored = ""
if (-not [string]::IsNullOrWhiteSpace($model)) {
    $modelPlain = "$iconModel $model"
    $modelColored = "$cyan$modelPlain$reset"
    if (-not [string]::IsNullOrWhiteSpace($effortLevel)) {
        $modelPlain += "$minorSeparatorPlain$effortLevel"
        $modelColored += "$minorSeparator$muted$effortLevel$reset"
    }
} elseif (-not [string]::IsNullOrWhiteSpace($effortLevel)) {
    $modelPlain = "$iconModel $effortLevel effort"
    $modelColored = "$muted$modelPlain$reset"
}

$identityLines = @()
if (-not [string]::IsNullOrWhiteSpace($modelPlain)) {
    $identityLines += $modelColored
}

if (-not [string]::IsNullOrWhiteSpace($sessionName)) {
    $labelPrefixPlain = "$iconSession "
    $labelInlinePlain = "$labelPrefixPlain$sessionName"
    $baseWidth = Get-VisibleWidth -Text $modelPlain
    $inlineWidth = $baseWidth + (Get-VisibleWidth -Text $majorSeparatorPlain) + (Get-VisibleWidth -Text $labelInlinePlain)
    if ($baseWidth -gt 0 -and $inlineWidth -le $terminalColumns) {
        $identityLines = @("$modelColored$majorSeparator$brightCyan$iconSession$reset $muted$sessionName$reset")
    } else {
        $labelWidth = [math]::Max(1, $terminalColumns - (Get-VisibleWidth -Text $labelPrefixPlain))
        $wrappedLabel = @(Get-WrappedText -Text $sessionName -MaxWidth $labelWidth)
        for ($index = 0; $index -lt $wrappedLabel.Count; $index++) {
            if ($index -eq 0) {
                $identityLines += "$brightCyan$iconSession$reset $muted$($wrappedLabel[$index])$reset"
            } else {
                $identityLines += "  $muted$($wrappedLabel[$index])$reset"
            }
        }
    }
}

$directoryLines = @()
$gitState = $null
if (-not [string]::IsNullOrWhiteSpace($currentDirectory)) {
    # Use the shell's home-relative shorthand so nested projects remain
    # distinguishable instead of collapsing to the leaf directory name.
    $trimmedDirectory = $currentDirectory.TrimEnd("\", "/")
    $homeDirectory = [Environment]::GetFolderPath("UserProfile").TrimEnd("\", "/")
    $normalizedDirectory = $trimmedDirectory.Replace("/", "\")
    $normalizedHomeDirectory = $homeDirectory.Replace("/", "\")
    if ($normalizedDirectory -ieq $normalizedHomeDirectory) {
        $directoryName = "~"
    } elseif ($normalizedDirectory.StartsWith("$normalizedHomeDirectory\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativeDirectory = $normalizedDirectory.Substring($normalizedHomeDirectory.Length).TrimStart("\")
        $directoryName = "~/$($relativeDirectory.Replace("\", "/"))"
    } else {
        $directoryName = $normalizedDirectory.Replace("\", "/")
    }

    $gitState = Get-GitSummary -Directory $currentDirectory
    $directoryFull = Get-DirectoryLabel -DirectoryName $directoryName -MaxWidth $terminalColumns
    if ($null -ne $gitState) {
        $gitFull = Get-GitLabel -GitState $gitState -MaxWidth $terminalColumns
        $combinedWidth = (Get-VisibleWidth -Text $directoryFull.Plain) +
            (Get-VisibleWidth -Text $majorSeparatorPlain) +
            (Get-VisibleWidth -Text $gitFull.Plain)

        $combined = $null
        if ($combinedWidth -le $terminalColumns) {
            $combined = "$($directoryFull.Colored)$majorSeparator$($gitFull.Colored)"
        }

        if ($null -ne $combined) {
            $directoryLines += $combined
        } else {
            $directoryLines += $directoryFull.Colored
            $directoryLines += $gitFull.Colored
        }
    } else {
        $directoryLines += $directoryFull.Colored
    }
}

$detailLines = @()
if ($null -ne $usedPercentage) {
    $contextPercentage = [math]::Floor([double]$usedPercentage)
    $contextPlain = "$iconContext $contextPercentage% $contextLabel"
    $contextColored = "$(Get-UsageColor -Percentage $contextPercentage)$contextPlain$reset"
} else {
    $contextPlain = "$iconContext $contextLabel $([char]0x2014)"
    $contextColored = "$muted$contextPlain$reset"
}

$limitPlainValues = @()
$limitColoredValues = @()
if ($null -ne $fiveHourUsage) {
    $limitPlainValues += Get-LimitPlainValue -Label "5h" -Percentage ([double]$fiveHourUsage) -ResetEpoch $fiveHourReset
    $limitColoredValues += Get-LimitValue -Label "5h" -Percentage ([double]$fiveHourUsage) -ResetEpoch $fiveHourReset
}
if ($null -ne $sevenDayUsage) {
    $limitPlainValues += Get-LimitPlainValue -Label "7d" -Percentage ([double]$sevenDayUsage) -ResetEpoch $sevenDayReset
    $limitColoredValues += Get-LimitValue -Label "7d" -Percentage ([double]$sevenDayUsage) -ResetEpoch $sevenDayReset
}

if ($limitPlainValues.Count -eq 0) {
    $detailLines += $contextColored
} else {
    $limitPlainJoined = $limitPlainValues -join $minorSeparatorPlain
    $limitColoredJoined = $limitColoredValues -join $minorSeparator
    $limitHeaderPlain = "$limitsLabel "
    $limitHeaderColored = "$muted$limitsLabel$reset "
    $detailPlain = "$contextPlain$majorSeparatorPlain$limitHeaderPlain$limitPlainJoined"
    if ((Get-VisibleWidth -Text $detailPlain) -le $terminalColumns) {
        $detailLines += "$contextColored$majorSeparator$limitHeaderColored$limitColoredJoined"
    } else {
        $firstPlain = "$contextPlain$majorSeparatorPlain$limitHeaderPlain$($limitPlainValues[0])"
        if ((Get-VisibleWidth -Text $firstPlain) -le $terminalColumns) {
            $detailLines += "$contextColored$majorSeparator$limitHeaderColored$($limitColoredValues[0])"
        } else {
            $detailLines += $contextColored
            $detailLines += "  $limitHeaderColored$($limitColoredValues[0])"
        }
        for ($index = 1; $index -lt $limitColoredValues.Count; $index++) {
            $detailLines += "  $($limitColoredValues[$index])"
        }
    }
}

# The output is intentionally variable-height: wrapping preserves information,
# while terminal auto-wrap would split separators and make fields ambiguous.
foreach ($line in $identityLines) { Write-Output $line }
foreach ($line in $directoryLines) { Write-Output $line }
foreach ($line in $detailLines) { Write-Output $line }
