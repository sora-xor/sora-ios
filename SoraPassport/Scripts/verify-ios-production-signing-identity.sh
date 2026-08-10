#!/bin/sh
set -eu

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." && /bin/pwd -P
)"
validator="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.py"

if [ ! -f "${validator}" ] || [ -L "${validator}" ]; then
    echo "error: iOS production signing-identity validator is absent or symbolic" >&2
    exit 1
fi

exec /usr/bin/python3 -B -I -S "${validator}" "$@"
