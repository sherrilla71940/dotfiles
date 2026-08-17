$ErrorActionPreference = "Stop"

# Windows PowerShell writes stdout using the console code page, which is not UTF-8 on every
# machine. Force UTF-8 before any output is produced.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

# Windows attributes a toast to an Application User Model ID (AUMID). Without a registered
# one it invents a per-process identity with an empty display name, so the banner cannot say
# where it came from. scripts/bootstrap-windows.ps1 registers this AUMID by hand.
$claudeCodeAumid = "Anthropic.ClaudeCode"

# Every Windows install ships this AUMID for Windows PowerShell, so it always delivers. An
# unregistered AUMID drops the toast silently, which is the failure this fallback prevents.
$fallbackAumid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

# The Start Menu shortcut carrying System.AppUserModel.ID is what registers the custom AUMID,
# so its presence is the registration test.
$claudeCodeShortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Claude Code.lnk"

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
# $blocksProgress marks the types where nothing more happens until the user acts. Those toasts
# stay on screen until dismissed, because work is stalled for as long as they go unseen. The
# rest report something already finished, so they behave normally and wait in Action Center:
# making every notification permanent would leave a queue to clear by hand, and across several
# sessions that trains you to dismiss without reading.
$notificationType = [string]$payload.notification_type
switch ($notificationType) {
    "permission_prompt" {
        $title = "Claude needs permission"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for tool approval." }
        $blocksProgress = $true
    }
    "elicitation_dialog" {
        $title = "Claude needs input"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for your response." }
        $blocksProgress = $true
    }
    "elicitation_url_dialog" {
        $title = "Claude needs you to open a link"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for you to open a URL." }
        $blocksProgress = $true
    }
    "idle_prompt" {
        $title = "Claude finished"
        $message = "Claude finished and is waiting for your next prompt."
        $blocksProgress = $false
    }
    "auth_success" {
        $title = "Claude signed in"
        $message = if ($payload.message) { [string]$payload.message } else { "Authentication succeeded." }
        $blocksProgress = $false
    }
    # Background agents report separately from the main session: without these a
    # subagent can finish, or stall waiting on an answer, entirely unannounced.
    "agent_needs_input" {
        $title = "Agent needs input"
        $message = if ($payload.message) { [string]$payload.message } else { "A background agent is waiting for your response." }
        $blocksProgress = $true
    }
    "agent_completed" {
        $title = "Agent finished"
        $message = if ($payload.message) { [string]$payload.message } else { "A background agent finished its task." }
        $blocksProgress = $false
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

    # Windows states the rule in Action Center itself: with Do Not Disturb on "you'll only see
    # banners for alarms". The alarm scenario is therefore the only one that both crosses Do Not
    # Disturb and shows what it is about, and it also stays put until dismissed.
    #
    # Two scenarios were tried before it. Reminder keeps a banner on screen but Do Not Disturb
    # suppresses it outright. Urgent is announced as an important notification and asks for
    # consent, but under Do Not Disturb it collapses to a contentless "new important
    # notification" and leaves nothing in Action Center afterwards, so it reported that
    # something had happened without saying what, and then lost it.
    #
    # The alarm scenario would otherwise sound like an alarm, which is wrong for this and would
    # be unpleasant in an office, so the ordinary notification sound is named explicitly and
    # looping is turned off.
    #
    # Windows expects a scenario toast to offer a way out, so it carries an explicit Dismiss
    # action; activationType="system" uses the shell's own handler, which needs no registered
    # COM server of our own. Everything else asks only for the longer normal duration, and Do
    # Not Disturb is welcome to hold those back: nothing is waiting on them.
    if ($blocksProgress) {
        $toastAttributes = ' scenario="alarm"'
        $toastActions = @'
  <audio src="ms-winsoundevent:Notification.Default" loop="false"/>
  <actions>
    <action content="Dismiss" arguments="dismiss" activationType="system"/>
  </actions>
'@
    } else {
        $toastAttributes = ' duration="long"'
        $toastActions = ""
    }

    return @"
<toast$toastAttributes>
  <visual>
    <binding template="ToastGeneric">
      <text>$([System.Security.SecurityElement]::Escape($title))</text>
      <text>$([System.Security.SecurityElement]::Escape($message))</text>
      <text placement="attribution">$([System.Security.SecurityElement]::Escape($attribution))</text>
    </binding>
  </visual>
$toastActions</toast>
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

$aumid = if (Test-Path -LiteralPath $claudeCodeShortcut) { $claudeCodeAumid } else { $fallbackAumid }

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
