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

if ! command -v code >/dev/null 2>&1; then
  printf 'VS Code CLI not on PATH. Install VS Code, then run "Shell Command: Install '"'"'code'"'"' command in PATH".\n' >&2
fi

printf 'Optional tools are ready.\n'
