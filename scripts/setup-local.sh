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

REPO=$(cd "$(dirname "$0")/.." && pwd)
GITLOCAL="$HOME/.gitconfig.local"
SIGNERS="$HOME/.config/git/allowed_signers"
SSHLOCAL="$HOME/.ssh/config.local"
SIGNKEY_DEFAULT="$HOME/.ssh/id_ed25519_github_signing.pub"

say() { printf '%-6s %s\n' "$1" "$2"; }

short() {
    case "$1" in
        "$HOME"*) printf '~%s\n' "${1#"$HOME"}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

keyinfo() { ssh-keygen -lf "$1" 2>/dev/null | awk '{ gsub(/[()]/, "", $NF); print $NF, $2 }' || echo "not a valid public key"; }

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

echo "== git identity ($(short "$GITLOCAL"))"
if [ -e "$GITLOCAL" ]; then
    say skip "exists, not changed:"
    say "" "  name       $(git config --file "$GITLOCAL" user.name || echo '(not set)')"
    say "" "  email      $(git config --file "$GITLOCAL" user.email || echo '(not set)')"
    say "" "  signingkey $(short "$(git config --file "$GITLOCAL" user.signingkey || echo '(not set)')")"
else
    name=$(ask "Git name" "$(id -un)")
    echo "       GitHub noreply address: Settings > Emails > 'Keep my email addresses private'"
    email=$(ask "Git email" "")
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

echo "== signature check ($(short "$SIGNERS"))"
email=$(git config --file "$GITLOCAL" user.email || true)
signkey=$(git config --file "$GITLOCAL" user.signingkey || true)
signkey="${signkey/#\~/$HOME}"
if [ -e "$SIGNERS" ]; then
    signers=$(grep -v '^#' "$SIGNERS" | cut -d' ' -f1 | paste -sd, - || true)
    say skip "exists, not changed: signers ${signers:-(none)}"
    if [ -f "$signkey" ] && ! grep -qF "$(cut -d' ' -f2 "$signkey")" "$SIGNERS"; then
        say note "your signing key $(short "$signkey") is NOT in it: git will not verify your own commits"
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

echo "== ssh hosts ($(short "$SSHLOCAL"))"
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
for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519_github_signing"; do
    if [ -f "$key.pub" ]; then
        say found "key $(short "$key") ($(keyinfo "$key.pub"))"
    else
        say note "key $(short "$key") missing (named in the repo's ssh/config)"
    fi
done

HUSH="$HOME/.hushlogin"
echo "== login message ($(short "$HUSH"))"
if [ -e "$HUSH" ]; then
    say skip "exists"
else
    touch "$HUSH"
    say made "$(short "$HUSH") (empty)"
fi

echo "== links (made by hand / the install script, only checked here)"
for pair in "$HOME/.gitconfig:$REPO/git/.gitconfig" "$HOME/.ssh/config:$REPO/ssh/config"; do
    target="${pair%%:*}"
    source="${pair#*:}"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        say ok "$(short "$target") -> $(short "$source")"
    elif [ -e "$target" ] || [ -L "$target" ]; then
        say note "$(short "$target") is not the repo's (the .local files above stay unused until it is)"
    else
        say note "$(short "$target") missing: ln -sfn $(short "$source") $(short "$target")"
    fi
done
