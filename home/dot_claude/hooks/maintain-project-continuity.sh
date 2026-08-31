#!/usr/bin/env bash
# Preserve a compact, private recovery bridge when Claude Code compacts a conversation.
# The project-continuity skill remains responsible for semantic state and Git reconciliation.
set -euo pipefail

input="$(cat)"
common_fields="$(printf '%s' "$input" | jq -r '[.hook_event_name // "", .session_id // "", .cwd // ""] | @tsv' 2>/dev/null || true)"
event_name=""
session_id=""
working_directory=""
IFS=$'\t' read -r event_name session_id working_directory <<< "$common_fields" || true
safe_session_id="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"

if [[ -z "$event_name" || -z "$safe_session_id" ]]; then
  exit 0
fi

runtime_directory="${TMPDIR:-/tmp}/claude-project-continuity"
marker_file="$runtime_directory/$safe_session_id.json"
recovery_start='<!-- claude-compaction-recovery:start -->'
recovery_end='<!-- claude-compaction-recovery:end -->'

get_working_tree_root() {
  if [[ -z "$working_directory" || ! -d "$working_directory" ]]; then
    return 1
  fi
  git -C "$working_directory" rev-parse --show-toplevel 2>/dev/null
}

# Locate continuity state without paying for git when the session is already at the working
# tree root, which is the ordinary case. Stop runs after every response, so the path taken
# when no continuity exists must stay a shell builtin.
find_state_file() {
  local root

  if [[ -z "$working_directory" || ! -d "$working_directory" ]]; then
    return 1
  fi
  if [[ -f "$working_directory/.project-continuity/state.md" ]]; then
    printf '%s\n' "$working_directory/.project-continuity/state.md"
    return 0
  fi
  root="$(git -C "$working_directory" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$root" && -f "$root/.project-continuity/state.md" ]]; then
    printf '%s\n' "$root/.project-continuity/state.md"
    return 0
  fi
  return 1
}

# Read one `- Field: `value`` line out of the Verification block.
recorded_field() {
  local state_file="$1" field="$2" line
  line="$(grep -m1 -E "^- $field:" "$state_file" 2>/dev/null || true)"
  printf '%s' "$line" | sed -n 's/.*`\(.*\)`.*/\1/p'
}

# The Verification block records a branch and a HEAD, and git can answer both. Leaving that to
# discipline is what lets a state file quietly describe a commit that is no longer current, so
# the divergence is reported instead of waited for. Everything else in the file - the objective,
# the decisions, whether a TODO is really done - has no such oracle and is left to the skill.
report_stale_verification() {
  local state_file="$1" directory="$2"
  local recorded_head actual_head recorded_branch actual_branch
  local head_drift="" branch_drift="" message=""

  recorded_head="$(recorded_field "$state_file" "HEAD")"
  recorded_branch="$(recorded_field "$state_file" "Branch")"
  if [[ -z "$recorded_head" && -z "$recorded_branch" ]]; then
    return 0
  fi

  actual_head="$(git -C "$directory" rev-parse --short HEAD 2>/dev/null || true)"
  actual_branch="$(git -C "$directory" branch --show-current 2>/dev/null || true)"

  if [[ -n "$recorded_head" && "$recorded_head" != "unknown" && -n "$actual_head" \
        && "$recorded_head" != "$actual_head" ]]; then
    head_drift="continuity records HEAD $recorded_head, but HEAD is $actual_head"
  fi
  # An empty actual_branch means a detached HEAD, which is how the Codex app runs its managed
  # worktrees. That is not branch drift, so the -n guard keeps it out of the warning below.
  if [[ -n "$recorded_branch" && "$recorded_branch" != "unknown" && -n "$actual_branch" \
        && "$recorded_branch" != "$actual_branch" ]]; then
    branch_drift="continuity records branch $recorded_branch, but the branch is $actual_branch"
  fi

  if [[ -z "$head_drift" && -z "$branch_drift" ]]; then
    return 0
  fi

  # The two kinds of drift call for opposite actions, so they must not share one message. A moved
  # HEAD means the recorded commit is merely stale and should be refreshed at the next checkpoint.
  # A different branch may mean a different task, and there the damaging move is folding the new
  # branch's work into state that belongs to the old one - so that message says leave it alone.
  if [[ -n "$branch_drift" ]]; then
    message="Project continuity: $branch_drift."
    message="$message A branch switch is not by itself a new task, and branch is supporting"
    message="$message evidence rather than task identity. Do not merge work from"
    message="$message $actual_branch into .project-continuity/state.md, and do not replace that"
    message="$message state while it still holds useful unfinished work. If this is the same task,"
    message="$message reconcile at the next checkpoint. If it is a separate substantive task that"
    message="$message must stay resumable, leave that state untouched and use a separate worktree."
    if [[ -n "$head_drift" ]]; then
      message="$message Separately, $head_drift."
    fi
  else
    message="Project continuity is out of date: $head_drift."
    message="$message Reconcile .project-continuity/state.md against Git before the next"
    message="$message checkpoint, and prune anything in it that the repository can already answer."
  fi

  jq -cn --arg message "$message" '{systemMessage:$message}'
}

# The skill's trigger for offering cleanup sat inside its checkpoint step, and a finished task
# removes the reason to checkpoint, so a completed task's state file could sit in the tree
# indefinitely. Whether these four sections hold any open item is the one part of that judgment a
# hook can decide, so it is checked here and the semantic call is left to the skill.
report_finished_state() {
  local state_file="$1"
  local open_items message

  # Emergency recovery state is unverified by definition and always carries work to do.
  if grep -qxF "$recovery_start" "$state_file" 2>/dev/null; then
    return 0
  fi
  # A user who declined cleanup should not be asked again for the rest of the task.
  if [[ "$(recorded_field "$state_file" "Cleanup")" == "declined" ]]; then
    return 0
  fi

  open_items="$(awk '
    BEGIN {
      tracked["In progress"] = 1
      tracked["Next actions"] = 1
      tracked["Blockers"] = 1
      tracked["TODO / deferred"] = 1
    }
    /^## / {
      section = substr($0, 4)
      sub(/[[:space:]]+$/, "", section)
      tracking = (section in tracked)
      next
    }
    tracking && /^[[:space:]]*([-*]|[0-9]+[.])[[:space:]]+[^[:space:]]/ { count++ }
    END { print count + 0 }
  ' "$state_file" 2>/dev/null || printf '1')"

  if [[ "$open_items" != "0" ]]; then
    return 0
  fi

  message="Project continuity at .project-continuity/state.md records no unfinished work:"
  message="$message In progress, Next actions, Blockers and TODO / deferred are all empty or"
  message="$message absent. If the tracked task is genuinely complete, do not invent a next"
  message="$message action - say continuity looks unnecessary and offer cleanup in this response,"
  message="$message naming anything that belongs in durable documentation first. If work does"
  message="$message remain, record it. If the user declines cleanup, record Cleanup: \`declined\`"
  message="$message in the Verification block so this is not raised again."

  jq -cn --arg message "$message" '{systemMessage:$message}'
}

# A response carries at most one system message, so the notices are ranked. Drift comes first,
# because a state file describing the wrong commit or branch actively misleads the next reader,
# where an unretired finished file only wastes a cleanup.
report_continuity_notice() {
  local state_file="$1"
  local directory notice

  directory="$(dirname "$(dirname "$state_file")")"
  notice="$(report_stale_verification "$state_file" "$directory")"
  if [[ -z "$notice" ]]; then
    notice="$(report_finished_state "$state_file")"
  fi
  if [[ -n "$notice" ]]; then
    printf '%s\n' "$notice"
  fi
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
    # Compaction recovery outranks the staleness notice: it blocks the stop, and emitting both
    # would put two messages on one response.
    if [[ ! -f "$marker_file" ]]; then
      if state_file="$(find_state_file)"; then
        report_continuity_notice "$state_file"
      fi
      exit 0
    fi

    root="$(jq -r '.working_tree_root // empty' "$marker_file" 2>/dev/null || true)"
    state_file="$root/.project-continuity/state.md"
    if [[ -z "$root" || ! -f "$state_file" ]] || ! grep -qxF "$recovery_start" "$state_file"; then
      rm -f "$marker_file"
      if state_file="$(find_state_file)"; then
        report_continuity_notice "$state_file"
      fi
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
