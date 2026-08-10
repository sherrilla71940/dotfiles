#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
if ! working_directory="$(printf '%s' "$input" | jq -er '.cwd // empty')"; then
  exit 0
fi
if [[ ! -d "$working_directory" ]]; then
  exit 0
fi
if git -C "$working_directory" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

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

if (( ${#worktree_names[@]} == 0 )); then
  exit 0
fi

names=""
for name in "${worktree_names[@]}"; do
  names="${names:+$names, }$name"
done

context="Claude Code started in '$working_directory', which is not a git checkout but contains linked worktrees ($names). Repository auto memory may not have loaded for this session. At the beginning of your first response, briefly tell the user and recommend restarting Claude inside the intended worktree. Do not repeat the reminder in later responses."
jq -cn --arg context "$context" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$context}}'
