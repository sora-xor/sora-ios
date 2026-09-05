#!/bin/sh
set -eu

# Create one production-scheme Release archive/export as observed migration
# input. This route never uploads or promotes. The target build phase still runs
# every ordinary Release gate except the receipt-dependent migration admission
# that this exact exported IPA exists to produce.

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"
project="${root}/SoraPassport.xcodeproj"
scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassport.xcscheme"
export_options="${root}/SoraPassport/Configs/ios-migration-candidate-export-options.plist"
handoff_tool="${root}/SoraPassport/Scripts/create-ios-migration-candidate-handoff.py"
contract_tool="${root}/SoraPassport/Scripts/ios-migration-qualification-contract.py"
exact_ipa_controller="${root}/SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py"
release_package_tool="${root}/SoraPassport/Scripts/verify-ios-release-reproducibility-package.py"
signing_identity_tool="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.sh"
vendored_binary_tool="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh"
taira_deployment_tool="${root}/SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
mode="sora-ios-migration-observed-only-candidate-archive-v1"
maximum_taira_deployment_candidate_age_seconds=21600
production_bundle_identifier="co.jp.soramitsu.sora"
production_development_team="YLWWUD25VZ"
production_application_identifier="YLWWUD25VZ.co.jp.soramitsu.sora"
production_distribution_certificate_name="Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)"
production_distribution_certificate_sha1="84AB95335BE14CAE9B050A353910F86FF2F9539B"
production_distribution_certificate_sha256="d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"
production_distribution_certificate_sha256_upper="D830D54BCE8E583089F2ED8CF927FC12B60C9D591E560FFE6F5D2A71C91317FB"
production_provisioning_profile_uuid="7ae520bc-599b-48ae-abfa-627eef530f0c"
production_provisioning_profile_name="iOS Team Store Provisioning Profile: co.jp.soramitsu.sora"
production_provisioning_profile_raw_sha256="19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"
production_provisioning_profile_path="${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${production_provisioning_profile_uuid}.mobileprovision"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

lint_contract() {
    for required in "${project}/project.pbxproj" "${scheme}" "${export_options}" "${handoff_tool}" "${contract_tool}" "${exact_ipa_controller}" "${release_package_tool}" "${signing_identity_tool}" "${vendored_binary_tool}" "${taira_deployment_tool}"
    do
        [ -f "${required}" ] && [ ! -L "${required}" ] ||
            fail "candidate archive contract input is missing or symbolic: ${required}"
    done
    /usr/bin/python3 -I -S "${handoff_tool}" --lint-contract >/dev/null
    /usr/bin/python3 -B -I -S "${release_package_tool}" --lint-contract >/dev/null
    /bin/sh "${signing_identity_tool}" --lint-templates >/dev/null
    /bin/sh "${vendored_binary_tool}" --lint-templates >/dev/null
    /usr/bin/python3 -B -I -S "${taira_deployment_tool}" --lint-contract >/dev/null
    /usr/bin/grep -Fq 'buildForArchiving = "YES"' "${scheme}" ||
        fail "production scheme does not archive the production target"
    /usr/bin/grep -Fq 'buildConfiguration = "Release"' "${scheme}" ||
        fail "production scheme lacks its Release archive action"
}

canonical_build_number() {
    raw_value="$1"
    value_label="$2"
    case "${raw_value}" in
        ''|0|0*|*[!0-9]*) fail "${value_label} must be one positive canonical decimal integer" ;;
    esac
    [ "${#raw_value}" -le 18 ] ||
        fail "${value_label} exceeds the 18-digit release bound"
    /usr/bin/printf '%s\n' "${raw_value}"
}

canonical_epoch_seconds() {
    raw_value="$1"
    value_label="$2"
    case "${raw_value}" in
        ''|0|0*|*[!0-9]*) fail "${value_label} must be one positive canonical epoch" ;;
    esac
    [ "${#raw_value}" -le 10 ] && [ "${raw_value}" -le 9999999999 ] 2>/dev/null ||
        fail "${value_label} exceeds the canonical epoch bound"
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
    case "${canonical_path}/" in "${root}/"*) fail "${path_label} must remain outside the repository" ;; esac
    [ ! -e "${canonical_path}" ] && [ ! -L "${canonical_path}" ] ||
        fail "${path_label} must be fresh"
    /usr/bin/printf '%s\n' "${canonical_path}"
}

require_exact_codesigning_identity() {
    identity_listing="$({
        /usr/bin/security find-identity -v -p codesigning
    })" || fail "installed code-signing identities cannot be enumerated"
    identity_count="$({
        /usr/bin/printf '%s\n' "${identity_listing}" | /usr/bin/awk \
            -v fingerprint="${production_distribution_certificate_sha1}" \
            -v common_name="${production_distribution_certificate_name}" '
                $2 == fingerprint && index($0, "\"" common_name "\"") > 0 {
                    count += 1
                }
                END { print count + 0 }
            '
    })"
    [ "${identity_count}" = "1" ] ||
        fail "exact retained Apple Distribution identity and private key are not installed"

    certificate_listing="$({
        /usr/bin/security find-certificate -a -Z \
            -c "${production_distribution_certificate_name}"
    })" || fail "retained Apple Distribution certificate cannot be enumerated"
    certificate_pair_count="$({
        /usr/bin/printf '%s\n' "${certificate_listing}" | /usr/bin/awk \
            -v expected_sha1="${production_distribution_certificate_sha1}" \
            -v expected_sha256="${production_distribution_certificate_sha256_upper}" '
                $0 == "SHA-256 hash: " expected_sha256 { pending = 1; next }
                pending == 1 && $0 == "SHA-1 hash: " expected_sha1 {
                    count += 1
                    pending = 0
                    next
                }
                { pending = 0 }
                END { print count + 0 }
            '
    })"
    [ "${certificate_pair_count}" = "1" ] ||
        fail "retained Apple Distribution certificate fingerprints are not exact"
}

validate_installed_production_profile() {
    [ -f "${production_provisioning_profile_path}" ] &&
        [ ! -L "${production_provisioning_profile_path}" ] ||
        fail "retained App Store provisioning profile is not installed at its pinned Xcode path"
    installed_profile_sha="$({
        /usr/bin/shasum -a 256 "${production_provisioning_profile_path}" |
            /usr/bin/awk '{print $1}'
    })" || fail "installed App Store provisioning profile cannot be hashed"
    [ "${installed_profile_sha}" = "${production_provisioning_profile_raw_sha256}" ] ||
        fail "installed App Store provisioning profile differs from the retained profile"
    /usr/bin/security cms -D \
        -i "${production_provisioning_profile_path}" \
        -o "${production_profile_plist_snapshot}" >/dev/null 2>&1 ||
        fail "installed App Store provisioning profile does not have a valid CMS envelope"
    /bin/chmod 600 "${production_profile_plist_snapshot}" ||
        fail "decoded provisioning-profile snapshot cannot be made owner-only"

    [ "$({ /usr/bin/plutil -extract UUID raw -expect string "${production_profile_plist_snapshot}" 2>/dev/null; })" = "${production_provisioning_profile_uuid}" ] ||
        fail "installed App Store provisioning profile UUID drifted"
    [ "$({ /usr/bin/plutil -extract Name raw -expect string "${production_profile_plist_snapshot}" 2>/dev/null; })" = "${production_provisioning_profile_name}" ] ||
        fail "installed App Store provisioning profile name drifted"
    [ "$({ /usr/bin/plutil -extract TeamIdentifier.0 raw -expect string "${production_profile_plist_snapshot}" 2>/dev/null; })" = "${production_development_team}" ] ||
        fail "installed App Store provisioning profile team drifted"
    [ "$({ /usr/bin/plutil -extract ApplicationIdentifierPrefix.0 raw -expect string "${production_profile_plist_snapshot}" 2>/dev/null; })" = "${production_development_team}" ] ||
        fail "installed App Store provisioning profile application prefix drifted"
    [ "$({ /usr/bin/plutil -extract Entitlements.application-identifier raw -expect string "${production_profile_plist_snapshot}" 2>/dev/null; })" = "${production_application_identifier}" ] ||
        fail "installed App Store provisioning profile application identifier drifted"

    profile_certificate_count="$({
        /usr/bin/plutil -extract DeveloperCertificates raw \
            "${production_profile_plist_snapshot}" 2>/dev/null
    })" || fail "installed App Store provisioning profile lacks its certificate inventory"
    case "${profile_certificate_count}" in
        ''|0|*[!0-9]*) fail "installed App Store provisioning profile certificate count is invalid" ;;
    esac
    [ "${profile_certificate_count}" -le 16 ] ||
        fail "installed App Store provisioning profile certificate inventory is excessive"
    profile_certificate_index=0
    profile_certificate_match_count=0
    while [ "${profile_certificate_index}" -lt "${profile_certificate_count}" ]; do
        profile_certificate_base64="$({
            /usr/bin/plutil -extract "DeveloperCertificates.${profile_certificate_index}" raw \
                "${production_profile_plist_snapshot}" 2>/dev/null
        })" || fail "installed App Store provisioning profile certificate cannot be decoded"
        profile_certificate_sha1="$({
            /usr/bin/printf '%s' "${profile_certificate_base64}" |
                /usr/bin/base64 -D |
                /usr/bin/shasum |
                /usr/bin/awk '{print toupper($1)}'
        })" || fail "installed App Store provisioning profile certificate SHA-1 cannot be computed"
        profile_certificate_sha256="$({
            /usr/bin/printf '%s' "${profile_certificate_base64}" |
                /usr/bin/base64 -D |
                /usr/bin/shasum -a 256 |
                /usr/bin/awk '{print $1}'
        })" || fail "installed App Store provisioning profile certificate SHA-256 cannot be computed"
        if [ "${profile_certificate_sha1}" = "${production_distribution_certificate_sha1}" ] &&
           [ "${profile_certificate_sha256}" = "${production_distribution_certificate_sha256}" ]; then
            profile_certificate_match_count=$((profile_certificate_match_count + 1))
        fi
        profile_certificate_index=$((profile_certificate_index + 1))
    done
    [ "${profile_certificate_match_count}" = "1" ] ||
        fail "installed App Store provisioning profile does not contain the exact retained distribution certificate"
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS migration observed-only candidate archive contract: OK\n'
    exit 0
fi

reproducible_build=false
build_role=""
derived_data_path=""
if [ "$#" -eq 7 ] &&
   [ "$1" = "--archive-and-export" ] &&
   [ "$2" = "--build-number" ] &&
   [ "$4" = "--archive-path" ] &&
   [ "$6" = "--export-path" ]; then
    build_number_argument="$3"
    archive_argument="$5"
    export_argument="$7"
elif [ "$#" -eq 11 ] &&
     [ "$1" = "--archive-and-export-reproducible" ] &&
     [ "$2" = "--role" ] &&
     { [ "$3" = "primary" ] || [ "$3" = "reproduction" ]; } &&
     [ "$4" = "--build-number" ] &&
     [ "$6" = "--derived-data-path" ] &&
     [ "$8" = "--archive-path" ] &&
     [ "${10}" = "--export-path" ]; then
    reproducible_build=true
    build_role="$3"
    build_number_argument="$5"
    derived_data_argument="$7"
    archive_argument="$9"
    export_argument="${11}"
else
    fail "usage: archive-ios-migration-candidate.sh --lint-contract | --archive-and-export --build-number N --archive-path /private/new.xcarchive --export-path /private/new-export | --archive-and-export-reproducible --role primary|reproduction --build-number N --derived-data-path /private/new-DerivedData --archive-path /private/new.xcarchive --export-path /private/new-export"
fi

lint_contract
build_number="$(canonical_build_number "${build_number_argument}" "candidate build number")"
: "${IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND:?controller-provided App Store build-number lower bound is required}"
app_store_build_number_lower_bound="$(canonical_build_number "${IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND}" "App Store build-number lower bound")"
[ "${build_number}" -gt "${app_store_build_number_lower_bound}" ] ||
    fail "candidate build number must be greater than the controller-provided App Store lower bound"
archive_path="$(canonical_fresh_private_path "${archive_argument}" ".xcarchive" "candidate archive path")"
export_path="$(canonical_fresh_private_path "${export_argument}" "-export" "candidate export path")"
[ "${archive_path}" != "${export_path}" ] || fail "candidate archive and export paths must differ"
control_path="$(canonical_fresh_private_path "${archive_path}.observed-control" ".observed-control" "candidate control path")"
if [ "${reproducible_build}" = true ]; then
    derived_data_path="$(canonical_fresh_private_path "${derived_data_argument}" "-DerivedData" "candidate DerivedData path")"
    [ "${derived_data_path}" != "${archive_path}" ] && [ "${derived_data_path}" != "${export_path}" ] ||
        fail "candidate DerivedData, archive, and export paths must be distinct"
    [ -x /usr/bin/git ] || fail "git is required to prove a clean Release checkout"
    [ "$(/usr/bin/git -C "${root}" rev-parse --show-toplevel 2>/dev/null)" = "${root}" ] ||
        fail "Release checkout root is not exact"
    [ -z "$(/usr/bin/git -C "${root}" status --porcelain=v1 --untracked-files=normal)" ] ||
        fail "independent Release archive/export requires a completely clean checkout"
fi

: "${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID:?protected evidence authorization key ID is required}"
: "${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64:?protected evidence authorization public point is required}"
: "${IOS_MIGRATION_EVIDENCE_SOURCE_REVISION:?protected evidence source revision is required}"
: "${IOS_SIGNING_IDENTITY_RECEIPT_PATH:?protected external signing-identity receipt path is required}"
: "${IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH:?protected Taira deployment manifest path is required}"
: "${IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH:?protected Taira operator signature path is required}"
: "${IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH:?protected Taira reviewer signature path is required}"
: "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH:?protected Taira operator public-key path is required}"
: "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH:?protected Taira reviewer public-key path is required}"
: "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256:?protected Taira operator public-key pin is required}"
: "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256:?protected Taira reviewer public-key pin is required}"
: "${IOS_TAIRA_DEPLOYMENT_EXPECTED_MANIFEST_SEQUENCE_NUMBER:?protected exact Taira manifest sequence is required}"
: "${IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS:?protected Taira deployment evaluation epoch is required}"
taira_deployment_evaluation_epoch="$(canonical_epoch_seconds "${IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS}" "Taira deployment evaluation epoch")"
current_epoch="$(/bin/date +%s)"
minimum_taira_deployment_epoch=$((current_epoch - maximum_taira_deployment_candidate_age_seconds))
[ "${taira_deployment_evaluation_epoch}" -ge "${minimum_taira_deployment_epoch}" ] &&
    [ "${taira_deployment_evaluation_epoch}" -le "${current_epoch}" ] ||
    fail "Taira deployment admission must be no more than six hours old and not future-dated for candidate archive"
authority_binding="$({
    /usr/bin/python3 -I -S "${exact_ipa_controller}" \
        --validate-authority-binding \
        --key-id "${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID}" \
        --public-point-base64 "${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64}" \
        --source-revision "${IOS_MIGRATION_EVIDENCE_SOURCE_REVISION}"
})" || fail "protected evidence authorization binding is invalid"
[ "$({ /usr/bin/printf '%s\n' "${authority_binding}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "protected evidence authorization binding returned an ambiguous result"
case "${authority_binding}" in
    authorizationKeyIdSha256=????????????????????????????????????????????????????????????????\ authorizationPublicPointSha256=????????????????????????????????????????????????????????????????\ sourceRevision=????????????????????????????????????????) ;;
    *) fail "protected evidence authorization binding returned an invalid result" ;;
esac

umask 077
/bin/mkdir -m 700 "${control_path}" ||
    fail "candidate control directory cannot be created exclusively"
qualification_contract_snapshot="${control_path}/qualification-contract.json"
export_options_snapshot="${control_path}/export-options.plist"
archive_log="${control_path}/archive.log"
export_log="${control_path}/export.log"
taira_admission="${control_path}/taira-deployment-admission.json"
signing_receipt_snapshot="${control_path}/signing-identity-receipt.json"
production_profile_plist_snapshot="${control_path}/production-provisioning-profile.plist"

require_exact_codesigning_identity
validate_installed_production_profile

taira_admission_result="$({
    /usr/bin/python3 -B -I -S "${taira_deployment_tool}" --verify-protected \
        --manifest "${IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH}" \
        --operator-signature "${IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH}" \
        --reviewer-signature "${IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH}" \
        --operator-public-key "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH}" \
        --reviewer-public-key "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH}" \
        --operator-key-sha256 "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256}" \
        --reviewer-key-sha256 "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256}" \
        --expected-manifest-sequence-number "${IOS_TAIRA_DEPLOYMENT_EXPECTED_MANIFEST_SEQUENCE_NUMBER}" \
        --evaluated-at-epoch-seconds "${taira_deployment_evaluation_epoch}" \
        --output "${taira_admission}"
})" || fail "protected Taira deployment manifest was not admitted"
case "${taira_admission_result}" in
    manifestSha256=????????????????????????????????????????????????????????????????\ admissionSha256=????????????????????????????????????????????????????????????????\ manifestSequenceNumber=*\ currentChainId=????????-????-????-????-????????????\ currentGenesisHash=????????????????????????????????????????????????????????????????\ currentDeploymentEpoch=*\ currentToriiBaseUrl=https://*\ currentMcpEndpoint=https://*/v1/mcp\ currentExplorerBaseUrl=https://*\ retiredChainId=????????-????-????-????-????????????\ retiredGenesisHash=????????????????????????????????????????????????????????????????\ retiredDeploymentEpoch=*) ;;
    *) fail "protected Taira deployment admission returned an invalid projection" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${taira_admission_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "protected Taira deployment admission returned multiple projections"

signing_identity_result="$({
    /bin/sh "${signing_identity_tool}" --verify-qualified
})" || fail "protected production signing-continuity receipt was not admitted"
case "${signing_identity_result}" in
    receiptSha256=????????????????????????????????????????????????????????????????)
        signing_identity_sha="${signing_identity_result#receiptSha256=}"
        ;;
    *) fail "protected production signing-continuity admission returned an invalid result" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${signing_identity_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "protected production signing-continuity admission returned multiple records"
/usr/bin/install -m 600 \
    "${IOS_SIGNING_IDENTITY_RECEIPT_PATH}" \
    "${signing_receipt_snapshot}" ||
    fail "admitted signing-identity receipt cannot be snapshotted owner-only"
[ -f "${signing_receipt_snapshot}" ] && [ ! -L "${signing_receipt_snapshot}" ] &&
    [ "$({ /usr/bin/stat -f '%u:%Sp:%l' "${signing_receipt_snapshot}"; })" = "$({ /usr/bin/id -u; }):-rw-------:1" ] ||
    fail "signing-identity receipt snapshot is not one owner-only regular inode"
signing_receipt_snapshot_sha="$({
    /usr/bin/shasum -a 256 "${signing_receipt_snapshot}" |
        /usr/bin/awk '{print $1}'
})" || fail "signing-identity receipt snapshot cannot be hashed"
[ "${signing_receipt_snapshot_sha}" = "${signing_identity_sha}" ] ||
    fail "signing-identity receipt changed while it was snapshotted"

vendored_binary_result="$({
    /bin/sh "${vendored_binary_tool}" --verify-qualified
})" || fail "protected vendored-binary qualification receipt was not admitted"
case "${vendored_binary_result}" in
    receiptSha256=????????????????????????????????????????????????????????????????)
        vendored_binary_sha="${vendored_binary_result#receiptSha256=}"
        ;;
    *) fail "protected vendored-binary admission returned an invalid result" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${vendored_binary_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "protected vendored-binary admission returned multiple records"

admission_projection_value() {
    projection_key="$1"
    /usr/bin/printf '%s\n' "${taira_admission_result}" | /usr/bin/awk -v key="${projection_key}" '
        {
            prefix = key "="
            for (field_index = 1; field_index <= NF; field_index += 1) {
                if (substr($field_index, 1, length(prefix)) == prefix) {
                    count += 1
                    value = substr($field_index, length(prefix) + 1)
                }
            }
        }
        END {
            if (count != 1 || value == "") exit 1
            print value
        }
    '
}
taira_manifest_sha="$(admission_projection_value manifestSha256)" || fail "Taira manifest digest is absent"
taira_admission_sha="$(admission_projection_value admissionSha256)" || fail "Taira admission digest is absent"
taira_manifest_sequence="$(admission_projection_value manifestSequenceNumber)" || fail "Taira manifest sequence is absent"
taira_current_chain="$(admission_projection_value currentChainId)" || fail "Taira current UUID is absent"
taira_retired_chain="$(admission_projection_value retiredChainId)" || fail "Taira retired UUID is absent"
taira_current_genesis="$(admission_projection_value currentGenesisHash)" || fail "Taira current genesis is absent"
taira_retired_genesis="$(admission_projection_value retiredGenesisHash)" || fail "Taira retired genesis is absent"
taira_current_epoch="$(admission_projection_value currentDeploymentEpoch)" || fail "Taira current deployment epoch is absent"
taira_retired_epoch="$(admission_projection_value retiredDeploymentEpoch)" || fail "Taira retired deployment epoch is absent"
taira_base_url="$(admission_projection_value currentToriiBaseUrl)" || fail "Taira canonical Torii origin is absent"
taira_mcp_endpoint="$(admission_projection_value currentMcpEndpoint)" || fail "Taira explicit MCP endpoint is absent"
taira_explorer_base_url="$(admission_projection_value currentExplorerBaseUrl)" || fail "Taira explorer origin is absent"
[ "${taira_manifest_sequence}" = "${IOS_TAIRA_DEPLOYMENT_EXPECTED_MANIFEST_SEQUENCE_NUMBER}" ] ||
    fail "Taira admission sequence differs from protected release sequence"

qualification_contract_sha="$({
    /usr/bin/python3 -I -S "${contract_tool}" \
        --repository-root "${root}" \
        --snapshot "${qualification_contract_snapshot}"
})" || fail "candidate qualification source contract cannot be snapshotted"
case "${qualification_contract_sha}" in
    *[!0-9a-f]*|'') fail "candidate qualification source contract returned an invalid SHA-256" ;;
esac
[ "${#qualification_contract_sha}" -eq 64 ] ||
    fail "candidate qualification source contract returned an invalid SHA-256"

export_options_result="$({
    /usr/bin/python3 -I -S "${handoff_tool}" \
        --snapshot-export-options "${export_options_snapshot}"
})" || fail "candidate export options cannot be snapshotted"
case "${export_options_result}" in
    exportOptionsSha256=*) export_options_sha="${export_options_result#exportOptionsSha256=}" ;;
    *) fail "candidate export-options snapshot returned an invalid result" ;;
esac
case "${export_options_sha}" in
    *[!0-9a-f]*|'') fail "candidate export-options snapshot returned an invalid SHA-256" ;;
esac
[ "${#export_options_sha}" -eq 64 ] &&
    [ "$(/usr/bin/printf '%s\n' "${export_options_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" = "1" ] ||
    fail "candidate export-options snapshot returned an invalid SHA-256"

/usr/bin/printf '%s\n' \
    'warning: creating an observed-only production candidate; no upload or promotion authority is granted' >&2

if [ "${reproducible_build}" = true ]; then
    if ! /usr/bin/xcodebuild \
        -project "${project}" \
        -scheme SoraPassport \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "${derived_data_path}" \
        -archivePath "${archive_path}" \
        CODE_SIGN_STYLE=Manual \
        "CODE_SIGN_IDENTITY=${production_distribution_certificate_sha1}" \
        "DEVELOPMENT_TEAM=${production_development_team}" \
        "PROVISIONING_PROFILE_SPECIFIER=${production_provisioning_profile_uuid}" \
        "CURRENT_PROJECT_VERSION=${build_number}" \
        "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE=${mode}" \
        SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION=archive \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID}" \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64}" \
        "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${IOS_MIGRATION_EVIDENCE_SOURCE_REVISION}" \
        "SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_CONTRACT_ID=sora-ios-taira-deployment-admission-v2" \
        "SORA_TAIRA_DEPLOYMENT_MANIFEST_SHA256=${taira_manifest_sha}" \
        "SORA_TAIRA_DEPLOYMENT_MANIFEST_SEQUENCE_NUMBER=${taira_manifest_sequence}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_SHA256=${taira_admission_sha}" \
        "SORA_TAIRA_CURRENT_CHAIN_ID=${taira_current_chain}" \
        "SORA_TAIRA_RETIRED_CHAIN_ID=${taira_retired_chain}" \
        "SORA_TAIRA_CURRENT_GENESIS_HASH=${taira_current_genesis}" \
        "SORA_TAIRA_RETIRED_GENESIS_HASH=${taira_retired_genesis}" \
        "SORA_TAIRA_CURRENT_DEPLOYMENT_EPOCH=${taira_current_epoch}" \
        "SORA_TAIRA_RETIRED_DEPLOYMENT_EPOCH=${taira_retired_epoch}" \
        "SORA_TAIRA_CANONICAL_TORII_BASE_URL=${taira_base_url}" \
        "SORA_TAIRA_PUBLIC_MCP_ENDPOINT=${taira_mcp_endpoint}" \
        "SORA_TAIRA_EXPLORER_BASE_URL=${taira_explorer_base_url}" \
        "SORA_TAIRA_PENDING_ROW_POLICY=schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation" \
        archive >"${archive_log}" 2>&1; then
        fail "reproducible candidate archive failed; protected archive log retained"
    fi
else
    if ! /usr/bin/xcodebuild \
        -project "${project}" \
        -scheme SoraPassport \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "${archive_path}" \
        CODE_SIGN_STYLE=Manual \
        "CODE_SIGN_IDENTITY=${production_distribution_certificate_sha1}" \
        "DEVELOPMENT_TEAM=${production_development_team}" \
        "PROVISIONING_PROFILE_SPECIFIER=${production_provisioning_profile_uuid}" \
        "CURRENT_PROJECT_VERSION=${build_number}" \
        "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE=${mode}" \
        SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION=archive \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID}" \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64}" \
        "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${IOS_MIGRATION_EVIDENCE_SOURCE_REVISION}" \
        "SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_CONTRACT_ID=sora-ios-taira-deployment-admission-v2" \
        "SORA_TAIRA_DEPLOYMENT_MANIFEST_SHA256=${taira_manifest_sha}" \
        "SORA_TAIRA_DEPLOYMENT_MANIFEST_SEQUENCE_NUMBER=${taira_manifest_sequence}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_SHA256=${taira_admission_sha}" \
        "SORA_TAIRA_CURRENT_CHAIN_ID=${taira_current_chain}" \
        "SORA_TAIRA_RETIRED_CHAIN_ID=${taira_retired_chain}" \
        "SORA_TAIRA_CURRENT_GENESIS_HASH=${taira_current_genesis}" \
        "SORA_TAIRA_RETIRED_GENESIS_HASH=${taira_retired_genesis}" \
        "SORA_TAIRA_CURRENT_DEPLOYMENT_EPOCH=${taira_current_epoch}" \
        "SORA_TAIRA_RETIRED_DEPLOYMENT_EPOCH=${taira_retired_epoch}" \
        "SORA_TAIRA_CANONICAL_TORII_BASE_URL=${taira_base_url}" \
        "SORA_TAIRA_PUBLIC_MCP_ENDPOINT=${taira_mcp_endpoint}" \
        "SORA_TAIRA_EXPLORER_BASE_URL=${taira_explorer_base_url}" \
        "SORA_TAIRA_PENDING_ROW_POLICY=schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation" \
        archive >"${archive_log}" 2>&1; then
        fail "candidate archive failed; protected archive log retained"
    fi
fi

[ -d "${archive_path}" ] && [ ! -L "${archive_path}" ] ||
    fail "candidate archive was not created as a non-symbolic directory"
archived_app_count="$({ /usr/bin/find "${archive_path}/Products/Applications" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })"
[ "${archived_app_count}" = "1" ] ||
    fail "candidate archive does not contain exactly one application"
archived_app="$({ /usr/bin/find "${archive_path}/Products/Applications" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print; })"
[ ! -L "${archived_app}" ] && [ -f "${archived_app}/Info.plist" ] && [ ! -L "${archived_app}/Info.plist" ] ||
    fail "candidate archived application identity is missing or symbolic"
archived_build_number="$({ /usr/bin/plutil -extract CFBundleVersion raw -expect string "${archived_app}/Info.plist" 2>/dev/null; })" ||
    fail "candidate archived application lacks its build number"
[ "${archived_build_number}" = "${build_number}" ] ||
    fail "candidate archived application build number differs from the controller-authorized input"

if ! /usr/bin/xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${export_options_snapshot}" >"${export_log}" 2>&1; then
    fail "candidate export failed; protected export log retained"
fi

[ -d "${export_path}" ] && [ ! -L "${export_path}" ] ||
    fail "candidate export was not created as a non-symbolic directory"
/bin/chmod 700 "${export_path}"

signing_identity_recheck="$({
    /bin/sh "${signing_identity_tool}" --verify-qualified
})" || fail "protected production signing-continuity receipt failed its post-export recheck"
[ "${signing_identity_recheck}" = "receiptSha256=${signing_identity_sha}" ] ||
    fail "protected production signing-continuity receipt changed during archive/export"
signing_receipt_snapshot_recheck="$({
    /usr/bin/shasum -a 256 "${signing_receipt_snapshot}" |
        /usr/bin/awk '{print $1}'
})" || fail "signing-identity receipt snapshot cannot be rechecked"
[ "${signing_receipt_snapshot_recheck}" = "${signing_identity_sha}" ] ||
    fail "snapshotted signing-identity receipt changed during archive/export"
installed_profile_recheck="$({
    /usr/bin/shasum -a 256 "${production_provisioning_profile_path}" |
        /usr/bin/awk '{print $1}'
})" || fail "installed App Store provisioning profile cannot be rechecked"
[ "${installed_profile_recheck}" = "${production_provisioning_profile_raw_sha256}" ] ||
    fail "installed App Store provisioning profile changed during archive/export"
require_exact_codesigning_identity
vendored_binary_recheck="$({
    /bin/sh "${vendored_binary_tool}" --verify-qualified
})" || fail "protected vendored-binary receipt failed its post-export recheck"
[ "${vendored_binary_recheck}" = "receiptSha256=${vendored_binary_sha}" ] ||
    fail "protected vendored-binary receipt changed during archive/export"

/usr/bin/python3 -I -S "${contract_tool}" \
    --repository-root "${root}" \
    --verify-snapshot "${qualification_contract_snapshot}" \
    --expected-sha "${qualification_contract_sha}" >/dev/null ||
    fail "candidate qualification source contract changed during archive/export"
/usr/bin/python3 -I -S "${handoff_tool}" \
    --verify-export-options-snapshot "${export_options_snapshot}" \
    "${export_options_sha}" >/dev/null ||
    fail "candidate export-options snapshot changed during archive/export"
/usr/bin/python3 -I -S "${handoff_tool}" \
    --verify-export-options-source "${export_options_sha}" >/dev/null ||
    fail "candidate export-options source changed during archive/export"

handoff_result="$({
    /usr/bin/python3 -I -S "${handoff_tool}" \
        --create \
        --export-root "${export_path}" \
        --qualification-contract-sha "${qualification_contract_sha}" \
        --export-options-sha "${export_options_sha}"
})" || fail "candidate identity handoff could not be created"
case "${handoff_result}" in
    ipaPath=/*\ ipaSha256=????????????????????????????????????????????????????????????????\ handoffSha256=????????????????????????????????????????????????????????????????) ;;
    *) fail "candidate identity handoff returned an invalid result" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${handoff_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "candidate identity handoff returned multiple records"
handoff_path="${export_path}/ios-migration-candidate-handoff.json"
handoff_build_number="$({ /usr/bin/plutil -extract ipa.buildVersion raw -expect string "${handoff_path}" 2>/dev/null; })" ||
    fail "candidate identity handoff lacks its build number"
[ "${handoff_build_number}" = "${build_number}" ] ||
    fail "candidate exported IPA build number differs from the controller-authorized input"

if [ "${reproducible_build}" = true ]; then
    candidate_ipa="${handoff_result#ipaPath=}"
    candidate_ipa="${candidate_ipa%% ipaSha256=*}"
    build_manifest="${control_path}/${build_role}-build-manifest.json"
    manifest_result="$({
        /usr/bin/python3 -B -I -S "${release_package_tool}" \
            --capture-build-manifest \
            --role "${build_role}" \
            --repository "${root}" \
            --derived-data "${derived_data_path}" \
            --archive "${archive_path}" \
            --export "${export_path}" \
            --ipa "${candidate_ipa}" \
            --archive-log "${archive_log}" \
            --export-log "${export_log}" \
            --qualification-contract-sha "${qualification_contract_sha}" \
            --signing-receipt "${signing_receipt_snapshot}" \
            --signing-receipt-sha "${signing_identity_sha}" \
            --vendored-receipt-sha "${vendored_binary_sha}" \
            --build-number "${build_number}" \
            --app-store-build-lower-bound "${app_store_build_number_lower_bound}" \
            --output "${build_manifest}"
    })" || fail "candidate archive/export manifest could not be captured"
    case "${manifest_result}" in
        buildManifestSha256=????????????????????????????????????????????????????????????????) ;;
        *) fail "candidate build manifest returned an invalid result" ;;
    esac
    /usr/bin/printf '%s buildManifestPath=%s %s\n' \
        "${handoff_result}" "${build_manifest}" "${manifest_result}"
else
    /usr/bin/printf '%s\n' "${handoff_result}"
fi
