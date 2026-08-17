#!/bin/bash
set -euo pipefail

: "${SORA_SR25519_SANITIZED_RLIB_DIR:?missing sanitized-rLib directory}"
readonly sanitized_dir="$SORA_SR25519_SANITIZED_RLIB_DIR"
mkdir -p "$sanitized_dir"

rewritten_args=()
for linker_arg in "$@"; do
    if [[ "$linker_arg" == *.rlib && -f "$linker_arg" ]]; then
        sanitized_archive="$sanitized_dir/$(basename "$linker_arg")"
        if [[ ! -f "$sanitized_archive" || "$linker_arg" -nt "$sanitized_archive" ]]; then
            temporary_archive="${sanitized_archive}.tmp.$$"
            cp "$linker_arg" "$temporary_archive"
            if xcrun ar -t "$temporary_archive" 2>/dev/null | grep '^lib\.rmeta$' >/dev/null; then
                xcrun ar -d "$temporary_archive" lib.rmeta
            fi
            mv "$temporary_archive" "$sanitized_archive"
        fi
        rewritten_args+=("$sanitized_archive")
    else
        rewritten_args+=("$linker_arg")
    fi
done

# Xcode 26's default linker rejects the Rust 1.46 metadata member even when
# it is removed from a temporary link-only copy. ld-classic retains the
# behavior expected by this historical toolchain.
exec /usr/bin/arch -x86_64 /usr/bin/clang \
    -arch x86_64 \
    -Wl,-ld_classic \
    "${rewritten_args[@]}"
