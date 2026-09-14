#!/usr/bin/env bash
# Report which parts of the managed Claude Code configuration are actually being used.
#
# Run by hand. Deliberately NOT a chezmoi script: anything under home/.chezmoiscripts/
# runs on every `chezmoi apply`.
#
# The repository can prove a skill renders correctly - the pre-commit hook checks file-count
# parity, symlink integrity and rule-body divergence. It cannot tell whether anything ever
# invoked one. A skill that never fires still costs context in every session, and a rule that
# is silently ignored looks identical to a rule that is obeyed. This script reads the local
# session transcripts and answers the question the source state cannot: what got used.
#
# It reads only ~/.claude/projects/**/*.jsonl and this repository's source state. It writes
# nothing, sends nothing, and prints no message content - only counts of skill and command
# names.
#
#   scripts/diagnostics/claude-config-usage.sh            # every transcript on this machine
#   scripts/diagnostics/claude-config-usage.sh --days 30  # only the last 30 days
set -euo pipefail

DAYS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --days)
      DAYS="${2:-}"
      [ -n "$DAYS" ] || { printf '--days needs a number.\n' >&2; exit 2; }
      shift 2
      ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

PROJECTS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
if [ ! -d "$PROJECTS" ]; then
  printf 'No transcripts at %s. Nothing to report.\n' "$PROJECTS" >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"

PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

PROJECTS="$PROJECTS" REPO="$REPO" DAYS="$DAYS" "$PY" <<'PYCODE'
import io, json, os, re, sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

projects = os.environ["PROJECTS"]
repo = os.environ["REPO"]
days = os.environ.get("DAYS") or ""

cutoff = None
if days:
    cutoff = datetime.now(timezone.utc) - timedelta(days=int(days))

COMMAND = re.compile(r"<command-name>/?([A-Za-z0-9:_-]+)</command-name>")
# A typed command carries its arguments in a sibling tag, not in the Skill tool input, so a
# report that reads only the tool call undercounts flags such as `zhtw`.
COMMAND_ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)


def managed_skills():
    """Skill names this repository owns, from the source state rather than the live tree."""
    names = set()
    shared = os.path.join(repo, "home", "dot_agents", "skills")
    if os.path.isdir(shared):
        for entry in os.listdir(shared):
            if os.path.isfile(os.path.join(shared, entry, "SKILL.md")):
                names.add(entry)
    claude_only = os.path.join(repo, "home", "dot_claude", "skills")
    if os.path.isdir(claude_only):
        for entry in os.listdir(claude_only):
            if os.path.isfile(os.path.join(claude_only, entry, "SKILL.md")):
                names.add(entry)
    commands = os.path.join(repo, "home", "dot_claude", "commands")
    if os.path.isdir(commands):
        for entry in os.listdir(commands):
            if entry.endswith(".md"):
                names.add(entry[:-3])
    return names


def walk(node, found):
    """Collect Skill tool calls and embedded slash-command names from one transcript line."""
    if isinstance(node, dict):
        if node.get("type") == "tool_use" and node.get("name") == "Skill":
            payload = node.get("input") or {}
            if isinstance(payload, dict) and payload.get("skill"):
                found.append(("model", str(payload["skill"]), str(payload.get("args") or "")))
        for value in node.values():
            walk(value, found)
    elif isinstance(node, list):
        for value in node:
            walk(value, found)
    elif isinstance(node, str) and "<command-name>" in node:
        names = COMMAND.findall(node)
        args = COMMAND_ARGS.findall(node)
        for index, name in enumerate(names):
            found.append(("typed", name, args[index] if index < len(args) else ""))


by_channel = defaultdict(lambda: {"typed": 0, "model": 0})
args_seen = defaultdict(list)
projects_seen = defaultdict(set)
first_ts = last_ts = None
transcripts = skipped = 0

for root, _dirs, files in os.walk(projects):
    project = os.path.basename(root)
    for name in sorted(files):
        if not name.endswith(".jsonl"):
            continue
        path = os.path.join(root, name)
        if cutoff is not None:
            mtime = datetime.fromtimestamp(os.path.getmtime(path), timezone.utc)
            if mtime < cutoff:
                skipped += 1
                continue
        transcripts += 1
        with io.open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                # Cheap prefilter: most lines carry neither marker, and parsing every line
                # of every transcript is the whole runtime.
                if '"Skill"' not in line and "<command-name>" not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                stamp = entry.get("timestamp")
                if isinstance(stamp, str):
                    if first_ts is None or stamp < first_ts:
                        first_ts = stamp
                    if last_ts is None or stamp > last_ts:
                        last_ts = stamp
                found = []
                walk(entry, found)
                for channel, skill, args in found:
                    by_channel[skill][channel] += 1
                    projects_seen[skill].add(project)
                    if args:
                        args_seen[skill].append(args)

managed = managed_skills()
used = {name: counts for name, counts in by_channel.items()
        if counts["typed"] or counts["model"]}


def total(name):
    return by_channel[name]["typed"] + by_channel[name]["model"]


print("Transcripts read: %d%s" % (transcripts,
      "  (skipped %d outside the window)" % skipped if skipped else ""))
if first_ts and last_ts:
    # The --days filter selects files by modification time, so a kept file can still hold
    # older entries. Report the span actually counted rather than implying it equals --days.
    print("Entries counted:  %s to %s" % (first_ts[:10], last_ts[:10]))
print()

print("Managed skills that were invoked")
print("--------------------------------")
rows = sorted((n for n in used if n in managed), key=total, reverse=True)
if not rows:
    print("  (none)")
for name in rows:
    counts = by_channel[name]
    print("  %-32s %4d   typed %-4d model %-4d   %d project(s)"
          % (name, total(name), counts["typed"], counts["model"], len(projects_seen[name])))
print()

print("Managed skills never invoked")
print("----------------------------")
unused = sorted(managed - set(used))
if not unused:
    print("  (none)")
for name in unused:
    print("  %s" % name)
print()

other = sorted((n for n in used if n not in managed), key=total, reverse=True)[:15]
if other:
    print("Most-used commands and skills this repository does not manage")
    print("-------------------------------------------------------------")
    for name in other:
        print("  %-32s %4d" % (name, total(name)))
    print()

# One compliance ratio worth watching: the commit skill defaults to Traditional Chinese in
# this setup, and every zh-TW artifact is supposed to load natural-zhtw. A commit count far
# above the natural-zhtw count is a signal, not a verdict - see the caveat below.
ZHTW_ALIAS = re.compile(r"\b(zhtw|zh-tw|chinese|mandarin|chin)\b", re.I)
zhtw_commits = sum(1 for args in args_seen.get("git-commit-action", []) if ZHTW_ALIAS.search(args))
zhtw_loads = total("natural-zhtw") if "natural-zhtw" in by_channel else 0
commit_runs = total("git-commit-action") if "git-commit-action" in by_channel else 0
if commit_runs or zhtw_loads:
    print("Traditional Chinese signal")
    print("--------------------------")
    print("  git-commit-action runs        %d  (%d asked for zh-TW, counting the skill's"
          % (commit_runs, zhtw_commits))
    print("                                    documented aliases: chin, chinese, mandarin)")
    print("  natural-zhtw invocations      %d" % zhtw_loads)
    print()

print("How to read this")
print("----------------")
print("A zero is a lower bound, not proof of neglect. A skill marked")
print("user-invocable: false can only be model-invoked; one whose guidance was followed")
print("from memory without a Skill tool call is indistinguishable here from one that was")
print("ignored. Transcripts are also local to this machine and subject to the retention")
print("sweep, so an old invocation may simply be gone.")
print()
print("What a zero does justify is a question: would a real request ever match this")
print("skill's description? That is the usual reason a useful skill never fires, and")
print("the description is the cheapest thing to fix. Retiring a skill is the other")
print("honest outcome - see docs/customization-support.md for where each one lives.")
PYCODE
