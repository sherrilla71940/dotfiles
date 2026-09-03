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
# Rate limits are present only for Claude.ai Pro/Max sessions, and each window
# can be absent independently, so both are treated as optional.
five_hour_usage="$(printf '%s' "$input" | jq -r 'if .rate_limits.five_hour.used_percentage == null then empty else (.rate_limits.five_hour.used_percentage | floor | tostring) end')"
seven_day_usage="$(printf '%s' "$input" | jq -r 'if .rate_limits.seven_day.used_percentage == null then empty else (.rate_limits.seven_day.used_percentage | floor | tostring) end')"
# Floored like the percentages above: a fractional epoch would reach bash
# arithmetic as 1786943229.5 and raise a syntax error on every render.
five_hour_reset="$(printf '%s' "$input" | jq -r 'if .rate_limits.five_hour.resets_at == null then empty else (.rate_limits.five_hour.resets_at | floor | tostring) end')"
seven_day_reset="$(printf '%s' "$input" | jq -r 'if .rate_limits.seven_day.resets_at == null then empty else (.rate_limits.seven_day.resets_at | floor | tostring) end')"

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
bright_cyan=$'\033[96m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'
reset=$'\033[0m'

# Claude Code exports the terminal size before running this script, because output is
# captured rather than attached to the terminal and the usual width queries cannot see it.
# The fallback matters: an unset or non-numeric value must not make every session look narrow.
terminal_columns="${COLUMNS:-80}"
if [[ ! "$terminal_columns" =~ ^[0-9]+$ ]] || ((terminal_columns <= 0)); then
  terminal_columns=80
fi

# Below 90 columns, compact labels leave room for both rate-limit windows. A
# vertical separator remains readable at every width, while the long prose is
# replaced with the shorter form only when it saves meaningful space.
if ((terminal_columns < 90)); then
  major_separator_plain=" │ "
  major_separator="${dim}${major_separator_plain}${reset}"
  context_label="ctx"
  reset_prefix="→"
  limits_label="⏳"
else
  major_separator_plain="  │  "
  major_separator="${dim}${major_separator_plain}${reset}"
  context_label="of context"
  reset_prefix=" resets "
  limits_label="⏳ limits"
fi

minor_separator_plain=" · "
minor_separator="${dim}${minor_separator_plain}${reset}"

# Statusline fields are plain text when measured. ASCII characters occupy one
# cell; CJK and emoji conservatively occupy two. The specific punctuation and
# UI glyphs used here that occupy one cell are listed in the width condition.
# This keeps width decisions local and fast enough for a render on every event.
if ((terminal_columns < 90)); then
  # Add one cell before the compact reset arrow so both limit groups have the
  # same visual spacing as the full reset labels.
  reset_prefix=" ${reset_prefix}"
fi

visible_width() {
  local text="$1" width=0 index character code_point
  if [[ "$text" == *$'\033'* ]]; then
    text="$(printf '%s' "$text" | sed $'s/\033\\[[0-9;]*[ -/]*[@-~]//g')"
  fi
  for ((index = 0; index < ${#text}; index++)); do
    character="${text:index:1}"
    printf -v code_point '%d' "'$character"
    if ((code_point >= 0xD800 && code_point <= 0xDBFF && index + 1 < ${#text})); then
      index=$((index + 1))
      width=$((width + 2))
    elif ((code_point < 128)); then
      width=$((width + 1))
    elif ((code_point == 183 || code_point == 8212 || code_point == 8230 ||
           (code_point >= 8592 && code_point <= 8595) || code_point == 9203 ||
           code_point == 9474 || code_point == 9670)); then
      # These punctuation and UI glyphs occupy one cell in the terminals
      # supported by the PowerShell copy; emoji and CJK remain two cells below.
      width=$((width + 1))
    else
      width=$((width + 2))
    fi
  done
  printf '%s' "$width"
}

text_prefix_by_width() {
  local text="$1" max_width="$2" result="" index character character_width code_point character_length
  if ((max_width <= 0)); then
    return 0
  fi
  if [[ "$text" == *[^$'\001'-$'\177']* ]]; then
    :
  else
    printf '%s' "${text:0:max_width}"
    return 0
  fi
  for ((index = 0; index < ${#text}; index++)); do
    character="${text:index:1}"
    printf -v code_point '%d' "'$character"
    character_length=1
    if ((code_point >= 0xD800 && code_point <= 0xDBFF && index + 1 < ${#text})); then
      character="${text:index:2}"
      character_length=2
    fi
    character_width="$(visible_width "$character")"
    if (( $(visible_width "$result") + character_width > max_width )); then
      break
    fi
    result+="$character"
    index=$((index + character_length - 1))
  done
  printf '%s' "$result"
}

text_suffix_by_width() {
  local text="$1" max_width="$2" result="" index character character_width code_point character_start character_length
  if ((max_width <= 0)); then
    return 0
  fi
  if [[ "$text" == *[^$'\001'-$'\177']* ]]; then
    :
  else
    local start_index=$(( ${#text} - max_width ))
    if ((start_index < 0)); then
      start_index=0
    fi
    printf '%s' "${text:start_index}"
    return 0
  fi
  for ((index = ${#text} - 1; index >= 0; index--)); do
    character="${text:index:1}"
    printf -v code_point '%d' "'$character"
    character_start=$index
    character_length=1
    if ((code_point >= 0xDC00 && code_point <= 0xDFFF && index > 0)); then
      character_start=$((index - 1))
      character="${text:character_start:2}"
      character_length=2
    fi
    character_width="$(visible_width "$character")"
    if (( $(visible_width "$result") + character_width > max_width )); then
      break
    fi
    result="$character$result"
    index=$((index - character_length + 1))
  done
  printf '%s' "$result"
}

truncate_middle() {
  local text="$1" max_width="$2" left_width right_width left right
  if ((max_width <= 0)); then
    return 0
  fi
  if (( $(visible_width "$text") <= max_width )); then
    printf '%s' "$text"
    return 0
  fi
  if ((max_width == 1)); then
    printf '…'
    return 0
  fi
  left_width=$(( (max_width - 1) / 2 ))
  right_width=$(( max_width - 1 - left_width ))
  left="$(text_prefix_by_width "$text" "$left_width")"
  right="$(text_suffix_by_width "$text" "$right_width")"
  printf '%s…%s' "$left" "$right"
}

# The session label is information, not decoration. Wrap at words and hard-split
# only an individual overlong token so the complete label remains available.
wrapped_lines=()
wrap_text() {
  local text="$1" max_width="$2" word piece candidate current=""
  wrapped_lines=()
  read -r -a words <<<"$text"
  for word in "${words[@]}"; do
    if [[ -n "$current" ]] && (( $(visible_width "$word") > max_width )); then
      wrapped_lines+=("$current")
      current=""
    fi
    while [[ -n "$word" ]] && (( $(visible_width "$word") > max_width )); do
      piece="$(text_prefix_by_width "$word" "$max_width")"
      if [[ -z "$piece" ]]; then
        piece="${word:0:1}"
      fi
      wrapped_lines+=("$piece")
      word="${word:${#piece}}"
    done
    if [[ -z "$word" ]]; then
      continue
    fi
    if [[ -z "$current" ]]; then
      current="$word"
    else
      candidate="$current $word"
      if (( $(visible_width "$candidate") > max_width )); then
        wrapped_lines+=("$current")
        current="$word"
      else
        current="$candidate"
      fi
    fi
  done
  if [[ -n "$current" ]]; then
    wrapped_lines+=("$current")
  fi
}

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
# necessarily the project. Normal untracked files are included because newly
# created artifacts are still work-tree changes worth showing.
git_branch=""
git_object_id=""
git_ahead_count=0
git_behind_count=0
git_staged_count=0
git_modified_count=0
git_untracked_count=0
git_summary() {
  local directory="$1"
  git_branch=""
  git_object_id=""
  git_ahead_count=0
  git_behind_count=0
  git_staged_count=0
  git_modified_count=0
  git_untracked_count=0
  if [[ -z "$directory" ]] || ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  local status_output line states
  status_output="$(git -C "$directory" status --porcelain=v2 --branch --untracked-files=normal 2>/dev/null || true)"
  if [[ -z "$status_output" ]]; then
    return 0
  fi

  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*) git_branch="${line#\# branch.head }" ;;
      '# branch.oid '*) git_object_id="${line#\# branch.oid }" ;;
      '# branch.ab '*)
        read -r ahead behind _ <<<"${line#\# branch.ab }"
        if [[ "$ahead" =~ ^\+([0-9]+)$ ]]; then
          git_ahead_count="${BASH_REMATCH[1]}"
        fi
        if [[ "$behind" =~ ^-([0-9]+)$ ]]; then
          git_behind_count="${BASH_REMATCH[1]}"
        fi
        ;;
      \?*) git_untracked_count=$((git_untracked_count + 1)) ;;
      # Changed, renamed and unmerged entries all carry the two state columns in
      # the same position: the index state then the work-tree state.
      [12u]' '*)
        states="${line:2:2}"
        case "$states" in
          [!.]*) git_staged_count=$((git_staged_count + 1)) ;;
        esac
        case "$states" in
          ?[!.]) git_modified_count=$((git_modified_count + 1)) ;;
        esac
        ;;
    esac
  done <<<"$status_output"

  if [[ "$git_branch" == "(detached)" ]]; then
    git_branch="(${git_object_id:0:7})"
  fi
}

git_change_suffix() {
  local suffix=""
  if ((git_staged_count > 0)); then
    suffix+=" +${git_staged_count}"
  fi
  if ((git_modified_count > 0)); then
    suffix+=" ~${git_modified_count}"
  fi
  if ((git_untracked_count > 0)); then
    suffix+=" ?${git_untracked_count}"
  fi
  printf '%s' "$suffix"
}

git_tracking_suffix() {
  local suffix=""
  if ((git_ahead_count > 0)); then
    suffix+=" ↑${git_ahead_count}"
  fi
  if ((git_behind_count > 0)); then
    suffix+=" ↓${git_behind_count}"
  fi
  printf '%s' "$suffix"
}

git_label_plain_value=""
git_label_colored_value=""
build_git_label() {
  local max_width="$1" prefix="🌿 " tracking suffix branch_width branch_display
  tracking="$(git_tracking_suffix)"
  suffix="$(git_change_suffix)"
  branch_width=$((max_width - $(visible_width "$prefix") - $(visible_width "$tracking") - $(visible_width "$suffix")))
  if ((branch_width < 1)); then
    branch_width=1
  fi
  branch_display="$(truncate_middle "$git_branch" "$branch_width")"
  git_label_plain_value="${prefix}${branch_display}${tracking}${suffix}"
  git_label_colored_value="${magenta}${prefix}${branch_display}${reset}"
  if ((git_ahead_count > 0)); then
    git_label_colored_value+="${cyan} ↑${git_ahead_count}${reset}"
  fi
  if ((git_behind_count > 0)); then
    git_label_colored_value+="${blue} ↓${git_behind_count}${reset}"
  fi
  if ((git_staged_count > 0)); then
    git_label_colored_value+="${green} +${git_staged_count}${reset}"
  fi
  if ((git_modified_count > 0)); then
    git_label_colored_value+="${yellow} ~${git_modified_count}${reset}"
  fi
  if ((git_untracked_count > 0)); then
    git_label_colored_value+="${red} ?${git_untracked_count}${reset}"
  fi
}

directory_plain_value=""
directory_colored_value=""
build_directory_label() {
  local directory_name="$1" max_width="$2" prefix="📁 " directory_width directory_display
  directory_width=$((max_width - $(visible_width "$prefix")))
  if ((directory_width < 1)); then
    directory_width=1
  fi
  directory_display="$(truncate_middle "$directory_name" "$directory_width")"
  directory_plain_value="${prefix}${directory_display}"
  directory_colored_value="${blue}${directory_plain_value}${reset}"
}

# Git Bash can receive a Windows drive path from a rendered fixture while HOME
# uses the POSIX form, so normalize only the display comparison. Keep the
# original path for git, which accepts the Windows form here.
normalize_display_path() {
  local path="$1" drive
  path="${path//\\//}"
  if [[ "$path" =~ ^([A-Za-z]):/(.*)$ ]]; then
    drive="${BASH_REMATCH[1],,}"
    path="/${drive}/${BASH_REMATCH[2]}"
  fi
  printf '%s' "${path%/}"
}

# An absolute wall-clock time rather than a countdown: this script runs on
# events, and those go quiet while the session is idle, so a countdown would
# silently drift while a clock time stays correct however stale the render is.
reset_label() {
  local epoch="$1" now format='+%H:%M'
  now="$(date +%s)"
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
limit_plain_value() {
  local label="$1" percentage="$2" reset_epoch="$3" text moment
  text="${label} ${percentage}%"
  if [[ -n "$reset_epoch" ]]; then
    moment="$(reset_label "$reset_epoch")"
    if [[ -n "$moment" ]]; then
      text+="${reset_prefix}${moment}"
    fi
  fi
  printf '%s' "$text"
}

limit_value() {
  local label="$1" percentage="$2" reset_epoch="$3" text moment
  text="$(usage_color "$percentage")${label} ${percentage}%${reset}"
  if [[ -n "$reset_epoch" ]]; then
    moment="$(reset_label "$reset_epoch")"
    if [[ -n "$moment" ]]; then
      text+="${muted}${reset_prefix}${moment}${reset}"
    fi
  fi
  printf '%s' "$text"
}

join_values() {
  local separator="$1"
  shift
  local result="" value
  for value in "$@"; do
    if [[ -n "$result" ]]; then
      result+="$separator"
    fi
    result+="$value"
  done
  printf '%s' "$result"
}

model_plain=""
model_colored=""
if [[ -n "$model" ]]; then
  model_plain="🤖 ${model}"
  model_colored="${cyan}${model_plain}${reset}"
  if [[ -n "$effort_level" ]]; then
    model_plain+="${minor_separator_plain}${effort_level}"
    model_colored+="${minor_separator}${muted}${effort_level}${reset}"
  fi
elif [[ -n "$effort_level" ]]; then
  model_plain="🤖 ${effort_level} effort"
  model_colored="${muted}${model_plain}${reset}"
fi

identity_lines=()
if [[ -n "$model_plain" ]]; then
  identity_lines+=("$model_colored")
fi

if [[ -n "$session_name" ]]; then
  label_prefix_plain="◆ "
  label_inline_plain="${label_prefix_plain}${session_name}"
  base_width="$(visible_width "$model_plain")"
  inline_width=$((base_width + $(visible_width "$major_separator_plain") + $(visible_width "$label_inline_plain")))
  if ((base_width > 0 && inline_width <= terminal_columns)); then
    identity_lines=("${model_colored}${major_separator}${bright_cyan}◆${reset} ${muted}${session_name}${reset}")
  else
    label_width=$((terminal_columns - $(visible_width "$label_prefix_plain")))
    if ((label_width < 1)); then
      label_width=1
    fi
    wrap_text "$session_name" "$label_width"
    for index in "${!wrapped_lines[@]}"; do
      if ((index == 0)); then
        identity_lines+=("${bright_cyan}◆${reset} ${muted}${wrapped_lines[index]}${reset}")
      else
        identity_lines+=("  ${muted}${wrapped_lines[index]}${reset}")
      fi
    done
  fi
fi

directory_lines=()
if [[ -n "$current_directory" ]]; then
  # Use the shell's home-relative shorthand so nested projects remain
  # distinguishable instead of collapsing to the leaf directory name.
  trimmed_directory="${current_directory%/}"
  display_directory="$(normalize_display_path "$trimmed_directory")"
  home_directory="$(normalize_display_path "${HOME%/}")"
  if [[ "$display_directory" == "$home_directory" ]]; then
    directory_label="~"
  elif [[ "$display_directory" == "$home_directory/"* ]]; then
    relative_directory="${display_directory#"$home_directory/"}"
    directory_label="~/$relative_directory"
  else
    directory_label="$display_directory"
  fi

  git_summary "$current_directory"
  build_directory_label "$directory_label" "$terminal_columns"
  if [[ -n "$git_branch" ]]; then
    build_git_label "$terminal_columns"
    combined_width=$(( $(visible_width "$directory_plain_value") + $(visible_width "$major_separator_plain") + $(visible_width "$git_label_plain_value") ))
    combined=""
    if ((combined_width <= terminal_columns)); then
      combined="${directory_colored_value}${major_separator}${git_label_colored_value}"
    fi

    if [[ -n "$combined" ]]; then
      directory_lines+=("$combined")
    else
      build_directory_label "$directory_label" "$terminal_columns"
      directory_lines+=("$directory_colored_value")
      build_git_label "$terminal_columns"
      directory_lines+=("$git_label_colored_value")
    fi
  else
    directory_lines+=("$directory_colored_value")
  fi
fi

detail_lines=()
if [[ -n "$used_percentage" ]]; then
  context_plain="🧠 ${used_percentage}% ${context_label}"
  context_colored="$(usage_color "$used_percentage")${context_plain}${reset}"
else
  context_plain="🧠 ${context_label} —"
  context_colored="${muted}${context_plain}${reset}"
fi

limit_plain_values=()
limit_colored_values=()
if [[ -n "$five_hour_usage" ]]; then
  limit_plain_values+=("$(limit_plain_value "5h" "$five_hour_usage" "$five_hour_reset")")
  limit_colored_values+=("$(limit_value "5h" "$five_hour_usage" "$five_hour_reset")")
fi
if [[ -n "$seven_day_usage" ]]; then
  limit_plain_values+=("$(limit_plain_value "7d" "$seven_day_usage" "$seven_day_reset")")
  limit_colored_values+=("$(limit_value "7d" "$seven_day_usage" "$seven_day_reset")")
fi

if ((${#limit_plain_values[@]} == 0)); then
  detail_lines+=("$context_colored")
else
  limit_plain_joined="$(join_values "$minor_separator_plain" "${limit_plain_values[@]}")"
  limit_colored_joined="$(join_values "$minor_separator" "${limit_colored_values[@]}")"
  limit_header_plain="${limits_label} "
  limit_header_colored="${muted}${limits_label}${reset} "
  detail_plain="${context_plain}${major_separator_plain}${limit_header_plain}${limit_plain_joined}"
  if (( $(visible_width "$detail_plain") <= terminal_columns )); then
    detail_lines+=("${context_colored}${major_separator}${limit_header_colored}${limit_colored_joined}")
  else
    first_plain="${context_plain}${major_separator_plain}${limit_header_plain}${limit_plain_values[0]}"
    if (( $(visible_width "$first_plain") <= terminal_columns )); then
      detail_lines+=("${context_colored}${major_separator}${limit_header_colored}${limit_colored_values[0]}")
    else
      detail_lines+=("$context_colored")
      detail_lines+=("  ${limit_header_colored}${limit_colored_values[0]}")
    fi
    for index in "${!limit_colored_values[@]}"; do
      if ((index > 0)); then
        detail_lines+=("  ${limit_colored_values[index]}")
      fi
    done
  fi
fi

# The output is intentionally variable-height: wrapping preserves information,
# while terminal auto-wrap would split separators and make fields ambiguous.
for line in "${identity_lines[@]}"; do printf '%s\n' "$line"; done
for line in "${directory_lines[@]}"; do printf '%s\n' "$line"; done
for line in "${detail_lines[@]}"; do printf '%s\n' "$line"; done
