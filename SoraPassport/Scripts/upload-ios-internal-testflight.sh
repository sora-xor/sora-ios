#!/bin/sh
set -eu

# Archive and upload one exact-source Release build to internal TestFlight only.
# This capability is permanently barred from external TestFlight and App Store
# distribution by Apple's testFlightInternalTestingOnly export option. It never
# grants migration, signing-continuity, canary, rollout, or promotion authority.

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"
project="${root}/SoraPassport.xcodeproj"
scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassport.xcscheme"
export_options="${root}/SoraPassport/Configs/ios-internal-testflight-export-options.plist"
source_contract_tool="${root}/SoraPassport/Scripts/ios-migration-qualification-contract.py"
delivery_verifier="${root}/SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py"
mode="sora-ios-internal-testflight-upload-v1"
reviewed_base_revision="60c4057460be62437675d046737183fca7b8b17d"
reviewed_upstream="origin/modernize"
reviewed_build_number="2026081002"
reviewed_lower_bound="2026081001"
reviewed_marketing_version="3.8.7"
reviewed_bundle_identifier="co.jp.soramitsu.sora"
reviewed_team_id="YLWWUD25VZ"
reviewed_signing_identity="Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)"
reviewed_signing_certificate_sha1="84AB95335BE14CAE9B050A353910F86FF2F9539B"
reviewed_signing_certificate_sha256="d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"
reviewed_profile_uuid="7ae520bc-599b-48ae-abfa-627eef530f0c"
reviewed_profile_sha256="19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

sha256_file() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

plist_raw() {
    /usr/bin/plutil -extract "$1" raw "$2" 2>/dev/null
}

lint_contract() {
    for required in \
        "${project}/project.pbxproj" \
        "${scheme}" \
        "${export_options}" \
        "${source_contract_tool}" \
        "${delivery_verifier}"
    do
        [ -f "${required}" ] && [ ! -L "${required}" ] ||
            fail "internal TestFlight contract input is missing or symbolic: ${required}"
    done
    [ "$(plist_raw destination "${export_options}")" = "upload" ] ||
        fail "internal TestFlight export destination must be upload"
    [ "$(plist_raw method "${export_options}")" = "app-store-connect" ] ||
        fail "internal TestFlight export method must be app-store-connect"
    [ "$(plist_raw manageAppVersionAndBuildNumber "${export_options}")" = "false" ] ||
        fail "Xcode must not mutate the reviewed build number"
    [ "$(plist_raw signingStyle "${export_options}")" = "manual" ] ||
        fail "internal TestFlight export signing style must be manual"
    [ "$(plist_raw signingCertificate "${export_options}")" = "${reviewed_signing_certificate_sha1}" ] ||
        fail "internal TestFlight export signing certificate drifted"
    [ "$(plist_raw teamID "${export_options}")" = "${reviewed_team_id}" ] ||
        fail "internal TestFlight export team is invalid"
    [ "$(plist_raw testFlightInternalTestingOnly "${export_options}")" = "true" ] ||
        fail "internal TestFlight export must be permanently internal-only"
    [ "$(plist_raw stripSwiftSymbols "${export_options}")" = "true" ] &&
        [ "$(plist_raw uploadSymbols "${export_options}")" = "false" ] ||
        fail "internal TestFlight symbol policy drifted"
    [ "$(/usr/bin/plutil -convert json -o - "${export_options}" | /usr/bin/python3 -B -I -S -c 'import json,sys; print(len(json.load(sys.stdin)))')" = "10" ] ||
        fail "internal TestFlight export options contain an unreviewed key"
    /usr/bin/python3 -I -S - "${export_options}" "${reviewed_bundle_identifier}" "${reviewed_profile_uuid}" <<'PY' || fail "internal TestFlight export provisioning profile drifted"
import plistlib
import sys
from pathlib import Path

options = plistlib.loads(Path(sys.argv[1]).read_bytes())
if options.get("provisioningProfiles") != {sys.argv[2]: sys.argv[3]}:
    raise SystemExit(1)
PY
    /usr/bin/grep -Fq 'buildForArchiving = "YES"' "${scheme}" ||
        fail "production scheme does not archive the production target"
    /usr/bin/grep -Fq 'buildConfiguration = "Release"' "${scheme}" ||
        fail "production scheme lacks its Release archive action"
    /usr/bin/python3 -I -S "${delivery_verifier}" --lint-contract >/dev/null ||
        fail "internal TestFlight delivery verifier contract drifted"
}

canonical_build_number() {
    raw_value="$1"
    value_label="$2"
    case "${raw_value}" in
        ''|0|0*|*[!0-9]*) fail "${value_label} must be one positive canonical decimal integer" ;;
    esac
    [ "${#raw_value}" -le 18 ] || fail "${value_label} exceeds the 18-digit bound"
    /usr/bin/printf '%s\n' "${raw_value}"
}

canonical_fresh_private_path() {
    raw_path="$1"
    required_suffix="$2"
    path_label="$3"
    case "${raw_path}" in /*) ;; *) fail "${path_label} must be absolute" ;; esac
    [ "${raw_path}" != "/" ] || fail "${path_label} must not be the filesystem root"
    path_parent="$(/usr/bin/dirname "${raw_path}")"
    path_leaf="$(/usr/bin/basename "${raw_path}")"
    case "${path_leaf}" in ''|.|..|*[!A-Za-z0-9._-]*) fail "${path_label} leaf is invalid" ;; esac
    case "${path_leaf}" in *"${required_suffix}") ;; *) fail "${path_label} has the wrong suffix" ;; esac
    [ -d "${path_parent}" ] && [ ! -L "${path_parent}" ] ||
        fail "${path_label} parent must be an existing non-symbolic directory"
    canonical_parent="$(CDPATH= cd "${path_parent}" && /bin/pwd -P)" ||
        fail "${path_label} parent cannot be resolved canonically"
    [ "$({ /usr/bin/stat -f '%u:%Sp' "${canonical_parent}"; } 2>/dev/null)" = "$(/usr/bin/id -u):drwx------" ] ||
        fail "${path_label} parent must be current-user-owned mode 0700"
    canonical_path="${canonical_parent}/${path_leaf}"
    case "${canonical_path}/" in "${root}/"*) fail "${path_label} must stay outside the repository" ;; esac
    [ ! -e "${canonical_path}" ] && [ ! -L "${canonical_path}" ] ||
        fail "${path_label} must be fresh"
    /usr/bin/printf '%s\n' "${canonical_path}"
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS internal-only TestFlight upload contract: OK\n'
    exit 0
fi

if [ "$#" -ne 11 ] ||
   [ "$1" != "--archive-and-upload" ] ||
   [ "$2" != "--build-number" ] ||
   [ "$4" != "--app-store-build-lower-bound" ] ||
   [ "$6" != "--derived-data-path" ] ||
   [ "$8" != "--archive-path" ] ||
   [ "${10}" != "--export-path" ]; then
    fail "usage: upload-ios-internal-testflight.sh --lint-contract | --archive-and-upload --build-number N --app-store-build-lower-bound N --derived-data-path /private/new-DerivedData --archive-path /private/new.xcarchive --export-path /private/new-upload"
fi

lint_contract
build_number="$(canonical_build_number "$3" "internal TestFlight build number")"
lower_bound="$(canonical_build_number "$5" "App Store build-number lower bound")"
[ "${build_number}" = "${reviewed_build_number}" ] ||
    fail "internal TestFlight build number is not the reviewed one-time value"
[ "${lower_bound}" = "${reviewed_lower_bound}" ] ||
    fail "App Store build-number lower bound is not the reviewed observation"
[ "${build_number}" -gt "${lower_bound}" ] ||
    fail "internal TestFlight build number must exceed the observed App Store lower bound"
derived_data_path="$(canonical_fresh_private_path "$7" "-DerivedData" "internal TestFlight DerivedData path")"
archive_path="$(canonical_fresh_private_path "$9" ".xcarchive" "internal TestFlight archive path")"
export_path="$(canonical_fresh_private_path "${11}" "-upload" "internal TestFlight export path")"
[ "${derived_data_path}" != "${archive_path}" ] &&
    [ "${derived_data_path}" != "${export_path}" ] &&
    [ "${archive_path}" != "${export_path}" ] ||
    fail "internal TestFlight paths must be distinct"

[ -x /usr/bin/git ] || fail "git is required to bind the uploaded source revision"
[ "$(/usr/bin/git -C "${root}" rev-parse --show-toplevel 2>/dev/null)" = "${root}" ] ||
    fail "internal TestFlight checkout root is not exact"
[ -z "$(/usr/bin/git -C "${root}" status --porcelain=v1 --untracked-files=normal)" ] ||
    fail "internal TestFlight upload requires a completely clean checkout"
source_revision="$(/usr/bin/git -C "${root}" rev-parse HEAD)"
case "${source_revision}" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *) fail "internal TestFlight source revision is invalid" ;;
esac
upstream_revision="$(/usr/bin/git -C "${root}" rev-parse '@{upstream}' 2>/dev/null)" ||
    fail "internal TestFlight branch must have an upstream"
[ "${source_revision}" = "${upstream_revision}" ] ||
    fail "internal TestFlight source must exactly match its pushed upstream"
upstream_name="$(/usr/bin/git -C "${root}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" ||
    fail "internal TestFlight upstream name cannot be resolved"
[ "${upstream_name}" = "${reviewed_upstream}" ] ||
    fail "internal TestFlight source must be pushed to origin/modernize"
parent_revision="$(/usr/bin/git -C "${root}" rev-parse HEAD^ 2>/dev/null)" ||
    fail "internal TestFlight source parent cannot be resolved"
[ "${parent_revision}" = "${reviewed_base_revision}" ] ||
    fail "internal TestFlight source is not the reviewed single successor"
[ "$(/usr/bin/git -C "${root}" rev-list --count "${reviewed_base_revision}..${source_revision}")" = "1" ] ||
    fail "internal TestFlight source history is not the reviewed single commit"
reviewed_successor_paths='SoraPassport/Scripts/test-ios-internal-testflight-upload.py
SoraPassport/Scripts/upload-ios-internal-testflight.sh
SoraPassport/Scripts/verify-modernization-dependencies.sh'
observed_successor_paths="$(/usr/bin/git -C "${root}" diff --name-only --no-renames "${reviewed_base_revision}..${source_revision}")"
[ "${observed_successor_paths}" = "${reviewed_successor_paths}" ] ||
    fail "internal TestFlight successor contains an unreviewed path set"
if ! /usr/bin/git -C "${root}" diff --name-status --no-renames "${reviewed_base_revision}..${source_revision}" |
    /usr/bin/awk '$1 != "A" && $1 != "M" { exit 1 }'; then
    fail "internal TestFlight successor contains an unreviewed change type"
fi
/usr/bin/git -C "${root}" diff --check "${reviewed_base_revision}..${source_revision}" >/dev/null ||
    fail "internal TestFlight successor diff is malformed"

control_path="$(canonical_fresh_private_path "${archive_path}.internal-testflight-control" ".internal-testflight-control" "internal TestFlight control path")"
umask 077
/bin/mkdir -m 700 "${control_path}" || fail "internal TestFlight control directory cannot be created"
archive_log="${control_path}/archive.log"
export_log="${control_path}/upload.log"
contract_snapshot="${control_path}/qualification-contract.json"
export_options_snapshot="${control_path}/export-options.plist"
manifest_path="${control_path}/internal-testflight-upload.json"
delivery_receipt_path="${control_path}/apple-upload-receipt.json"
reviewed_profile_path="${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${reviewed_profile_uuid}.mobileprovision"
[ -f "${reviewed_profile_path}" ] && [ ! -L "${reviewed_profile_path}" ] ||
    fail "reviewed App Store provisioning profile is unavailable"
[ "$(sha256_file "${reviewed_profile_path}")" = "${reviewed_profile_sha256}" ] ||
    fail "reviewed App Store provisioning profile bytes drifted"
/usr/bin/security find-identity -v -p codesigning >"${control_path}/codesigning-identities.txt" 2>&1 ||
    fail "code-signing identities cannot be inspected"
[ "$(/usr/bin/grep -Fci "${reviewed_signing_certificate_sha1} \"${reviewed_signing_identity}\"" "${control_path}/codesigning-identities.txt")" = "1" ] ||
    fail "the exact reviewed Apple Distribution private identity is unavailable or ambiguous"
/bin/cp -p "${export_options}" "${export_options_snapshot}" || fail "export options cannot be snapshotted"
/bin/chmod 400 "${export_options_snapshot}" || fail "export options snapshot cannot be made read-only"
export_options_sha="$(sha256_file "${export_options_snapshot}")"
qualification_contract_sha="$(
    /usr/bin/python3 -I -S "${source_contract_tool}" \
        --repository-root "${root}" \
        --snapshot "${contract_snapshot}"
)" || fail "qualification source contract cannot be snapshotted"

/usr/bin/printf '%s\n' \
    'warning: uploading an internal-TestFlight-only, non-authorizing build; no production promotion authority is granted' >&2
if ! /usr/bin/xcodebuild \
    -project "${project}" \
    -scheme SoraPassport \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "${derived_data_path}" \
    -archivePath "${archive_path}" \
    -allowProvisioningUpdates \
    "CURRENT_PROJECT_VERSION=${build_number}" \
    "CODE_SIGN_STYLE=Automatic" \
    "CODE_SIGN_IDENTITY=${reviewed_signing_certificate_sha1}" \
    "DEVELOPMENT_TEAM=${reviewed_team_id}" \
    "SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE=${mode}" \
    SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION=archive \
    "SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER=${build_number}" \
    "SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION=${source_revision}" \
    "SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256=${export_options_sha}" \
    "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${source_revision}" \
    "SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}" \
    archive >"${archive_log}" 2>&1; then
    fail "internal TestFlight archive failed; private archive log retained at ${archive_log}"
fi

[ -d "${archive_path}" ] && [ ! -L "${archive_path}" ] || fail "internal TestFlight archive is missing"
/usr/bin/python3 -I -S "${source_contract_tool}" \
    --repository-root "${root}" \
    --verify-snapshot "${contract_snapshot}" \
    --expected-sha "${qualification_contract_sha}" >/dev/null ||
    fail "qualification source contract changed during archive"
archived_app_count="$({ /usr/bin/find "${archive_path}/Products/Applications" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })"
[ "${archived_app_count}" = "1" ] || fail "archive must contain exactly one application"
archived_app="$({ /usr/bin/find "${archive_path}/Products/Applications" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print; })"
info_plist="${archived_app}/Info.plist"
profile_path="${archived_app}/embedded.mobileprovision"
[ -f "${info_plist}" ] && [ ! -L "${info_plist}" ] &&
    [ -f "${profile_path}" ] && [ ! -L "${profile_path}" ] ||
    fail "archived application identity or profile is missing"
[ "$(plist_raw CFBundleIdentifier "${info_plist}")" = "${reviewed_bundle_identifier}" ] || fail "archived bundle identifier drifted"
[ "$(plist_raw CFBundleVersion "${info_plist}")" = "${build_number}" ] || fail "archived build number drifted"
[ "$(plist_raw CFBundleShortVersionString "${info_plist}")" = "${reviewed_marketing_version}" ] || fail "archived marketing version drifted"
[ "$(plist_raw SoraMigrationEvidenceSourceRevision "${info_plist}")" = "${source_revision}" ] || fail "archive does not bind the exact source revision"
[ "$(plist_raw SoraMigrationEvidenceQualificationContractSha256 "${info_plist}")" = "${qualification_contract_sha}" ] || fail "archive qualification source digest drifted"
/usr/bin/codesign --verify --deep --strict "${archived_app}" >/dev/null 2>&1 || fail "archived application code signature is invalid"
/usr/bin/codesign -dvv "${archived_app}" >"${control_path}/codesign.txt" 2>&1 || fail "archived signing identity cannot be inspected"
/usr/bin/grep -Fq "TeamIdentifier=${reviewed_team_id}" "${control_path}/codesign.txt" || fail "archived signing team drifted"
/usr/bin/grep -Fq "Authority=${reviewed_signing_identity}" "${control_path}/codesign.txt" || fail "archive is not signed by the reviewed Apple Distribution identity"
/usr/bin/codesign -d --extract-certificates="${control_path}/codesign-cert" "${archived_app}" >/dev/null 2>&1 ||
    fail "archived signing certificate chain cannot be extracted"
[ -f "${control_path}/codesign-cert0" ] && [ ! -L "${control_path}/codesign-cert0" ] ||
    fail "archived signing leaf certificate is missing"
signed_certificate_sha1="$(/usr/bin/shasum -a 1 "${control_path}/codesign-cert0" | /usr/bin/awk '{print toupper($1)}')"
signed_certificate_sha256="$(sha256_file "${control_path}/codesign-cert0")"
[ "${signed_certificate_sha1}" = "${reviewed_signing_certificate_sha1}" ] &&
    [ "${signed_certificate_sha256}" = "${reviewed_signing_certificate_sha256}" ] ||
    fail "archived signing leaf certificate is not the reviewed identity"
/usr/bin/codesign -d --entitlements=- --xml "${archived_app}" \
    >"${control_path}/signed-entitlements.plist" \
    2>"${control_path}/signed-entitlements.log" ||
    fail "archived signed entitlements cannot be extracted"
/usr/bin/python3 -I -S - "${control_path}/signed-entitlements.plist" <<'PY' || fail "archived signed entitlements are not the exact App Store entitlement set"
import plistlib
import sys
from pathlib import Path

entitlements = plistlib.loads(Path(sys.argv[1]).read_bytes())
if entitlements != {
    "application-identifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
    "beta-reports-active": True,
    "com.apple.developer.team-identifier": "YLWWUD25VZ",
    "get-task-allow": False,
}:
    raise SystemExit(1)
PY
/usr/bin/security cms -D -i "${profile_path}" -o "${control_path}/profile.plist" >/dev/null 2>&1 || fail "embedded profile cannot be decoded"
[ "$(sha256_file "${profile_path}")" = "${reviewed_profile_sha256}" ] ||
    fail "embedded App Store profile bytes drifted"
/usr/bin/python3 -I -S - "${control_path}/profile.plist" <<'PY' || fail "embedded App Store profile is invalid"
import datetime
import hashlib
import plistlib
import sys
from pathlib import Path

profile = plistlib.loads(Path(sys.argv[1]).read_bytes())
entitlements = profile.get("Entitlements")
if not isinstance(entitlements, dict):
    raise SystemExit(1)
if profile.get("UUID") != "7ae520bc-599b-48ae-abfa-627eef530f0c":
    raise SystemExit(1)
if profile.get("Name") != "iOS Team Store Provisioning Profile: co.jp.soramitsu.sora":
    raise SystemExit(1)
if profile.get("TeamIdentifier") != ["YLWWUD25VZ"]:
    raise SystemExit(1)
if entitlements.get("application-identifier") != "YLWWUD25VZ.co.jp.soramitsu.sora":
    raise SystemExit(1)
if entitlements.get("com.apple.developer.team-identifier") != "YLWWUD25VZ":
    raise SystemExit(1)
if entitlements.get("get-task-allow") is not False:
    raise SystemExit(1)
if entitlements.get("beta-reports-active") is not True:
    raise SystemExit(1)
if "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices") is True:
    raise SystemExit(1)
certificates = profile.get("DeveloperCertificates")
if not isinstance(certificates, list) or [hashlib.sha256(item).hexdigest() for item in certificates] != [
    "bb62a695f45ef159ab28e2ed224bb8b5fe71fad68f1c58fdda897064898fb505",
    "d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb",
    "09e36070bac48cf47c125d2237692475db7b64454ff45a17b889380f31510c93",
]:
    raise SystemExit(1)
expires = profile.get("ExpirationDate")
if not isinstance(expires, datetime.datetime):
    raise SystemExit(1)
if expires.tzinfo is None:
    expires = expires.replace(tzinfo=datetime.timezone.utc)
if expires <= datetime.datetime.now(datetime.timezone.utc):
    raise SystemExit(1)
PY

app_executable="$(plist_raw CFBundleExecutable "${info_plist}")"
case "${app_executable}" in ''|*/*) fail "archived executable name is invalid" ;; esac
[ -f "${archived_app}/${app_executable}" ] && [ ! -L "${archived_app}/${app_executable}" ] || fail "archived executable is missing"
executable_sha="$(sha256_file "${archived_app}/${app_executable}")"
profile_sha="$(sha256_file "${profile_path}")"
[ "$(sha256_file "${export_options}")" = "${export_options_sha}" ] &&
    [ "$(sha256_file "${export_options_snapshot}")" = "${export_options_sha}" ] ||
    fail "export options changed before upload"

if ! /usr/bin/xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${export_options_snapshot}" \
    -allowProvisioningUpdates >"${export_log}" 2>&1; then
    fail "internal TestFlight upload failed; private upload log retained at ${export_log}"
fi

[ "$(sha256_file "${export_options}")" = "${export_options_sha}" ] &&
    [ "$(sha256_file "${export_options_snapshot}")" = "${export_options_sha}" ] ||
    fail "export options changed during upload"
/usr/bin/python3 -I -S "${source_contract_tool}" \
    --repository-root "${root}" \
    --verify-snapshot "${contract_snapshot}" \
    --expected-sha "${qualification_contract_sha}" >/dev/null ||
    fail "qualification source contract changed during upload"
[ "$(/usr/bin/git -C "${root}" rev-parse HEAD)" = "${source_revision}" ] &&
    [ -z "$(/usr/bin/git -C "${root}" status --porcelain=v1 --untracked-files=normal)" ] ||
    fail "source changed during internal TestFlight upload"
if ! /usr/bin/python3 -I -S "${delivery_verifier}" \
    --archive-info "${archive_path}/Info.plist" \
    --receipt "${delivery_receipt_path}" \
    --build-number "${build_number}" >"${control_path}/delivery-verification.log"; then
    fail "Xcode did not record one exact successful Apple upload"
fi
delivery_id="$(plist_raw deliveryId "${delivery_receipt_path}")"
delivery_uploaded_at="$(plist_raw uploadedAt "${delivery_receipt_path}")"
delivery_receipt_sha="$(sha256_file "${delivery_receipt_path}")"
/usr/bin/python3 -I -S - \
    "${manifest_path}" "${source_revision}" "${build_number}" "${qualification_contract_sha}" \
    "${export_options_sha}" "${executable_sha}" "${profile_sha}" \
    "${signed_certificate_sha1}" "${signed_certificate_sha256}" \
    "${delivery_id}" "${delivery_uploaded_at}" "${delivery_receipt_sha}" <<'PY'
import datetime
import json
import os
import sys

(
    path,
    source,
    build,
    contract,
    export_options,
    executable,
    profile,
    certificate_sha1,
    certificate_sha256,
    delivery_id,
    uploaded_at,
    delivery_receipt_sha256,
) = sys.argv[1:]
manifest = {
    "schemaVersion": 1,
    "scope": "sora-ios-internal-testflight-upload-v1",
    "sourceRevision": source,
    "bundleIdentifier": "co.jp.soramitsu.sora",
    "marketingVersion": "3.8.7",
    "teamId": "YLWWUD25VZ",
    "buildNumber": build,
    "qualificationContractSha256": contract,
    "exportOptionsSha256": export_options,
    "archivedExecutableSha256": executable,
    "embeddedProfileSha256": profile,
    "embeddedProfileUuid": "7ae520bc-599b-48ae-abfa-627eef530f0c",
    "embeddedProfileName": "iOS Team Store Provisioning Profile: co.jp.soramitsu.sora",
    "signedLeafCertificateSha1": certificate_sha1,
    "signedLeafCertificateSha256": certificate_sha256,
    "appleAdamId": "1457566711",
    "appleProviderId": "69a6de8e-8bb9-47e3-e053-5b8c7c11a4d1",
    "appleDeliveryId": delivery_id,
    "appleUploadState": "success",
    "appleUploadedAt": uploaded_at,
    "appleUploadReceiptSha256": delivery_receipt_sha256,
    "testFlightInternalTestingOnly": True,
    "externalTestFlightAuthorized": False,
    "appStorePromotionAuthorized": False,
    "productionRolloutAuthorized": False,
    "uploadCompletedAt": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
with os.fdopen(descriptor, "w", encoding="utf-8") as output:
    json.dump(manifest, output, sort_keys=True, separators=(",", ":"))
    output.write("\n")
PY

/usr/bin/printf 'internalTestFlightUpload=complete sourceRevision=%s buildNumber=%s manifestPath=%s uploadLog=%s\n' \
    "${source_revision}" "${build_number}" "${manifest_path}" "${export_log}"
/usr/bin/printf 'appleDeliveryId=%s appleUploadState=success appleUploadedAt=%s\n' \
    "${delivery_id}" "${delivery_uploaded_at}"
