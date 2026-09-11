#!/usr/bin/env bash
# Stage one continuity fixture in a throwaway repository and print how to run it.
#
# Never stage a case in this repository. 03 replaces state and 04 is built to tempt a
# session into destroying it, and both would do that to the real tree.
#
# A case is a directory holding prompt.txt, expected.md, and optionally:
#
#   state.md   fixture continuity state, copied into .project-continuity/. Absent for a
#              case that tests what happens when no continuity exists.
#   setup.sh   repository setup, run inside the throwaway repo. Replaces the default
#              alignment below, for a case that needs a particular shape.
#
# By default the recorded branch, HEAD and working-tree path are rewritten to match the
# throwaway repository. Without that the Stop hook reports drift on every case, and the
# session is then reacting to a drift notice rather than to the situation under test.
set -euo pipefail

case_dir="${1:-}"
if [[ -z "$case_dir" || ! -f "$case_dir/prompt.txt" ]]; then
  printf 'usage: %s <fixture-case-directory>\n' "$0" >&2
  exit 2
fi
case_dir="$(cd "$case_dir" && pwd)"

target="$(mktemp -d)"
cd "$target"
git init -q
git commit -q --allow-empty -m "init"

# Git Bash reports a POSIX path that PowerShell and cmd cannot cd into, and this is a
# manual procedure driven from a Windows terminal as often as from bash. pwd -W is
# MSYS-only, so a failure here just means there is no second path worth printing.
target_windows="$(pwd -W 2>/dev/null || true)"

if [[ -f "$case_dir/state.md" ]]; then
  mkdir -p .project-continuity
  cp "$case_dir/state.md" .project-continuity/state.md
fi

if [[ -f "$case_dir/setup.sh" ]]; then
  bash "$case_dir/setup.sh"
elif [[ -f .project-continuity/state.md ]]; then
  recorded_branch="$(sed -n 's/^- Branch: `\(.*\)`$/\1/p' .project-continuity/state.md)"
  if [[ -n "$recorded_branch" ]]; then
    git switch -q -c "$recorded_branch"
  fi
  sed -i "s|^- HEAD: \`.*\`\$|- HEAD: \`$(git rev-parse --short HEAD)\`|" .project-continuity/state.md
  sed -i "s|^- Working tree: \`.*\`\$|- Working tree: \`$target\`|" .project-continuity/state.md
fi

printf '\nStaged %s in %s\n' "$(basename "$case_dir")" "$target"
if [[ -n "$target_windows" && "$target_windows" != "$target" ]]; then
  printf 'From PowerShell or cmd: %s\n' "$target_windows"
fi
if [[ -f .project-continuity/state.md ]]; then
  printf 'Continuity state is in place.\n\n'
else
  printf 'No continuity state, by design for this case.\n\n'
fi
printf 'Paste this as the first message, verbatim, and nothing else:\n\n'
sed 's/^/    /' "$case_dir/prompt.txt"
printf '\nThen score the response against %s/expected.md.\n' "$case_dir"
printf 'Delete %s afterwards; a leftover fixture is fabricated state.\n' "${target_windows:-$target}"
