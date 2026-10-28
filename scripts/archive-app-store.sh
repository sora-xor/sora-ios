#!/bin/bash
# Archive and export the pinned release. Upload is a separate release action.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() { echo "error: $*" >&2; exit 1; }
require_clean() {
  [[ -z "$(git status --porcelain --untracked-files=all)" ]] ||
    fail "The release checkout changed or contains uncommitted files; inspect git status."
}

require_clean
[[ -z "${SORA_MIGRATION_EVIDENCE_HARNESS:-}" ]] || fail "Evidence harness is enabled."
case "${SORA_EVIDENCE_HARNESS_CONDITION:-} ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} ${OTHER_SWIFT_FLAGS:-}" in
  *SORA_MIGRATION_EVIDENCE_HARNESS*) fail "Evidence harness is enabled." ;;
esac

: "${SORA_ARCHIVE_PATH:?Set an absolute path for the new .xcarchive outside the checkout.}"
: "${SORA_EXPORT_PATH:?Set an absolute export directory outside the checkout.}"
for output in "$SORA_ARCHIVE_PATH" "$SORA_EXPORT_PATH"; do
  [[ "$output" = /* && "$output" != "$repo_root" && "$output" != "$repo_root/"* ]] ||
    fail "Archive and export paths must be absolute and outside the checkout."
  [[ ! -e "$output" ]] || fail "Output already exists: $output"
done

options="${SORA_EXPORT_OPTIONS_PLIST:-$repo_root/SoraPassport/Configs/ExportOptions.app-store-connect.plist}"
[[ -f "$options" ]] || fail "Export options plist is missing."
# Export never submits to App Store Connect. Verify even caller-provided options.
[[ "$(/usr/libexec/PlistBuddy -c 'Print :destination' "$options")" = export ]] ||
  fail "Export options must use destination=export."

args=(-project SoraPassport.xcodeproj -scheme SoraPassport -configuration Release
      -destination generic/platform=iOS -onlyUsePackageVersionsFromResolvedFile)
[[ -z "${SORA_SOURCE_PACKAGES_PATH:-}" ]] || args+=(-clonedSourcePackagesDirPath "$SORA_SOURCE_PACKAGES_PATH")
[[ -z "${SORA_DERIVED_DATA_PATH:-}" ]] || args+=(-derivedDataPath "$SORA_DERIVED_DATA_PATH")
[[ -z "${SORA_DEVELOPMENT_TEAM:-}" ]] || args+=("DEVELOPMENT_TEAM=$SORA_DEVELOPMENT_TEAM")
[[ -z "${SORA_PROVISIONING_PROFILE_SPECIFIER:-}" ]] || args+=("PROVISIONING_PROFILE_SPECIFIER=$SORA_PROVISIONING_PROFILE_SPECIFIER")

trap require_clean EXIT
xcodebuild "${args[@]}" -archivePath "$SORA_ARCHIVE_PATH" archive
require_clean

app="$SORA_ARCHIVE_PATH/Products/Applications/SoraPassport.app"
[[ -d "$app" ]] || fail "Archive does not contain SoraPassport.app."
/usr/bin/python3 - "$app/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleIdentifier') != 'co.jp.soramitsu.sora':
    raise SystemExit('error: unexpected archive bundle identifier')
client = info.get('GIDClientID')
schemes = [s for entry in info.get('CFBundleURLTypes', []) for s in entry.get('CFBundleURLSchemes', [])]
if not client or not any(s.startswith('com.googleusercontent.apps.') for s in schemes):
    raise SystemExit('error: archive is missing Google Sign-In continuity values')
print('Compare these public identifiers with the App Store 3.8.6 release before uploading:')
print('GIDClientID:', client)
print('URL schemes:', ', '.join(schemes))
PY

xcodebuild -exportArchive -archivePath "$SORA_ARCHIVE_PATH" \
  -exportOptionsPlist "$options" -exportPath "$SORA_EXPORT_PATH" \
  -onlyUsePackageVersionsFromResolvedFile
require_clean
echo "Export ready for release checks: $SORA_EXPORT_PATH"
