#!/bin/bash
set -euo pipefail

readonly expected_toolchain="nightly-2020-06-27-x86_64-apple-darwin"
readonly expected_rust_commit="7750c3d46bc19784adb1ee6e37a5ec7e4cd7e772"
readonly vendor_toolchain="1.95.0-aarch64-apple-darwin"
readonly script_dir="$(cd "$(dirname "$0")" && pwd -P)"
readonly package_root="$(cd "$script_dir/../.." && pwd -P)"
readonly output_xcframework="$package_root/Binaries/Sr25519SafeValidator.xcframework"
readonly support_dir="$script_dir/support"
readonly temporary_root="$(mktemp -d "${TMPDIR:-/private/tmp}/sora-sr25519-validator.XXXXXX")"

cleanup() {
    case "$temporary_root" in
        "${TMPDIR:-/private/tmp}"/sora-sr25519-validator.*)
            rm -rf -- "$temporary_root"
            ;;
        *)
            printf 'Refusing to remove unexpected temporary path: %s\n' "$temporary_root" >&2
            ;;
    esac
}
trap cleanup EXIT

readonly historical_rustc="$(rustup which rustc --toolchain "$expected_toolchain")"
readonly historical_cargo="$(rustup which cargo --toolchain "$expected_toolchain")"
readonly vendor_cargo="$(rustup which cargo --toolchain "$vendor_toolchain")"
readonly rustc_details="$(/usr/bin/arch -x86_64 "$historical_rustc" -Vv)"

if [[ "$rustc_details" != *"commit-hash: $expected_rust_commit"* ]]; then
    printf 'Unexpected Rust compiler:\n%s\n' "$rustc_details" >&2
    exit 1
fi

readonly historical_sysroot="$(/usr/bin/arch -x86_64 "$historical_rustc" --print sysroot)"
for target_name in aarch64-apple-ios x86_64-apple-ios; do
    if [[ ! -d "$historical_sysroot/lib/rustlib/$target_name/lib" ]]; then
        printf 'Missing %s for %s. Add it with rustup target add.\n' \
            "$target_name" "$expected_toolchain" >&2
        exit 1
    fi
done

mkdir -p "$temporary_root/cargo-home" \
    "$temporary_root/vendor" \
    "$temporary_root/link-rlibs" \
    "$temporary_root/target"
cp "$support_dir/cargo-config" "$temporary_root/cargo-home/config"

# Do not let caller-specific Cargo/Rust overrides change the checked-in binary.
unset CARGO_BUILD_RUSTFLAGS \
    CARGO_ENCODED_RUSTFLAGS \
    CARGO_TARGET_DIR \
    RUSTC_WRAPPER \
    RUSTC_WORKSPACE_WRAPPER \
    RUSTDOCFLAGS \
    RUSTFLAGS
for variable_name in ${!CARGO_PROFILE_@}; do
    unset "$variable_name"
done

"$vendor_cargo" vendor \
    --locked \
    --versioned-dirs \
    "$temporary_root/vendor" \
    --manifest-path "$script_dir/Cargo.toml" \
    >/dev/null

export CARGO_HOME="$temporary_root/cargo-home"
export CARGO_TARGET_DIR="$temporary_root/target"
export CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER="$support_dir/x86_64-clang-linker.sh"
export IPHONEOS_DEPLOYMENT_TARGET=11.0
export RUSTC="$historical_rustc"
export RUSTFLAGS="--remap-path-prefix=$temporary_root=/sora-sr25519-validator/build --remap-path-prefix=$script_dir=/sora-sr25519-validator/source"
export SORA_SR25519_SANITIZED_RLIB_DIR="$temporary_root/link-rlibs"

readonly historical_cargo_command=(/usr/bin/arch -x86_64 "$historical_cargo")

"${historical_cargo_command[@]}" test \
    --release \
    --locked \
    --manifest-path "$script_dir/Cargo.toml"

for target_name in aarch64-apple-ios x86_64-apple-ios; do
    "${historical_cargo_command[@]}" build \
        --release \
        --locked \
        --target "$target_name" \
        --manifest-path "$script_dir/Cargo.toml"
done

readonly library_name="libsora_sr25519_safe_validator.a"
readonly device_library="$temporary_root/target/aarch64-apple-ios/release/$library_name"
readonly simulator_x86_library="$temporary_root/target/x86_64-apple-ios/release/$library_name"

cp "$device_library" "$output_xcframework/ios-arm64/$library_name"
cp "$simulator_x86_library" \
    "$output_xcframework/ios-x86_64-simulator/$library_name"

for header_directory in \
    "$output_xcframework/ios-arm64/Headers" \
    "$output_xcframework/ios-x86_64-simulator/Headers"; do
    cp "$script_dir/include/sora_sr25519_safe_validator.h" "$header_directory/"
    cp "$script_dir/include/module.modulemap" "$header_directory/"
done

if ! strings "$device_library" | grep "/rustc/$expected_rust_commit" >/dev/null; then
    printf 'Device library was not built by the expected Rust compiler.\n' >&2
    exit 1
fi

for exported_symbol in \
    _sora_sr25519_keypair_is_valid \
    _sora_sr25519_secret_from_ed25519 \
    _sora_sr25519_validator_contains_forced_panic; do
    if ! nm -gU "$device_library" 2>/dev/null | grep " $exported_symbol$" >/dev/null; then
        printf 'Missing exported symbol: %s\n' "$exported_symbol" >&2
        exit 1
    fi
done

xcrun lipo "$device_library" -verify_arch arm64
xcrun lipo "$simulator_x86_library" -verify_arch x86_64
shasum -a 256 \
    "$output_xcframework/ios-arm64/$library_name" \
    "$output_xcframework/ios-x86_64-simulator/$library_name"
