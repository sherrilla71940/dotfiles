#!/usr/bin/env bash
# Report the deterministic facts about continuity state that Git can prove: recorded branch or
# HEAD that no longer matches the checkout, and a task whose tracking sections hold nothing.
# Semantic state belongs to the project-continuity skill, and check-worktree-launch.sh owns
# every SessionStart message, so this script emits none.
set -euo pipefail

input="$(cat)"
# Keep this to a single @tsv line: jq on Windows writes CRLF, and command substitution strips
# only a trailing newline, so a multi-line form would leave a stray CR on every field but the
# last. Neither field is ever empty, so tab-collapsing cannot shift the split.
common_fields="$(printf '%s' "$input" | jq -r '[.hook_event_name // "", .cwd // ""] | @tsv' 2>/dev/null || true)"
event_name=""
working_directory=""
IFS=$'\t' read -r event_name working_directory <<< "$common_fields" || true

if [[ -z "$event_name" ]]; then
  exit 0
fi

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
    message="$message must stay resumable, leave that state untouched and park it instead."
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

case "$event_name" in
  SessionStart)
    # Silent backstop only. The skill instructs the model to add the exclude entry itself, and
    # check-worktree-launch.sh owns every SessionStart message, including the one that asks for
    # reconciliation after a compaction. Emitting a second message here would compete with it.
    if state_file="$(find_state_file)"; then
      ensure_private_state_path "$(dirname "$(dirname "$state_file")")" || true
    fi
    ;;
  Stop)
    if state_file="$(find_state_file)"; then
      report_continuity_notice "$state_file"
    fi
    ;;
esac
