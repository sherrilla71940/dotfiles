#!/usr/bin/env bash
set -euo pipefail

log_directory="$HOME/.claude/logs"
log_file="$log_directory/notification-hook.log"
mkdir -p "$log_directory"

write_log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$log_file"
}

input="$(cat)"
if [ -z "${input//[[:space:]]/}" ]; then
  exit 0
fi

if ! printf '%s' "$input" | jq -e . >/dev/null 2>&1; then
  write_log "Invalid hook input"
  exit 1
fi

notification_type="$(printf '%s' "$input" | jq -r '.notification_type // empty')"

# Codex sends no notification_type - it has no Notification event, only lifecycle ones - so its
# SessionEnd is mapped to a type here. Without this the case below falls to its default and the
# banner is silently dropped, which is how the previous Codex hook failed unnoticed.
if [[ -z "$notification_type" ]]   && [[ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty')" == "SessionEnd" ]]; then
  notification_type="session_end"
fi

# The Windows copy keeps a toast on screen until dismissed when a notification means work is
# blocked. There is no equivalent here: how long a banner lingers is chosen by the user per
# application in System Settings > Notifications, as Banner or Alert, and no argument to
# osascript or terminal-notifier overrides it. Set the posting application to Alert there to
# get the same behaviour.

# Every notification_type listed in the Notification hook matcher needs a branch here. A type
# that reaches the default branch matches the hook and then announces nothing.
case "$notification_type" in
  permission_prompt)
    title="Claude needs permission"
    message="$(printf '%s' "$input" | jq -r '.message // "Claude is waiting for tool approval."')"
    ;;
  elicitation_dialog)
    title="Claude needs input"
    message="$(printf '%s' "$input" | jq -r '.message // "Claude is waiting for your response."')"
    ;;
  elicitation_url_dialog)
    title="Claude needs you to open a link"
    message="$(printf '%s' "$input" | jq -r '.message // "Claude is waiting for you to open a URL."')"
    ;;
  idle_prompt)
    title="Claude finished"
    message="Claude finished and is waiting for your next prompt."
    ;;
  auth_success)
    title="Claude signed in"
    message="$(printf '%s' "$input" | jq -r '.message // "Authentication succeeded."')"
    ;;
  # Background agents report separately from the main session: without these a
  # subagent can finish, or stall waiting on an answer, entirely unannounced.
  agent_needs_input)
    title="Agent needs input"
    message="$(printf '%s' "$input" | jq -r '.message // "A background agent is waiting for your response."')"
    ;;
  agent_completed)
    title="Agent finished"
    message="$(printf '%s' "$input" | jq -r '.message // "A background agent finished its task."')"
    ;;
  session_end)
    title="Codex finished"
    message="The Codex session ended."
    ;;
  *)
    exit 0
    ;;
esac

# Several sessions run at once, so a banner that does not name its origin is close to useless.
# The product name leads because macOS attributes a banner to whichever binary posted it,
# never to Claude Code. Either identifying field can be absent, so each is appended only when
# it has a value.
attribution="Claude Code"

working_directory="$(printf '%s' "$input" | jq -r '.cwd // empty')"
if [ -n "$working_directory" ]; then
  project="$(basename "${working_directory%/}")"
  if [ -n "$project" ]; then
    attribution="$attribution · $project"
  fi
fi

session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
if [ -n "$session_id" ]; then
  # The full UUID overflows the subtitle; its leading block is already unique enough to match
  # a banner against a terminal.
  attribution="$attribution · session ${session_id:0:7}"
fi

# terminal-notifier can borrow an installed application's identity, which is the only way a
# banner carries a Claude icon and name rather than the posting binary's. It is optional, so
# osascript remains the fallback.
resolve_sender_bundle_id() {
  local bundle
  local bundle_id
  for bundle in "/Applications/Claude.app" "$HOME/Applications/Claude.app"; do
    if [ -d "$bundle" ]; then
      bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Contents/Info.plist" 2>/dev/null || true)"
      if [ -n "$bundle_id" ]; then
        printf '%s' "$bundle_id"
        return 0
      fi
    fi
  done
  return 0
}

send_notification() {
  if command -v terminal-notifier >/dev/null 2>&1; then
    local sender_bundle_id
    sender_bundle_id="$(resolve_sender_bundle_id)"
    # An unresolvable bundle identifier suppresses delivery, so pass -sender only when the
    # bundle really is on disk.
    if [ -n "$sender_bundle_id" ]; then
      terminal-notifier -sender "$sender_bundle_id" -title "$title" -subtitle "$attribution" -message "$message"
    else
      terminal-notifier -title "$title" -subtitle "$attribution" -message "$message"
    fi
    return
  fi

  # Arguments rather than interpolation: a message containing quotes would otherwise break
  # the AppleScript source.
  /usr/bin/osascript - "$title" "$attribution" "$message" <<'APPLESCRIPT'
on run arguments
  display notification (item 3 of arguments) with title (item 1 of arguments) subtitle (item 2 of arguments)
end run
APPLESCRIPT
}

if send_notification; then
  write_log "Notification sent: $notification_type - $title"
else
  write_log "Notification failed: $notification_type - $title"
  exit 1
fi
