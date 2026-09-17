#!/usr/bin/env bash
# Report how the live ~/.claude/settings.json differs from what this repository pins.
#
# Run by hand. Deliberately NOT a chezmoi script: anything under home/.chezmoiscripts/
# runs on every `chezmoi apply`.
#
# `chezmoi diff ~/.claude/settings.json` only shows keys the repository owns, because the
# modify template leaves every other key alone. That makes a setting you changed locally and
# might want on all your machines invisible there. This script names those settings so
# promoting one into the source state is a deliberate choice rather than something you have
# to remember to look for.
set -euo pipefail

LIVE="$HOME/.claude/settings.json"
if [ ! -f "$LIVE" ]; then
  printf 'No live settings at %s. Nothing to compare.\n' "$LIVE" >&2
  exit 1
fi

PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

DURABLE_FILE="$(mktemp)"
trap 'rm -f "$DURABLE_FILE"' EXIT
chezmoi execute-template '{{ includeTemplate "claude/settings-durable.json" . }}' > "$DURABLE_FILE"

DURABLE_FILE="$DURABLE_FILE" LIVE_FILE="$LIVE" "$PY" <<'PYCODE'
import io, json, os

durable = json.load(io.open(os.environ["DURABLE_FILE"], encoding="utf-8"))
live = json.load(io.open(os.environ["LIVE_FILE"], encoding="utf-8"))

local_only = sorted(k for k in live if k not in durable)
added_under_owned = []
overridden = []

for key in sorted(durable):
    if key not in live:
        continue
    d, l = durable[key], live[key]
    if isinstance(d, dict) and isinstance(l, dict):
        added_under_owned += [(key, sub) for sub in sorted(l) if sub not in d]
    elif d != l:
        overridden.append((key, l, d))

def section(title, rows):
    print(title)
    if not rows:
        print("  (none)")
    for row in rows:
        print("  " + row)
    print()

section(
    "Yours alone - set locally, absent from the repository, never committed:",
    ["%s = %s" % (k, json.dumps(live[k])) for k in local_only],
)
section(
    "Added locally under a repository-owned key - kept by the merge, still not committed:",
    ["%s.%s" % (k, sub) for k, sub in added_under_owned],
)
section(
    "Reverted on the next apply - the repository pins a different value:",
    ["%s: live %s -> repository %s" % (k, json.dumps(l), json.dumps(d))
     for k, l, d in overridden],
)

print("Everything above is yours, and most of it is meant to stay that way. Before")
print("promoting one into the repository, check it against the admission criterion in")
print("docs/decisions/0005-merge-durable-claude-settings-as-json.md: needed on every")
print("machine, stable enough not to change mid-session, and not written by the")
print("application. theme, verbose, tui, permissions and enabledPlugins were released")
print("deliberately, so re-pinning one reverses that decision.")
print()
print("Plugins are the exception that does not belong here at all: add them to the")
print("claude plugin install list in scripts/bootstrap/bootstrap-* instead.")
print()
print("Otherwise copy the value into")
print("home/.chezmoitemplates/claude/settings-durable.json, then run chezmoi apply.")
PYCODE
