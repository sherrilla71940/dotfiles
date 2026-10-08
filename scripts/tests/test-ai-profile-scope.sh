#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  chezmoi_bin="$(command -v chezmoi || true)"
  source_root="$(git rev-parse --show-toplevel)"
elif [[ "$#" -eq 2 ]]; then
  chezmoi_bin="$1"
  source_root="$2"
else
  printf 'usage: %s [<chezmoi-bin> <source-root>]\n' "$0" >&2
  exit 2
fi

[[ -n "$chezmoi_bin" ]] || {
  printf 'profile scope check: chezmoi is unavailable\n' >&2
  exit 1
}
[[ -x "$chezmoi_bin" || -f "$chezmoi_bin" ]] || {
  printf 'profile scope check: chezmoi is unavailable: %s\n' "$chezmoi_bin" >&2
  exit 1
}
[[ -d "$source_root/home/.chezmoitemplates" ]] || {
  printf 'profile scope check: source root is invalid: %s\n' "$source_root" >&2
  exit 1
}

work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
config_file="$work_directory/chezmoi.toml"
printf '[data]\n' >"$config_file"

fail() {
  printf 'profile scope check: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing rendered file: $1"
}

assert_contains() {
  local file="$1" needle="$2"
  grep -Fq -- "$needle" "$file" || fail "'$needle' not found in $file"
}

assert_not_contains() {
  local file="$1" needle="$2"
  ! grep -Fq -- "$needle" "$file" || fail "unexpected '$needle' in $file"
}

company_rule='use PascalCase for VanillaJS/VanillaTS function names and globals, overriding the shared JavaScript default'
baseline_rule='Use `camelCase` for VanillaJS/VanillaTS function names, globals, and other identifiers by default.'
classifier='classify profile applicability (`baseline`, `personal`, or `company`) separately from client reach'
source_skill_count="$(find "$source_root/home/dot_agents/skills" -type f ! -name '.*' | wc -l | tr -d ' ')"

for context in personal company; do
  override="$work_directory/$context.yaml"
  destination="$work_directory/render-$context"
  printf 'ai_context: %s\n' "$context" >"$override"
  mkdir -p "$destination"

  "$chezmoi_bin" apply \
    --config="$config_file" \
    --source="$source_root" \
    --destination="$destination" \
    --exclude=scripts \
    --override-data-file="$override" \
    --no-tty \
    --force >/dev/null

  claude_core="$destination/.claude/CLAUDE.md"
  codex_core="$destination/.codex/AGENTS.md"
  copilot_core="$destination/.copilot/instructions/core.instructions.md"
  claude_javascript="$destination/.claude/rules/javascript.md"
  copilot_javascript="$destination/.copilot/instructions/javascript.instructions.md"
  for file in "$claude_core" "$codex_core" "$copilot_core" \
    "$claude_javascript" "$copilot_javascript"; do
    assert_file "$file"
  done

  for file in "$claude_core" "$codex_core" "$copilot_core"; do
    assert_contains "$file" "$classifier"
  done

  assert_contains "$claude_javascript" "$baseline_rule"
  assert_contains "$copilot_javascript" "$baseline_rule"
  assert_not_contains "$claude_javascript" "$company_rule"
  assert_not_contains "$copilot_javascript" "$company_rule"

  if [[ "$context" == company ]]; then
    assert_contains "$claude_core" "$company_rule"
    assert_contains "$codex_core" "$company_rule"
    assert_contains "$copilot_core" "$company_rule"
    assert_not_contains "$claude_core" 'The active context is `personal`.'
  else
    assert_not_contains "$claude_core" "$company_rule"
    assert_not_contains "$codex_core" "$company_rule"
    assert_not_contains "$copilot_core" "$company_rule"
    assert_not_contains "$claude_core" 'The active context is `company`.'
  fi

  rendered_skill_count="$(find "$destination/.agents/skills" -type f | wc -l | tr -d ' ')"
  [[ "$source_skill_count" == "$rendered_skill_count" ]] ||
    fail "skill discovery changed by context: source=$source_skill_count rendered=$rendered_skill_count ($context)"

  printf 'profile scope check: %s context renders correctly\n' "$context"
done
