#!/bin/bash
#
# Folders and repos from workspace.txt (paths relative to ~). Safe to run again.
#   folder missing                   -> created
#   repo missing                     -> cloned (public repos: no login; a private one fails, never prompts)
#   repo there, same remote          -> ok, plus a note for uncommitted changes or unpushed commits
#   anything else at a repo's path   -> reported, left alone
# Never pulls, resets or changes an existing clone.
#
# Usage: scripts/workspace.sh [-n]    (-n: dry run, only report)
#

set -euo pipefail

DRY=false
[ "${1:-}" = "-n" ] && DRY=true

# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

LIST="$REPO/workspace.txt"
[ -f "$LIST" ] || { echo "No list at $LIST." >&2; exit 1; }

# A clone must never stop to ask for a login: a wrong or private URL just fails
export GIT_TERMINAL_PROMPT=0

$DRY && section "dry run: nothing is changed"

do_dir() {
    local dst="$HOME/$1"
    if [ -d "$dst" ]; then
        say ok "$(short "$dst")/"
    elif [ -e "$dst" ]; then
        say note "$(short "$dst") exists but is not a folder (left alone)"
    else
        run mkdir -p "$dst"
        say made "$(short "$dst")/"
    fi
}

# same_url A B: equal, ignoring a trailing .git and /
same_url() {
    local a="${1%/}" b="${2%/}"
    [ "${a%.git}" = "${b%.git}" ]
}

do_repo() {
    local dst="$HOME/$1" url="$2" remote dirty ahead
    if [ ! -e "$dst" ]; then
        if $DRY; then
            say made "$(short "$dst") <- $url (dry run: not cloned)"
        elif git -c credential.helper= clone --quiet "$url" "$dst"; then
            say made "$(short "$dst") <- $url"
        else
            say note "clone of $url failed (private, renamed, or no network?)"
        fi
        return
    fi
    if ! git -C "$dst" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        say note "$(short "$dst") exists but is not a git repo (left alone)"
        return
    fi
    remote=$(git -C "$dst" remote get-url origin 2>/dev/null || true)
    if ! same_url "$remote" "$url"; then
        say note "$(short "$dst") is a clone of ${remote:-(no origin)}, not $url (left alone)"
        return
    fi
    say ok "$(short "$dst") ($url)"
    dirty=$(git -C "$dst" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "$dirty" -eq 0 ] || say note "$dirty uncommitted change(s)"
    if ahead=$(git -C "$dst" rev-list --count '@{upstream}..HEAD' 2>/dev/null) && [ "$ahead" -gt 0 ]; then
        say note "$ahead unpushed commit(s)"
    fi
}

section "folders"
while read -r kind path url; do
    if [ "$kind" = dir ]; then do_dir "$path"; fi
done < <(grep -v '^[[:space:]]*\(#\|$\)' "$LIST")

section "repos"
while read -r kind path url; do
    if [ "$kind" = repo ]; then do_repo "$path" "$url"; fi
done < <(grep -v '^[[:space:]]*\(#\|$\)' "$LIST")
