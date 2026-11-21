#!/bin/bash
#
# Links the repo's configs into place. Safe to run again: correct links are left alone.
#   real file in the way      -> moved to <file>.bak (once; later ones get a timestamp), then linked
#   link pointing elsewhere   -> left alone, reported with the command to fix it
#   file not in the repo yet  -> skipped
#
# Usage: scripts/link.sh [-n]    (-n: dry run, only report)
#

set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
DRY=false
[ "${1:-}" = "-n" ] && DRY=true

# Colours only on a terminal, and not when NO_COLOR is set
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_CYAN=$'\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_YELLOW='' C_CYAN=''
fi

# say TAG MESSAGE: one aligned line per finding or action, coloured by tag
say() {
    local c=''
    case "$1" in
        made | ok) c=$C_GREEN ;;
        found) c=$C_CYAN ;;
        note | moved) c=$C_YELLOW ;;
        skip) c=$C_DIM ;;
    esac
    printf '%s%-6s%s %s\n' "$c" "$1" "$C_RESET" "$2"
}
# section TITLE: bold header
section() { printf '%s== %s%s\n' "$C_BOLD" "$1" "$C_RESET"; }
short() {
    case "$1" in
        "$HOME"*) printf '~%s\n' "${1#"$HOME"}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}
run() { $DRY || "$@"; }

# link SOURCE (relative to the repo) TARGET
link() {
    local src="$REPO/$1" dst="$2" bak
    if [ ! -e "$src" ]; then
        say skip "$1 not in the repo yet"
        return
    fi
    if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$src" ]; then
            say ok "$(short "$dst") -> $1"
        else
            say note "$(short "$dst") links to $(short "$(readlink "$dst")"), left alone; to switch: ln -sfn $(short "$src") $(short "$dst")"
        fi
        return
    fi
    if [ ! -d "$(dirname "$dst")" ]; then
        run mkdir -p "$(dirname "$dst")"
        say made "$(short "$(dirname "$dst")")/"
    fi
    if [ -e "$dst" ]; then
        bak="$dst.bak"
        [ -e "$bak" ] && bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
        run mv "$dst" "$bak"
        say moved "$(short "$dst") -> $(short "$bak")"
    fi
    run ln -s "$src" "$dst"
    say made "$(short "$dst") -> $1"
}

$DRY && section "dry run: nothing is changed"

[ -d "$HOME/.ssh" ] || { run mkdir -p "$HOME/.ssh"; run chmod 700 "$HOME/.ssh"; say made "$(short "$HOME/.ssh")/ (700)"; }

link fish/config.fish        "$HOME/.config/fish/config.fish"
for f in "$REPO"/fish/functions/*.fish; do
    [ -e "$f" ] || continue
    link "fish/functions/$(basename "$f")" "$HOME/.config/fish/functions/$(basename "$f")"
done
link ghostty/config.ghostty  "$HOME/.config/ghostty/config.ghostty"
link git/.gitconfig          "$HOME/.gitconfig"
link ssh/config              "$HOME/.ssh/config"
link vscode/settings.json    "$HOME/Library/Application Support/Code/User/settings.json"
link zsh/zprofile            "$HOME/.zprofile"

for f in "$HOME/.config/ghostty/config" \
         "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty" \
         "$HOME/Library/Application Support/com.mitchellh.ghostty/config"; do
    if [ -s "$f" ]; then
        say note "$(short "$f") also loads and overrides the repo's Ghostty config: merge it in, then remove it"
    fi
done
