#!/bin/bash
#
# Creates the per-machine files the repo leaves out on purpose (gitignored):
#   ~/.gitconfig.local               git identity + signing key, loaded by the repo's gitconfig
#   ~/.config/git/allowed_signers    your signing key, so git can verify your signatures locally
#   ~/.ssh/config.local              named hosts, loaded by the repo's ssh config
#   ~/.hushlogin                     hides macOS "Last login: ..." in new terminal windows
# Existing files are never overwritten. Safe to run again.
#

set -euo pipefail

GITLOCAL="$HOME/.gitconfig.local"
SIGNERS="$HOME/.config/git/allowed_signers"
SSHLOCAL="$HOME/.ssh/config.local"
SIGNKEY_DEFAULT="$HOME/.ssh/id_ed25519_github_signing.pub"

ask() {
    local answer
    if [ -n "$2" ]; then
        read -r -p "$1 [$2]: " answer
        echo "${answer:-$2}"
    else
        read -r -p "$1: " answer
        echo "$answer"
    fi
}

if [ -e "$GITLOCAL" ]; then
    echo "skip  $GITLOCAL exists"
else
    name=$(ask "Git name" "$(id -un)")
    echo "      GitHub noreply address: Settings > Emails > 'Keep my email addresses private'"
    email=$(ask "Git email" "")
    [ -n "$email" ] || { echo "An email is required." >&2; exit 1; }
    signkey=$(ask "SSH signing key (public part)" "$SIGNKEY_DEFAULT")
    [ -f "${signkey/#\~/$HOME}" ] || echo "note  $signkey does not exist yet; create it, then add it in GitHub as a Signing key"

    git config --file "$GITLOCAL" user.name "$name"
    git config --file "$GITLOCAL" user.email "$email"
    git config --file "$GITLOCAL" user.signingkey "$signkey"
    chmod 600 "$GITLOCAL"
    echo "made  $GITLOCAL"
fi

if [ -e "$SIGNERS" ]; then
    echo "skip  $SIGNERS exists"
else
    email=$(git config --file "$GITLOCAL" user.email || true)
    signkey=$(git config --file "$GITLOCAL" user.signingkey || true)
    signkey="${signkey/#\~/$HOME}"
    if [ -z "$email" ] || [ ! -f "$signkey" ]; then
        echo "note  no email or signing key yet; run this again once ${signkey:-the key} exists"
    else
        mkdir -p "$(dirname "$SIGNERS")"
        printf '%s namespaces="git" %s\n' "$email" "$(cut -d' ' -f1,2 "$signkey")" > "$SIGNERS"
        echo "made  $SIGNERS"
    fi
fi

if [ -e "$SSHLOCAL" ]; then
    echo "skip  $SSHLOCAL exists"
else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    cat > "$SSHLOCAL" <<'HOSTS'
# Hosts of this machine only (not in the dotfiles repo). Example:
#
# Host name
#   HostName 192.168.x.x
#   User someone
#   IdentityFile ~/.ssh/id_ed25519_name
HOSTS
    chmod 600 "$SSHLOCAL"
    echo "made  $SSHLOCAL (add your hosts there)"
fi

if [ -e "$HOME/.hushlogin" ]; then
    echo "skip  ~/.hushlogin exists"
else
    touch "$HOME/.hushlogin"
    echo "made  ~/.hushlogin"
fi
