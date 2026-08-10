#!/usr/bin/env bash
set -euo pipefail

repository_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
migrate=false
install_vscode_extensions=false

known_components="claude codex copilot vscode shell"
requested_components=""

usage() {
  cat >&2 <<'EOF'
Usage: ./setup-macos.sh [--components <list>] [--migrate] [--install-vscode-extensions]

  --components <list>  Comma-separated subset of: claude, codex, copilot, vscode, shell, all
                       Omitted means all.
  --migrate            Move conflicting live paths into a timestamped backup first.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --migrate) migrate=true ;;
    --install-vscode-extensions) install_vscode_extensions=true ;;
    --components)
      [[ $# -ge 2 ]] || { printf 'Missing value for --components\n' >&2; usage; exit 2; }
      requested_components="$2"
      shift
      ;;
    --components=*) requested_components="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
  shift
done

is_known_component() {
  local candidate="$1" known
  for known in $known_components; do
    [[ "$candidate" == "$known" ]] && return 0
  done
  return 1
}

selected_components=""
if [[ -z "$requested_components" ]]; then
  selected_components="$known_components"
else
  for component in ${requested_components//,/ }; do
    component="$(printf '%s' "$component" | tr '[:upper:]' '[:lower:]')"
    [[ -z "$component" ]] && continue
    if [[ "$component" == "all" ]]; then
      selected_components="$known_components"
      break
    fi
    if ! is_known_component "$component"; then
      printf 'Unknown component: %s\n' "$component" >&2
      printf 'Valid components: %s, all\n' "${known_components// /, }" >&2
      exit 2
    fi
    case " $selected_components " in
      *" $component "*) ;;
      *) selected_components="${selected_components:+$selected_components }$component" ;;
    esac
  done
  [[ -n "$selected_components" ]] || { printf 'No components selected.\n' >&2; exit 2; }
fi

component_selected() {
  case " $selected_components " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

required_commands="git"
if component_selected codex; then required_commands="$required_commands jq"; fi
if component_selected claude; then required_commands="$required_commands osascript"; fi
for command_name in $required_commands; do
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
    printf 'OK  %s -> %s\n' "$live_path" "$source_path"
    return
  fi
  if [[ -e "$live_path" || -L "$live_path" ]]; then
    if [[ "$migrate" != true ]]; then
      printf 'Refusing to replace existing path: %s\n' "$live_path" >&2
      if [[ -L "$live_path" ]]; then
        printf 'It currently resolves to: %s\n' "$(readlink "$live_path")" >&2
      else
        printf 'It is a real file or directory.\n' >&2
      fi
      printf 'Intended source: %s\n' "$source_path" >&2
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
# Default VS Code profile. Named profiles keep their own storage under
# "$vscode_home/profiles/<id>"; see dotfiles-setup.md.
vscode_home="$HOME/Library/Application Support/Code/User"

printf 'Components: %s\n' "${selected_components// /, }"

if component_selected claude; then mkdir -p "$claude_home"; fi
if component_selected codex; then mkdir -p "$codex_home" "$agents_home"; fi
if component_selected copilot; then mkdir -p "$copilot_home"; fi
if component_selected vscode; then mkdir -p "$vscode_home"; fi

# The link table lives in links.tsv so both installers read one source of truth.
cr="$(printf '\r')"   # so a CRLF checkout of links.tsv cannot corrupt the last field
seen_backups=""
while IFS=$'	' read -r component live source platform; do
  component="${component%$cr}"; live="${live%$cr}"; source="${source%$cr}"; platform="${platform%$cr}"
  [[ -z "$component" || "$component" == \#* ]] && continue
  [[ -n "$source" ]] || { printf 'Malformed row in links.tsv: %s\n' "$component" >&2; exit 1; }
  [[ -z "$platform" || "$platform" == "macos" ]] || continue
  is_known_component "$component" || { printf 'links.tsv references unknown component: %s\n' "$component" >&2; exit 1; }
  component_selected "$component" || continue
  live="${live//\{HOME\}/$HOME}"
  live="${live//\{VSCODE_USER\}/$vscode_home}"
  # Backup name is keyed on the live path, not the source: two live paths can share one
  # source (both ~/.claude/skills and ~/.agents/skills point at skills/), and identical
  # backup names would collide in the same timestamped backup directory.
  backup_name="$component/$(basename -- "$live")"
  case " $seen_backups " in
    *" $backup_name "*)
      printf 'links.tsv rows produce colliding backup names: %s\n' "$backup_name" >&2
      exit 1
      ;;
  esac
  seen_backups="${seen_backups:+$seen_backups }$backup_name"
  ensure_symbolic_link "$live" "$repository_root/$source" "$backup_name"
done < "$repository_root/links.tsv"

if component_selected copilot; then
  # Copilot writes these itself; they stay local and untracked.
  for runtime_path in "config.json" "ide" "logs"; do
    if [[ -e "$copilot_home/$runtime_path" ]]; then
      printf 'LOCAL %s (Copilot runtime state; intentionally not linked)\n' "$copilot_home/$runtime_path"
    fi
  done
fi

if component_selected codex; then
  if [[ -e "$codex_home/config.toml" ]]; then
    printf 'LOCAL %s (kept local because Codex writes machine state here)\n' "$codex_home/config.toml"
  else
    cp -- "$repository_root/codex/config.shared.toml" "$codex_home/config.toml"
    printf 'ADD %s (bootstrapped from tracked template; intentionally not linked)\n' "$codex_home/config.toml"
  fi

  if [[ -e "$HOME/AGENTS.md" ]]; then
    printf 'Warning: %s is not managed and can duplicate ~/.codex/AGENTS.md below your home directory; review it manually.\n' "$HOME/AGENTS.md" >&2
  fi
fi

if [[ "$install_vscode_extensions" == true ]]; then
  component_selected vscode || { printf -- '--install-vscode-extensions requires the vscode component.\n' >&2; exit 2; }
  command -v code >/dev/null 2>&1 || { printf "VS Code's 'code' command is not available on PATH.\n" >&2; exit 1; }
  while IFS= read -r extension_id; do
    [[ -z "$extension_id" || "$extension_id" == \#* ]] && continue
    code --install-extension "$extension_id" --force
  done < "$repository_root/vscode/extensions.txt"
fi

printf 'Dotfiles setup is complete for: %s\n' "${selected_components// /, }"
printf 'Restart the applications you just configured so they re-read the linked files.\n'
if component_selected claude; then
  printf 'For Claude notifications, test: osascript -e '\''display notification "test" with title "Claude Code"'\''\n'
fi
