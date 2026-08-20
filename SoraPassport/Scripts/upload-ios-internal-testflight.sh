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
internal_taira_config="${root}/Fixtures/Modernization/ios-taira-internal-testflight-v1.json"
mode="sora-ios-internal-testflight-upload-v1"
reviewed_base_revision="b2c564493db296c71f94e1d1fa2ed7d5f00f8627"
reviewed_upstream="origin/codex/taira-network-switch-20260819"
reviewed_build_number="2026082002"
reviewed_lower_bound="2026082001"
reviewed_marketing_version="3.8.7"
reviewed_bundle_identifier="co.jp.soramitsu.sora"
reviewed_team_id="YLWWUD25VZ"
internal_taira_contract_id="sora-ios-taira-internal-testflight-v1"
internal_taira_config_sha256="bac9ad666efd0d1c144ff86159899705d651457694fad4255c54e1d808c4bf90"
internal_taira_chain_id="fc56984b-2be7-431d-840e-21514d1883f0"
internal_taira_genesis_hash="d8df4ad9f8e4b67a1734c805baed9a97fc34fc6a9ca905ac7c8daed00fbbdf3b"
internal_taira_torii_base_url="https://taira.sora.org"
internal_taira_mcp_endpoint="https://taira.sora.org/v1/mcp"
reviewed_signing_identity="Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)"
reviewed_signing_certificate_sha1="84AB95335BE14CAE9B050A353910F86FF2F9539B"
reviewed_signing_certificate_sha256="d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"
reviewed_profile_uuid="7ae520bc-599b-48ae-abfa-627eef530f0c"
reviewed_profile_sha256="19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"
reviewed_archive_signing_identity="Apple Development: Makoto Takemiya (6A4BK72ZFV)"
reviewed_archive_signing_certificate_sha1="1F57A04EB10B3665696663CDA0DBD893CF7FE886"
reviewed_archive_signing_certificate_sha256="b479b9064f19cf90085926479768088416407c9e99e1537662014ba6805c179d"
reviewed_archive_profile_uuid="908dc5a8-2b34-4617-94bb-f4a58ed5f4da"
reviewed_archive_profile_sha256="ede945565f09b23b4d92eca0752cb6ad52fe47b8a6ebb0e38f424ce64de79235"

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
        "${delivery_verifier}" \
        "${internal_taira_config}"
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
    [ "$(plist_raw signingStyle "${export_options}")" = "automatic" ] ||
        fail "the Xcode-managed App Store profile requires automatic export signing"
    if /usr/bin/plutil -extract signingCertificate raw "${export_options}" >/dev/null 2>&1; then
        fail "automatic export must not contain the manual-only signingCertificate key"
    fi
    if /usr/bin/plutil -extract provisioningProfiles raw "${export_options}" >/dev/null 2>&1; then
        fail "automatic export must not contain the manual-only provisioningProfiles key"
    fi
    [ "$(plist_raw teamID "${export_options}")" = "${reviewed_team_id}" ] ||
        fail "internal TestFlight export team is invalid"
    [ "$(plist_raw testFlightInternalTestingOnly "${export_options}")" = "true" ] ||
        fail "internal TestFlight export must be permanently internal-only"
    [ "$(plist_raw stripSwiftSymbols "${export_options}")" = "true" ] &&
        [ "$(plist_raw uploadSymbols "${export_options}")" = "false" ] ||
        fail "internal TestFlight symbol policy drifted"
    [ "$(/usr/bin/plutil -convert json -o - "${export_options}" | /usr/bin/python3 -B -I -S -c 'import json,sys; print(len(json.load(sys.stdin)))')" = "8" ] ||
        fail "internal TestFlight export options contain an unreviewed key"
    /usr/bin/grep -Fq 'buildForArchiving = "YES"' "${scheme}" ||
        fail "production scheme does not archive the production target"
    /usr/bin/grep -Fq 'buildConfiguration = "Release"' "${scheme}" ||
        fail "production scheme lacks its Release archive action"
    /usr/bin/python3 -I -S "${delivery_verifier}" --lint-contract >/dev/null ||
        fail "internal TestFlight delivery verifier contract drifted"
    [ "$(sha256_file "${internal_taira_config}")" = "${internal_taira_config_sha256}" ] ||
        fail "internal Taira configuration bytes drifted"
    if ! /usr/bin/python3 -I -S - "${internal_taira_config}" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_bytes())
if value != {
    "schemaVersion": 1,
    "contractId": "sora-ios-taira-internal-testflight-v1",
    "scope": "internal-testflight-only",
    "currentChainId": "fc56984b-2be7-431d-840e-21514d1883f0",
    "currentGenesisHash": "d8df4ad9f8e4b67a1734c805baed9a97fc34fc6a9ca905ac7c8daed00fbbdf3b",
    "canonicalToriiBaseUrl": "https://taira.sora.org",
    "publicMcpEndpoint": "https://taira.sora.org/v1/mcp",
    "productionAdmissionAuthorized": False,
    "externalTestFlightAuthorized": False,
    "appStoreDistributionAuthorized": False,
}:
    raise SystemExit(1)
PY
    then
        fail "internal Taira configuration contract drifted"
    fi
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
    fail "internal TestFlight source must be pushed to the reviewed upstream"
parent_revision="$(/usr/bin/git -C "${root}" rev-parse HEAD^ 2>/dev/null)" ||
    fail "internal TestFlight source parent cannot be resolved"
[ "${parent_revision}" = "${reviewed_base_revision}" ] ||
    fail "internal TestFlight source is not the reviewed single successor"
[ "$(/usr/bin/git -C "${root}" rev-list --count "${reviewed_base_revision}..${source_revision}")" = "1" ] ||
    fail "internal TestFlight source history is not the reviewed single commit"
reviewed_successor_paths='Fixtures/Modernization/ios-migration-qualification-contract-v1.json
SoraPassport/Common/Helpers/AssetManager.swift
SoraPassport/Common/Helpers/MainTransitionHelper.swift
SoraPassport/Common/Storage/SelectedWalletSettings.swift
SoraPassport/ModulesRedesign/AccountAdd/Interactors/AddAccountImportInteractor.swift
SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewController.swift
SoraPassport/ModulesRedesign/MainTabBar/MainTabBarViewFactory.swift
SoraPassport/ModulesRedesign/MainTabBar/MainTabBarWireframe.swift
SoraPassport/ModulesRedesign/Migration/MigrationService.swift
SoraPassport/ModulesRedesign/Pincode/InputPincodePresenter.swift
SoraPassport/ModulesRedesign/Root/RootInteractor.swift
SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift
SoraPassport/Scripts/test-ios-internal-testflight-upload.py
SoraPassport/Scripts/upload-ios-internal-testflight.sh
SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py
SoraPassport/Scripts/verify-modernization-dependencies.sh
SoraPassportTests/Modules/Root/RootFactoryTests.swift
VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/Keychain/Keychain.swift'
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
reviewed_archive_profile_path="${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${reviewed_archive_profile_uuid}.mobileprovision"
[ -f "${reviewed_profile_path}" ] && [ ! -L "${reviewed_profile_path}" ] ||
    fail "reviewed App Store provisioning profile is unavailable"
[ "$(sha256_file "${reviewed_profile_path}")" = "${reviewed_profile_sha256}" ] ||
    fail "reviewed App Store provisioning profile bytes drifted"
[ -f "${reviewed_archive_profile_path}" ] && [ ! -L "${reviewed_archive_profile_path}" ] ||
    fail "reviewed archive provisioning profile is unavailable"
[ "$(sha256_file "${reviewed_archive_profile_path}")" = "${reviewed_archive_profile_sha256}" ] ||
    fail "reviewed archive provisioning profile bytes drifted"
/usr/bin/security find-identity -v -p codesigning >"${control_path}/codesigning-identities.txt" 2>&1 ||
    fail "code-signing identities cannot be inspected"
[ "$(/usr/bin/grep -Fci "${reviewed_signing_certificate_sha1} \"${reviewed_signing_identity}\"" "${control_path}/codesigning-identities.txt")" = "1" ] ||
    fail "the exact reviewed Apple Distribution private identity is unavailable or ambiguous"
[ "$(/usr/bin/grep -Fci "${reviewed_archive_signing_certificate_sha1} \"${reviewed_archive_signing_identity}\"" "${control_path}/codesigning-identities.txt")" = "1" ] ||
    fail "the exact reviewed Apple Development private identity is unavailable or ambiguous"
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
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) SORA_INTERNAL_TAIRA_TESTFLIGHT' \
    "SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE=${mode}" \
    SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION=archive \
    "SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER=${build_number}" \
    "SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION=${source_revision}" \
    "SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256=${export_options_sha}" \
    "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${source_revision}" \
    "SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_BUILD_NUMBER=${build_number}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_CONFIG_SHA256=${internal_taira_config_sha256}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_CONTRACT_ID=${internal_taira_contract_id}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_CURRENT_CHAIN_ID=${internal_taira_chain_id}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_CURRENT_GENESIS_HASH=${internal_taira_genesis_hash}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_MCP_ENDPOINT=${internal_taira_mcp_endpoint}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_SOURCE_REVISION=${source_revision}" \
    "SORA_TAIRA_INTERNAL_TESTFLIGHT_TORII_BASE_URL=${internal_taira_torii_base_url}" \
    SORA_TAIRA_DEPLOYMENT_ADMISSION_CONTRACT_ID= \
    SORA_TAIRA_DEPLOYMENT_MANIFEST_SHA256= \
    SORA_TAIRA_DEPLOYMENT_ADMISSION_SHA256= \
    SORA_TAIRA_CURRENT_CHAIN_ID= \
    SORA_TAIRA_RETIRED_CHAIN_ID= \
    SORA_TAIRA_CURRENT_GENESIS_HASH= \
    SORA_TAIRA_RETIRED_GENESIS_HASH= \
    SORA_TAIRA_CURRENT_DEPLOYMENT_EPOCH= \
    SORA_TAIRA_RETIRED_DEPLOYMENT_EPOCH= \
    SORA_TAIRA_CANONICAL_TORII_BASE_URL= \
    SORA_TAIRA_PUBLIC_MCP_ENDPOINT= \
    SORA_TAIRA_PENDING_ROW_POLICY= \
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
[ "$(plist_raw SoraTairaInternalTestFlightBuildNumber "${info_plist}")" = "${build_number}" ] || fail "internal Taira build binding drifted"
[ "$(plist_raw SoraTairaInternalTestFlightConfigSha256 "${info_plist}")" = "${internal_taira_config_sha256}" ] || fail "internal Taira configuration digest drifted"
[ "$(plist_raw SoraTairaInternalTestFlightContractId "${info_plist}")" = "${internal_taira_contract_id}" ] || fail "internal Taira contract drifted"
[ "$(plist_raw SoraTairaInternalTestFlightCurrentChainId "${info_plist}")" = "${internal_taira_chain_id}" ] || fail "internal Taira chain identity drifted"
[ "$(plist_raw SoraTairaInternalTestFlightCurrentGenesisHash "${info_plist}")" = "${internal_taira_genesis_hash}" ] || fail "internal Taira genesis identity drifted"
[ "$(plist_raw SoraTairaInternalTestFlightMcpEndpoint "${info_plist}")" = "${internal_taira_mcp_endpoint}" ] || fail "internal Taira MCP endpoint drifted"
[ "$(plist_raw SoraTairaInternalTestFlightSourceRevision "${info_plist}")" = "${source_revision}" ] || fail "internal Taira source binding drifted"
[ "$(plist_raw SoraTairaInternalTestFlightToriiBaseUrl "${info_plist}")" = "${internal_taira_torii_base_url}" ] || fail "internal Taira Torii origin drifted"
for production_taira_key in \
    SoraTairaDeploymentAdmissionContractId \
    SoraTairaDeploymentManifestSha256 \
    SoraTairaDeploymentAdmissionSha256 \
    SoraTairaCurrentChainId \
    SoraTairaRetiredChainId \
    SoraTairaCurrentGenesisHash \
    SoraTairaRetiredGenesisHash \
    SoraTairaCurrentDeploymentEpoch \
    SoraTairaRetiredDeploymentEpoch \
    SoraTairaCanonicalToriiBaseUrl \
    SoraTairaPublicMcpEndpoint \
    SoraTairaPendingRowPolicy
do
    [ -z "$(plist_raw "${production_taira_key}" "${info_plist}")" ] ||
        fail "production Taira admission leaked into the internal archive"
done
/usr/bin/codesign --verify --deep --strict "${archived_app}" >/dev/null 2>&1 || fail "archived application code signature is invalid"
/usr/bin/codesign -dvv "${archived_app}" >"${control_path}/codesign.txt" 2>&1 || fail "archived signing identity cannot be inspected"
/usr/bin/grep -Fq "TeamIdentifier=${reviewed_team_id}" "${control_path}/codesign.txt" || fail "archived signing team drifted"
/usr/bin/grep -Fq "Authority=${reviewed_archive_signing_identity}" "${control_path}/codesign.txt" || fail "archive is not signed by the reviewed Apple Development identity"
/usr/bin/codesign -d --extract-certificates="${control_path}/codesign-cert" "${archived_app}" >/dev/null 2>&1 ||
    fail "archived signing certificate chain cannot be extracted"
[ -f "${control_path}/codesign-cert0" ] && [ ! -L "${control_path}/codesign-cert0" ] ||
    fail "archived signing leaf certificate is missing"
signed_certificate_sha1="$(/usr/bin/shasum -a 1 "${control_path}/codesign-cert0" | /usr/bin/awk '{print toupper($1)}')"
signed_certificate_sha256="$(sha256_file "${control_path}/codesign-cert0")"
[ "${signed_certificate_sha1}" = "${reviewed_archive_signing_certificate_sha1}" ] &&
    [ "${signed_certificate_sha256}" = "${reviewed_archive_signing_certificate_sha256}" ] ||
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
    "com.apple.developer.team-identifier": "YLWWUD25VZ",
    "get-task-allow": True,
}:
    raise SystemExit(1)
PY
/usr/bin/security cms -D -i "${profile_path}" -o "${control_path}/profile.plist" >/dev/null 2>&1 || fail "embedded profile cannot be decoded"
[ "$(sha256_file "${profile_path}")" = "${reviewed_archive_profile_sha256}" ] ||
    fail "embedded archive profile bytes drifted"
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
if profile.get("UUID") != "908dc5a8-2b34-4617-94bb-f4a58ed5f4da":
    raise SystemExit(1)
if profile.get("Name") != "iOS Team Provisioning Profile: co.jp.soramitsu.sora":
    raise SystemExit(1)
if profile.get("TeamIdentifier") != ["YLWWUD25VZ"]:
    raise SystemExit(1)
if entitlements.get("application-identifier") != "YLWWUD25VZ.co.jp.soramitsu.sora":
    raise SystemExit(1)
if entitlements.get("com.apple.developer.team-identifier") != "YLWWUD25VZ":
    raise SystemExit(1)
if entitlements.get("get-task-allow") is not True:
    raise SystemExit(1)
if "beta-reports-active" in entitlements:
    raise SystemExit(1)
if not isinstance(profile.get("ProvisionedDevices"), list) or len(profile["ProvisionedDevices"]) != 17:
    raise SystemExit(1)
if profile.get("ProvisionsAllDevices") is True:
    raise SystemExit(1)
certificates = profile.get("DeveloperCertificates")
if not isinstance(certificates, list) or [hashlib.sha256(item).hexdigest() for item in certificates] != [
    "838ad686faf6b019d66b5a0fca25aff1b9e6956e92c353a453a9d739b67bdc52",
    "b479b9064f19cf90085926479768088416407c9e99e1537662014ba6805c179d",
    "7cd9c5bca8c27d4b504d847fb5d84c6a1c2cb8899779a44f040c7d89b3463006",
    "9173a31c6f3080a549d8ba443ab425fc46d79822ecf9d485316d83451d710328",
    "582df4037fb85e0eda3220ed45ace7f050094f9de7752b843bd041100880d1a1",
    "1fa3b9dffd3699466da99cc90d8ca9db554db36d17534ebf92a45385610d7a66",
    "f24e778e55737cf00423985d11e8664ffdc5047fc37e9d92a960ca4e5df5d742",
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
/usr/bin/python3 -I -S "${delivery_verifier}" \
    --verify-app-runtime-closure "${archived_app}" >/dev/null ||
    fail "archived application runtime dependency closure is incomplete"
executable_sha="$(sha256_file "${archived_app}/${app_executable}")"
profile_sha="$(sha256_file "${profile_path}")"
[ "$(sha256_file "${export_options}")" = "${export_options_sha}" ] &&
    [ "$(sha256_file "${export_options_snapshot}")" = "${export_options_sha}" ] ||
    fail "export options changed before upload"

if ! /usr/bin/xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${export_options_snapshot}" >"${export_log}" 2>&1; then
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
    --xcodebuild-log "${export_log}" \
    --reviewed-profile "${reviewed_profile_path}" \
    --receipt "${delivery_receipt_path}" \
    --build-number "${build_number}" >"${control_path}/delivery-verification.log"; then
    fail "Xcode did not record one exact successful Apple upload"
fi
delivery_id="$(plist_raw deliveryId "${delivery_receipt_path}")"
delivery_uploaded_at="$(plist_raw uploadedAt "${delivery_receipt_path}")"
delivery_profile_uuid="$(plist_raw provisioningProfileUuid "${delivery_receipt_path}")"
delivery_profile_name="$(plist_raw provisioningProfileName "${delivery_receipt_path}")"
delivery_profile_sha="$(plist_raw provisioningProfileSha256 "${delivery_receipt_path}")"
delivery_profile_managed="$(plist_raw provisioningProfileIsXcodeManaged "${delivery_receipt_path}")"
delivery_signing_style="$(plist_raw signingStyle "${delivery_receipt_path}")"
delivery_standard_log_sha="$(plist_raw standardDistributionLogSha256 "${delivery_receipt_path}")"
delivery_verbose_log_sha="$(plist_raw verboseDistributionLogSha256 "${delivery_receipt_path}")"
delivery_receipt_sha="$(sha256_file "${delivery_receipt_path}")"
/usr/bin/python3 -I -S - \
    "${manifest_path}" "${source_revision}" "${build_number}" "${qualification_contract_sha}" \
    "${export_options_sha}" "${executable_sha}" "${profile_sha}" \
    "${signed_certificate_sha1}" "${signed_certificate_sha256}" \
    "${delivery_id}" "${delivery_uploaded_at}" "${delivery_receipt_sha}" \
    "${delivery_profile_uuid}" "${delivery_profile_name}" "${delivery_profile_sha}" \
    "${delivery_profile_managed}" "${delivery_signing_style}" \
    "${delivery_standard_log_sha}" "${delivery_verbose_log_sha}" <<'PY'
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
    upload_profile_uuid,
    upload_profile_name,
    upload_profile_sha256,
    upload_profile_managed,
    upload_signing_style,
    standard_distribution_log_sha256,
    verbose_distribution_log_sha256,
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
    "embeddedProfileUuid": "908dc5a8-2b34-4617-94bb-f4a58ed5f4da",
    "embeddedProfileName": "iOS Team Provisioning Profile: co.jp.soramitsu.sora",
    "archivedLeafCertificateSha1": certificate_sha1,
    "archivedLeafCertificateSha256": certificate_sha256,
    "uploadProvisioningProfileUuid": upload_profile_uuid,
    "uploadProvisioningProfileName": upload_profile_name,
    "uploadProvisioningProfileSha256": upload_profile_sha256,
    "uploadProvisioningProfileIsXcodeManaged": upload_profile_managed == "true",
    "uploadSigningStyle": upload_signing_style,
    "uploadSigningCertificateSha1": "84AB95335BE14CAE9B050A353910F86FF2F9539B",
    "standardDistributionLogSha256": standard_distribution_log_sha256,
    "verboseDistributionLogSha256": verbose_distribution_log_sha256,
    "appleAdamId": "1457566711",
    "appleProviderId": "69a6de8e-8bb9-47e3-e053-5b8c7c11a4d1",
    "appleDeliveryId": delivery_id,
    "appleUploadState": "success",
    "appleUploadedAt": uploaded_at,
    "appleUploadReceiptSha256": delivery_receipt_sha256,
    "internalTairaTestFlight": {
        "contractId": "sora-ios-taira-internal-testflight-v1",
        "configurationSha256": "bac9ad666efd0d1c144ff86159899705d651457694fad4255c54e1d808c4bf90",
        "currentChainId": "fc56984b-2be7-431d-840e-21514d1883f0",
        "currentGenesisHash": "d8df4ad9f8e4b67a1734c805baed9a97fc34fc6a9ca905ac7c8daed00fbbdf3b",
        "canonicalToriiBaseUrl": "https://taira.sora.org",
        "publicMcpEndpoint": "https://taira.sora.org/v1/mcp",
    },
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
