#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 077
SERVICE='io.github.dennisimoo.WakeBeeFree.helper'
INSTALL_DIR='/Library/PrivilegedHelperTools/io.github.dennisimoo.WakeBeeFree'
PLIST="/Library/LaunchDaemons/$SERVICE.plist"
[[ $EUID -eq 0 && $# -eq 3 ]] || { echo 'Administrator approval is required.' >&2; exit 77; }
ACTION=$1
APP=$2
CLIENT_UID=$3
[[ "$ACTION" == install || "$ACTION" == uninstall ]] || exit 2
[[ "$CLIENT_UID" =~ ^[0-9]+$ && "$CLIENT_UID" -gt 0 ]] || exit 2

# Never follow an installed-path symlink or execute a replaceable root helper.
for directory in /Library/PrivilegedHelperTools /Library/LaunchDaemons "$INSTALL_DIR"; do
    [[ ! -L "$directory" ]] || { echo 'Unsafe helper directory.' >&2; exit 77; }
    if [[ -e "$directory" ]]; then
        [[ -d "$directory" && $(stat -f '%u' "$directory") == 0 ]] || exit 77
        permissions=$(stat -f '%Lp' "$directory")
        (( (8#$permissions & 8#022) == 0 )) || exit 77
    fi
done
if [[ -e "$PLIST" || -L "$PLIST" ]]; then
    [[ -f "$PLIST" && ! -L "$PLIST" && $(stat -f '%u' "$PLIST") == 0 ]] || exit 77
    permissions=$(stat -f '%Lp' "$PLIST")
    (( (8#$permissions & 8#022) == 0 )) || exit 77
fi

# Another app must not own a concurrent sleep-setting recovery journal.
for old in com.awakemac.helper app.wakebee.helper; do
    if launchctl print "system/$old" >/dev/null 2>&1 || [[ -e "/private/var/db/$old/recovery.json" ]]; then
        echo 'End sessions and remove the other WakeBee/ AwakeMac closed-lid helper first.' >&2
        exit 1
    fi
done

# Stage and verify BEFORE touching a functioning installation. Staging is root
# owned, so user processes cannot swap binaries after signature verification.
install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools /Library/LaunchDaemons
STAGE=$(mktemp -d /Library/PrivilegedHelperTools/.wakebee-free.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
if [[ "$ACTION" == install ]]; then
    [[ -d "$APP" && ! -L "$APP" ]] || exit 2
    ditto "$APP" "$STAGE/App.app"
    [[ -z $(find "$STAGE/App.app" -type l -print -quit) ]] || { echo 'Symlinked app contents are not supported.' >&2; exit 77; }
    chown -R root:wheel "$STAGE"
    codesign --verify --deep --strict "$STAGE/App.app"
    CONTENTS="$STAGE/App.app/Contents"
    [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$CONTENTS/Info.plist") == io.github.dennisimoo.WakeBeeFree ]] || exit 77
    [[ ! -L "$CONTENTS/Library/HelperTools/WakeBeeHelper" ]] || exit 77
    REQUIREMENT=$(/bin/bash "$CONTENTS/Resources/code_requirement.sh" "$CONTENTS/MacOS/WakeBee")
    # Verify the bundled peer requirement matches the actual helper.
    codesign --verify --strict -R "=$(cat "$CONTENTS/Resources/helper-requirement.txt")" "$CONTENTS/Library/HelperTools/WakeBeeHelper"
fi

if [[ -d "$INSTALL_DIR" ]]; then
    HELPER="$INSTALL_DIR/WakeBeeHelper"
    [[ -f "$HELPER" && ! -L "$HELPER" && $(stat -f '%u' "$HELPER") == 0 ]] || exit 77
    permissions=$(stat -f '%Lp' "$HELPER")
    (( (8#$permissions & 8#022) == 0 )) || exit 77
    if launchctl print "system/$SERVICE" >/dev/null 2>&1; then
        launchctl bootout "system/$SERVICE"
    fi
    # SIGTERM normally restores sleep. Recover again from its durable journal
    # after launchd confirms the old service is gone. On failure keep all files
    # and restart the watchdog; never remove the only recovery mechanism.
    if ! "$HELPER" --recover-only; then
        launchctl bootstrap system "$PLIST"
        echo 'Sleep restoration failed; the recovery helper was left installed.' >&2
        exit 1
    fi
fi

if [[ "$ACTION" == uninstall ]]; then
    rm -f "$PLIST"
    rm -rf "$INSTALL_DIR"
    exit 0
fi

install -d -o root -g wheel -m 755 "$INSTALL_DIR"
install -o root -g wheel -m 755 "$CONTENTS/Library/HelperTools/WakeBeeHelper" "$INSTALL_DIR/WakeBeeHelper"
plutil -create xml1 "$STAGE/client.plist"
plutil -insert uid -integer "$CLIENT_UID" "$STAGE/client.plist"
plutil -insert requirement -string "$REQUIREMENT" "$STAGE/client.plist"
install -o root -g wheel -m 644 "$STAGE/client.plist" "$INSTALL_DIR/client.plist"
install -o root -g wheel -m 644 "$CONTENTS/Library/LaunchDaemons/$SERVICE.plist" "$PLIST"
launchctl bootstrap system "$PLIST"
