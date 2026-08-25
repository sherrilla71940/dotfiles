#!/usr/bin/env bash
# SessionStart hook. Two independent checks, either of which may add context:
#   1. Another interactive session is already in this working directory, so both share one
#      working tree, one index and one HEAD. Claude Code takes no lock on a directory, and
#      git only refuses a duplicate checkout across worktrees, not across processes.
#   2. Claude started in a directory that merely contains worktrees, so repository auto
#      memory may not have loaded.
# Check 1 applies inside a checkout and check 2 outside one, so neither may exit early.
set -euo pipefail

input="$(cat)"
if ! working_directory="$(printf '%s' "$input" | jq -er '.cwd // empty')"; then
  exit 0
fi
if [[ ! -d "$working_directory" ]]; then
  exit 0
fi
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

messages=()

# Drive-letter case and separator style both vary between the hook payload and the agent
# listing on Windows, so compare normalised paths rather than raw strings.
if command -v claude >/dev/null 2>&1; then
  siblings="$(timeout 10 claude agents --json 2>/dev/null || true)"
  if [[ -n "$siblings" ]]; then
    count="$(printf '%s' "$siblings" | jq -r --arg cwd "$working_directory" --arg sid "$session_id" '
      def norm: ascii_downcase | gsub("\\\\"; "/") | sub("/$"; "");
      [ .[]
        | select(.kind == "interactive")
        | select((.sessionId // "") != $sid)
        | select(((.cwd // "") | norm) == ($cwd | norm))
      ] | length
    ' 2>/dev/null || printf '0')"
    if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 )); then
      messages+=("$count other interactive Claude Code session(s) are already running in '$working_directory'. They share this working tree, index and HEAD, so a git add or commit here can pick up their staged changes, and a checkout switches their branch too. At the beginning of your first response, tell the user, and suggest 'claude --worktree <name>' for genuinely parallel work. Before any git add or commit in this session, stage explicit paths rather than -A or ., and check git diff --cached for files this session did not touch.")
    fi
  fi
fi

if ! git -C "$working_directory" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  worktree_names=()
  shopt -s nullglob dotglob
  for child in "$working_directory"/*; do
    if [[ ! -d "$child" ]]; then
      continue
    fi
    if [[ -f "$child/.git" ]] && git -C "$child" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      worktree_names+=("$(basename "$child")")
      if (( ${#worktree_names[@]} == 5 )); then
        break
      fi
    fi
  done

  if (( ${#worktree_names[@]} > 0 )); then
    names=""
    for name in "${worktree_names[@]}"; do
      names="${names:+$names, }$name"
    done
    messages+=("Claude Code started in '$working_directory', which is not a git checkout but contains linked worktrees ($names). Repository auto memory may not have loaded for this session. At the beginning of your first response, briefly tell the user and recommend restarting Claude inside the intended worktree.")
  fi
fi

if (( ${#messages[@]} == 0 )); then
  exit 0
fi

context=""
for message in "${messages[@]}"; do
  context="${context:+$context }$message"
done
context="$context Do not repeat these reminders in later responses."

jq -cn --arg context "$context" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$context}}'
