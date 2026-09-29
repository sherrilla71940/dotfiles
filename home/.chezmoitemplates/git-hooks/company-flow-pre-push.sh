#!/usr/bin/env bash
# Defense-in-depth branch-policy check for repositories using the global Git hook path.
# The managed workflow remains the authoritative resolver; this hook catches direct pushes that
# would otherwise bypass the workflow. A repository-local branch.policy value of personal or
# project-exception is an explicit local exception.
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

has_recorded_workflow_bypass() {
  local state="$repo/.task-continuity/state.md"
  [[ -f "$state" ]] || return 1
  [[ "$(sed -n 's/^Branch: //p' "$state" | head -n 1)" == "$1" ]] || return 1
  grep -Fqx 'Branch policy: company-flow-bypassed' "$state" || return 1
  grep -Fqx 'Policy bypass: --force' "$state" || return 1
}

while read -r local_ref local_oid remote_ref remote_oid; do
  [[ "$local_oid" =~ ^0{40}$ ]] && continue
  [[ "$local_ref" == refs/heads/* ]] || continue

  branch="${local_ref#refs/heads/}"
  is_flow_branch "$branch" && continue

  if has_recorded_workflow_bypass "$branch"; then
    printf 'company-flow policy: explicit --force bypass accepted for %s.\n' "$branch" >&2
    continue
  fi

  printf 'company-flow policy: refusing non-flow branch %s.\n' "$branch" >&2
  printf 'Use run-task-end-to-end with --force and an explicit branch=... only for a deliberate exception.\n' >&2
  printf "For a direct emergency hook bypass, use Git's explicit --no-verify option.\n" >&2
  exit 1
done
