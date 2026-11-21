#!/bin/bash
#
# SSH keys this Mac needs: every IdentityFile in the repo's ssh/config and ~/.ssh/config.local,
# plus git's signing key. Safe to run again.
#   key there, passphrase in the Keychain  -> ok
#   key there, not in the Keychain         -> added (ssh-add asks for the passphrase once)
#   key without a passphrase               -> reported, left alone
#   key missing                            -> created (ssh-keygen asks for a passphrase), added to the
#                                             Keychain, and what is left to do is printed
#                                             (GitHub signing key / authorized_keys on a host)
# Never copies, restores or uploads a private key.
#
# Usage: scripts/ssh-keys.sh [-n]    (-n: dry run, only report)
#

set -euo pipefail

DRY=false
[ "${1:-}" = "-n" ] && DRY=true

# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"

SSHREPO="$REPO/ssh/config"
SSHLOCAL="$HOME/.ssh/config.local"

[ "$(uname -s)" = Darwin ] || { echo "macOS only (Keychain)." >&2; exit 1; }

$DRY && section "dry run: nothing is changed"

# key<TAB>where, one line per key, every place that names it joined
list_keys() {
    local conf label signpub
    for conf in "$SSHREPO" "$SSHLOCAL"; do
        [ -f "$conf" ] || continue
        label=$(short "$conf")
        [ "$conf" = "$SSHREPO" ] && label="the repo's ssh/config"
        awk -v src="$label" '
            tolower($1) == "host" { $1 = ""; sub(/^ /, ""); host = $0 }
            tolower($1) == "identityfile" { print $2 "\t" (host == "" ? "(all hosts)" : "Host " host) " in " src }
        ' "$conf"
    done
    signpub=$(git config --global user.signingkey 2>/dev/null || echo "$SIGNKEY_DEFAULT")
    printf '%s\t%s\n' "${signpub%.pub}" "git signing key"
}

# too_open KEY: true if group or others can read or write it (ssh refuses such a key)
too_open() { [ -n "$(find "$1" -prune \( -perm -g+r -o -perm -g+w -o -perm -o+r -o -perm -o+w \) 2>/dev/null)" ]; }

# in_keychain KEY: true if macOS stored its passphrase (ssh-add --apple-use-keychain). Read-only lookup.
in_keychain() { security find-generic-password -l "SSH: $1" >/dev/null 2>&1; }

# next_steps KEY WHERE: what a new key still needs, outside this Mac
next_steps() {
    case "$2" in
        *"git signing key"*)
            say note "add it on GitHub: github.com/settings/keys > New SSH key > Key type: Signing key"
            ;;
    esac
    case "$2" in
        *Host*)
            say note "add it to ~/.ssh/authorized_keys on the host(s) above (password login is off on Nova/Orion:"
            say "" "  use the recovery key or the console, see PENDING-PASTES / README)"
            ;;
    esac
    say "" "  public key: $(cat "$1.pub")"
}

list_keys | sed "s#^~#$HOME#" | sort | awk -F'\t' '
    $1 == prev { where = where ", " $2; next }
    NR > 1 { print prev "\t" where }
    { prev = $1; where = $2 }
    END { if (NR) print prev "\t" where }
' | while IFS="$(printf '\t')" read -r key where; do
    section "$(short "$key") ($where)"

    if [ ! -f "$key" ]; then
        if [ -f "$key.pub" ]; then
            say note "only the .pub is here; the private key is on another machine (left alone)"
            continue
        fi
        say note "missing: creating it (ssh-keygen asks for a passphrase)"
        if $DRY; then
            say skip "dry run: ssh-keygen and ssh-add not run"
            continue
        fi
        mkdir -p "$(dirname "$key")"
        chmod 700 "$HOME/.ssh"
        if ! ssh-keygen -t ed25519 -a 100 -C "$(basename "$key") $(date +%Y-%m-%d)" -f "$key" </dev/tty; then
            say note "ssh-keygen failed or was cancelled: no key made"
            continue
        fi
        say made "$(short "$key") ($(keyinfo "$key.pub"))"
        if ssh-add --apple-use-keychain "$key" </dev/tty; then
            say made "passphrase in the Keychain, key in the agent"
        else
            say note "not added to the Keychain (run this script again)"
        fi
        next_steps "$key" "$where"
        continue
    fi

    if [ -f "$key.pub" ]; then
        say found "$(keyinfo "$key.pub")"
    else
        say note "no .pub next to it: ssh-keygen -y -f $(short "$key") > $(short "$key").pub"
    fi

    if too_open "$key"; then
        run chmod 600 "$key"
        say made "permissions set to 600 (group/others could read it; ssh refuses such keys)"
        if $DRY; then
            say skip "dry run: passphrase and Keychain not checked until the permissions are fixed"
            continue
        fi
    fi

    if ssh-keygen -y -P '' -f "$key" >/dev/null 2>&1; then
        say note "no passphrase (left alone; add one: ssh-keygen -p -f $(short "$key"))"
    elif in_keychain "$key"; then
        say ok "passphrase in the Keychain"
    else
        say note "passphrase not in the Keychain: adding it (ssh-add asks once)"
        if $DRY; then
            say skip "dry run: ssh-add --apple-use-keychain not run"
        else
            if ssh-add --apple-use-keychain "$key" </dev/tty; then
                say made "passphrase in the Keychain, key in the agent"
            else
                say note "not added (wrong passphrase or cancelled)"
            fi
        fi
    fi
done
