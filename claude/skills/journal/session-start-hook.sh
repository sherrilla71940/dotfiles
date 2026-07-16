#!/usr/bin/env bash
# SessionStart reminder for the journal skill.
# Prints a hint (added to session context) only when a project-journal.md
# already exists for the current working directory's project. Silent otherwise.

CONFIG="$HOME/.claude/skills/journal/config.json"
[ -f "$CONFIG" ] || exit 0

# Extract journalRoot from the single-key config (naive but sufficient).
JROOT=$(grep -o '"journalRoot"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" \
        | sed 's/.*:[[:space:]]*"//; s/"$//')
[ -n "$JROOT" ] || exit 0

# Collapse JSON-escaped backslashes (\\ -> \), then convert to a unix path.
JROOT=${JROOT//\\\\/\\}
if command -v cygpath >/dev/null 2>&1; then
  UROOT=$(cygpath -u "$JROOT")
else
  UROOT="$JROOT"
fi

# Project = git repo name, or cwd basename as fallback.
PROJ=$(git rev-parse --show-toplevel 2>/dev/null | xargs -r basename)
[ -n "$PROJ" ] || PROJ=$(basename "$PWD")

JFILE="$UROOT/$PROJ/logs/project-journal.md"
if [ -f "$JFILE" ]; then
  COUNT=$(grep -c '^## [0-9]' "$JFILE" 2>/dev/null)

  # Drift check: are there code commits after the newest journal entry's day?
  LAST_DATE=$(grep -m1 -oE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$JFILE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  BEHIND=0
  if [ -n "$LAST_DATE" ]; then
    # Count commits strictly after that day, so same-day journaled commits don't false-positive.
    BEHIND=$(git log --since="$LAST_DATE 23:59:59" --oneline 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null; then
    echo "📓⚠️ Journal for '$PROJ' looks BEHIND: ${BEHIND} commit(s) in the code since the last entry (${LAST_DATE}) — it may be missing recent work. Run /journal read (Claude will offer a catch-up) or /journal write. And if this session does more journal-worthy work, Claude should proactively offer /journal write before wrapping up, while the reasoning is fresh."
  else
    echo "📓 Journal exists for '$PROJ' (${COUNT:-0} entries), up to date. /journal list to see titles, /journal read to load context. If this session does journal-worthy work (decisions, corrections, discoveries), Claude should proactively offer /journal write before wrapping up, while the reasoning is fresh."
  fi
fi
exit 0
