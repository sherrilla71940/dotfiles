#!/usr/bin/env bash
# Preserve a compact, private recovery bridge when Claude Code compacts a conversation.
# The project-continuity skill remains responsible for semantic state and Git reconciliation.
set -euo pipefail

input="$(cat)"
common_fields="$(printf '%s' "$input" | jq -r '[.hook_event_name // "", .session_id // ""] | @tsv' 2>/dev/null || true)"
event_name=""
session_id=""
IFS=$'\t' read -r event_name session_id <<< "$common_fields" || true
safe_session_id="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"

if [[ -z "$event_name" || -z "$safe_session_id" ]]; then
  exit 0
fi

runtime_directory="${TMPDIR:-/tmp}/claude-project-continuity"
marker_file="$runtime_directory/$safe_session_id.json"
recovery_start='<!-- claude-compaction-recovery:start -->'
recovery_end='<!-- claude-compaction-recovery:end -->'

get_working_tree_root() {
  local working_directory
  working_directory="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
  if [[ -z "$working_directory" || ! -d "$working_directory" ]]; then
    return 1
  fi
  git -C "$working_directory" rev-parse --show-toplevel 2>/dev/null
}

ensure_private_state_path() {
  local root="$1"
  local exclude_file

  if git -C "$root" check-ignore -q -- .project-continuity/state.md 2>/dev/null; then
    return 0
  fi

  exclude_file="$(git -C "$root" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null || true)"
  if [[ -z "$exclude_file" ]]; then
    return 1
  fi

  mkdir -p "$(dirname "$exclude_file")"
  touch "$exclude_file"
  if ! grep -qxF '/.project-continuity/' "$exclude_file"; then
    printf '\n/.project-continuity/\n' >> "$exclude_file"
  fi

  git -C "$root" check-ignore -q -- .project-continuity/state.md 2>/dev/null
}

write_marker() {
  local root="$1"
  local marker_temp

  mkdir -p "$runtime_directory"
  chmod 700 "$runtime_directory" 2>/dev/null || true
  marker_temp="$(mktemp "$runtime_directory/.marker.XXXXXX")"
  jq -cn --arg root "$root" '{working_tree_root:$root}' > "$marker_temp"
  chmod 600 "$marker_temp" 2>/dev/null || true
  mv -f "$marker_temp" "$marker_file"
}

write_emergency_skeleton() {
  local root="$1"
  local state_file="$root/.project-continuity/state.md"
  local branch head status_count timestamp state_temp

  if [[ -f "$state_file" ]]; then
    return 0
  fi

  branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
  head="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || true)"
  status_count="$(git -C "$root" status --short 2>/dev/null | wc -l | tr -d '[:space:]')"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  mkdir -p "$root/.project-continuity"
  state_temp="$(mktemp "$root/.project-continuity/.state.XXXXXX")"
  chmod 600 "$state_temp" 2>/dev/null || true

  cat > "$state_temp" <<EOF
# Project Continuity

## Objective

Recover and reconcile the active task after Claude Code context compaction.

## Current phase

Emergency recovery state was created automatically before compaction. Its task details are
unverified until the project-continuity skill reconciles them against Git and the current request.

## In progress

- Recover the active objective, decisions, progress and next action from the compaction summary.

## Next actions

1. Invoke the project-continuity skill.
2. Reconcile this state against Git and the current user instruction.
3. Replace the emergency scaffold with normal continuity state and continue the task.

## Verification

- Working tree: \`$root\`
- Branch: \`${branch:-unknown}\`
- HEAD: \`${head:-unknown}\`
- Started from: \`${head:-unknown}\`
- Status: emergency capture; $status_count working-tree change(s) observed before compaction
- Last reconciled: not yet; captured $timestamp
EOF

  if [[ -f "$state_file" ]]; then
    rm -f "$state_temp"
  else
    mv "$state_temp" "$state_file"
  fi
}

replace_recovery_section() {
  local root="$1"
  local state_file="$root/.project-continuity/state.md"
  local trigger summary summary_excerpt timestamp state_without_recovery state_temp
  local state_fingerprint latest_fingerprint

  trigger="$(printf '%s' "$input" | jq -r '.trigger // "unknown"' 2>/dev/null || printf 'unknown')"
  summary="$(printf '%s' "$input" | jq -r '
    (.compact_summary // "")
    | if length > 10000 then .[:10000] + "\n[compact summary truncated by continuity hook]" else . end
  ' 2>/dev/null || true)"
  if [[ -z "$summary" ]]; then
    summary='Claude Code did not provide a compact summary to the hook.'
  fi
  summary_excerpt="$(printf '%s\n' "$summary" | awk 'NR <= 60 { print }')"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  write_emergency_skeleton "$root"
  state_without_recovery="$(mktemp "$root/.project-continuity/.state-without-recovery.XXXXXX")"
  state_temp="$(mktemp "$root/.project-continuity/.state.XXXXXX")"
  chmod 600 "$state_without_recovery" "$state_temp" 2>/dev/null || true

  state_fingerprint="$(git hash-object "$state_file" 2>/dev/null || true)"
  awk -v start="$recovery_start" -v end="$recovery_end" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$state_file" > "$state_without_recovery"

  # Re-read immediately before replacement. If another client checkpointed after the first
  # read, rebuild from its newest content rather than writing the earlier snapshot.
  latest_fingerprint="$(git hash-object "$state_file" 2>/dev/null || true)"
  if [[ "$latest_fingerprint" != "$state_fingerprint" ]]; then
    awk -v start="$recovery_start" -v end="$recovery_end" '
      $0 == start { skipping = 1; next }
      $0 == end { skipping = 0; next }
      !skipping { print }
    ' "$state_file" > "$state_without_recovery"
  fi

  {
    awk '
      { lines[NR] = $0 }
      END {
        last = NR
        while (last > 0 && lines[last] == "") { last-- }
        for (line = 1; line <= last; line++) { print lines[line] }
      }
    ' "$state_without_recovery"
    printf '\n\n%s\n' "$recovery_start"
    printf '## Emergency recovery\n\n'
    printf 'Claude Code captured this temporary, unverified context after `%s` compaction at `%s`.\n' "$trigger" "$timestamp"
    printf 'The project-continuity skill must reconcile it against Git and the current request, merge\n'
    printf 'useful facts into the normal sections above, then remove this entire emergency section.\n\n'
    printf '### Compact summary\n\n'
    while IFS= read -r line || [[ -n "$line" ]]; do
      printf '> %s\n' "$line"
    done <<< "$summary_excerpt"
    printf '%s\n' "$recovery_end"
  } > "$state_temp"

  mv -f "$state_temp" "$state_file"
  rm -f "$state_without_recovery"
}

case "$event_name" in
  PreCompact)
    if root="$(get_working_tree_root)" && ensure_private_state_path "$root"; then
      write_emergency_skeleton "$root"
      write_marker "$root"
    fi
    ;;
  PostCompact)
    if root="$(get_working_tree_root)" && ensure_private_state_path "$root"; then
      replace_recovery_section "$root"
      write_marker "$root"
    fi
    ;;
  Stop)
    if [[ ! -f "$marker_file" ]]; then
      exit 0
    fi

    root="$(jq -r '.working_tree_root // empty' "$marker_file" 2>/dev/null || true)"
    state_file="$root/.project-continuity/state.md"
    if [[ -z "$root" || ! -f "$state_file" ]] || ! grep -qxF "$recovery_start" "$state_file"; then
      rm -f "$marker_file"
      exit 0
    fi

    stop_hook_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || printf 'false')"
    if [[ "$stop_hook_active" == "true" ]]; then
      # One continuation is enough to request reconciliation without risking a stop loop.
      rm -f "$marker_file"
      exit 0
    fi

    jq -cn '{decision:"block",reason:"Claude compaction left an Emergency recovery section in .project-continuity/state.md. Invoke the project-continuity skill now, reconcile the summary against Git and the current request, merge useful facts into normal state, remove the emergency section, then finish the response."}'
    ;;
esac
