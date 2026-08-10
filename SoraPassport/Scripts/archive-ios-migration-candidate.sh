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

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS migration observed-only candidate archive contract: OK\n'
    exit 0
fi

reproducible_build=false
build_role=""
derived_data_path=""
if [ "$#" -eq 5 ] &&
   [ "$1" = "--archive-and-export" ] &&
   [ "$2" = "--archive-path" ] &&
   [ "$4" = "--export-path" ]; then
    archive_argument="$3"
    export_argument="$5"
elif [ "$#" -eq 9 ] &&
     [ "$1" = "--archive-and-export-reproducible" ] &&
     [ "$2" = "--role" ] &&
     { [ "$3" = "primary" ] || [ "$3" = "reproduction" ]; } &&
     [ "$4" = "--derived-data-path" ] &&
     [ "$6" = "--archive-path" ] &&
     [ "$8" = "--export-path" ]; then
    reproducible_build=true
    build_role="$3"
    derived_data_argument="$5"
    archive_argument="$7"
    export_argument="$9"
else
    fail "usage: archive-ios-migration-candidate.sh --lint-contract | --archive-and-export --archive-path /private/new.xcarchive --export-path /private/new-export | --archive-and-export-reproducible --role primary|reproduction --derived-data-path /private/new-DerivedData --archive-path /private/new.xcarchive --export-path /private/new-export"
fi

lint_contract
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
: "${IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH:?protected Taira deployment manifest path is required}"
: "${IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH:?protected Taira operator signature path is required}"
: "${IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH:?protected Taira reviewer signature path is required}"
: "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH:?protected Taira operator public-key path is required}"
: "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH:?protected Taira reviewer public-key path is required}"
: "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256:?protected Taira operator public-key pin is required}"
: "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256:?protected Taira reviewer public-key pin is required}"
: "${IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS:?protected Taira deployment evaluation epoch is required}"
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

taira_admission_result="$({
    /usr/bin/python3 -B -I -S "${taira_deployment_tool}" --verify-protected \
        --manifest "${IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH}" \
        --operator-signature "${IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH}" \
        --reviewer-signature "${IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH}" \
        --operator-public-key "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH}" \
        --reviewer-public-key "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH}" \
        --operator-key-sha256 "${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256}" \
        --reviewer-key-sha256 "${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256}" \
        --evaluated-at-epoch-seconds "${IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS}" \
        --output "${taira_admission}"
})" || fail "protected Taira deployment manifest was not admitted"
case "${taira_admission_result}" in
    manifestSha256=????????????????????????????????????????????????????????????????\ admissionSha256=????????????????????????????????????????????????????????????????\ currentChainId=????????-????-????-????-????????????\ currentGenesisHash=????????????????????????????????????????????????????????????????\ currentDeploymentEpoch=*\ currentToriiBaseUrl=https://*\ currentMcpEndpoint=https://*/v1/mcp\ retiredChainId=????????-????-????-????-????????????) ;;
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

json_raw() {
    /usr/bin/plutil -extract "$1" raw -expect "$2" "${taira_admission}" 2>/dev/null
}
taira_manifest_sha="$(json_raw manifestSha256 string)" || fail "Taira manifest digest is absent"
taira_admission_sha="$({ /usr/bin/shasum -a 256 "${taira_admission}" | /usr/bin/awk '{print $1}'; })"
taira_current_chain="$(json_raw current.chainId string)" || fail "Taira current UUID is absent"
taira_retired_chain="$(json_raw retired.chainId string)" || fail "Taira retired UUID is absent"
taira_current_genesis="$(json_raw current.genesisHash string)" || fail "Taira current genesis is absent"
taira_retired_genesis="$(json_raw retired.genesisHash string)" || fail "Taira retired genesis is absent"
taira_current_epoch="$(json_raw current.deploymentEpoch integer)" || fail "Taira current deployment epoch is absent"
taira_retired_epoch="$(json_raw retired.deploymentEpoch integer)" || fail "Taira retired deployment epoch is absent"
taira_base_url="$(json_raw current.canonicalToriiBaseUrl string)" || fail "Taira canonical Torii origin is absent"
taira_mcp_endpoint="$(json_raw current.publicMcpEndpoint string)" || fail "Taira explicit MCP endpoint is absent"
[ "${taira_admission_sha}" = "$({ /usr/bin/printf '%s\n' "${taira_admission_result}" | /usr/bin/sed -E 's/^.* admissionSha256=([0-9a-f]{64}) .*$/\1/'; })" ] ||
    fail "Taira admission receipt digest changed after verification"

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
        "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE=${mode}" \
        SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION=archive \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID}" \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64}" \
        "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${IOS_MIGRATION_EVIDENCE_SOURCE_REVISION}" \
        "SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_CONTRACT_ID=sora-ios-taira-deployment-admission-v1" \
        "SORA_TAIRA_DEPLOYMENT_MANIFEST_SHA256=${taira_manifest_sha}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_SHA256=${taira_admission_sha}" \
        "SORA_TAIRA_CURRENT_CHAIN_ID=${taira_current_chain}" \
        "SORA_TAIRA_RETIRED_CHAIN_ID=${taira_retired_chain}" \
        "SORA_TAIRA_CURRENT_GENESIS_HASH=${taira_current_genesis}" \
        "SORA_TAIRA_RETIRED_GENESIS_HASH=${taira_retired_genesis}" \
        "SORA_TAIRA_CURRENT_DEPLOYMENT_EPOCH=${taira_current_epoch}" \
        "SORA_TAIRA_RETIRED_DEPLOYMENT_EPOCH=${taira_retired_epoch}" \
        "SORA_TAIRA_CANONICAL_TORII_BASE_URL=${taira_base_url}" \
        "SORA_TAIRA_PUBLIC_MCP_ENDPOINT=${taira_mcp_endpoint}" \
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
        "SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE=${mode}" \
        SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION=archive \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_KEY_ID}" \
        "SORA_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64=${IOS_MIGRATION_EVIDENCE_AUTHORIZATION_PUBLIC_KEY_X963_BASE64}" \
        "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${IOS_MIGRATION_EVIDENCE_SOURCE_REVISION}" \
        "SORA_MIGRATION_EVIDENCE_QUALIFICATION_CONTRACT_SHA256=${qualification_contract_sha}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_CONTRACT_ID=sora-ios-taira-deployment-admission-v1" \
        "SORA_TAIRA_DEPLOYMENT_MANIFEST_SHA256=${taira_manifest_sha}" \
        "SORA_TAIRA_DEPLOYMENT_ADMISSION_SHA256=${taira_admission_sha}" \
        "SORA_TAIRA_CURRENT_CHAIN_ID=${taira_current_chain}" \
        "SORA_TAIRA_RETIRED_CHAIN_ID=${taira_retired_chain}" \
        "SORA_TAIRA_CURRENT_GENESIS_HASH=${taira_current_genesis}" \
        "SORA_TAIRA_RETIRED_GENESIS_HASH=${taira_retired_genesis}" \
        "SORA_TAIRA_CURRENT_DEPLOYMENT_EPOCH=${taira_current_epoch}" \
        "SORA_TAIRA_RETIRED_DEPLOYMENT_EPOCH=${taira_retired_epoch}" \
        "SORA_TAIRA_CANONICAL_TORII_BASE_URL=${taira_base_url}" \
        "SORA_TAIRA_PUBLIC_MCP_ENDPOINT=${taira_mcp_endpoint}" \
        "SORA_TAIRA_PENDING_ROW_POLICY=schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation" \
        archive >"${archive_log}" 2>&1; then
        fail "candidate archive failed; protected archive log retained"
    fi
fi

[ -d "${archive_path}" ] && [ ! -L "${archive_path}" ] ||
    fail "candidate archive was not created as a non-symbolic directory"

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
            --signing-receipt-sha "${signing_identity_sha}" \
            --vendored-receipt-sha "${vendored_binary_sha}" \
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
