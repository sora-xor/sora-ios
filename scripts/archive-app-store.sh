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
# Testers and App Review see these values; never take them from xcconfig defaults.
: "${SORA_MARKETING_VERSION:?Set the marketing version, for example 3.9.2.}"
: "${SORA_BUILD_NUMBER:?Set an unused build number (YYYYMMDDNN) above every earlier upload.}"
[[ "$SORA_MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Marketing version must look like 3.9.2."
[[ "$SORA_BUILD_NUMBER" =~ ^20[0-9]{8}$ ]] || fail "Build number must be YYYYMMDDNN."
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

# Archive a pristine copy of HEAD. It differs from the commit in one line, the
# one every 3.9.x TestFlight upload used: the modernization gate build phase
# runs its source-gate lints, because the full production-promotion mode needs
# Nexus signing and qualification receipts that this release does not ship.
stage_parent="$(mktemp -d "${TMPDIR:-/tmp}/sora-archive-source.XXXXXX")"
trap 'rm -rf "$stage_parent"; require_clean' EXIT
# mktemp's directory is private (0700). The copy inside it gets a checkout's
# usual 0755, because the gate's self-tests expect a repository root that is
# not private.
stage="$stage_parent/source"
mkdir -m 755 "$stage"
git archive --format=tar HEAD | tar -x -C "$stage"
/usr/bin/python3 - "$stage/SoraPassport.xcodeproj/project.pbxproj" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
gate = '/bin/sh \\"${PROJECT_DIR}/SoraPassport/Scripts/verify-modernization-dependencies.sh\\"'
old, new = gate + '\\n";', gate + ' --lint-ios-migration-release-source-gate\\n";'
if text.count(old) != 2:
    raise SystemExit('error: expected exactly two modernization gate build phases')
path.write_text(text.replace(old, new))
PY

args=(-project "$stage/SoraPassport.xcodeproj" -scheme SoraPassport -configuration Release
      -destination generic/platform=iOS -onlyUsePackageVersionsFromResolvedFile
      "MARKETING_VERSION=$SORA_MARKETING_VERSION" "CURRENT_PROJECT_VERSION=$SORA_BUILD_NUMBER")
[[ -z "${SORA_SOURCE_PACKAGES_PATH:-}" ]] || args+=(-clonedSourcePackagesDirPath "$SORA_SOURCE_PACKAGES_PATH")
[[ -z "${SORA_DERIVED_DATA_PATH:-}" ]] || args+=(-derivedDataPath "$SORA_DERIVED_DATA_PATH")
[[ -z "${SORA_DEVELOPMENT_TEAM:-}" ]] || args+=("DEVELOPMENT_TEAM=$SORA_DEVELOPMENT_TEAM")
[[ -z "${SORA_PROVISIONING_PROFILE_SPECIFIER:-}" ]] || args+=("PROVISIONING_PROFILE_SPECIFIER=$SORA_PROVISIONING_PROFILE_SPECIFIER")

(cd "$stage" && xcodebuild "${args[@]}" -archivePath "$SORA_ARCHIVE_PATH" archive)
require_clean
# The archive must have used the committed dependency pins.
while IFS= read -r -d '' resolved; do
  relative="${resolved#"$stage"/}"
  git show "HEAD:$relative" | cmp -s - "$resolved" || fail "The archive changed pinned dependencies: $relative"
done < <(find "$stage" -name Package.resolved -print0)

# Existing users keep their wallets only while the Keychain group stays the
# same: bundle ID, team and application identifier, and no access groups.
verify_app() {
  /usr/bin/python3 - "$1" "$SORA_MARKETING_VERSION" "$SORA_BUILD_NUMBER" "$2" <<'PY'
import plistlib
import subprocess
import sys
app, version, build, stage = sys.argv[1:]
with open(f'{app}/Info.plist', 'rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleIdentifier') != 'co.jp.soramitsu.sora':
    raise SystemExit(f'error: unexpected {stage} bundle identifier')
if info.get('CFBundleShortVersionString') != version or info.get('CFBundleVersion') != build:
    raise SystemExit(f'error: {stage} version or build differs from the requested values')
entitlements = plistlib.loads(subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', app],
                                             check=True, capture_output=True).stdout)
if entitlements.get('application-identifier') != 'YLWWUD25VZ.co.jp.soramitsu.sora' or \
   entitlements.get('com.apple.developer.team-identifier') != 'YLWWUD25VZ':
    raise SystemExit(f'error: {stage} signing would change the wallet Keychain group')
if 'keychain-access-groups' in entitlements or 'com.apple.security.application-groups' in entitlements:
    raise SystemExit(f'error: {stage} adds Keychain or app groups that change where wallet keys live')
if stage == 'export' and entitlements.get('get-task-allow') is not False:
    raise SystemExit('error: the exported app is not distribution-signed')
with open(f'{app}/SoraPassport', 'rb') as stream:
    if b'SoraWalletMigrationEvidence' in stream.read():
        raise SystemExit(f'error: the {stage} contains the migration evidence harness')
client = info.get('GIDClientID')
schemes = [s for entry in info.get('CFBundleURLTypes', []) for s in entry.get('CFBundleURLSchemes', [])]
if not client or not any(s.startswith('com.googleusercontent.apps.') for s in schemes):
    raise SystemExit(f'error: {stage} is missing Google Sign-In continuity values')
if stage == 'archive':
    print('Compare these public identifiers with the App Store 3.8.6 release before uploading:')
    print('GIDClientID:', client)
    print('URL schemes:', ', '.join(schemes))
PY
}

app="$SORA_ARCHIVE_PATH/Products/Applications/SoraPassport.app"
[[ -d "$app" ]] || fail "Archive does not contain SoraPassport.app."
verify_app "$app" archive

xcodebuild -exportArchive -archivePath "$SORA_ARCHIVE_PATH" \
  -exportOptionsPlist "$options" -exportPath "$SORA_EXPORT_PATH" \
  -onlyUsePackageVersionsFromResolvedFile
require_clean
ipa="$SORA_EXPORT_PATH/SoraPassport.ipa"
[[ -f "$ipa" ]] || fail "Export does not contain SoraPassport.ipa."
/usr/bin/ditto -x -k "$ipa" "$stage/exported"
verify_app "$stage/exported/Payload/SoraPassport.app" export
echo "Export ready for release checks: $SORA_EXPORT_PATH"
