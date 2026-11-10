#!/bin/sh
# Checks the in-repo blake2lib, libed25519 and sr25519lib sources against the
# outputs of the prebuilt libraries they replaced. Runs natively on macOS:
#   sh VendorPackages/shared-features-spm/Tests/CryptoCompatibility/run.sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../../Sources" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

build() {
    out=$1; shift
    xcrun clang -O2 -w "$@" \
        -I"$SRC/sr25519lib/include/sr25519lib" -I"$SRC/sr25519lib/include" -I"$SRC/sr25519lib" \
        -I"$SRC/libed25519/include/libed25519" -I"$SRC/libed25519/iroha/include" \
        -I"$SRC/blake2lib/include/blake2lib" \
        "$HERE/harness.c" "$SRC/blake2lib/"*.c \
        "$SRC/libed25519/orlp/"*.c "$SRC/libed25519/iroha/ref10/"*.c "$SRC/libed25519/iroha/sha3/"*.c "$SRC/libed25519/iroha/"*.c \
        "$SRC/sr25519lib/sr25519.c" "$SRC/sr25519lib/donna/"*.c \
        -o "$out"
}

fail=0
check() { if [ "$1" = "$2" ]; then echo "ok   $3"; else echo "FAIL $3 ($1 != $2)"; fail=1; fi; }

for variant in 64 32; do
    if [ $variant = 32 ]; then build "$WORK/h$variant" -DED25519_FORCE_32BIT; else build "$WORK/h$variant"; fi
    "$WORK/h$variant" gen 3000 > "$WORK/gen$variant.txt"
    det=$(grep -vE '^(SIG|SOFTSIGVERIFY|SELFVERIFY|IRCREATE) ' "$WORK/gen$variant.txt" | shasum -a 256 | cut -d' ' -f1)
    check "$det" "$(sed -n 's/^deterministic-gen-3000 //p' "$HERE/expected.txt")" "$variant-bit: 69,000 deterministic outputs equal the old binary's"
    fromed=$("$WORK/h$variant" fromed 2000 | shasum -a 256 | cut -d' ' -f1)
    check "$fromed" "$(sed -n 's/^fromed-2000 //p' "$HERE/expected.txt")" "$variant-bit: from_ed25519_bytes on 2,000 arbitrary inputs"
    self=$(grep '^SELFVERIFY' "$WORK/gen$variant.txt" | awk '$3 != 1 || $4 != 0' | wc -l | tr -d ' ')
    check "$self" 0 "$variant-bit: own signatures verify, tampered ones do not"
    soft=$(grep '^SOFTSIGVERIFY' "$WORK/gen$variant.txt" | awk '$3 != 1' | wc -l | tr -d ' ')
    check "$soft" 0 "$variant-bit: soft-derived keys sign"
    old=$("$WORK/h$variant" verify "$HERE/old-binary-signatures.txt" | awk '$3 != 1' | wc -l | tr -d ' ')
    check "$old" 0 "$variant-bit: all 300 signatures made by the old binary verify"
done

xcrun clang -O2 -w -I"$SRC/sr25519lib/include" -I"$SRC/sr25519lib" "$HERE/kat.c" \
    "$SRC/sr25519lib/sr25519.c" "$SRC/sr25519lib/donna/"*.c -o "$WORK/kat"
if "$WORK/kat" > "$WORK/kat.txt"; then
    echo "ok   $(grep -c '^PASS' "$WORK/kat.txt") known-answer tests (RFC 9496, //Alice, //Bob, rejections)"
else
    grep -v '^PASS' "$WORK/kat.txt"; fail=1
fi
exit $fail
