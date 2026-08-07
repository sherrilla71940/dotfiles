#!/usr/bin/env bash
set -euo pipefail

repository_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
migrate=false
install_vscode_extensions=false

for argument in "$@"; do
  case "$argument" in
    --migrate) migrate=true ;;
    --install-vscode-extensions) install_vscode_extensions=true ;;
    *) printf 'Unknown argument: %s\n' "$argument" >&2; exit 2 ;;
  esac
done

for command_name in git jq osascript; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    [[ "$command_name" == "jq" ]] && printf 'Install it with: brew install jq\n' >&2
    exit 1
  fi
done

move_to_backup() {
  local live_path="$1"
  local backup_name="$2"
  local destination="$backup_root/$backup_name"
  mkdir -p "$(dirname -- "$destination")"
  mv -- "$live_path" "$destination"
  printf 'BAK %s -> %s\n' "$live_path" "$destination" >&2
  printf '%s\n' "$destination"
}

ensure_symbolic_link() {
  local live_path="$1"
  local source_path="$2"
  local backup_name="$3"
  local backup_destination=""

  [[ -e "$source_path" ]] || { printf 'Missing repository source: %s\n' "$source_path" >&2; exit 1; }
  if [[ -L "$live_path" && "$(readlink "$live_path")" == "$source_path" ]]; then
    printf 'OK  %s\n' "$live_path"
    return
  fi
  if [[ -e "$live_path" || -L "$live_path" ]]; then
    if [[ "$migrate" != true ]]; then
      printf 'Refusing to replace existing path: %s\n' "$live_path" >&2
      printf 'Rerun with --migrate to move it into a timestamped backup first.\n' >&2
      exit 1
    fi
    backup_destination="$(move_to_backup "$live_path" "$backup_name")"
  fi

  mkdir -p "$(dirname -- "$live_path")"
  if ! ln -s "$source_path" "$live_path"; then
    if [[ -n "$backup_destination" && ! -e "$live_path" && -e "$backup_destination" ]]; then
      mv -- "$backup_destination" "$live_path"
      printf 'Restored %s because link creation failed.\n' "$live_path" >&2
    fi
    exit 1
  fi
  printf 'ADD %s -> %s\n' "$live_path" "$source_path"
}

claude_home="$HOME/.claude"
codex_home="$HOME/.codex"
agents_home="$HOME/.agents"
copilot_home="$HOME/.copilot"
vscode_home="$HOME/Library/Application Support/Code/User"
mkdir -p "$claude_home" "$codex_home" "$agents_home" "$copilot_home" "$vscode_home"

ensure_symbolic_link "$claude_home/dotfiles" "$repository_root/claude" "claude/dotfiles"
ensure_symbolic_link "$claude_home/CLAUDE.md" "$repository_root/claude/CLAUDE.md" "claude/CLAUDE.md"
ensure_symbolic_link "$claude_home/commands" "$repository_root/claude/commands" "claude/commands"
ensure_symbolic_link "$claude_home/rules" "$repository_root/claude/rules" "claude/rules"
ensure_symbolic_link "$claude_home/settings.json" "$repository_root/claude/settings.macos.json" "claude/settings.json"
ensure_symbolic_link "$claude_home/skills" "$repository_root/claude/skills" "claude/skills"
ensure_symbolic_link "$codex_home/AGENTS.md" "$repository_root/codex/AGENTS.md" "codex/AGENTS.md"
ensure_symbolic_link "$agents_home/skills" "$repository_root/agents/skills" "agents/skills"
ensure_symbolic_link "$copilot_home/agents" "$repository_root/copilot/agents" "copilot/agents"
ensure_symbolic_link "$copilot_home/instructions" "$repository_root/copilot/instructions" "copilot/instructions"
ensure_symbolic_link "$copilot_home/skills" "$repository_root/copilot/skills" "copilot/skills"
ensure_symbolic_link "$vscode_home/settings.json" "$repository_root/vscode/settings.json" "vscode/settings.json"
ensure_symbolic_link "$vscode_home/keybindings.json" "$repository_root/vscode/keybindings.json" "vscode/keybindings.json"
ensure_symbolic_link "$vscode_home/mcp.json" "$repository_root/vscode/mcp.json" "vscode/mcp.json"
ensure_symbolic_link "$vscode_home/prompts" "$repository_root/copilot/prompts" "copilot/prompts"
ensure_symbolic_link "$HOME/.bashrc" "$repository_root/shell/bashrc" "shell/bashrc"
ensure_symbolic_link "$HOME/.bash_profile" "$repository_root/shell/bash_profile" "shell/bash_profile"

if [[ -e "$codex_home/config.toml" ]]; then
  printf 'LOCAL %s (kept local because Codex writes machine state here)\n' "$codex_home/config.toml"
else
  cp -- "$repository_root/codex/config.shared.toml" "$codex_home/config.toml"
  printf 'ADD %s (bootstrapped from tracked template; intentionally not linked)\n' "$codex_home/config.toml"
fi

if [[ -e "$HOME/AGENTS.md" ]]; then
  printf 'Warning: %s is not managed and can duplicate ~/.codex/AGENTS.md below your home directory; review it manually.\n' "$HOME/AGENTS.md" >&2
fi

if [[ "$install_vscode_extensions" == true ]]; then
  command -v code >/dev/null 2>&1 || { printf "VS Code's 'code' command is not available on PATH.\n" >&2; exit 1; }
  while IFS= read -r extension_id; do
    [[ -z "$extension_id" || "$extension_id" == \#* ]] && continue
    code --install-extension "$extension_id" --force
  done < "$repository_root/vscode/extensions.txt"
fi

printf 'Dotfiles setup is complete. Restart Claude Code, Codex, and VS Code.\n'
printf 'For Claude notifications, test: osascript -e '\''display notification "test" with title "Claude Code"'\''\n'
