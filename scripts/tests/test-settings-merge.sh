#!/usr/bin/env bash
# Render every partially managed JSON modify template against fixture durable sources and check
# that repository-owned keys win collisions, including false, 0, "" and empty-array values that
# sprig's plain merge treats as empty and silently hands to the live file.
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

fail() {
  printf 'settings merge check: %s\n' "$1" >&2
  exit 1
}

[[ -n "$chezmoi_bin" ]] || fail 'chezmoi is unavailable'
command -v jq >/dev/null 2>&1 || fail 'jq is unavailable'
[[ -d "$source_root/home" ]] || fail "source root is invalid: $source_root"

work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
config_file="$work_directory/chezmoi.toml"
printf '[data]\n' >"$config_file"
fixture_source="$work_directory/source"
mkdir -p "$fixture_source/.chezmoitemplates"/{claude,copilot,vscode,windows-terminal}

# Template path relative to home/, then the durable source it includes.
templates=(
  "AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/modify_settings.json|windows-terminal/settings-durable.json"
  "AppData/Roaming/Code/User/modify_settings.json|vscode/settings-durable.json"
  "AppData/Roaming/Code/User/modify_mcp.json|vscode/mcp.json"
  "Library/Application Support/Code/User/modify_settings.json|vscode/settings-durable.json"
  "Library/Application Support/Code/User/modify_mcp.json|vscode/mcp.json"
  "dot_claude/modify_settings.json|claude/settings-durable.json"
  "dot_copilot/modify_settings.json|copilot/settings-durable.json"
  "dot_copilot/modify_mcp-config.json|copilot/mcp-config-durable.json"
)

# A new template that still uses the plain merge would otherwise pass unnoticed.
while IFS= read -r unsafe; do
  fail "plain merge lets live empty-looking values win; use mergeOverwrite (deepCopy \$live) \$durable: $unsafe"
done < <(grep -rlE 'merge \$durable \$live' "$source_root/home" --include='modify_*' || true)

render() {
  local template="$1"
  local live="$2"
  printf '%s' "$live" |
    "$chezmoi_bin" execute-template --config="$config_file" --source="$fixture_source" \
      --with-stdin --file "$source_root/home/$template"
}

assert_json() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$(jq -S . <<<"$actual")" != "$(jq -S . <<<"$expected")" ]]; then
    printf 'settings merge check: %s rendered:\n%s\nexpected:\n%s\n' \
      "$label" "$(jq -S . <<<"$actual")" "$(jq -S . <<<"$expected")" >&2
    exit 1
  fi
}

durable='{
  "flag": false,
  "count": 0,
  "text": "",
  "list": [],
  "replaced": [3],
  "nested": {"flag": false, "deeper": {"flag": false}}
}'
live='{
  "flag": true,
  "count": 5,
  "text": "live",
  "list": [1],
  "replaced": [1, 2],
  "nested": {"flag": true, "appOwned": true, "deeper": {"flag": true, "appOwned": 1}},
  "appOwned": "live"
}'
expected='{
  "flag": false,
  "count": 0,
  "text": "",
  "list": [],
  "replaced": [3],
  "nested": {"flag": false, "appOwned": true, "deeper": {"flag": false, "appOwned": 1}},
  "appOwned": "live"
}'

for entry in "${templates[@]}"; do
  template="${entry%%|*}"
  durable_name="${entry#*|}"
  [[ -f "$source_root/home/$template" ]] || fail "template is missing: $template"
  printf '%s' "$durable" >"$fixture_source/.chezmoitemplates/$durable_name"
  assert_json "$template" "$(render "$template" "$live")" "$expected"
  # An empty live file renders the durable values alone.
  assert_json "$template (empty live)" "$(render "$template" '')" "$durable"
done

# Per-entry array rules still apply after the key merge, and the durable entry wins its id.
printf '%s' '{
  "actions": [{"id": "Repo.Action", "enabled": false}],
  "keybindings": [{"keys": "ctrl+a", "id": "Repo.Action"}]
}' >"$fixture_source/.chezmoitemplates/windows-terminal/settings-durable.json"
assert_json 'Windows Terminal actions and keybindings' \
  "$(render "${templates[0]%%|*}" '{
    "actions": [{"id": "Repo.Action", "enabled": true}, {"id": "App.Action"}],
    "keybindings": [{"keys": "ctrl+a", "id": "App.Other"}, {"keys": "ctrl+b", "id": "App.Action"}]
  }')" '{
    "actions": [{"id": "Repo.Action", "enabled": false}, {"id": "App.Action"}],
    "keybindings": [{"keys": "ctrl+a", "id": "Repo.Action"}, {"keys": "ctrl+b", "id": "App.Action"}]
  }'

printf '%s' '{
  "servers": {"repo": {"type": "stdio", "disabled": false}},
  "inputs": [{"id": "repo-token", "password": false}]
}' >"$fixture_source/.chezmoitemplates/vscode/mcp.json"
for template in "AppData/Roaming/Code/User/modify_mcp.json" \
  "Library/Application Support/Code/User/modify_mcp.json"; do
  assert_json "$template inputs" "$(render "$template" '{
      "servers": {"repo": {"type": "stdio", "disabled": true}, "app": {"type": "http"}},
      "inputs": [{"id": "repo-token", "password": true}, {"id": "app-token"}]
    }')" '{
      "servers": {"repo": {"type": "stdio", "disabled": false}, "app": {"type": "http"}},
      "inputs": [{"id": "repo-token", "password": false}, {"id": "app-token"}]
    }'
done

printf 'test-settings-merge: repository values win in %s modify templates.\n' "${#templates[@]}"
