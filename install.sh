#!/bin/bash
#
# Sets up Mac from the repo, one step after another. Every step is safe to run again
#   1 scripts/homebrew.sh     Homebrew + the Brewfile
#   2 scripts/ssh-keys.sh     SSH keys (created if missing, into the Keychain)
#   3 scripts/setup-local.sh  per-machine files (git identity, ssh hosts)
#   4 scripts/link.sh         the repo's configs linked into place
#   5 scripts/workspace.sh    folders + the public repos
#
# Usage: ./install.sh [-n]    (-n: dry run; setup-local.sh has none, so it is skipped)
#

set -euo pipefail

DRY=false
[ "${1:-}" = "-n" ] && DRY=true

# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/scripts/lib.sh"

[ "$(uname -s)" = Darwin ] || { echo "macOS only." >&2; exit 1; }

NOTES_FILE=$(mktemp "${TMPDIR:-/tmp}/install-notes.XXXXXX")
trap 'rm -f "$NOTES_FILE"' EXIT
export INSTALL_NOTES=$NOTES_FILE

STEPS="homebrew ssh-keys setup-local link workspace"
NO_DRY_RUN="setup-local"

section "install: $(short "$REPO") on macOS $(sw_vers -productVersion 2>/dev/null || echo '?')$($DRY && echo ', dry run')"

failed=''
for step in $STEPS; do
    script="$REPO/scripts/$step.sh"
    printf '\n'
    section "step: $step"
    if [ ! -x "$script" ]; then
        say note "$(short "$script") missing or not executable (skipped)"
        continue
    fi
    if $DRY; then
        case " $NO_DRY_RUN " in
            *" $step "*)
                say skip "no dry run in $step.sh (it asks questions and writes files); a real run does it"
                continue
                ;;
        esac
        args=(-n)
    else
        args=()
    fi
    if ! INSTALL_STEP=$step "$script" ${args[@]+"${args[@]}"}; then
        failed=$step
        break
    fi
done

unset INSTALL_NOTES
printf '\n'
if [ -s "$NOTES_FILE" ]; then
    section "left for you (every note above)"
    while IFS= read -r line; do say note "$line"; done < "$NOTES_FILE"
else
    section "nothing left to do from the steps"
fi
printf '\n'
if [ -n "$failed" ]; then
    section "stopped: $failed failed"
    say note "fix it, then run ./install.sh again (the steps that already worked just report ok)"
    exit 1
fi
section "done$($DRY && echo ' (dry run: nothing was changed)')"
say found "the manual steps (Apple ID, permissions, app logins) are in README.md"
