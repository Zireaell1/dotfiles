#!/bin/bash
#
# Creates the per-machine files the repo leaves out on purpose (gitignored):
#   ~/.gitconfig.local               git identity + signing key, loaded by the repo's gitconfig
#   ~/.config/git/allowed_signers    your signing key, so git can verify your signatures locally
#   ~/.ssh/config.local              named hosts, loaded by the repo's ssh config
#   ~/.hushlogin                     hides macOS "Last login: ..." in new terminal windows
# Existing files are never overwritten. Safe to run again: it then reports what is there.
#

set -euo pipefail

GITLOCAL="$HOME/.gitconfig.local"
SIGNERS="$HOME/.config/git/allowed_signers"
SSHLOCAL="$HOME/.ssh/config.local"

# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

section "git identity ($(short "$GITLOCAL"))"
if [ -e "$GITLOCAL" ]; then
    say skip "exists, not changed:"
    say "" "  name       $(git config --file "$GITLOCAL" user.name || echo '(not set)')"
    say "" "  email      $(git config --file "$GITLOCAL" user.email || echo '(not set)')"
    say "" "  signingkey $(short "$(git config --file "$GITLOCAL" user.signingkey || echo '(not set)')")"
else
    name=$(ask "Git name" "$(git config --global user.name || id -un)")
    echo "       GitHub noreply address: Settings > Emails > 'Keep my email addresses private'"
    email=$(ask "Git email" "$(git config --global user.email || true)")
    [ -n "$email" ] || { echo "An email is required." >&2; exit 1; }
    signkey=$(ask "SSH signing key (public part)" "$SIGNKEY_DEFAULT")
    signkey="${signkey/#\~/$HOME}"
    if [ -f "$signkey" ]; then
        say found "signing key $(short "$signkey") ($(keyinfo "$signkey"))"
    else
        say note "$(short "$signkey") does not exist yet; create it, then add it in GitHub as a Signing key"
    fi

    git config --file "$GITLOCAL" user.name "$name"
    git config --file "$GITLOCAL" user.email "$email"
    git config --file "$GITLOCAL" user.signingkey "$signkey"
    chmod 600 "$GITLOCAL"
    say made "$(short "$GITLOCAL"): $name <$email>, key $(short "$signkey")"
fi

section "signature check ($(short "$SIGNERS"))"
email=$(git config --file "$GITLOCAL" user.email || true)
signkey=$(git config --file "$GITLOCAL" user.signingkey || true)
signkey="${signkey/#\~/$HOME}"
if [ -e "$SIGNERS" ]; then
    signers=$(grep -v '^#' "$SIGNERS" | cut -d' ' -f1 | paste -sd, - || true)
    if [ ! -f "$signkey" ]; then
        say skip "exists, not changed: signers ${signers:-(none)} (no signing key to compare)"
    elif grep -qF "$(cut -d' ' -f2 "$signkey")" "$SIGNERS"; then
        say ok "has your signing key (signers ${signers:-(none)})"
    else
        say note "exists, but your signing key $(short "$signkey") is NOT in it: git will not verify your own commits"
    fi
elif [ -z "$email" ] || [ ! -f "$signkey" ]; then
    say note "no email or signing key yet; run this again once $(short "${signkey:-the key}") exists"
else
    if [ ! -d "$(dirname "$SIGNERS")" ]; then
        mkdir -p "$(dirname "$SIGNERS")"
        say made "$(short "$(dirname "$SIGNERS")")/"
    fi

    printf '%s namespaces="git" %s\n' "$email" "$(cut -d' ' -f1,2 "$signkey")" > "$SIGNERS"
    say made "$(short "$SIGNERS"): $email -> $(keyinfo "$signkey")"
fi

section "ssh hosts ($(short "$SSHLOCAL"))"
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    say made "$(short "$HOME/.ssh")/ (700)"
fi
if [ -e "$SSHLOCAL" ]; then
    hosts=$(awk 'tolower($1) == "host" { $1 = ""; sub(/^ /, ""); printf "%s%s", sep, $0; sep = ", " }' "$SSHLOCAL")
    say skip "exists, not changed: hosts ${hosts:-(none yet)}"
else
    cat > "$SSHLOCAL" <<'HOSTS'
# Hosts of this machine only (not in the dotfiles repo). Example:
#
# Host name
#   HostName 192.168.x.x
#   User someone
#   IdentityFile ~/.ssh/id_ed25519_name
HOSTS
    chmod 600 "$SSHLOCAL"
    say made "$(short "$SSHLOCAL") (commented example only: add your hosts there)"
fi

key="$HOME/.ssh/id_ed25519"
if [ -f "$key.pub" ]; then
    say found "key $(short "$key") ($(keyinfo "$key.pub"))"
else
    say note "key $(short "$key") missing (named in the repo's ssh/config)"
fi

HUSH="$HOME/.hushlogin"
section "login message ($(short "$HUSH"))"
if [ -e "$HUSH" ]; then
    say ok "exists"
else
    touch "$HUSH"
    say made "$(short "$HUSH") (empty)"
fi
