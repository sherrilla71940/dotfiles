#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  printf 'Claude Code is not installed or is not available on PATH.\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required. Run the platform bootstrap script first.\n' >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest_path="$script_dir/claude-user-mcp-servers.json"

while IFS= read -r server; do
  name="$(jq -r '.key' <<<"$server")"
  configuration="$(jq -c '.value' <<<"$server")"

  if claude mcp get "$name" >/dev/null 2>&1; then
    printf '%s is already configured; leaving the live definition unchanged.\n' "$name"
    continue
  fi

  claude mcp add-json --scope user "$name" "$configuration"
done < <(jq -c '.mcpServers | to_entries[]' "$manifest_path")
