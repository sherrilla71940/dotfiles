#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
model="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
current_directory="$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')"
used_percentage="$(printf '%s' "$input" | jq -r 'if .context_window.used_percentage == null then empty else (.context_window.used_percentage | floor | tostring) end')"

parts=()
if [[ -n "$model" ]]; then
  parts+=("[$model]")
fi
if [[ -n "$current_directory" ]]; then
  parts+=("$(basename "$current_directory")")
fi
if [[ -n "$used_percentage" ]]; then
  parts+=("${used_percentage}% context")
fi

if (( ${#parts[@]} > 0 )); then
  printf '%s' "${parts[0]}"
  for ((index = 1; index < ${#parts[@]}; index++)); do
    printf ' | %s' "${parts[$index]}"
  done
fi
printf '\n'
