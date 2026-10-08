#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
chezmoi_bin="$(command -v chezmoi || true)"
command -v python >/dev/null 2>&1 || { printf 'profile tests: python is required\n' >&2; exit 1; }
[[ -n "$chezmoi_bin" ]] || { printf 'profile tests: chezmoi is required\n' >&2; exit 1; }

work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
config_file="$work_directory/chezmoi.toml"
printf '[data]\n' >"$config_file"

fail() {
  printf 'profile tests: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing rendered file: $1"
}

assert_contains() {
  grep -Fq -- "$2" "$1" || fail "'$2' not found in $1"
}

assert_not_contains() {
  ! grep -Fq -- "$2" "$1" || fail "unexpected '$2' in $1"
}

for context in personal company; do
  override="$work_directory/$context.yaml"
  destination="$work_directory/render-$context"
  printf 'ai_context: %s\n' "$context" >"$override"
  mkdir -p "$destination"

  "$chezmoi_bin" apply \
    --config="$config_file" \
    --source="$repository_root" \
    --destination="$destination" \
    --exclude=scripts \
    --override-data-file="$override" \
    --no-tty \
    --force >/dev/null

  claude_core="$destination/.claude/CLAUDE.md"
  codex_core="$destination/.codex/AGENTS.md"
  copilot_core="$destination/.copilot/instructions/core.instructions.md"
  claude_settings="$destination/.claude/settings.json"
  codex_hooks="$destination/.codex/hooks.json"
  for file in "$claude_core" "$codex_core" "$copilot_core" "$claude_settings" "$codex_hooks"; do
    assert_file "$file"
  done

  handoff_skill="$destination/.agents/skills/task-handoff/SKILL.md"
  task_skill="$destination/.agents/skills/run-task-end-to-end/SKILL.md"
  assert_file "$handoff_skill"
  assert_file "$task_skill"
  assert_contains "$handoff_skill" 'disable-model-invocation: true'
  assert_contains "$handoff_skill" 'Receiver verification:** `pending`'
  assert_contains "$handoff_skill" 'Receiving session: Treat this handoff as unverified context'
  assert_contains "$handoff_skill" 'Report receiver verification as pending'
  assert_contains "$task_skill" "native worktree flow when available"
  assert_contains "$task_skill" 'branch=<name>'
  assert_contains "$task_skill" 'a suitable current branch or native detached worktree can hold the work'
  assert_contains "$task_skill" '<type>/<short-ascii-slug>'
  assert_contains "$task_skill" "record the current checkout's HEAD or the native worktree's starting commit"
  assert_contains "$task_skill" 'create the required branch before committing or publishing'
  assert_contains "$task_skill" 'active repository and profile policies'
  assert_contains "$task_skill" 'Do not infer policy-required identifiers'
  assert_not_contains "$task_skill" 'company-flow'
  assert_not_contains "$task_skill" 'flow=<number>'
  branch_section_line="$(grep -n '^## Establish the starting point and branch$' "$task_skill" | cut -d: -f1)"
  implement_section_line="$(grep -n '^## Implement and verify$' "$task_skill" | cut -d: -f1)"
  [[ -n "$branch_section_line" && -n "$implement_section_line" && "$branch_section_line" -lt "$implement_section_line" ]] ||
    fail 'starting point and branch setup must be documented before implementation'
  assert_not_contains "$task_skill" 'runtime=auto'

  if [[ "$context" == company ]]; then
    assert_contains "$claude_core" 'Traditional Chinese (zh-TW)'
    assert_contains "$codex_core" 'Traditional Chinese (zh-TW)'
    assert_contains "$copilot_core" 'Traditional Chinese (zh-TW)'
    assert_contains "$claude_core" '`company-flow`'
    assert_contains "$claude_core" 'explicit one-to-nine-digit flow number'
  else
    assert_contains "$claude_core" 'Default applicable artifact language is English'
    assert_not_contains "$claude_core" 'Traditional Chinese (zh-TW) unless repository instructions'
    assert_not_contains "$claude_core" '`company-flow`'
  fi

  python - "$claude_settings" "$codex_hooks" <<'PY'
import json
import sys

claude = json.load(open(sys.argv[1], encoding="utf-8"))
codex = json.load(open(sys.argv[2], encoding="utf-8"))
assert set(claude["hooks"]) == {"Notification", "SubagentStop"}
assert "statusLine" in claude
assert set(codex["hooks"]) == {"SessionEnd"}
for configuration in (claude, codex):
    rendered = json.dumps(configuration)
    for retired in ("maintain-task-continuity.sh", "check-worktree-launch", "worktree-runtime.py"):
        assert retired not in rendered, retired
PY

  printf 'profile tests: %s context renders native-first configuration\n' "$context"
done

for os_name in darwin windows; do
  override="$work_directory/os-$os_name.yaml"
  destination="$work_directory/render-os-$os_name"
  printf 'ai_context: personal\nchezmoi:\n  os: %s\n' "$os_name" >"$override"
  mkdir -p "$destination"

  "$chezmoi_bin" apply \
    --config="$config_file" \
    --source="$repository_root" \
    --destination="$destination" \
    --exclude=scripts \
    --override-data-file="$override" \
    --no-tty \
    --force >/dev/null

  if [[ "$os_name" == darwin ]]; then
    settings="$destination/Library/Application Support/Code/User/settings.json"
    [[ ! -e "$destination/AppData" ]] || fail 'macOS render included Windows AppData'
  else
    settings="$destination/AppData/Roaming/Code/User/settings.json"
    [[ ! -e "$destination/Library" ]] || fail 'Windows render included macOS Library'
  fi
  assert_file "$settings"
  assert_contains "$settings" 'git.worktreeIncludeFiles'
  assert_contains "$destination/.claude/CLAUDE.md" 'The active context is `personal`.'
done
printf 'profile tests: Windows and macOS source branches render successfully\n'

merge_destination="$work_directory/render-claude-merge"
mkdir -p "$merge_destination/.claude"
cat >"$merge_destination/.claude/settings.json" <<'JSON'
{
  "customSetting": "preserve",
  "hooks": {
    "Notification": [{"hooks": [
      {"type": "command", "command": "bash $HOME/.local/share/show-agent-notification-macos.sh"},
      {"type": "command", "command": "bash $HOME/custom-notification.sh"}
    ]}],
    "SessionStart": [{"hooks": [
      {"type": "command", "command": "bash $HOME/.claude/hooks/check-worktree-launch.sh"},
      {"type": "command", "command": "bash $HOME/custom-session-start.sh"}
    ]}],
    "Stop": [{"hooks": [
      {"type": "command", "command": "bash $HOME/.local/share/maintain-task-continuity.sh"},
      {"type": "command", "command": "bash $HOME/.local/share/maintain-project-continuity.sh"}
    ]}]
  }
}
JSON
"$chezmoi_bin" apply \
  --config="$config_file" \
  --source="$repository_root" \
  --destination="$merge_destination" \
  --exclude=scripts \
  --no-tty \
  --force >/dev/null
python - "$merge_destination/.claude/settings.json" <<'PY'
import json
import sys

settings = json.load(open(sys.argv[1], encoding="utf-8"))
assert settings["customSetting"] == "preserve"
commands = [hook["command"] for groups in settings["hooks"].values()
            for group in groups for hook in group.get("hooks", []) if "command" in hook]
assert any("custom-notification.sh" in command for command in commands)
assert any("custom-session-start.sh" in command for command in commands)
assert any("show-agent-notification.ps1" in command or "show-agent-notification-macos.sh" in command
           for command in commands)
assert not any("check-worktree-launch" in command or "maintain-task-continuity" in command
               or "maintain-project-continuity" in command
               for command in commands)
assert "Stop" not in settings["hooks"]
PY
printf 'profile tests: Claude settings preserve app-owned values and remove retired hooks\n'

default_destination="$work_directory/render-default"
mkdir -p "$default_destination"
"$chezmoi_bin" apply \
  --config="$config_file" \
  --source="$repository_root" \
  --destination="$default_destination" \
  --exclude=scripts \
  --no-tty \
  --force >/dev/null
default_core="$default_destination/.claude/CLAUDE.md"
assert_contains "$default_core" 'The active context is `personal`.'
assert_contains "$default_core" 'Default applicable artifact language is English'
printf 'profile tests: missing context defaults to personal\n'

invalid_override="$work_directory/invalid.yaml"
invalid_destination="$work_directory/render-invalid"
printf 'ai_context: invalid\n' >"$invalid_override"
mkdir -p "$invalid_destination"
if "$chezmoi_bin" apply \
  --config="$config_file" \
  --source="$repository_root" \
  --destination="$invalid_destination" \
  --exclude=scripts \
  --override-data-file="$invalid_override" \
  --no-tty \
  --force >"$work_directory/invalid.log" 2>&1; then
  fail 'invalid ai_context unexpectedly rendered successfully'
fi
assert_contains "$work_directory/invalid.log" 'invalid ai_context "invalid"'
printf 'profile tests: invalid context is rejected\n'

printf 'profile tests: both contexts render successfully\n'
