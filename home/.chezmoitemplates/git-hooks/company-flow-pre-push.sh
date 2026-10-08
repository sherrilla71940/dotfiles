#!/usr/bin/env bash
# Defense-in-depth branch-policy check for repositories using the global Git hook path.
# This hook catches direct pushes that would otherwise bypass the company-flow branch rule. A
# repository-local branch.policy value of personal or project-exception is an explicit exception.
set -euo pipefail

repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo" ]] || exit 0

local_policy="$(git -C "$repo" config --get branch.policy 2>/dev/null || true)"
case "$local_policy" in
  personal|project-exception)
    exit 0
    ;;
  ""|company-flow)
    ;;
  *)
    printf 'company-flow policy: unknown local branch.policy %q; refusing to push.\n' "$local_policy" >&2
    exit 1
    ;;
esac

is_flow_branch() {
  [[ "$1" =~ ^flow/[0-9]{1,9}(-[A-Za-z0-9_-]+)?$ ]]
}

while read -r local_ref local_oid remote_ref remote_oid; do
  [[ "$local_oid" =~ ^0{40}$ ]] && continue
  [[ "$local_ref" == refs/heads/* ]] || continue

  branch="${local_ref#refs/heads/}"
  is_flow_branch "$branch" && continue

  printf 'company-flow policy: refusing non-flow branch %s.\n' "$branch" >&2
  printf 'For a project-wide exception, document branch.policy=project-exception in this repository.\n' >&2
  printf "For a direct emergency hook bypass, use Git's explicit --no-verify option.\n" >&2
  exit 1
done
