# shellcheck shell=bash
#
# Shared helpers for the scripts in this folder. Sourced, not run:
#   . "$(dirname "$0")/lib.sh"
#
# A script with a dry run sets DRY=true before calling run (default: false).
#

# The repo root, whichever script sourced this
# shellcheck disable=SC2034  # used by the scripts that source this file
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Git's signing key (public part) when ~/.gitconfig.local doesn't name one yet
# shellcheck disable=SC2034  # used by the scripts that source this file
SIGNKEY_DEFAULT="$HOME/.ssh/id_ed25519_github_signing.pub"

# Colours only on a terminal, and not when NO_COLOR is set
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_MAGENTA=$'\033[35m' C_CYAN=$'\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_YELLOW='' C_MAGENTA='' C_CYAN=''
fi

# say TAG MESSAGE: one aligned line per finding or action, coloured by tag. Tags:
#   made   something was created or changed        moved  a file was moved aside (.bak)
#   ok     checked: already as it should be         skip   left alone on purpose, state not judged
#   found  a fact worth showing (path, version)     note   needs your attention
# ok vs skip: "ok" is a confirmation (it checked); "skip" only says nothing was done
# (your file is not overwritten, not in the repo yet, dry run).
say() {
    local c=''
    case "$1" in
        ok) c=$C_GREEN ;;
        made | moved) c=$C_YELLOW ;;
        found) c=$C_CYAN ;;
        note) c=$C_MAGENTA ;;
        skip) c=$C_DIM ;;
    esac
    printf '%s%-6s%s %s\n' "$c" "$1" "$C_RESET" "$2"
    if [ "$1" = note ] && [ -n "${INSTALL_NOTES:-}" ]; then
        printf '%s: %s\n' "${INSTALL_STEP:-?}" "$2" >> "$INSTALL_NOTES"
    fi
}

# section TITLE: bold header
section() { printf '%s== %s%s\n' "$C_BOLD" "$1" "$C_RESET"; }

# short PATH: ~ instead of $HOME, for display
short() {
    case "$1" in
        "$HOME"*) printf '~%s\n' "${1#"$HOME"}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# run COMMAND...: runs it, unless DRY=true
run() { ${DRY:-false} || "$@"; }

# indent: command output lined up under a say line
indent() { sed 's/^/       /'; }

# keyinfo PUBFILE: "ED25519 SHA256:..." (type and fingerprint)
keyinfo() { ssh-keygen -lf "$1" 2>/dev/null | awk '{ gsub(/[()]/, "", $NF); print $NF, $2 }' || echo "not a valid public key"; }

# ask PROMPT DEFAULT -> answer on stdout (default when Enter is pressed)
ask() {
    local answer
    if [ -n "$2" ]; then
        read -r -p "$1 [$(short "$2")]: " answer
        echo "${answer:-$2}"
    else
        read -r -p "$1: " answer
        echo "$answer"
    fi
}
