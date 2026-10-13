#!/bin/sh
set -eu

root="$({
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." && /bin/pwd -P
})"
controller="${root}/SoraPassport/Scripts/create-ios-migration-installable-clone.py"

[ -f "${controller}" ] && [ ! -L "${controller}" ] || {
    /usr/bin/printf '%s\n' 'error: installable-clone controller is missing or symbolic' >&2
    exit 1
}

exec /usr/bin/python3 -I -S "${controller}" "$@"
