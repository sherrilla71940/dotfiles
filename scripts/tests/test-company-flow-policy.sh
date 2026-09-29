#!/usr/bin/env bash
# Verify the profile-rendered company-flow hook and its explicit local exceptions.
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
hook="$repository_root/home/.chezmoitemplates/git-hooks/company-flow-pre-push.sh"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT

fail() {
  printf 'company-flow policy tests: %s\n' "$1" >&2
  exit 1
}

assert_success() {
  local label="$1" policy="$2" branch="$3" state="${4:-}"
  local repo="$work_directory/$label"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  git -C "$repo" config branch.policy "$policy"
  if [[ -n "$state" ]]; then
    mkdir -p "$repo/.task-continuity"
    printf '%s\n' "$state" > "$repo/.task-continuity/state.md"
  fi
  printf 'refs/heads/%s %s refs/heads/%s %s\n' "$branch" \
    1111111111111111111111111111111111111111 "$branch" \
    0000000000000000000000000000000000000000 |
    (cd "$repo" && bash "$hook") >/dev/null 2>&1 ||
    fail "$label should have been accepted"
}

assert_failure() {
  local label="$1" policy="$2" branch="$3"
  local repo="$work_directory/$label"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  git -C "$repo" config branch.policy "$policy"
  if printf 'refs/heads/%s %s refs/heads/%s %s\n' "$branch" \
      1111111111111111111111111111111111111111 "$branch" \
      0000000000000000000000000000000000000000 |
      (cd "$repo" && bash "$hook") >/dev/null 2>&1; then
    fail "$label should have been rejected"
  fi
}

bash -n "$hook"
assert_failure non_flow company-flow feat/legacy-task
assert_success valid_flow company-flow flow/123-example-task
assert_success personal_exception personal feat/legacy-task
assert_success project_exception project-exception feat/legacy-task
assert_failure invalid_policy unsupported feat/legacy-task
assert_success recorded_bypass company-flow feat/legacy-task $'Branch: feat/legacy-task\nBranch policy: company-flow-bypassed\nPolicy bypass: --force'

push_option_repo="$work_directory/push-option"
mkdir -p "$push_option_repo"
git -C "$push_option_repo" init -q
git -C "$push_option_repo" config user.email test@example.invalid
git -C "$push_option_repo" config user.name test
git -C "$push_option_repo" config branch.policy company-flow
if ! printf 'refs/heads/feat/legacy-task %s refs/heads/feat/legacy-task %s\n' \
    1111111111111111111111111111111111111111 \
    0000000000000000000000000000000000000000 |
    (cd "$push_option_repo" &&
      GIT_PUSH_OPTION_COUNT=1 \
      GIT_PUSH_OPTION_0='company-flow-bypass=--force' \
      bash "$hook") >/dev/null 2>&1; then
  fail 'explicit push option bypass should have been accepted'
fi

printf 'company-flow policy tests: default, exceptions, and explicit bypass OK\n'
