param(
  [string]$Title = "Claude Code",
  [string]$Message = "Notification"
)

function Write-HookLog([string]$Text) {
  $logDirectory = Join-Path $env:USERPROFILE ".claude\logs"
  New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -LiteralPath (Join-Path $logDirectory "notification-hook.log") -Value "$timestamp $Text"
}

function Escape-Xml([string]$Text) {
  return $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
}

try {
  [System.Media.SystemSounds]::Exclamation.Play()
} catch {
  Write-HookLog "Sound failed: $($_.Exception.Message)"
}

try {
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
  $safeTitle = Escape-Xml $Title
  $safeMessage = Escape-Xml $Message
  $xmlText = "<toast><visual><binding template=`"ToastGeneric`"><text>$safeTitle</text><text>$safeMessage</text></binding></visual></toast>"
  $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
  $xml.LoadXml($xmlText)
  $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
  Write-HookLog "Toast sent: $Title - $Message"
  exit 0
} catch {
  Write-HookLog "Toast failed: $($_.Exception.Message)"
}

try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $notification = New-Object System.Windows.Forms.NotifyIcon
  $notification.Icon = [System.Drawing.SystemIcons]::Information
  $notification.Visible = $true
  $notification.ShowBalloonTip(5000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
  Start-Sleep -Seconds 5
  $notification.Dispose()
  Write-HookLog "Balloon sent: $Title - $Message"
  exit 0
} catch {
  Write-HookLog "Balloon failed: $($_.Exception.Message)"
  Write-Error "Claude notification failed. See ~/.claude/logs/notification-hook.log."
  exit 1
}
