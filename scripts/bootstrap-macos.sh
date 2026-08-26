#!/usr/bin/env bash
# Run once on a new Mac, by hand. Deliberately NOT a chezmoi script: anything under
# home/.chezmoiscripts/ runs on every `chezmoi apply`, which meant a routine apply could
# install software unexpectedly.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Wiring the clone up runs before the package-manager gate below. Neither step needs Homebrew,
# and both are the ones that fail silently when skipped.

# Chezmoi reads its source from ~/.local/share/chezmoi, and this repository is developed at
# ~/dotfiles instead (ADR-0006), so the default path is satisfied with a symlink. That link is
# not part of the source state, so `chezmoi apply` neither creates nor repairs it, and a
# machine missing it silently uses whatever the directory happens to contain. An existing
# entry is never replaced: `ln -s` onto a directory nests inside it and still exits 0.
#
# -L as well as -e, because a dangling symlink is invisible to -e alone and would fall through
# to the ln below, which then fails with "File exists".
source_dir="$HOME/.local/share/chezmoi"
if [[ -e "$source_dir" || -L "$source_dir" ]]; then
  if [[ -L "$source_dir" && ! -e "$source_dir" ]]; then
    printf 'chezmoi source directory is a broken link: %s\n' "$source_dir" >&2
    printf '  Remove it, then rerun. Leaving it untouched.\n' >&2
  elif [[ "$(cd "$source_dir" && pwd -P)" == "$repo" ]]; then
    printf 'chezmoi source directory already points at %s\n' "$repo"
  else
    printf 'chezmoi source directory exists and is not this repository: %s\n' "$source_dir" >&2
    printf '  Move it aside and rerun, or set sourceDir yourself. Leaving it untouched.\n' >&2
  fi
else
  mkdir -p "$(dirname "$source_dir")"
  ln -s "$repo" "$source_dir"
  printf 'linked %s -> %s\n' "$source_dir" "$repo"
fi

# The pre-commit hook lives in the repository rather than .git/hooks, so it does nothing until
# core.hooksPath is set. Left unset, every validation check is silently absent on a new clone.
# Guarded so a non-checkout does not abort the rest of the script under set -e.
if git -C "$repo" config core.hooksPath scripts/git-hooks 2>/dev/null; then
  printf 'repository validation enabled (core.hooksPath)\n'
else
  printf 'Could not set core.hooksPath, so the validation hook will not run. Is %s a Git checkout?\n' "$repo" >&2
fi


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
else
  # The manifest stays out of routine apply because installing this many extensions is slow
  # and is not something a configuration change should trigger. This script runs once, by
  # hand, which is where it belongs.
  manifest="$repo/scripts/vscode-extensions.txt"
  if [[ -f "$manifest" ]]; then
    printf 'installing VS Code extensions from the manifest...\n'
    grep -v '^#' "$manifest" | grep . |
      xargs -I{} code --install-extension {} --force >/dev/null 2>&1 ||
      printf 'Some VS Code extensions failed. Rerun the manifest command from docs/setup.md.\n' >&2
  fi
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

  # ~/.claude.json also holds application-owned state, so the installer adds only missing
  # server names and leaves any existing one exactly as it is.
  if [[ -f "$repo/scripts/install-claude-mcp.sh" ]]; then
    bash "$repo/scripts/install-claude-mcp.sh" ||
      printf 'The Claude MCP installer failed. Run scripts/install-claude-mcp.sh by hand.\n' >&2
  fi
else
  printf 'claude is not on PATH, so plugins were skipped. Install Claude Code, then rerun this script.\n' >&2
fi

# Codex Memories is off upstream and is toggled by Codex's own command, which writes into
# ~/.codex/config.toml. That file carries the create_ prefix so chezmoi never overwrites the
# trust and runtime state Codex keeps there, which also means a source edit would not reach a
# machine that already has the file. Enabling it here is the same trade as the plugins above:
# set once on a new machine, and a later 'codex features disable memories' stays disabled.
if command -v codex >/dev/null 2>&1; then
  codex features enable memories >/dev/null 2>&1 ||
    printf 'Could not enable Codex memories. Run "codex features enable memories" by hand.\n' >&2
else
  printf 'codex is not on PATH, so Codex memories was skipped. Install Codex CLI, then rerun this script.\n' >&2
fi

printf 'Optional tools are ready.\n'
