#!/bin/sh
set -eu

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"

collector="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.py"
if [ ! -f "${collector}" ] || [ -L "${collector}" ]; then
    echo "error: iOS migration raw-evidence collector is absent or symbolic" >&2
    exit 1
fi

exec /usr/bin/python3 -I -S "${collector}" "$@"
