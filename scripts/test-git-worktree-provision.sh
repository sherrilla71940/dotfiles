#!/usr/bin/env bash
# Run the macOS worktree helper against disposable repositories containing non-secret
# fixtures. The suite is Bash 3.2 compatible and can also run under Git Bash on Windows.

set -u

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
tool_path="$repository_root/home/dot_local/share/git-worktree-provision.sh"
temporary_parent=$(cd "${TMPDIR:-/tmp}" && pwd -P)
test_root=$(mktemp -d "$temporary_parent/git-worktree-provision-tests.XXXXXX") || exit 1
passed=0
failed=0
skipped=0
result_output=""
result_status=0

cleanup() {
    case "$test_root" in
        "$temporary_parent"/git-worktree-provision-tests.*)
            [[ -d "$test_root" ]] && rm -rf -- "$test_root"
            ;;
        *)
            printf 'Refusing to remove unexpected test path: %s\n' "$test_root" >&2
            ;;
    esac
}
trap cleanup EXIT

write_fixture() {
    local path=$1
    local content=$2
    mkdir -p "${path%/*}"
    printf '%s' "$content" >"$path"
}

run_git() {
    local directory=$1
    shift
    result_output=$(cd "$directory" && git "$@" 2>&1)
    result_status=$?
}

git_checked() {
    local directory=$1
    shift
    run_git "$directory" "$@"
    if [[ $result_status -ne 0 ]]; then
        printf 'git %s failed:\n%s\n' "$*" "$result_output" >&2
        return 1
    fi
}

new_repository() {
    local name=$1
    local path="$test_root/$name"
    mkdir -p "$path"
    git_checked "$path" init --quiet --initial-branch=main || return 1
    git_checked "$path" config user.name 'Worktree Fixture' || return 1
    git_checked "$path" config user.email fixture@example.invalid || return 1
    git_checked "$path" config alias.wt-add "!bash \"$tool_path\" add" || return 1
    git_checked "$path" config alias.wt-copy "!bash \"$tool_path\" copy" || return 1
    write_fixture "$path/README.md" $'fixture\n'
    git_checked "$path" add README.md || return 1
    git_checked "$path" commit --quiet -m fixture || return 1
    fixture_repository=$path
}

add_manifest() {
    local repository=$1
    local ignore_content=$2
    local manifest_content=$3
    write_fixture "$repository/.gitignore" "$ignore_content"
    write_fixture "$repository/.worktreeinclude" "$manifest_content"
    git_checked "$repository" add .gitignore .worktreeinclude || return 1
    git_checked "$repository" commit --quiet -m 'add worktree manifest'
}

assert_true() {
    local message=$1
    shift
    "$@" || {
        printf '%s\n' "$message" >&2
        return 1
    }
}

assert_status() {
    local expected=$1
    local message=$2
    if [[ $result_status -ne $expected ]]; then
        printf '%s Expected %s, got %s. Output:\n%s\n' \
            "$message" "$expected" "$result_status" "$result_output" >&2
        return 1
    fi
}

assert_output_contains() {
    local expected=$1
    local message=$2
    if [[ "$result_output" != *"$expected"* ]]; then
        printf '%s Output:\n%s\n' "$message" "$result_output" >&2
        return 1
    fi
}

run_case() {
    local name=$1
    local function_name=$2
    if [[ -n "${WORKTREE_PROVISION_TEST_FILTER-}" && "$name" != *"$WORKTREE_PROVISION_TEST_FILTER"* ]]; then
        return
    fi
    if "$function_name"; then
        passed=$((passed + 1))
        printf 'PASS %s\n' "$name"
    else
        failed=$((failed + 1))
        printf 'FAIL %s\n' "$name"
    fi
}

case_no_manifest() {
    new_repository no-manifest || return 1
    local repository=$fixture_repository target="$test_root/no-manifest-target"
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 0 'Creation without a manifest should succeed.' || return 1
    assert_output_contains '[skipped] .worktreeinclude' 'The missing manifest should be reported.' || return 1
    [[ -f "$target/.git" ]]
}

case_matching() {
    new_repository matching || return 1
    local repository=$fixture_repository target="$test_root/matching-target"
    add_manifest "$repository" $'.env.local\n' $'.env.local\n' || return 1
    write_fixture "$repository/.env.local" $'fixture-value\n'
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 0 'Provisioning should succeed.' || return 1
    [[ $(<"$target/.env.local") == fixture-value ]]
}

case_unignored_and_outside_manifest() {
    new_repository eligibility || return 1
    local repository=$fixture_repository target="$test_root/eligibility-target"
    add_manifest "$repository" $'*.local\n' $'approved.local\nlocal.txt\n' || return 1
    write_fixture "$repository/approved.local" $'approved\n'
    write_fixture "$repository/other.local" $'not approved\n'
    write_fixture "$repository/local.txt" $'not ignored\n'
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 0 'Only manifest-listed ignored files should be eligible.' || return 1
    [[ -f "$target/approved.local" && ! -e "$target/other.local" && ! -e "$target/local.txt" ]] || return 1
    assert_output_contains '[missing] local.txt' 'The unignored manifest entry should be reported.'
}

case_nested_unicode() {
    new_repository unicode || return 1
    local repository=$fixture_repository target="$test_root/target space 測試"
    local relative='config space/測試.local'
    add_manifest "$repository" $'config space/\n' $'config space/\n' || return 1
    write_fixture "$repository/$relative" $'unicode\n'
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 0 'Unicode provisioning should succeed.' || return 1
    [[ -f "$target/$relative" ]]
}

case_conflict() {
    new_repository conflict || return 1
    local repository=$fixture_repository target="$test_root/conflict-target"
    add_manifest "$repository" $'.env\n' $'.env\n' || return 1
    git_checked "$repository" checkout --quiet -b target-with-file || return 1
    write_fixture "$repository/.env" $'tracked-target\n'
    git_checked "$repository" add --force .env || return 1
    git_checked "$repository" commit --quiet -m 'track target file' || return 1
    git_checked "$repository" checkout --quiet main || return 1
    write_fixture "$repository/.env" $'ignored-source\n'
    run_git "$repository" wt-add -- "$target" target-with-file
    assert_status 0 'A target conflict should be skipped without failing.' || return 1
    assert_output_contains '[conflict] .env' 'The conflict should be reported.' || return 1
    [[ $(<"$target/.env") == tracked-target ]]
}

case_native_failure() {
    new_repository native-failure || return 1
    local repository=$fixture_repository
    run_git "$repository" wt-add -- --detach
    [[ $result_status -ne 0 && "$result_output" != *'[copied]'* ]]
}

case_blocked_file() {
    new_repository blocked || return 1
    local repository=$fixture_repository target="$test_root/blocked-target"
    add_manifest "$repository" $'.project-continuity/\n' $'.project-continuity/\n' || return 1
    write_fixture "$repository/.project-continuity/state.md" $'fixture state\n'
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 2 'A blocked source should fail provisioning.' || return 1
    assert_output_contains '[rejected] .project-continuity/state.md' 'The blocked file should be reported.' || return 1
    [[ -f "$target/.git" ]]
}

case_traversal() {
    new_repository traversal || return 1
    local repository=$fixture_repository target="$test_root/traversal-target"
    add_manifest "$repository" $'*.env\n' $'../outside.env\n' || return 1
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 2 'A traversal manifest should fail provisioning.' || return 1
    assert_output_contains 'parent-directory traversal' 'The traversal reason should be reported.'
}

case_source_symlink() {
    if [[ $(uname -s) != Darwin ]]; then
        skipped=$((skipped + 1))
        printf 'SKIP source symlink (requires native macOS filesystem semantics)\n'
        return 0
    fi
    new_repository source-symlink || return 1
    local repository=$fixture_repository target="$test_root/source-symlink-target"
    local external="$test_root/source-symlink-external"
    add_manifest "$repository" $'linked.env\n' $'linked.env\n' || return 1
    mkdir -p "$external"
    write_fixture "$external/local.env" $'outside\n'
    ln -s "$external/local.env" "$repository/linked.env" || return 1
    run_git "$repository" wt-add -- --detach "$target" HEAD
    assert_status 2 'A source symlink should fail provisioning.' || return 1
    assert_output_contains 'source path traverses a symbolic link' 'The source symlink should be reported.'
}

case_repair_primary() {
    new_repository repair-primary || return 1
    local repository=$fixture_repository target="$test_root/repair-primary-target"
    add_manifest "$repository" $'.env.local\n' $'.env.local\n' || return 1
    write_fixture "$repository/.env.local" $'repair\n'
    git_checked "$repository" worktree add --quiet --detach "$target" HEAD || return 1
    run_git "$target" wt-copy
    assert_status 0 'Automatic repair should succeed.' || return 1
    assert_output_contains 'Source worktree:' 'The selected source should be reported.' || return 1
    [[ -f "$target/.env.local" ]]
}

case_repair_explicit() {
    new_repository repair-explicit || return 1
    local repository=$fixture_repository target="$test_root/repair-explicit-target"
    add_manifest "$repository" $'.env.test\n' $'.env.test\n' || return 1
    write_fixture "$repository/.env.test" $'explicit\n'
    git_checked "$repository" worktree add --quiet --detach "$target" HEAD || return 1
    run_git "$target" wt-copy --source "$repository"
    assert_status 0 'Explicit repair should succeed.' || return 1
    [[ -f "$target/.env.test" ]]
}

case_branch_forwarding() {
    new_repository forwarding || return 1
    local repository=$fixture_repository target="$test_root/forwarding-target"
    git_checked "$repository" checkout --quiet -b develop || return 1
    write_fixture "$repository/develop.txt" $'develop\n'
    git_checked "$repository" add develop.txt || return 1
    git_checked "$repository" commit --quiet -m 'develop marker' || return 1
    git_checked "$repository" checkout --quiet main || return 1
    run_git "$repository" wt-add -- -b feat/from-develop "$target" develop
    assert_status 0 'Native branch and start-point arguments should succeed.' || return 1
    git_checked "$target" branch --show-current || return 1
    [[ "$result_output" == feat/from-develop && -f "$target/develop.txt" ]]
}

case_dry_run() {
    new_repository dry-run || return 1
    local repository=$fixture_repository target="$test_root/dry-run-target"
    add_manifest "$repository" $'.env.local\n' $'.env.local\n' || return 1
    write_fixture "$repository/.env.local" $'dry\n'
    run_git "$repository" wt-add --dry-run -- --detach "$target" HEAD
    assert_status 0 'Dry run should succeed.' || return 1
    assert_output_contains '[eligible] .env.local' 'Dry run should report the eligible file.' || return 1
    [[ ! -e "$target" ]]
}

run_case 'create without manifest' case_no_manifest
run_case 'copy matching ignored file' case_matching
run_case 'enforce ignored-manifest intersection' case_unignored_and_outside_manifest
run_case 'copy nested Unicode path' case_nested_unicode
run_case 'preserve existing target file' case_conflict
run_case 'preserve native Git failure' case_native_failure
run_case 'leave worktree after provisioning rejection' case_blocked_file
run_case 'reject traversal pattern' case_traversal
run_case 'reject source symlink' case_source_symlink
run_case 'repair from discovered primary' case_repair_primary
run_case 'repair from explicit source' case_repair_explicit
run_case 'forward branch and start-point arguments' case_branch_forwarding
run_case 'dry run creates nothing' case_dry_run

printf 'Worktree tool tests: passed=%s failed=%s skipped=%s\n' "$passed" "$failed" "$skipped"
[[ $failed -eq 0 ]]
