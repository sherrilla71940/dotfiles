#!/usr/bin/env bash
# Run once on a new Mac, by hand. Deliberately NOT a chezmoi script: anything under
# home/.chezmoiscripts/ runs on every `chezmoi apply`, which meant a routine apply could
# install software unexpectedly.
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew is required. Install it from https://brew.sh, then rerun this script.\n' >&2
  exit 1
fi

# The documented setup installs Git and chezmoi before cloning. This post-clone helper adds
# jq for the Claude MCP installer and verifies whether the VS Code CLI is already available.
brew list --formula jq >/dev/null 2>&1 || brew install jq

# This script installs the typescript-lsp plugin below, and the plugin does not install its
# language server. Without the binary every session reports a
# plugin load error. Both packages are needed: the server shells out to tsserver, which
# ships with typescript.
if ! command -v typescript-language-server >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    npm install -g typescript-language-server typescript
  else
    printf 'npm is not on PATH, so typescript-language-server was skipped. Install Node, then run "npm install -g typescript-language-server typescript".
' >&2
  fi
fi

if ! command -v code >/dev/null 2>&1; then
  printf 'VS Code CLI not on PATH. Install VS Code, then run "Shell Command: Install '"'"'code'"'"' command in PATH".\n' >&2
fi

# Claude Code plugins are installed software, not configuration, so they belong here rather
# than in the chezmoi-managed settings: pinning enabledPlugins would mean a plugin disabled
# locally came back on the next apply. The official marketplace is normally registered on the
# first interactive launch, so add it explicitly to make this script safe to run before that.
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
  for plugin in figma typescript-lsp playwright; do
    if ! claude plugin install "$plugin@claude-plugins-official" --scope user >/dev/null 2>&1; then
      printf 'Could not install %s. Add it from /plugin once Claude Code is running.\n' "$plugin" >&2
    fi
  done
else
  printf 'claude is not on PATH, so plugins were skipped. Install Claude Code, then rerun this script.\n' >&2
fi

printf 'Optional tools are ready.\n'
