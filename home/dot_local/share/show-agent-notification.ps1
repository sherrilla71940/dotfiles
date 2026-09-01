$ErrorActionPreference = "Stop"

# Windows PowerShell writes stdout using the console code page, which is not UTF-8 on every
# machine. Force UTF-8 before any output is produced.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

# Windows attributes a toast to an Application User Model ID (AUMID). Without a registered
# one it invents a per-process identity with an empty display name, so the banner cannot say
# where it came from. scripts/bootstrap-windows.ps1 registers both AUMIDs below by hand.
#
# One script serves both clients, so the identity is chosen per notification: a banner raised
# for a Codex session must not be attributed to Claude Code. The AUMID sets the name and icon
# Windows draws in the header, which no property in the toast markup can override.
$claudeCodeAumid = "Anthropic.ClaudeCode"
$codexAumid = "OpenAI.Codex"

# Every Windows install ships this AUMID for Windows PowerShell, so it always delivers. An
# unregistered AUMID drops the toast silently, which is the failure this fallback prevents.
$fallbackAumid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

# The Start Menu shortcut carrying System.AppUserModel.ID is what registers the custom AUMID,
# so its presence is the registration test.
$startMenuPrograms = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$claudeCodeShortcut = Join-Path $startMenuPrograms "Claude Code.lnk"
$codexShortcut = Join-Path $startMenuPrograms "Codex.lnk"

# The banner's icon is named by scripts/bootstrap-windows.ps1 on the AppUserModelId key, so
# nothing about it belongs in the markup below. An appLogoOverride image was tried and removed:
# that slot is for imagery belonging to the notification, a sender's photograph or a piece of
# album art, and putting the application's own logo there repeats the header icon at a larger
# size and in different colours, which reads as two icons rather than one.

function Write-HookLog([string]$Text) {
    $logDirectory = Join-Path $env:USERPROFILE ".claude\logs"
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath (Join-Path $logDirectory "notification-hook.log") -Value "$timestamp $Text"
}

# The separator is built from its code point rather than written literally: Windows PowerShell
# parses a script without a byte order mark using the ANSI code page, which would corrupt a
# literal multi-byte character here.
$separator = " $([char]0x00B7) "

# Several sessions run at once, so a banner that does not name its origin is close to useless.
# The product name is prepended only under the fallback identity, which labels the toast
# "Windows PowerShell"; the registered identity already puts "Claude Code" in the header, and
# repeating it there would say the same thing twice. Either identifying field can be absent, so
# each is appended only when it has a value.
function Get-AttributionText($Payload, [bool]$NeedsProductName) {
    $parts = @()
    if ($NeedsProductName) {
        $parts += "Claude Code"
    }

    $workingDirectory = [string]$Payload.cwd
    if (-not [string]::IsNullOrWhiteSpace($workingDirectory)) {
        $project = Split-Path -Leaf $workingDirectory.TrimEnd("\", "/")
        if (-not [string]::IsNullOrWhiteSpace($project)) {
            $parts += $project
        }
    }

    # The full UUID overflows the attribution line; its leading block is already unique
    # enough to match a banner against a terminal.
    $shortId = Get-ShortSessionId -Payload $Payload
    if (-not [string]::IsNullOrWhiteSpace($shortId)) {
        $parts += "session $shortId"
    }

    return ($parts -join $separator)
}

function Show-Toast([string]$Aumid, [string]$Xml, [string]$Tag) {
    $document = New-Object Windows.Data.Xml.Dom.XmlDocument
    $document.LoadXml($Xml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $document

    # Tagging by session makes a new toast replace that session's previous one instead of
    # stacking beneath it. Without this a session that asks twice leaves two banners to
    # dismiss by hand, and since the blocking ones never expire the pile only grows. One
    # live banner per session still distinguishes which window wants attention, and the
    # session itself lists every request once you get there. The tag has a length limit,
    # so the shortened session id is used rather than the full identifier.
    if (-not [string]::IsNullOrWhiteSpace($Tag)) {
        $toast.Tag = $Tag
        $toast.Group = "claude-code"
    }

    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($Aumid).Show($toast)
}

# Shared by the attribution line and the toast tag, so the banner the user sees and the
# identity used to replace it cannot drift apart.
function Get-ShortSessionId($Payload) {
    $sessionId = [string]$Payload.session_id
    if ([string]::IsNullOrWhiteSpace($sessionId)) { return "" }
    if ($sessionId.Length -gt 7) { return $sessionId.Substring(0, 7) }
    return $sessionId
}

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    exit 0
}

try {
    $payload = $inputJson | ConvertFrom-Json
} catch {
    Write-HookLog "Invalid hook input: $($_.Exception.Message)"
    exit 1
}

# Every notification_type listed in the Notification hook matcher needs a branch here. A type
# that reaches the default branch matches the hook and then announces nothing.
#
# Every type is announced the same way. Ranking them by urgency was tried and the mechanisms
# Windows offers for it all cost more than they return: see New-ToastXml. Being away from the
# desk is the case this cannot serve at all, whatever the banner does, and that belongs to a
# notification that reaches a phone rather than to a longer toast.
# Codex sends no notification_type - it has no Notification event, only lifecycle ones - so
# its SessionEnd is mapped to a type here. Without this the switch falls to default and the
# toast is silently dropped, which is how the previous Codex hook failed unnoticed.
$notificationType = [string]$payload.notification_type
if (-not $notificationType -and [string]$payload.hook_event_name -eq "SessionEnd") {
    $notificationType = "session_end"
}
switch ($notificationType) {
    "permission_prompt" {
        $title = "Claude needs permission"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for tool approval." }
    }
    "elicitation_dialog" {
        $title = "Claude needs input"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for your response." }
    }
    "elicitation_url_dialog" {
        $title = "Claude needs you to open a link"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for you to open a URL." }
    }
    "idle_prompt" {
        $title = "Claude finished"
        $message = "Claude finished and is waiting for your next prompt."
    }
    "auth_success" {
        $title = "Claude signed in"
        $message = if ($payload.message) { [string]$payload.message } else { "Authentication succeeded." }
    }
    # Background agents report separately from the main session: without these a
    # subagent can finish, or stall waiting on an answer, entirely unannounced.
    "agent_needs_input" {
        $title = "Agent needs input"
        $message = if ($payload.message) { [string]$payload.message } else { "A background agent is waiting for your response." }
    }
    "agent_completed" {
        $title = "Agent finished"
        $message = if ($payload.message) { [string]$payload.message } else { "A background agent finished its task." }
    }
    "session_end" {
        $title = "Codex finished"
        $message = "The Codex session ended."
    }
    default {
        exit 0
    }
}

# Message text is arbitrary and routinely contains angle brackets and ampersands, so escape
# every interpolated value before it becomes toast markup. The attribution depends on which
# identity posts the toast, so the markup is built per identity rather than once.
function New-ToastXml([string]$Aumid) {
    $attribution = Get-AttributionText -Payload $payload -NeedsProductName ($Aumid -eq $fallbackAumid)

    # Every notification behaves the same way: the longer of the two durations Windows offers,
    # roughly twenty-five seconds, and nothing that overrides Do Not Disturb.
    #
    # Three scenarios were tried and all three are worse here. Reminder and alarm hold a banner
    # on screen until it is dismissed, which turns a run of notifications into a queue to clear
    # by hand and, on a shared or projected screen, parks the project and session name in front
    # of an audience. Alarm additionally ignores Do Not Disturb, and urgent ignores it while
    # collapsing to a contentless "new important notification" that leaves nothing behind in
    # Action Center. Do Not Disturb is a deliberate instruction and gets to win; a notification
    # missed while it is on is still waiting in Action Center afterwards.
    #
    # There is no middle duration to ask for. Windows accepts only short, about seven seconds,
    # and long, so long is as much dwell time as a well-behaved toast can have.
    return @"
<toast duration="long">
  <visual>
    <binding template="ToastGeneric">
      <text>$([System.Security.SecurityElement]::Escape($title))</text>
      <text>$([System.Security.SecurityElement]::Escape($message))</text>
      <text placement="attribution">$([System.Security.SecurityElement]::Escape($attribution))</text>
    </binding>
  </visual>
</toast>
"@
}

try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
    [void][Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime]
} catch {
    Write-HookLog "Notification failed: $notificationType - WinRT unavailable: $($_.Exception.Message)"
    Write-Error "Claude notification failed. See ~/.claude/logs/notification-hook.log."
    exit 1
}

# session_end is only ever raised by the Codex hook; every other type comes from Claude's
# Notification event. An unregistered identity drops the toast silently, so each falls back to
# the always-present Windows PowerShell identity rather than to the other client's.
if ($notificationType -eq "session_end") {
    $preferredAumid = $codexAumid
    $preferredShortcut = $codexShortcut
} else {
    $preferredAumid = $claudeCodeAumid
    $preferredShortcut = $claudeCodeShortcut
}
$aumid = if (Test-Path -LiteralPath $preferredShortcut) { $preferredAumid } else { $fallbackAumid }

try {
    Show-Toast -Aumid $aumid -Xml (New-ToastXml -Aumid $aumid) -Tag (Get-ShortSessionId -Payload $payload)
    Write-HookLog "Notification sent: $notificationType - $title (aumid: $aumid)"
    exit 0
} catch {
    # A custom AUMID can fail after its shortcut is removed or its registration is reset.
    # Retrying under the always-present identity beats losing the notification.
    if ($aumid -ne $fallbackAumid) {
        Write-HookLog "Notification retrying under fallback identity: $notificationType - $($_.Exception.Message)"
        try {
            Show-Toast -Aumid $fallbackAumid -Xml (New-ToastXml -Aumid $fallbackAumid) -Tag (Get-ShortSessionId -Payload $payload)
            Write-HookLog "Notification sent: $notificationType - $title (aumid: $fallbackAumid)"
            exit 0
        } catch {
            Write-HookLog "Notification failed: $notificationType - $($_.Exception.Message)"
            Write-Error "Claude notification failed. See ~/.claude/logs/notification-hook.log."
            exit 1
        }
    }

    Write-HookLog "Notification failed: $notificationType - $($_.Exception.Message)"
    Write-Error "Claude notification failed. See ~/.claude/logs/notification-hook.log."
    exit 1
}
