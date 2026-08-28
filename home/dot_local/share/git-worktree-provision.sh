#!/usr/bin/env bash
# Managed by the dotfiles repository. Provides the implementation behind the macOS
# `git wt-add` and `git wt-copy` aliases without requiring PowerShell.

set -u

temp_files=()
worktree_paths=()
standard_ignored=()
manifest_matched=()
pattern_matched=()
selection_files=()
selection_patterns=()
selection_missing=()
selection_rejected_patterns=()
selection_rejected_reasons=()
selection_manifest_present=false
rejection_reason=""

# A shell Git alias exports repository-local variables from the invoking worktree. They
# must not reach nested `git -C <other-worktree>` calls because GIT_DIR wins over -C.
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_DIR GIT_GRAFT_FILE
unset GIT_IMPLICIT_WORK_TREE GIT_INDEX_FILE GIT_INTERNAL_SUPER_PREFIX
unset GIT_NO_REPLACE_OBJECTS GIT_OBJECT_DIRECTORY GIT_PREFIX GIT_REPLACE_REF_BASE
unset GIT_SHALLOW_FILE GIT_WORK_TREE

cleanup() {
    local path
    for path in "${temp_files[@]}"; do
        [[ -n "$path" && -f "$path" ]] && rm -f -- "$path"
    done
}
trap cleanup EXIT

die() {
    printf 'git-worktree-provision: %s\n' "$*" >&2
    return 2
}

display_text() {
    printf '%s' "$1" | LC_ALL=C tr '[:cntrl:]' '?'
}

write_record() {
    local category=$1
    local path=$2
    local detail=${3-}
    local safe_path safe_detail
    safe_path=$(display_text "$path")
    if [[ -n "$detail" ]]; then
        safe_detail=$(display_text "$detail")
        printf '[%s] %s: %s\n' "$category" "$safe_path" "$safe_detail"
    else
        printf '[%s] %s\n' "$category" "$safe_path"
    fi
}

new_temp_file() {
    local path
    path=$(mktemp "${TMPDIR:-/tmp}/git-worktree-provision.XXXXXX") || return 1
    temp_files+=("$path")
    new_temp_path=$path
}

canonical_directory() {
    (cd "$1" 2>/dev/null && pwd -P)
}

repository_root() {
    git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

common_git_directory() {
    local root=$1
    local path
    path=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null) || return 1
    if [[ "$path" != /* && ! "$path" =~ ^[A-Za-z]:[\\/] ]]; then
        path="$root/$path"
    fi
    canonical_directory "$path"
}

same_path() {
    local left right
    left=$(canonical_directory "$1") || return 1
    right=$(canonical_directory "$2") || return 1
    [[ "$left" == "$right" ]]
}

path_inside_root() {
    local root=${1%/}
    local path=$2
    [[ "$path" == "$root"/* ]]
}

load_worktree_paths() {
    local root=$1
    local output field
    new_temp_file || return 1
    output=$new_temp_path
    git -C "$root" worktree list --porcelain -z >"$output" || return 1
    worktree_paths=()
    while IFS= read -r -d '' field; do
        case "$field" in
            'worktree '*) worktree_paths+=("${field#worktree }") ;;
        esac
    done <"$output"
}

array_contains() {
    local needle=$1
    shift
    local value
    for value in "$@"; do
        [[ "$value" == "$needle" ]] && return 0
    done
    return 1
}

find_symlink() {
    local root=${1%/}
    local path=$2
    local include_leaf=$3
    local relative remaining segment current leaf

    found_symlink=""
    path_inside_root "$root" "$path" || {
        found_symlink=$path
        return 0
    }

    relative=${path#"$root"/}
    remaining=$relative
    current=$root
    while [[ -n "$remaining" ]]; do
        if [[ "$remaining" == */* ]]; then
            segment=${remaining%%/*}
            remaining=${remaining#*/}
            leaf=false
        else
            segment=$remaining
            remaining=""
            leaf=true
        fi

        [[ "$leaf" == true && "$include_leaf" != true ]] && break
        [[ -z "$segment" ]] && continue
        current="$current/$segment"
        if [[ -L "$current" ]]; then
            found_symlink=$current
            return 0
        fi
    done
    return 1
}

get_pattern_rejection_reason() {
    local pattern=$1
    local candidate=$pattern
    rejection_reason=""
    [[ "$candidate" == '!'* ]] && candidate=${candidate#'!'}
    [[ "$candidate" == /* ]] && candidate=${candidate#/}

    if [[ "$candidate" =~ ^[A-Za-z]:[\\/] || "$candidate" =~ ^[/\\]{2} ]]; then
        rejection_reason="absolute filesystem paths are not allowed"
    elif [[ "/$candidate/" == *'/../'* ]]; then
        rejection_reason="parent-directory traversal is not allowed"
    fi
    [[ -n "$rejection_reason" ]]
}

get_file_rejection_reason() {
    local relative_path=$1
    local normalized lower name extension segment rest
    rejection_reason=""
    normalized=${relative_path//\\//}
    normalized=${normalized#/}
    lower=$(printf '%s' "$normalized" | LC_ALL=C tr '[:upper:]' '[:lower:]')

    rest=$lower
    while :; do
        if [[ "$rest" == */* ]]; then
            segment=${rest%%/*}
            rest=${rest#*/}
        else
            segment=$rest
            rest=""
        fi
        case "$segment" in
            .git|.project-continuity|node_modules|packages|bin|obj|.vs|.cache|coverage|dist)
                rejection_reason="blocked directory '$segment'"
                return 0
                ;;
        esac
        [[ -z "$rest" ]] && break
    done

    case "/$lower" in
        /.claude/worktrees|/.claude/worktrees/*|/.claude/logs|/.claude/logs/*|/.claude/agent-memory-local|/.claude/agent-memory-local/*)
            rejection_reason="Claude session state is never copied"
            return 0
            ;;
        /.codex|/.codex/*)
            rejection_reason="Codex local state is never copied"
            return 0
            ;;
    esac

    name=${lower##*/}
    case "$name" in
        .env.production|.env.production.local)
            rejection_reason="production environment files are never copied"
            return 0
            ;;
        .npmrc|nuget.config|credentials.json|auth.json|id_rsa|id_ed25519)
            rejection_reason="credential or authentication files are never copied"
            return 0
            ;;
    esac

    extension=""
    [[ "$name" == *.* ]] && extension=.${name##*.}
    case "$extension" in
        .pem|.key|.pfx|.p12|.cer|.crt)
            rejection_reason="private keys and certificates are never copied"
            return 0
            ;;
        .bak|.db|.sqlite|.sqlite3)
            rejection_reason="database backups and local data stores are never copied"
            return 0
            ;;
    esac
    return 1
}

load_ignored_files() {
    local root=$1
    local mode=$2
    local value output
    new_temp_file || return 1
    output=$new_temp_path

    if [[ "$mode" == standard ]]; then
        git -C "$root" ls-files --others --ignored --exclude-standard -z -- >"$output" || return 1
        standard_ignored=()
        while IFS= read -r -d '' value; do standard_ignored+=("$value"); done <"$output"
    elif [[ "$mode" == manifest ]]; then
        git -C "$root" ls-files --others --ignored --exclude-from=.worktreeinclude -z -- >"$output" || return 1
        manifest_matched=()
        while IFS= read -r -d '' value; do manifest_matched+=("$value"); done <"$output"
    else
        git -C "$root" ls-files --others --ignored --exclude-from="$mode" -z -- >"$output" || return 1
        pattern_matched=()
        while IFS= read -r -d '' value; do pattern_matched+=("$value"); done <"$output"
    fi
}

load_selection() {
    local source_root=$1
    local manifest="$source_root/.worktreeinclude"
    local line pattern match pattern_file has_match

    selection_manifest_present=false
    selection_files=()
    selection_patterns=()
    selection_missing=()
    selection_rejected_patterns=()
    selection_rejected_reasons=()

    if [[ ! -f "$manifest" ]]; then
        return 0
    fi
    selection_manifest_present=true

    if find_symlink "$source_root" "$manifest" true; then
        die ".worktreeinclude is or traverses a symbolic link."
        return 2
    fi
    if ! git -C "$source_root" ls-files --error-unmatch -- .worktreeinclude >/dev/null 2>&1; then
        die ".worktreeinclude must be tracked before it can authorize copying ignored files."
        return 2
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == '#'* ]] && continue
        selection_patterns+=("$line")
        if get_pattern_rejection_reason "$line"; then
            selection_rejected_patterns+=("$line")
            selection_rejected_reasons+=("$rejection_reason")
        fi
    done <"$manifest"

    load_ignored_files "$source_root" standard || {
        die "Git could not enumerate normally ignored files."
        return 2
    }
    load_ignored_files "$source_root" manifest || {
        die "Git could not apply .worktreeinclude."
        return 2
    }

    for match in "${manifest_matched[@]}"; do
        array_contains "$match" "${standard_ignored[@]}" && selection_files+=("$match")
    done

    for pattern in "${selection_patterns[@]}"; do
        [[ "$pattern" == '!'* ]] && continue
        get_pattern_rejection_reason "$pattern" && continue
        new_temp_file || return 2
        pattern_file=$new_temp_path
        printf '%s\n' "$pattern" >"$pattern_file"
        load_ignored_files "$source_root" "$pattern_file" || {
            die "Git could not evaluate a .worktreeinclude pattern."
            return 2
        }
        has_match=false
        for match in "${pattern_matched[@]}"; do
            if array_contains "$match" "${standard_ignored[@]}"; then
                has_match=true
                break
            fi
        done
        [[ "$has_match" == false ]] && selection_missing+=("$pattern")
    done
    return 0
}

assert_same_repository() {
    local source_common target_common
    source_common=$(common_git_directory "$1") || {
        die "Could not resolve the source repository's common Git directory."
        return 2
    }
    target_common=$(common_git_directory "$2") || {
        die "Could not resolve the target repository's common Git directory."
        return 2
    }
    if [[ "$source_common" != "$target_common" ]]; then
        die "Source and target are not worktrees of the same Git repository."
        return 2
    fi
}

provision_files() {
    local source_root=$1
    local target_root=$2
    local dry_run=${3-false}
    local pattern reason relative_path source_path target_path target_directory
    local copied=0 conflicts=0 rejected=0

    assert_same_repository "$source_root" "$target_root" || return 2
    load_selection "$source_root" || return 2
    if [[ "$selection_manifest_present" == false ]]; then
        write_record skipped .worktreeinclude "manifest not found in source worktree"
        return 0
    fi

    for pattern in "${selection_missing[@]}"; do
        write_record missing "$pattern" "no present Git-ignored source file matched"
    done
    for ((i = 0; i < ${#selection_rejected_patterns[@]}; i++)); do
        write_record rejected "${selection_rejected_patterns[$i]}" "${selection_rejected_reasons[$i]}"
        rejected=$((rejected + 1))
    done

    for relative_path in "${selection_files[@]}"; do
        if get_file_rejection_reason "$relative_path"; then
            write_record rejected "$relative_path" "$rejection_reason"
            rejected=$((rejected + 1))
            continue
        fi

        source_path="$source_root/$relative_path"
        target_path="$target_root/$relative_path"
        if ! path_inside_root "$source_root" "$source_path" || ! path_inside_root "$target_root" "$target_path"; then
            write_record rejected "$relative_path" "resolved path escapes a worktree root"
            rejected=$((rejected + 1))
            continue
        fi
        if find_symlink "$source_root" "$source_path" true; then
            write_record rejected "$relative_path" "source path traverses a symbolic link"
            rejected=$((rejected + 1))
            continue
        fi
        if [[ ! -f "$source_path" ]]; then
            write_record missing "$relative_path" "source file no longer exists or is not a regular file"
            continue
        fi
        if find_symlink "$target_root" "$target_path" false; then
            write_record rejected "$relative_path" "target path traverses a symbolic link"
            rejected=$((rejected + 1))
            continue
        fi
        if [[ -e "$target_path" || -L "$target_path" ]]; then
            write_record conflict "$relative_path" "target already exists; not overwritten"
            conflicts=$((conflicts + 1))
            continue
        fi
        if [[ "$dry_run" == true ]]; then
            write_record would-copy "$relative_path"
            copied=$((copied + 1))
            continue
        fi

        target_directory=${target_path%/*}
        if ! mkdir -p "$target_directory"; then
            write_record rejected "$relative_path" "could not create the target directory"
            rejected=$((rejected + 1))
            continue
        fi
        if find_symlink "$target_root" "$target_path" false; then
            write_record rejected "$relative_path" "target parent became a symbolic link"
            rejected=$((rejected + 1))
            continue
        fi

        # Bash noclobber opens the destination exclusively before cat runs, so a file that
        # appears after the existence check is preserved rather than overwritten.
        if (set -o noclobber; command cat "$source_path" >"$target_path") 2>/dev/null; then
            write_record copied "$relative_path"
            copied=$((copied + 1))
        else
            if [[ -e "$target_path" || -L "$target_path" ]]; then
                write_record conflict "$relative_path" "target already exists; not overwritten"
                conflicts=$((conflicts + 1))
            else
                write_record rejected "$relative_path" "copy failed"
                rejected=$((rejected + 1))
            fi
        fi
    done

    printf 'Summary: copied=%s conflicts=%s missing=%s rejected=%s\n' \
        "$copied" "$conflicts" "${#selection_missing[@]}" "$rejected"
    [[ "$rejected" -eq 0 ]]
}

show_add_usage() {
    printf '%s\n' 'Usage: git wt-add [--dry-run] [--skip-copy] [--open-code] -- <git worktree add arguments>'
}

show_copy_usage() {
    printf '%s\n' 'Usage: git wt-copy [--dry-run] [--source <existing-worktree-path>]'
}

open_worktree_in_code() {
    if ! command -v code >/dev/null 2>&1; then
        die "VS Code's 'code' command is not available on PATH."
        return 2
    fi
    code --new-window "$1" || {
        die "VS Code could not open the worktree."
        return 2
    }
}

show_handoff_reminder() {
    local worktree_path=$1

    printf '%s\n' 'Handoff reminder: continuity and uncommitted changes stay in this worktree.'
    printf '%s\n' 'Open this exact path in Claude Code, Codex, or Copilot:'
    printf '  %s\n' "$(display_text "$worktree_path")"
    printf '%s\n' 'Then say: Continue from project continuity.'
    printf '%s\n' 'Use a separate worktree for another unfinished task.'
}

find_primary_worktree() {
    local target_root=$1
    local common worktree_path git_directory
    common=$(common_git_directory "$target_root") || return 1
    load_worktree_paths "$target_root" || return 1
    primary_worktree=""
    for worktree_path in "${worktree_paths[@]}"; do
        [[ -d "$worktree_path" ]] || continue
        git_directory=$(git -C "$worktree_path" rev-parse --absolute-git-dir 2>/dev/null) || continue
        git_directory=$(canonical_directory "$git_directory") || continue
        if [[ "$git_directory" == "$common" ]]; then
            primary_worktree=$worktree_path
            return 0
        fi
    done
    return 1
}

add_command() {
    local dry_run=false skip_copy=false open_code=false separator_found=false
    local argument source_root target_root result
    local before_paths=() after_paths=() wrapper_args=() git_args=() added_paths=()

    for argument in "$@"; do
        [[ "$argument" == --help || "$argument" == -h ]] && {
            show_add_usage
            return 0
        }
        if [[ "$separator_found" == false && "$argument" == -- ]]; then
            separator_found=true
        elif [[ "$separator_found" == false ]]; then
            wrapper_args+=("$argument")
        else
            git_args+=("$argument")
        fi
    done
    if [[ "$separator_found" == false ]]; then
        die "Use -- to separate wrapper options from native 'git worktree add' arguments."
        return 2
    fi
    if [[ ${#git_args[@]} -eq 0 ]]; then
        die "Native 'git worktree add' arguments are required after --."
        return 2
    fi
    for argument in "${wrapper_args[@]}"; do
        case "$argument" in
            --dry-run) dry_run=true ;;
            --skip-copy) skip_copy=true ;;
            --open-code) open_code=true ;;
            *)
                die "Unknown wt-add option: $(display_text "$argument")"
                return 2
                ;;
        esac
    done

    source_root=$(repository_root "$PWD") || {
        die "Not inside a Git working tree."
        return 2
    }
    source_root=$(canonical_directory "$source_root") || return 2

    if [[ "$dry_run" == true ]]; then
        printf '%s\n' "[dry-run] git worktree add arguments accepted; Git will not be executed."
        if [[ "$skip_copy" == false ]]; then
            load_selection "$source_root" || return 2
            if [[ "$selection_manifest_present" == false ]]; then
                write_record skipped .worktreeinclude "manifest not found in source worktree"
            else
                for argument in "${selection_files[@]}"; do write_record eligible "$argument"; done
                for argument in "${selection_missing[@]}"; do
                    write_record missing "$argument" "no present Git-ignored source file matched"
                done
                for ((i = 0; i < ${#selection_rejected_patterns[@]}; i++)); do
                    write_record rejected "${selection_rejected_patterns[$i]}" "${selection_rejected_reasons[$i]}"
                done
                [[ ${#selection_rejected_patterns[@]} -gt 0 ]] && return 2
            fi
        fi
        [[ "$open_code" == true ]] && printf '%s\n' '[dry-run] VS Code will not be opened.'
        return 0
    fi

    load_worktree_paths "$source_root" || {
        die "Could not list Git worktrees."
        return 2
    }
    before_paths=("${worktree_paths[@]}")
    git -C "$source_root" worktree add "${git_args[@]}"
    result=$?
    [[ $result -ne 0 ]] && return "$result"

    load_worktree_paths "$source_root" || {
        die "Git created the worktree, but the updated worktree list could not be read."
        return 2
    }
    after_paths=("${worktree_paths[@]}")
    for target_root in "${after_paths[@]}"; do
        array_contains "$target_root" "${before_paths[@]}" || added_paths+=("$target_root")
    done
    if [[ ${#added_paths[@]} -ne 1 ]]; then
        die "Git created the worktree, but the new path could not be identified safely (found ${#added_paths[@]} new entries)."
        return 2
    fi
    target_root=${added_paths[0]}
    printf 'Worktree: %s\n' "$(display_text "$target_root")"

    if [[ "$skip_copy" == true ]]; then
        write_record skipped .worktreeinclude "copying disabled by --skip-copy"
    else
        provision_files "$source_root" "$target_root" || return 2
    fi
    if [[ "$open_code" == true ]]; then
        open_worktree_in_code "$target_root" || return 2
    fi
    show_handoff_reminder "$target_root"
    return 0
}

copy_command() {
    local dry_run=false source_argument="" argument target_root source_root
    while [[ $# -gt 0 ]]; do
        argument=$1
        shift
        case "$argument" in
            --help|-h)
                show_copy_usage
                return 0
                ;;
            --dry-run) dry_run=true ;;
            --source)
                if [[ $# -eq 0 ]]; then
                    die "--source requires a path."
                    return 2
                fi
                source_argument=$1
                shift
                ;;
            *)
                die "Unknown wt-copy option: $(display_text "$argument")"
                return 2
                ;;
        esac
    done

    target_root=$(repository_root "$PWD") || {
        die "Not inside a Git working tree."
        return 2
    }
    target_root=$(canonical_directory "$target_root") || return 2
    if [[ -n "$source_argument" ]]; then
        source_root=$(repository_root "$source_argument") || {
            die "The explicit source is not inside a Git working tree."
            return 2
        }
        source_root=$(canonical_directory "$source_root") || return 2
    else
        if ! find_primary_worktree "$target_root" || [[ -z "$primary_worktree" ]]; then
            die "The source worktree is ambiguous. Supply --source <existing-worktree-path>."
            return 2
        fi
        source_root=$(canonical_directory "$primary_worktree") || return 2
    fi

    assert_same_repository "$source_root" "$target_root" || return 2
    if [[ "$source_root" == "$target_root" ]]; then
        die "Source and target must be different worktrees."
        return 2
    fi
    printf 'Source worktree: %s\n' "$(display_text "$source_root")"
    printf 'Target worktree: %s\n' "$(display_text "$target_root")"
    provision_files "$source_root" "$target_root" "$dry_run"
}

main() {
    if [[ $# -eq 0 ]]; then
        printf '%s\n' 'Usage: git-worktree-provision.sh <add|copy> [arguments]'
        return 2
    fi
    local command=$1
    shift
    case "$command" in
        add) add_command "$@" ;;
        copy) copy_command "$@" ;;
        *)
            die "Unknown command: $(display_text "$command")"
            return 2
            ;;
    esac
}

main "$@"
