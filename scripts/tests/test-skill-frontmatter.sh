#!/usr/bin/env bash
# Exercise the YAML failure that rendering and regex checks previously missed.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd -P)"
check="$repo/scripts/git-hooks/check-skill-frontmatter.sh"
chezmoi_bin="$(command -v chezmoi)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
skill="$work/.agents/skills/example/SKILL.md"
mkdir -p "$(dirname "$skill")"

cat >"$skill" <<'EOF'
---
name: example
description: "A valid: description"
---
# Example
EOF
bash "$check" "$chezmoi_bin" "$work" >"$work/output"
grep -q 'skill frontmatter OK (1 checked)' "$work/output"

wrapper="$work/.copilot/skills/example/SKILL.md"
mkdir -p "$(dirname "$wrapper")"
cp "$skill" "$wrapper"
bash "$check" "$chezmoi_bin" "$work" >"$work/output"
grep -q 'skill frontmatter OK (2 checked)' "$work/output"

cat >"$skill" <<'EOF'
---
name: example
description: invalid: description
---
# Example
EOF
if bash "$check" "$chezmoi_bin" "$work" >"$work/output" 2>&1; then
  printf 'test-skill-frontmatter: malformed YAML passed.\n' >&2
  exit 1
fi
grep -q 'invalid YAML in .agents/skills/example/SKILL.md' "$work/output"

cat >"$skill" <<'EOF'
---
name: example
description: Valid description
---
# Example
EOF
cat >"$wrapper" <<'EOF'
---
name: example
description: invalid: description
---
# Example
EOF
if bash "$check" "$chezmoi_bin" "$work" >"$work/output" 2>&1; then
  printf 'test-skill-frontmatter: malformed client skill YAML passed.\n' >&2
  exit 1
fi
grep -q 'invalid YAML in .copilot/skills/example/SKILL.md' "$work/output"
cp "$skill" "$wrapper"

cat >"$skill" <<'EOF'
---
name: example
description: Valid description
# Missing closing delimiter
EOF
if bash "$check" "$chezmoi_bin" "$work" >"$work/output" 2>&1; then
  printf 'test-skill-frontmatter: missing delimiter passed.\n' >&2
  exit 1
fi
grep -q 'must start and end with --- delimiters' "$work/output"

printf 'test-skill-frontmatter: valid metadata passes; malformed YAML and delimiters fail.\n'
