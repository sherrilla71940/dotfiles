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
