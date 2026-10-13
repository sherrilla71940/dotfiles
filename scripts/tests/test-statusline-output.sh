#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
source "$repository_root/scripts/git-hooks/statusline-output.sh"

statusline_output_has_content 'Opus 5 · high' || {
  printf 'test-statusline-output: nonempty output was rejected.\n' >&2
  exit 1
}

for output in '' '   ' $'\t\n'; do
  if statusline_output_has_content "$output"; then
    printf 'test-statusline-output: empty output was accepted.\n' >&2
    exit 1
  fi
done

printf 'test-statusline-output: visible output is required.\n'
