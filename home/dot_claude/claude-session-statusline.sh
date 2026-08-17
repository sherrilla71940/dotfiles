#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
model="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
# Absent on models without a reasoning effort parameter; tracks /effort changes
# made mid-session.
effort_level="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
current_directory="$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')"
# Only set by --name, /rename or an AI-generated title; the default my-app-3f
# style display name does not populate it, so most sessions have none.
session_name="$(printf '%s' "$input" | jq -r '.session_name // empty')"
used_percentage="$(printf '%s' "$input" | jq -r 'if .context_window.used_percentage == null then empty else (.context_window.used_percentage | floor | tostring) end')"
# Client-side estimate only; resets to 0 when /clear starts a new session.
session_cost="$(printf '%s' "$input" | jq -r 'if (.cost.total_cost_usd // 0) > 0 then (.cost.total_cost_usd | tostring) else empty end')"
# Rate limits are present only for Claude.ai Pro/Max sessions, and each window
# can be absent independently, so both are treated as optional.
five_hour_usage="$(printf '%s' "$input" | jq -r 'if .rate_limits.five_hour.used_percentage == null then empty else (.rate_limits.five_hour.used_percentage | floor | tostring) end')"
seven_day_usage="$(printf '%s' "$input" | jq -r 'if .rate_limits.seven_day.used_percentage == null then empty else (.rate_limits.seven_day.used_percentage | floor | tostring) end')"
five_hour_reset="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty | tostring')"
seven_day_reset="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty | tostring')"

# Emoji carry their own colour, which no escape code can override, so they are
# chosen for contrast against each other: a label and a money bag are the same
# yellow as the folder and the hourglass, which made four segments look alike.
# Basic ANSI codes only, so the terminal's own theme decides the exact hues.
# Bright black is the separator colour and nothing else: on a dark theme it sits
# close to the background, which suits structure but loses any text put in it.
# Secondary text keeps the default foreground instead, the one colour guaranteed
# to stay legible whether the theme is light or dark.
dim=$'\033[90m'
muted=$'\033[39m'
cyan=$'\033[36m'
blue=$'\033[94m'
magenta=$'\033[95m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'
reset=$'\033[0m'

# Two separator weights carry the hierarchy: the heavier rule divides unrelated
# scopes, the lighter dot joins values that belong to the same group.
major_separator="${dim}  │  ${reset}"
minor_separator="${dim} · ${reset}"

# Context fill and rate-limit fill share one threshold scale, so a given colour
# always carries the same meaning wherever it appears on the line.
usage_color() {
  local percentage="$1"
  if ((percentage >= 90)); then
    printf '%s' "$red"
  elif ((percentage >= 70)); then
    printf '%s' "$yellow"
  else
    printf '%s' "$green"
  fi
}

# No branch is provided on stdin outside --worktree sessions, so ask git. A
# single porcelain v2 call answers all three questions at once — whether this is
# a repository, which branch is checked out, and what the work tree looks like —
# because spawning git costs about as much as git's own work here. The query is
# scoped to the session's directory since this script's working directory is not
# necessarily the project. Untracked files are excluded: they are not reported,
# and skipping them avoids the untracked scan.
git_summary() {
  local directory="$1"
  if [[ -z "$directory" ]] || ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  local status_output
  status_output="$(git -C "$directory" status --porcelain=v2 --branch --untracked-files=no 2>/dev/null || true)"
  if [[ -z "$status_output" ]]; then
    return 0
  fi

  local branch="" object_id="" staged_count=0 modified_count=0 line states
  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*) branch="${line#\# branch.head }" ;;
      '# branch.oid '*) object_id="${line#\# branch.oid }" ;;
      # Changed, renamed and unmerged entries all carry the two state columns in
      # the same position: the index state then the work-tree state.
      [12u]' '*)
        states="${line:2:2}"
        case "$states" in
          [!.]*) staged_count=$((staged_count + 1)) ;;
        esac
        case "$states" in
          ?[!.]) modified_count=$((modified_count + 1)) ;;
        esac
        ;;
    esac
  done <<<"$status_output"

  # Detached HEAD reports no branch name, so fall back to a parenthesised short
  # object id the way git's own shell prompt does.
  if [[ "$branch" == "(detached)" ]]; then
    branch="(${object_id:0:7})"
  fi
  if [[ -z "$branch" ]]; then
    return 0
  fi

  printf '%s' "$branch"
  if ((staged_count > 0)); then
    printf ' +%s' "$staged_count"
  fi
  if ((modified_count > 0)); then
    printf ' ~%s' "$modified_count"
  fi
}

# An absolute wall-clock time rather than a countdown: this script runs on
# events, and those go quiet while the session is idle, so a countdown would
# silently drift while a clock time stays correct however stale the render is.
reset_label() {
  local epoch="$1"
  local now
  now="$(date +%s)"

  # Beyond a day out the time of day alone is ambiguous, so name the weekday.
  local format='+%H:%M'
  if ((epoch - now >= 86400)); then
    format='+%a'
  fi

  # GNU date takes -d @epoch and BSD date takes -r epoch; try both so macOS
  # works. LC_ALL is pinned so the weekday matches the PowerShell copy.
  LC_ALL=C date -d "@${epoch}" "$format" 2>/dev/null ||
    LC_ALL=C date -r "$epoch" "$format" 2>/dev/null ||
    true
}

# The reset time always accompanies the percentage, because the percentage alone
# cannot say whether a nearly full window clears in minutes or in hours.
limit_value() {
  local label="$1" percentage="$2" reset_epoch="$3"
  local text
  text="$(usage_color "$percentage")${label} ${percentage}%${reset}"

  if [[ -n "$reset_epoch" ]]; then
    local moment
    moment="$(reset_label "$reset_epoch")"
    if [[ -n "$moment" ]]; then
      text+="${muted} resets ${moment}${reset}"
    fi
  fi

  printf '%s' "$text"
}

join_segments() {
  local separator="$1"
  shift
  if (($# == 0)); then
    return 0
  fi
  printf '%s' "$1"
  shift
  local segment
  for segment in "$@"; do
    printf '%s%s' "$separator" "$segment"
  done
}

# Line one is identity: rarely changes, so it stays out of the way of the meters.
identity_segments=()
# Effort qualifies the model rather than standing alone, so the two share a
# segment. It stays uncoloured: the threshold palette already means fill level.
if [[ -n "$model" ]]; then
  model_segment="${cyan}🤖 ${model}${reset}"
  if [[ -n "$effort_level" ]]; then
    model_segment+="${minor_separator}${muted}${effort_level}${reset}"
  fi
  identity_segments+=("$model_segment")
elif [[ -n "$effort_level" ]]; then
  identity_segments+=("${muted}🤖 ${effort_level} effort${reset}")
fi
# Branch joins the directory for the same reason effort joins the model: both
# answer "where am I", so they read as one group.
if [[ -n "$current_directory" ]]; then
  # In the home directory the basename is the account name, which reads as a
  # project that does not exist; the shell's own shorthand is clearer.
  if [[ "${current_directory%/}" == "${HOME%/}" ]]; then
    directory_label="~"
  else
    directory_label="$(basename "$current_directory")"
  fi
  directory_segment="${blue}📁 ${directory_label}${reset}"
  git_state="$(git_summary "$current_directory")"
  if [[ -n "$git_state" ]]; then
    directory_segment+="${minor_separator}${magenta}🌿 ${git_state}${reset}"
  fi
  identity_segments+=("$directory_segment")
fi

# The session name distinguishes concurrent terminals, which the project name
# cannot when several sessions sit in the same repository.
if [[ -n "$session_name" ]]; then
  identity_segments+=("${muted}🔖 ${session_name}${reset}")
fi

# Line two is session state: what this conversation has consumed so far.
meter_segments=()
if [[ -n "$used_percentage" ]]; then
  meter_segments+=("$(usage_color "$used_percentage")🧠 ${used_percentage}% of context${reset}")
else
  # Null until the first API response of a session, and again after /compact.
  # A placeholder keeps this row on screen so the status line does not change
  # height once the first response lands.
  meter_segments+=("${muted}🧠 context —${reset}")
fi
if [[ -n "$session_cost" ]]; then
  meter_segments+=("$(printf '%s💵 $%.2f%s' "$yellow" "$session_cost" "$reset")")
fi

# Line three is account state, which outlives this session. It earns its own row
# because both windows carrying a reset time overflows a shared line and the
# terminal truncates the tail.
limit_values=()
if [[ -n "$five_hour_usage" ]]; then
  limit_values+=("$(limit_value "5h" "$five_hour_usage" "$five_hour_reset")")
fi
if [[ -n "$seven_day_usage" ]]; then
  limit_values+=("$(limit_value "7d" "$seven_day_usage" "$seven_day_reset")")
fi
# Each row is emitted only when it has content, so no blank row is ever printed.
if ((${#identity_segments[@]} > 0)); then
  join_segments "$major_separator" "${identity_segments[@]}"
  printf '\n'
fi
if ((${#meter_segments[@]} > 0)); then
  join_segments "$major_separator" "${meter_segments[@]}"
  printf '\n'
fi
if ((${#limit_values[@]} > 0)); then
  printf '%s ' "${muted}⏳ limits${reset}"
  join_segments "$minor_separator" "${limit_values[@]}"
  printf '\n'
fi
