$ErrorActionPreference = "Stop"

function Write-HookLog([string]$Text) {
    $logDirectory = Join-Path $env:USERPROFILE ".claude\logs"
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath (Join-Path $logDirectory "notification-hook.log") -Value "$timestamp $Text"
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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$notificationType = [string]$payload.notification_type
switch ($notificationType) {
    "permission_prompt" {
        $title = "Claude needs permission"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for tool approval." }
        $icon = [System.Windows.Forms.ToolTipIcon]::Warning
    }
    "elicitation_dialog" {
        $title = "Claude needs input"
        $message = if ($payload.message) { [string]$payload.message } else { "Claude is waiting for your response." }
        $icon = [System.Windows.Forms.ToolTipIcon]::Info
    }
    "idle_prompt" {
        $title = "Claude finished"
        $message = "Claude finished and is waiting for your next prompt."
        $icon = [System.Windows.Forms.ToolTipIcon]::Info
    }
    # Background agents report separately from the main session: without these a
    # subagent can finish, or stall waiting on an answer, entirely unannounced.
    "agent_needs_input" {
        $title = "Agent needs input"
        $message = if ($payload.message) { [string]$payload.message } else { "A background agent is waiting for your response." }
        $icon = [System.Windows.Forms.ToolTipIcon]::Warning
    }
    "agent_completed" {
        $title = "Agent finished"
        $message = if ($payload.message) { [string]$payload.message } else { "A background agent finished its task." }
        $icon = [System.Windows.Forms.ToolTipIcon]::Info
    }
    default {
        exit 0
    }
}

try {
    [System.Media.SystemSounds]::Asterisk.Play()

    $notification = New-Object System.Windows.Forms.NotifyIcon
    $notification.Icon = [System.Drawing.SystemIcons]::Information
    $notification.Visible = $true
    $notification.ShowBalloonTip(5000, $title, $message, $icon)
    Start-Sleep -Seconds 5
    $notification.Dispose()
    Write-HookLog "Notification sent: $notificationType - $title"
    exit 0
} catch {
    Write-HookLog "Notification failed: $notificationType - $($_.Exception.Message)"
    Write-Error "Claude notification failed. See ~/.claude/logs/notification-hook.log."
    exit 1
}
