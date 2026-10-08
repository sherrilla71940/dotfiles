#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { printf 'repository tools: %s\n' "$1" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "missing '$2' in $1"; }

# A templated shared skill must appear as managed when a Claude transcript invokes it.
mkdir -p "$work/claude/projects/demo"
cat > "$work/claude/projects/demo/session.jsonl" <<'JSON'
{"timestamp":"2026-10-08T00:00:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"run-task-end-to-end"}}]}}
JSON
CLAUDE_CONFIG_DIR="$work/claude" bash "$repo/scripts/diagnostics/claude-config-usage.sh" > "$work/usage.log"
assert_contains "$work/usage.log" 'Managed skills that were invoked'
grep -Eq '^  run-task-end-to-end[[:space:]]+1[[:space:]]' "$work/usage.log" ||
  fail 'templated run-task-end-to-end skill was not counted as managed'

# Deep drift under an owned object must be visible; local hook groups remain preserved.
mkdir -p "$work/home/.claude" "$work/bin"
cat > "$work/durable.json" <<'JSON'
{"env":{"API_TIMEOUT_MS":"1200000"},"hooks":{"Notification":[{"hooks":[{"command":"managed"}]}]}}
JSON
cat > "$work/home/.claude/settings.json" <<'JSON'
{"env":{"API_TIMEOUT_MS":"1000","LOCAL_FLAG":"kept"},"hooks":{"Notification":[{"hooks":[{"command":"local"}]}]}}
JSON
cat > "$work/bin/chezmoi" <<'SH'
#!/usr/bin/env bash
case "$1" in
  execute-template) cat "$TEST_DURABLE" ;;
  source-path) printf '%s\n' "$TEST_SOURCE_PATH" ;;
  status) printf 'status command failed\n' >&2; exit 2 ;;
  --version) printf 'test chezmoi\n' ;;
  *) exit 2 ;;
esac
SH
chmod +x "$work/bin/chezmoi"
HOME="$work/home" PATH="$work/bin:$PATH" TEST_DURABLE="$work/durable.json" \
  bash "$repo/scripts/diagnostics/claude-settings-drift.sh" > "$work/drift.log"
assert_contains "$work/drift.log" 'env.API_TIMEOUT_MS:'
assert_contains "$work/drift.log" 'env.LOCAL_FLAG'
if grep -Fq 'hooks.Notification:' "$work/drift.log"; then
  fail 'preserved local notification hooks were reported as overwritten'
fi

# A failed status command is a doctor failure, not merely a drift warning.
if HOME="$work/home" PATH="$work/bin:$PATH" TEST_SOURCE_PATH="$repo/home" \
    TEST_DURABLE="$work/durable.json" bash "$repo/scripts/dev-env" doctor > "$work/doctor.log" 2>&1; then
  fail 'doctor accepted a failed chezmoi status command'
fi
assert_contains "$work/doctor.log" 'FAIL: chezmoi status failed: status command failed'

# A malformed MCP manifest must stop the Bash installer before it invokes Claude.
command -v jq >/dev/null 2>&1 || fail 'jq is required for the MCP installer test'
mkdir -p "$work/installer/install" "$work/installer/manifests"
cp "$repo/scripts/install/install-claude-mcp.sh" "$work/installer/install/install-claude-mcp.sh"
cat > "$work/bin/claude" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_CLAUDE_LOG"
[[ "$1 $2" != 'mcp get' ]]
SH
chmod +x "$work/bin/claude"
printf '{invalid\n' > "$work/installer/manifests/claude-user-mcp-servers.json"
if PATH="$work/bin:$PATH" TEST_CLAUDE_LOG="$work/claude.log" \
    bash "$work/installer/install/install-claude-mcp.sh" > "$work/mcp.log" 2>&1; then
  fail 'MCP installer accepted malformed JSON'
fi
[[ ! -e "$work/claude.log" ]] || fail 'Claude ran before MCP manifest validation'

printf 'repository tools: diagnostics and installer failure paths passed\n'
