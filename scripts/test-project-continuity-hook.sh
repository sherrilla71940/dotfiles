#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
lifecycle_hook="$repository_root/home/dot_claude/hooks/maintain-project-continuity.sh"
session_start_hook="$repository_root/home/dot_claude/hooks/check-worktree-launch.sh"
fixture="$(mktemp -d)"

cleanup() {
  case "$fixture" in
    "${TMPDIR:-/tmp}"/*) rm -rf -- "$fixture" ;;
    *) printf 'Refusing to remove unexpected fixture path: %s\n' "$fixture" >&2 ;;
  esac
}
trap cleanup EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.name test
git -C "$fixture" config user.email test@example.com
git -C "$fixture" config core.autocrlf false
printf 'fixture\n' > "$fixture/tracked.txt"
git -C "$fixture" add tracked.txt
git -C "$fixture" commit -qm initial

session_id="continuity-hook-test-$$"
state_file="$fixture/.project-continuity/state.md"

printf 'not-json' | bash "$lifecycle_hook"

jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
  '{session_id:$sid,cwd:$cwd,hook_event_name:"PreCompact",trigger:"auto",custom_instructions:""}' \
  | bash "$lifecycle_hook"

test -f "$state_file"
git -C "$fixture" check-ignore -q .project-continuity/state.md
grep -q 'Emergency recovery state was created automatically' "$state_file"

jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
  --arg summary $'Implemented one part.\nNext: verify the bridge.' \
  '{session_id:$sid,cwd:$cwd,hook_event_name:"PostCompact",trigger:"auto",compact_summary:$summary}' \
  | bash "$lifecycle_hook"

grep -qxF '<!-- claude-compaction-recovery:start -->' "$state_file"
grep -q '> Next: verify the bridge.' "$state_file"

# A later compact replaces temporary recovery context without losing normalized state.
printf '\n## Decisions still in force\n\n- Preserve this authored fact.\n' >> "$state_file"
jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
  --arg summary 'Replacement compact summary.' \
  '{session_id:$sid,cwd:$cwd,hook_event_name:"PostCompact",trigger:"manual",compact_summary:$summary}' \
  | bash "$lifecycle_hook"

test "$(grep -cFx '<!-- claude-compaction-recovery:start -->' "$state_file")" -eq 1
grep -q '> Replacement compact summary.' "$state_file"
grep -q -- '- Preserve this authored fact.' "$state_file"

session_output="$({
  jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
    '{session_id:$sid,cwd:$cwd,hook_event_name:"SessionStart",source:"compact"}' \
    | bash "$session_start_hook"
})"
printf '%s' "$session_output" \
  | jq -e '.hookSpecificOutput.additionalContext | contains("Claude compaction recovery is pending")' \
  >/dev/null

stop_output="$({
  jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
    '{session_id:$sid,cwd:$cwd,hook_event_name:"Stop",stop_hook_active:false}' \
    | bash "$lifecycle_hook"
})"
printf '%s' "$stop_output" | jq -e '.decision == "block"' >/dev/null

second_stop_output="$({
  jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
    '{session_id:$sid,cwd:$cwd,hook_event_name:"Stop",stop_hook_active:true}' \
    | bash "$lifecycle_hook"
})"
test -z "$second_stop_output"

printf 'project continuity hook lifecycle OK\n'

# --- Drift notices and the cleanup offer -------------------------------------------------------
# No marker remains, so Stop takes the notice path rather than the compaction-recovery path.
fixture_branch="$(git -C "$fixture" branch --show-current)"
fixture_head="$(git -C "$fixture" rev-parse --short HEAD)"

write_state() {
  # write_state <branch> <head> <trailing-verification-lines...>
  local branch="$1" head="$2"
  shift 2
  mkdir -p "$fixture/.project-continuity"
  {
    printf '# Project Continuity\n\n## Objective\n\nExercise the Stop notices.\n\n'
    printf '## Verification\n\n'
    printf -- '- Branch: `%s`\n' "$branch"
    printf -- '- HEAD: `%s`\n' "$head"
    local line
    for line in "$@"; do
      printf -- '%s\n' "$line"
    done
  } > "$state_file"
}

append_section() {
  printf '\n## %s\n\n%s\n' "$1" "$2" >> "$state_file"
}

stop_notice() {
  jq -cn --arg sid "$session_id" --arg cwd "$fixture" \
    '{session_id:$sid,cwd:$cwd,hook_event_name:"Stop",stop_hook_active:false}' \
    | bash "$lifecycle_hook"
}

notice_message() {
  printf '%s' "$1" | jq -r '.systemMessage // ""'
}

# A moved HEAD is ordinary progress: the recorded commit is stale and should be refreshed.
write_state "$fixture_branch" deadbee
append_section 'Next actions' '1. Keep the task open.'
head_message="$(notice_message "$(stop_notice)")"
case "$head_message" in
  *"is out of date"*"Reconcile"*) ;;
  *) printf 'expected HEAD-drift reconcile notice, got: %s\n' "$head_message" >&2; exit 1 ;;
esac
case "$head_message" in
  *"not by itself a new task"*)
    printf 'HEAD drift must not emit the branch-switch warning\n' >&2; exit 1 ;;
esac

# A different branch may mean a different task, so the notice must warn against merging rather
# than ask for reconciliation - that is the case that used to corrupt the previous task's state.
write_state some-other-branch "$fixture_head"
append_section 'Next actions' '1. Keep the task open.'
branch_message="$(notice_message "$(stop_notice)")"
case "$branch_message" in
  *"not by itself a new task"*"separate worktree"*) ;;
  *) printf 'expected branch-switch warning, got: %s\n' "$branch_message" >&2; exit 1 ;;
esac
case "$branch_message" in
  *"is out of date"*)
    printf 'branch drift must not reuse the stale-HEAD reconcile wording\n' >&2; exit 1 ;;
esac

# Both drifting reports the branch warning first and mentions the stale commit separately.
write_state some-other-branch deadbee
append_section 'Next actions' '1. Keep the task open.'
both_message="$(notice_message "$(stop_notice)")"
case "$both_message" in
  *"not by itself a new task"*"Separately, continuity records HEAD deadbee"*) ;;
  *) printf 'expected combined branch-then-HEAD notice, got: %s\n' "$both_message" >&2; exit 1 ;;
esac

# A detached HEAD has no branch name, which is how the Codex app runs its managed worktrees. It
# must not read as branch drift.
git -C "$fixture" checkout -q --detach HEAD
write_state "$fixture_branch" "$fixture_head"
append_section 'Next actions' '1. Keep the task open.'
test -z "$(stop_notice)"
git -C "$fixture" checkout -q "$fixture_branch"

# A state file with no unfinished work anywhere should raise the cleanup offer.
write_state "$fixture_branch" "$fixture_head"
append_section 'Completed' '- Verified work only.'
cleanup_message="$(notice_message "$(stop_notice)")"
case "$cleanup_message" in
  *"records no unfinished work"*"offer cleanup"*) ;;
  *) printf 'expected cleanup offer, got: %s\n' "$cleanup_message" >&2; exit 1 ;;
esac

# Present-but-empty tracking sections count as finished too.
write_state "$fixture_branch" "$fixture_head"
append_section 'In progress' ''
append_section 'Next actions' ''
append_section 'Blockers' ''
append_section 'TODO / deferred' ''
notice_message "$(stop_notice)" | grep -q 'records no unfinished work'

# One open item in any tracking section is enough to keep the offer silent.
for open_section in 'In progress' 'Next actions' 'Blockers' 'TODO / deferred'; do
  write_state "$fixture_branch" "$fixture_head"
  append_section "$open_section" '- Still outstanding.'
  if [[ -n "$(stop_notice)" ]]; then
    printf 'an open item in %s must suppress the cleanup offer\n' "$open_section" >&2
    exit 1
  fi
done

# A declined offer is not raised again for the rest of the task.
write_state "$fixture_branch" "$fixture_head" '- Cleanup: `declined`'
append_section 'Completed' '- Verified work only.'
test -z "$(stop_notice)"

# Drift outranks the cleanup offer, because one response carries one system message and wrong
# recorded state misleads the next reader more than an unretired file does.
write_state "$fixture_branch" deadbee
append_section 'Completed' '- Verified work only.'
notice_message "$(stop_notice)" | grep -q 'is out of date'

# An unreconciled emergency section always has work to do, so no cleanup offer.
write_state "$fixture_branch" "$fixture_head"
printf '\n<!-- claude-compaction-recovery:start -->\n## Emergency recovery\n\n> summary\n<!-- claude-compaction-recovery:end -->\n' >> "$state_file"
test -z "$(stop_notice)"

# With no Verification block there is nothing to compare against, so drift stays silent -
# but the file still records no unfinished work, so the cleanup offer is the right notice.
printf '# Project Continuity\n\n## Objective\n\nNo verification block.\n' > "$state_file"
notice_message "$(stop_notice)" | grep -q 'records no unfinished work'

printf 'project continuity drift and cleanup notices OK\n'
