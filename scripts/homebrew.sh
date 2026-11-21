#!/bin/bash
#
# Homebrew and everything in homebrew/Brewfile. Safe to run again.
#   no Homebrew                      -> installs it (official script; asks for your password once)
#   analytics on                     -> turned off
#   something in the Brewfile missing -> installed; what is already there is never upgraded (updates stay manual)
#   installed but not in the Brewfile -> listed only, nothing is removed
#
# Usage: scripts/homebrew.sh [-n]    (-n: dry run, only report)
#

set -euo pipefail

DRY=false
[ "${1:-}" = "-n" ] && DRY=true

# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

BREWFILE="$REPO/homebrew/Brewfile"
BREW=/opt/homebrew/bin/brew
INSTALLER=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

[ "$(uname -s)" = Darwin ] || { echo "macOS only." >&2; exit 1; }
[ "$(uname -m)" = arm64 ] || { echo "Apple Silicon only: the repo's configs use /opt/homebrew." >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "Run as your user, not with sudo." >&2; exit 1; }
[ -f "$BREWFILE" ] || { echo "No Brewfile at $BREWFILE." >&2; exit 1; }

if $DRY; then
    section "dry run: nothing is changed"
    # brew bundle runs `brew update` first, which updates Homebrew itself: not in a dry run
    export HOMEBREW_NO_AUTO_UPDATE=1
fi

section "command line tools"
if xcode-select -p >/dev/null 2>&1; then
    say found "$(xcode-select -p)"
else
    say note "not installed: the Homebrew installer adds them"
fi

section "homebrew ($BREW)"
if [ -x "$BREW" ]; then
    say found "$("$BREW" --version | awk 'NR == 1')"
elif $DRY; then
    say note "not installed: a real run installs it; the steps below need it, so the dry run stops here"
    exit 0
else
    say note "not installed: installing (your password, once)"
    # Non-interactive mode only uses sudo -n: cache the password first
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$INSTALLER")"
    [ -x "$BREW" ] || { echo "The installer ran, but $BREW is not there." >&2; exit 1; }
    say made "$("$BREW" --version | awk 'NR == 1')"
fi
# brew on PATH for the rest of this script (fish and zsh get it from their own configs)
eval "$("$BREW" shellenv bash)"

section "analytics"
state=$(brew analytics state 2>&1 || true)
case "$state" in
    *isabled*) say ok "already off" ;;
    *)
        run brew analytics off
        say made "turned off"
        ;;
esac

section "Brewfile ($(short "$BREWFILE"))"
if brew bundle check --no-upgrade --file "$BREWFILE" >/dev/null 2>&1; then
    say ok "everything in it is installed"
else
    say note "missing:"
    brew bundle check --no-upgrade --verbose --file "$BREWFILE" 2>&1 | indent || true
    # --no-upgrade: install what is missing, leave the rest at its version
    run brew bundle install --no-upgrade --file "$BREWFILE"
    if $DRY; then
        say skip "dry run: brew bundle install --no-upgrade not run"
    elif brew bundle check --no-upgrade --file "$BREWFILE" >/dev/null 2>&1; then
        say made "everything in it is installed"
    else
        say note "still missing after the install (see brew's output above):"
        brew bundle check --no-upgrade --verbose --file "$BREWFILE" 2>&1 | indent || true
    fi
fi

section "installed but not in the Brewfile (nothing is removed)"
wanted=$(awk -F'"' '/^(brew|cask) "/ { n = $2; sub(/.*\//, "", n); print n }' "$BREWFILE" | sort -u)
have=$({ brew leaves --installed-on-request; brew list --cask -1; } 2>/dev/null | sed 's#.*/##' | sort -u)
extra=$(comm -13 <(printf '%s\n' "$wanted") <(printf '%s\n' "$have") | sed '/^$/d')
if command -v code >/dev/null 2>&1; then
    wanted_ext=$(awk -F'"' '/^vscode "/ { print tolower($2) }' "$BREWFILE" | sort -u)
    have_ext=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u)
    extra_ext=$(comm -13 <(printf '%s\n' "$wanted_ext") <(printf '%s\n' "$have_ext") | sed '/^$/d')
else
    extra_ext=''
fi
if [ -z "$extra" ] && [ -z "$extra_ext" ]; then
    say ok "nothing extra"
else
    for name in $extra; do say note "$name (add it to the Brewfile, or brew uninstall it)"; done
    for name in $extra_ext; do say note "vscode $name (add it to the Brewfile, or uninstall it in VS Code)"; done
fi
