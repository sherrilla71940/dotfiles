#!/usr/bin/env bash
# Check rendered SKILL.md metadata without depending on a separate YAML installation.
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf 'usage: %s <chezmoi> <rendered-home>\n' "$0" >&2
  exit 2
fi

chezmoi_bin="$1"
render="$2"
count=0

for skill_root in "$render/.agents/skills" "$render/.claude/skills" "$render/.copilot/skills"; do
  [[ -d "$skill_root" ]] || continue

  while IFS= read -r -d '' skill; do
    relative="${skill#"$render"/}"
    if ! frontmatter="$(awk '
      NR == 1 { if ($0 != "---") exit 1; next }
      $0 == "---" { closed = 1; exit }
      { print }
      END { if (!closed) exit 1 }
    ' "$skill")"; then
      printf 'skill frontmatter: %s must start and end with --- delimiters.\n' "$relative" >&2
      exit 1
    fi

    if ! parsed="$(printf '%s\n' "$frontmatter" | "$chezmoi_bin" execute-template \
      --with-stdin '{{ $meta := .chezmoi.stdin | fromYaml }}{{ if and $meta.name $meta.description }}ok{{ end }}' 2>&1)"; then
      printf 'skill frontmatter: invalid YAML in %s:\n%s\n' "$relative" "$parsed" >&2
      exit 1
    fi
    if [[ "$parsed" != ok ]]; then
      printf 'skill frontmatter: %s needs nonempty name and description fields.\n' "$relative" >&2
      exit 1
    fi
    count=$((count + 1))
  done < <(find "$skill_root" -type f -name SKILL.md -print0)
done

printf 'pre-commit: skill frontmatter OK (%s checked).\n' "$count"
