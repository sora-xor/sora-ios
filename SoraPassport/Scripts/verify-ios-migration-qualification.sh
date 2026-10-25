#!/bin/sh
set -eu

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"

validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.py"
if [ ! -f "${validator}" ] || [ -L "${validator}" ]; then
    echo "error: retained iOS migration qualification validator is absent or symbolic" >&2
    exit 1
fi

exec /usr/bin/python3 -I -S "${validator}" "$@"
