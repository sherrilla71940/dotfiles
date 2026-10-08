#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
chezmoi_bin="$(command -v chezmoi || true)"
[[ -n "$chezmoi_bin" ]] || { printf 'Git config migration test: chezmoi is required\n' >&2; exit 1; }

work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
input="$work_directory/gitconfig"
output="$work_directory/rendered-gitconfig"

cat >"$input" <<'EOF'
[user]
	email = old@example.invalid
	name = Old Name
	useConfigOnly = true
[core]
	autocrlf = input
	hooksPath = /old/hooks
[alias]
	wt-add = "!bash \"$HOME/.local/share/git-worktree-provision.sh\" add"
	wt-check = "!powershell.exe -File \"$HOME/.local/share/git-worktree-provision.ps1\" check"
	wt-copy = "!git worktree add"
	keep = "!echo keep"
# BEGIN chezmoi-managed Git config include
[include]
	path = ~/.config/git/old
# END chezmoi-managed Git config include
EOF

chezmoi_worktree="$(realpath "$repository_root/home")"
"$chezmoi_bin" execute-template \
  --source="$chezmoi_worktree" \
  --with-stdin \
  -f "$repository_root/home/modify_dot_gitconfig" \
  <"$input" >"$output"

git config --file "$output" --get user.useConfigOnly >/dev/null || {
  printf 'Git config migration test: user section or unrelated key was lost\n' >&2
  exit 1
}
git config --file "$output" --get core.autocrlf >/dev/null || {
  printf 'Git config migration test: core section or unrelated key was lost\n' >&2
  exit 1
}
git config --file "$output" --get alias.wt-copy >/dev/null || {
  printf 'Git config migration test: same-named user alias was removed\n' >&2
  exit 1
}
git config --file "$output" --get alias.keep >/dev/null || {
  printf 'Git config migration test: unrelated alias was removed\n' >&2
  exit 1
}
if git config --file "$output" --get-regexp '^alias\.(wt-add|wt-check)$' >/dev/null; then
  printf 'Git config migration test: alias to a retired helper survived\n' >&2
  exit 1
fi
[[ "$(grep -Fxc '# BEGIN chezmoi-managed Git config include' "$output")" -eq 1 ]] || {
  printf 'Git config migration test: managed include block was not replaced exactly once\n' >&2
  exit 1
}

printf 'Git config migration test: preserved unrelated settings and removed retired helper aliases\n'
