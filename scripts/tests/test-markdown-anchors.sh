#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
fixture_dir="$(mktemp -d)"

cleanup() {
  rm -f -- "$fixture_dir/README.md" "$fixture_dir/guide.md" "$fixture_dir/error.txt"
  rmdir -- "$fixture_dir"
}
trap cleanup EXIT

cat >"$fixture_dir/guide.md" <<'EOF'
## 跨專案平行工作（Work across projects in parallel）
EOF
cat >"$fixture_dir/README.md" <<'EOF'
[Parallel guide](guide.md#跨專案平行工作work-across-projects-in-parallel)
EOF

checked="$(cd "$fixture_dir" && awk -f "$repository_root/scripts/git-hooks/markdown-anchors.awk" README.md guide.md)"
[[ "$checked" == 1 ]] || {
  printf 'test-markdown-anchors: Unicode fragment was not checked.\n' >&2
  exit 1
}

cat >"$fixture_dir/README.md" <<'EOF'
[Parallel guide](guide.md#work-across-projects-in-parallel)
EOF
if (cd "$fixture_dir" && awk -f "$repository_root/scripts/git-hooks/markdown-anchors.awk" README.md guide.md) >"$fixture_dir/error.txt" 2>&1; then
  printf 'test-markdown-anchors: incomplete fragment was accepted.\n' >&2
  exit 1
fi
if ! grep -q 'no such heading' "$fixture_dir/error.txt"; then
  cat "$fixture_dir/error.txt" >&2
  exit 1
fi

printf 'test-markdown-anchors: Unicode fragments are checked.\n'
