#!/bin/bash
input=$(cat)

extract() { echo "$input" | grep -o "\"$1\":[^,}]*" | head -1 | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/'; }

MODEL=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | cut -d'"' -f4)
DIR=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | cut -d'"' -f4)
PCT=$(echo "$input" | grep -o '"used_percentage":[0-9.]*' | head -1 | cut -d: -f2 | cut -d. -f1)
COST=$(echo "$input" | grep -o '"total_cost_usd":[0-9.]*' | head -1 | cut -d: -f2)
DURATION_MS=$(echo "$input" | grep -o '"total_duration_ms":[0-9]*' | head -1 | cut -d: -f2)

PCT=${PCT:-0}
COST=${COST:-0}
DURATION_MS=${DURATION_MS:-0}

CYAN='\033[36m'; YELLOW='\033[33m'; RED='\033[31m'; GREEN='\033[32m'; RESET='\033[0m'

if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

COST_FMT=$(printf '$%.2f' "$COST")
echo -e "${CYAN}[${MODEL:-unknown}]${RESET} 📁 ${DIR##*/}${BRANCH}"
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"
