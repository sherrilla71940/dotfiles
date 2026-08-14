#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
model="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
# Absent on models without a reasoning effort parameter; tracks /effort changes
# made mid-session.
effort_level="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
current_directory="$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')"
used_percentage="$(printf '%s' "$input" | jq -r 'if .context_window.used_percentage == null then empty else (.context_window.used_percentage | floor | tostring) end')"
# Client-side estimate only; resets to 0 when /clear starts a new session.
session_cost="$(printf '%s' "$input" | jq -r 'if (.cost.total_cost_usd // 0) > 0 then (.cost.total_cost_usd | tostring) else empty end')"
# Rate limits are present only for Claude.ai Pro/Max sessions, and each window
# can be absent independently, so both are treated as optional.
five_hour_usage="$(printf '%s' "$input" | jq -r 'if .rate_limits.five_hour.used_percentage == null then empty else (.rate_limits.five_hour.used_percentage | floor | tostring) end')"
seven_day_usage="$(printf '%s' "$input" | jq -r 'if .rate_limits.seven_day.used_percentage == null then empty else (.rate_limits.seven_day.used_percentage | floor | tostring) end')"

# Basic ANSI codes only, so the terminal's own theme decides the exact hues.
dim=$'\033[90m'
cyan=$'\033[36m'
blue=$'\033[94m'
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
    model_segment+="${minor_separator}${dim}${effort_level}${reset}"
  fi
  identity_segments+=("$model_segment")
elif [[ -n "$effort_level" ]]; then
  identity_segments+=("${dim}🤖 ${effort_level} effort${reset}")
fi
if [[ -n "$current_directory" ]]; then
  identity_segments+=("${blue}📁 $(basename "$current_directory")${reset}")
fi

# Line two is everything that moves while you work.
meter_segments=()
if [[ -n "$used_percentage" ]]; then
  meter_segments+=("$(usage_color "$used_percentage")🧠 ${used_percentage}% of context${reset}")
fi
if [[ -n "$session_cost" ]]; then
  meter_segments+=("$(printf '%s💰 $%.2f%s' "$yellow" "$session_cost" "$reset")")
fi

# Both windows share one labelled segment so the numbers read as a pair rather
# than as two unrelated percentages.
limit_values=()
if [[ -n "$five_hour_usage" ]]; then
  limit_values+=("$(usage_color "$five_hour_usage")5h ${five_hour_usage}%${reset}")
fi
if [[ -n "$seven_day_usage" ]]; then
  limit_values+=("$(usage_color "$seven_day_usage")7d ${seven_day_usage}%${reset}")
fi
if ((${#limit_values[@]} > 0)); then
  meter_segments+=("${dim}⏳ limits${reset} $(join_segments "$minor_separator" "${limit_values[@]}")")
fi

# Each row is emitted only when it has content, so an early session shows one
# line instead of a blank row.
if ((${#identity_segments[@]} > 0)); then
  join_segments "$major_separator" "${identity_segments[@]}"
  printf '\n'
fi
if ((${#meter_segments[@]} > 0)); then
  join_segments "$major_separator" "${meter_segments[@]}"
  printf '\n'
fi
