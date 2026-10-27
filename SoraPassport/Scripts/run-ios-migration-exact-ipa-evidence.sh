#!/bin/sh
set -eu

root="$({
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." && /bin/pwd -P
})"
controller="${root}/SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py"

[ -f "${controller}" ] && [ ! -L "${controller}" ] || {
    /usr/bin/printf '%s\n' 'error: exact-IPA migration evidence controller is missing or symbolic' >&2
    exit 1
}

exec /usr/bin/python3 -I -S "${controller}" "$@"
