#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
notification_type="$(printf '%s' "$input" | jq -r '.notification_type // empty')"

case "$notification_type" in
  permission_prompt)
    title="Claude needs permission"
    message="$(printf '%s' "$input" | jq -r '.message // "Claude is waiting for tool approval."')"
    ;;
  elicitation_dialog)
    title="Claude needs input"
    message="$(printf '%s' "$input" | jq -r '.message // "Claude is waiting for your response."')"
    ;;
  idle_prompt)
    title="Claude finished"
    message="Claude finished and is waiting for your next prompt."
    ;;
  *)
    exit 0
    ;;
esac

log_directory="$HOME/.claude/logs"
log_file="$log_directory/notification-hook.log"
mkdir -p "$log_directory"

if /usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT'
on run arguments
  display notification (item 2 of arguments) with title (item 1 of arguments)
end run
APPLESCRIPT
then
  printf '%s Notification sent: %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$notification_type" "$title" >> "$log_file"
else
  printf '%s Notification failed: %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$notification_type" "$title" >> "$log_file"
  exit 1
fi
