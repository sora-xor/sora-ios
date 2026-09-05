#!/bin/sh
set -eu

# This is a post-export promotion gate. Ordinary Xcode builds must call only
# --lint-templates through verify-modernization-dependencies.sh. A production
# invocation with missing controller inputs is always an error.

root="$({ CDPATH= cd "$(/usr/bin/dirname "$0")/../.." && /bin/pwd -P; })"
candidate_template="${root}/Fixtures/Modernization/production-rollout-candidate.blocked.json"
advancement_template="${root}/Fixtures/Modernization/production-rollout-advancement.blocked.json"
controller_trust="${root}/Fixtures/Modernization/production-rollout-controller-trust.json"
json_validator="${root}/SoraPassport/Scripts/verify-production-rollout-json.py"
funded_canary_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary.sh"
taira_deployment_validator="${root}/SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
migration_promotion_admission="${root}/SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"
maximum_json_bytes=262144
maximum_signature_bytes=4096
maximum_public_key_bytes=65536
maximum_ipa_bytes=4294967296
maximum_path_characters=4096
minimum_dwell_seconds=172800
maximum_freshness_seconds=300
maximum_authorization_delay_seconds=30
maximum_taira_deployment_rollout_age_seconds=604800
sora2_revision="411dcdb70c5c00b21482a44d02334840d5f338c6"
reviewed_runtime_metadata_sha256="2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf"
production_bundle_identifier="co.jp.soramitsu.sora"
production_development_team="YLWWUD25VZ"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

secure_openssl() {
    /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/openssl "$@"
}

is_lower_hex_64() {
    value="$1"
    [ "${#value}" -eq 64 ] || return 1
    case "${value}" in
        *[!0-9a-f]*) return 1 ;;
    esac
    [ "${value}" != "0000000000000000000000000000000000000000000000000000000000000000" ] || return 1
}

is_lower_hex_40() {
    value="$1"
    [ "${#value}" -eq 40 ] || return 1
    case "${value}" in
        *[!0-9a-f]*) return 1 ;;
    esac
    [ "${value}" != "0000000000000000000000000000000000000000" ] || return 1
}

is_epoch_seconds() {
    value="$1"
    case "${value}" in
        ""|*[!0-9]*) return 1 ;;
    esac
    [ "${#value}" -le 10 ] || return 1
    [ "${value}" -le 9999999999 ] 2>/dev/null
}

is_exact_sequence() {
    value="$1"
    case "${value}" in
        ""|0|0*|*[!0-9]*) return 1 ;;
    esac
    [ "${#value}" -le 16 ] &&
        [ "${value}" -le 9007199254740991 ] 2>/dev/null
}

require_absolute_path() {
    checked_path="$1"
    checked_label="$2"
    [ -n "${checked_path}" ] || fail "${checked_label} path is missing"
    [ "${#checked_path}" -le "${maximum_path_characters}" ] ||
        fail "${checked_label} path is too long"
    case "${checked_path}" in
        /*) ;;
        *) fail "${checked_label} path must be absolute" ;;
    esac
}

json_raw() {
    /usr/bin/plutil -extract "$1" raw "$2" 2>/dev/null || /usr/bin/true
}

admission_projection_value() {
    projection="$1"
    projection_key="$2"
    /usr/bin/printf '%s\n' "${projection}" | /usr/bin/awk -v key="${projection_key}" '
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

secure_sha256() {
    hashed_path="$1"
    byte_bound="$2"
    hashed_label="$3"
    require_absolute_path "${hashed_path}" "${hashed_label}"
    result="$(
        /usr/bin/python3 -I -S "${json_validator}" hash "${hashed_path}" "${byte_bound}"
    )" || fail "${hashed_label} is not one stable regular non-symlink file"
    is_lower_hex_64 "${result}" || fail "${hashed_label} SHA-256 is invalid"
    /usr/bin/printf '%s\n' "${result}"
}

validate_templates() {
    [ -f "${json_validator}" ] && [ ! -L "${json_validator}" ] ||
        fail "strict rollout JSON validator is missing or a symbolic link"
    secure_sha256 "${candidate_template}" "${maximum_json_bytes}" "candidate blocked template" >/dev/null
    secure_sha256 "${advancement_template}" "${maximum_json_bytes}" "advancement blocked template" >/dev/null
    secure_sha256 "${controller_trust}" "${maximum_json_bytes}" "controller trust root" >/dev/null
    /usr/bin/python3 -I -S "${json_validator}" templates \
        "${candidate_template}" \
        "${advancement_template}" \
        "${controller_trust}" ||
        fail "rollout v3 blocked templates or controller trust root are invalid"
    [ -f "${funded_canary_validator}" ] && [ ! -L "${funded_canary_validator}" ] ||
        fail "funded Nexus canary admission validator is missing or symbolic"
    /bin/sh "${funded_canary_validator}" --lint-templates >/dev/null ||
        fail "funded Nexus canary blocked templates are invalid"
    [ -f "${taira_deployment_validator}" ] && [ ! -L "${taira_deployment_validator}" ] ||
        fail "Taira deployment admission validator is missing or symbolic"
    /usr/bin/python3 -B -I -S "${taira_deployment_validator}" --lint-contract >/dev/null ||
        fail "Taira deployment admission contract is not exact and blocked"
    [ -f "${migration_promotion_admission}" ] && [ ! -L "${migration_promotion_admission}" ] ||
        fail "post-archive iOS migration admission is missing or symbolic"
    /bin/sh "${migration_promotion_admission}" --lint-contract >/dev/null ||
        fail "post-archive iOS migration admission contract is invalid"
}

if [ "$#" -gt 1 ]; then
    fail "rollout validator accepts only --lint-templates or no argument"
fi
if [ "$#" -eq 1 ]; then
    [ "$1" = "--lint-templates" ] || fail "unknown rollout validator argument"
    validate_templates
    /usr/bin/printf 'production rollout v3 blocked templates are fail-closed\n'
    exit 0
fi

validate_templates

target="${PRODUCTION_ROLLOUT_TARGET_PERCENT:-}"
[ -n "${target}" ] ||
    fail "PRODUCTION_ROLLOUT_TARGET_PERCENT is required; omission is never qualification"

case "${target}" in
    1)
        sequence_number=1
        expected_from=0
        ;;
    5)
        sequence_number=2
        expected_from=1
        ;;
    25)
        sequence_number=3
        expected_from=5
        ;;
    100)
        sequence_number=4
        expected_from=25
        ;;
    *) fail "rollout target must be exactly one of 1, 5, 25, or 100" ;;
esac

candidate_ipa="${PRODUCTION_ROLLOUT_IPA_PATH:-}"
rollout_receipt="${PRODUCTION_ROLLOUT_RECEIPT_PATH:-}"
rollout_signature="${PRODUCTION_ROLLOUT_RECEIPT_SIGNATURE_PATH:-}"
artifact_receipt="${PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH:-}"
artifact_signature="${PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH:-}"
qualification_receipt="${PRODUCTION_QUALIFICATION_RECEIPT_PATH:-}"
qualification_signature="${PRODUCTION_QUALIFICATION_RECEIPT_SIGNATURE_PATH:-}"
pi_probe="${PI_PRODUCTION_PROBE_RECEIPT_PATH:-}"
pi_probe_signature="${PI_PRODUCTION_PROBE_SIGNATURE_PATH:-}"
controller_public_key="${PRODUCTION_ROLLOUT_CONTROLLER_PUBLIC_KEY_PATH:-}"
expected_trust_sha="${PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256:-}"
expected_source_revision="${PRODUCTION_CANDIDATE_SOURCE_REVISION:-}"
expected_keychain_access_groups_sha="${PRODUCTION_KEYCHAIN_ACCESS_GROUPS_SHA256:-}"
taira_deployment_manifest="${IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH:-}"
taira_deployment_operator_signature="${IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH:-}"
taira_deployment_reviewer_signature="${IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH:-}"
taira_deployment_operator_key="${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH:-}"
taira_deployment_reviewer_key="${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH:-}"
taira_deployment_operator_key_sha="${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256:-}"
taira_deployment_reviewer_key_sha="${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256:-}"
taira_deployment_expected_sequence="${IOS_TAIRA_DEPLOYMENT_EXPECTED_MANIFEST_SEQUENCE_NUMBER:-}"
taira_deployment_evaluation_epoch="${IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS:-}"
prior_1_receipt="${PRODUCTION_ROLLOUT_RECEIPT_1_PATH:-}"
prior_1_signature="${PRODUCTION_ROLLOUT_RECEIPT_1_SIGNATURE_PATH:-}"
prior_5_receipt="${PRODUCTION_ROLLOUT_RECEIPT_5_PATH:-}"
prior_5_signature="${PRODUCTION_ROLLOUT_RECEIPT_5_SIGNATURE_PATH:-}"
prior_25_receipt="${PRODUCTION_ROLLOUT_RECEIPT_25_PATH:-}"
prior_25_signature="${PRODUCTION_ROLLOUT_RECEIPT_25_SIGNATURE_PATH:-}"
prior_1_pi_probe="${PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_1_PATH:-}"
prior_1_pi_signature="${PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_1_SIGNATURE_PATH:-}"
prior_5_pi_probe="${PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_PATH:-}"
prior_5_pi_signature="${PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_SIGNATURE_PATH:-}"
prior_25_pi_probe="${PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_25_PATH:-}"
prior_25_pi_signature="${PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_25_SIGNATURE_PATH:-}"
prior_5_telemetry_attestation="${PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_PATH:-}"
prior_5_telemetry_signature="${PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_SIGNATURE_PATH:-}"
prior_5_distribution_attestation="${PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_PATH:-}"
prior_5_distribution_signature="${PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_SIGNATURE_PATH:-}"
prior_25_telemetry_attestation="${PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_25_PATH:-}"
prior_25_telemetry_signature="${PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_25_SIGNATURE_PATH:-}"
prior_25_distribution_attestation="${PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_25_PATH:-}"
prior_25_distribution_signature="${PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_25_SIGNATURE_PATH:-}"
telemetry_attestation="${PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_PATH:-}"
telemetry_signature="${PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_SIGNATURE_PATH:-}"
distribution_attestation="${PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_PATH:-}"
distribution_signature="${PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_SIGNATURE_PATH:-}"

for path_and_label in \
    "${candidate_ipa}|exported IPA" \
    "${rollout_receipt}|rollout qualification receipt" \
    "${rollout_signature}|rollout qualification signature" \
    "${artifact_receipt}|artifact identity receipt" \
    "${artifact_signature}|artifact identity signature" \
    "${qualification_receipt}|upstream production qualification receipt" \
    "${qualification_signature}|upstream production qualification signature" \
    "${pi_probe}|PI production probe receipt" \
    "${pi_probe_signature}|PI production probe signature" \
    "${controller_public_key}|production rollout controller public key" \
    "${taira_deployment_manifest}|Taira deployment manifest" \
    "${taira_deployment_operator_signature}|Taira deployment operator signature" \
    "${taira_deployment_reviewer_signature}|Taira deployment reviewer signature" \
    "${taira_deployment_operator_key}|Taira deployment operator public key" \
    "${taira_deployment_reviewer_key}|Taira deployment reviewer public key"
do
    path_value="${path_and_label%%|*}"
    path_label="${path_and_label#*|}"
    require_absolute_path "${path_value}" "${path_label}"
done
is_lower_hex_64 "${taira_deployment_operator_key_sha}" ||
    fail "Taira deployment operator key requires an independent SHA-256 pin"
is_lower_hex_64 "${taira_deployment_reviewer_key_sha}" ||
    fail "Taira deployment reviewer key requires an independent SHA-256 pin"
is_exact_sequence "${taira_deployment_expected_sequence}" ||
    fail "protected exact Taira deployment manifest sequence is required"
is_epoch_seconds "${taira_deployment_evaluation_epoch}" ||
    fail "Taira deployment evaluation epoch is required"
current_epoch="$(/bin/date +%s)"
minimum_taira_deployment_epoch=$((current_epoch - maximum_taira_deployment_rollout_age_seconds))
[ "${taira_deployment_evaluation_epoch}" -ge "${minimum_taira_deployment_epoch}" ] &&
    [ "${taira_deployment_evaluation_epoch}" -le "${current_epoch}" ] ||
    fail "Taira deployment admission must be no more than seven days old and not future-dated at every rollout gate"

# Migration qualification is intentionally checked here, after export produced
# a complete IPA and before any rollout authority is consumed. The validator
# authenticates schema v8 first, then compares this exact IPA with the
# protected/collected identity and its independently reproduced sealed package.
migration_admission="$({
    /bin/sh "${migration_promotion_admission}" --verify-qualified-ipa "${candidate_ipa}"
} 2>/dev/null)" || fail "completed IPA lacks authenticated retained-device migration admission"
case "${migration_admission}" in
    receiptSha256=*' ipaSha256='*)
        migration_receipt_field="${migration_admission%% *}"
        migration_ipa_field="${migration_admission#* }"
        migration_receipt_sha256="${migration_receipt_field#receiptSha256=}"
        migration_admitted_ipa_sha256="${migration_ipa_field#ipaSha256=}"
        ;;
    *) fail "post-archive iOS migration admission returned an invalid result" ;;
esac
is_lower_hex_64 "${migration_receipt_sha256}" ||
    fail "post-archive iOS migration receipt identity is malformed"
is_lower_hex_64 "${migration_admitted_ipa_sha256}" ||
    fail "post-archive iOS migration IPA identity is malformed"
[ "$(/usr/bin/printf '%s\n' "${migration_admission}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" = "1" ] ||
    fail "post-archive iOS migration admission returned multiple records"

if [ "${target}" != "1" ]; then
    for path_and_label in \
        "${telemetry_attestation}|aggregate telemetry attestation" \
        "${telemetry_signature}|aggregate telemetry signature" \
        "${distribution_attestation}|distribution-platform attestation" \
        "${distribution_signature}|distribution-platform signature"
    do
        path_value="${path_and_label%%|*}"
        path_label="${path_and_label#*|}"
        require_absolute_path "${path_value}" "${path_label}"
    done
fi

require_prior_pair() {
    require_absolute_path "$1" "rollout $3% receipt"
    require_absolute_path "$2" "rollout $3% receipt signature"
}

require_empty_prior_pair() {
    [ -z "$1" ] && [ -z "$2" ] ||
        fail "rollout $3% receipt inputs are not part of the requested chain"
}

require_pi_pair() {
    require_absolute_path "$1" "rollout $3% PI receipt"
    require_absolute_path "$2" "rollout $3% PI receipt signature"
}

require_empty_pi_pair() {
    [ -z "$1" ] && [ -z "$2" ] ||
        fail "rollout $3% PI receipt inputs are not part of the requested chain"
}

require_cohort_attestation_set() {
    require_absolute_path "$1" "rollout $5% telemetry attestation"
    require_absolute_path "$2" "rollout $5% telemetry attestation signature"
    require_absolute_path "$3" "rollout $5% distribution attestation"
    require_absolute_path "$4" "rollout $5% distribution attestation signature"
}

require_empty_cohort_attestation_set() {
    [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ] && [ -z "$4" ] ||
        fail "rollout $5% historical cohort attestations are not part of the requested chain"
}

case "${target}" in
    1)
        require_empty_prior_pair "${prior_1_receipt}" "${prior_1_signature}" 1
        require_empty_prior_pair "${prior_5_receipt}" "${prior_5_signature}" 5
        require_empty_prior_pair "${prior_25_receipt}" "${prior_25_signature}" 25
        require_empty_pi_pair "${prior_1_pi_probe}" "${prior_1_pi_signature}" 1
        require_empty_pi_pair "${prior_5_pi_probe}" "${prior_5_pi_signature}" 5
        require_empty_pi_pair "${prior_25_pi_probe}" "${prior_25_pi_signature}" 25
        require_empty_cohort_attestation_set "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}" 5
        require_empty_cohort_attestation_set "${prior_25_telemetry_attestation}" "${prior_25_telemetry_signature}" "${prior_25_distribution_attestation}" "${prior_25_distribution_signature}" 25
        ;;
    5)
        require_prior_pair "${prior_1_receipt}" "${prior_1_signature}" 1
        require_empty_prior_pair "${prior_5_receipt}" "${prior_5_signature}" 5
        require_empty_prior_pair "${prior_25_receipt}" "${prior_25_signature}" 25
        require_pi_pair "${prior_1_pi_probe}" "${prior_1_pi_signature}" 1
        require_empty_pi_pair "${prior_5_pi_probe}" "${prior_5_pi_signature}" 5
        require_empty_pi_pair "${prior_25_pi_probe}" "${prior_25_pi_signature}" 25
        require_empty_cohort_attestation_set "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}" 5
        require_empty_cohort_attestation_set "${prior_25_telemetry_attestation}" "${prior_25_telemetry_signature}" "${prior_25_distribution_attestation}" "${prior_25_distribution_signature}" 25
        ;;
    25)
        require_prior_pair "${prior_1_receipt}" "${prior_1_signature}" 1
        require_prior_pair "${prior_5_receipt}" "${prior_5_signature}" 5
        require_empty_prior_pair "${prior_25_receipt}" "${prior_25_signature}" 25
        require_pi_pair "${prior_1_pi_probe}" "${prior_1_pi_signature}" 1
        require_pi_pair "${prior_5_pi_probe}" "${prior_5_pi_signature}" 5
        require_empty_pi_pair "${prior_25_pi_probe}" "${prior_25_pi_signature}" 25
        require_cohort_attestation_set "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}" 5
        require_empty_cohort_attestation_set "${prior_25_telemetry_attestation}" "${prior_25_telemetry_signature}" "${prior_25_distribution_attestation}" "${prior_25_distribution_signature}" 25
        ;;
    100)
        require_prior_pair "${prior_1_receipt}" "${prior_1_signature}" 1
        require_prior_pair "${prior_5_receipt}" "${prior_5_signature}" 5
        require_prior_pair "${prior_25_receipt}" "${prior_25_signature}" 25
        require_pi_pair "${prior_1_pi_probe}" "${prior_1_pi_signature}" 1
        require_pi_pair "${prior_5_pi_probe}" "${prior_5_pi_signature}" 5
        require_pi_pair "${prior_25_pi_probe}" "${prior_25_pi_signature}" 25
        require_cohort_attestation_set "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}" 5
        require_cohort_attestation_set "${prior_25_telemetry_attestation}" "${prior_25_telemetry_signature}" "${prior_25_distribution_attestation}" "${prior_25_distribution_signature}" 25
        ;;
esac

# Every bounded controller input is copied once through an O_NOFOLLOW, stable-
# descriptor read into a private directory. Semantic parsing, fixed-field
# extraction, and detached-signature verification then consume the same bytes.
# The IPA remains in place because it may be four GiB; its validator and both
# outer hashes use stable descriptors and revalidate it at the end.
snapshot_directory="$(/usr/bin/mktemp -d /private/tmp/sora-ios-rollout.XXXXXX)" ||
    fail "cannot create private rollout evidence snapshot directory"
cleanup_snapshots() {
    /bin/rm -rf -- "${snapshot_directory}"
}
trap cleanup_snapshots EXIT
trap 'exit 1' HUP INT TERM

taira_deployment_admission="${snapshot_directory}/taira-deployment-admission.json"
taira_deployment_result="$(/usr/bin/python3 -B -I -S "${taira_deployment_validator}" --verify-protected \
    --manifest "${taira_deployment_manifest}" \
    --operator-signature "${taira_deployment_operator_signature}" \
    --reviewer-signature "${taira_deployment_reviewer_signature}" \
    --operator-public-key "${taira_deployment_operator_key}" \
    --reviewer-public-key "${taira_deployment_reviewer_key}" \
    --operator-key-sha256 "${taira_deployment_operator_key_sha}" \
    --reviewer-key-sha256 "${taira_deployment_reviewer_key_sha}" \
    --expected-manifest-sequence-number "${taira_deployment_expected_sequence}" \
    --evaluated-at-epoch-seconds "${taira_deployment_evaluation_epoch}" \
    --output "${taira_deployment_admission}")" ||
    fail "Taira deployment manifest did not pass protected dual-signature admission"
case "${taira_deployment_result}" in
    manifestSha256=????????????????????????????????????????????????????????????????\ admissionSha256=????????????????????????????????????????????????????????????????\ manifestSequenceNumber=*\ currentChainId=????????-????-????-????-????????????\ currentGenesisHash=????????????????????????????????????????????????????????????????\ currentDeploymentEpoch=*\ currentToriiBaseUrl=https://*\ currentMcpEndpoint=https://*/v1/mcp\ currentExplorerBaseUrl=https://*\ retiredChainId=????????-????-????-????-????????????\ retiredGenesisHash=????????????????????????????????????????????????????????????????\ retiredDeploymentEpoch=*) ;;
    *) fail "Taira deployment admission returned an invalid projection" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${taira_deployment_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "Taira deployment admission returned multiple projections"
taira_deployment_manifest_sha="$(admission_projection_value "${taira_deployment_result}" manifestSha256)"
taira_deployment_admission_sha="$(admission_projection_value "${taira_deployment_result}" admissionSha256)"
taira_deployment_manifest_sequence="$(admission_projection_value "${taira_deployment_result}" manifestSequenceNumber)"
taira_current_chain_id="$(admission_projection_value "${taira_deployment_result}" currentChainId)"
taira_current_genesis_hash="$(admission_projection_value "${taira_deployment_result}" currentGenesisHash)"
taira_canonical_torii="$(admission_projection_value "${taira_deployment_result}" currentToriiBaseUrl)"
taira_public_mcp="$(admission_projection_value "${taira_deployment_result}" currentMcpEndpoint)"
taira_explorer="$(admission_projection_value "${taira_deployment_result}" currentExplorerBaseUrl)"
is_lower_hex_64 "${taira_deployment_manifest_sha}" &&
    is_lower_hex_64 "${taira_deployment_admission_sha}" &&
    is_lower_hex_64 "${taira_current_genesis_hash}" &&
    [ "${taira_deployment_manifest_sha}" != "${taira_deployment_admission_sha}" ] ||
    fail "Taira deployment admission identities are invalid"
[ "${taira_deployment_manifest_sequence}" = "${taira_deployment_expected_sequence}" ] ||
    fail "Taira deployment admission sequence differs from protected release sequence"
IOS_TAIRA_DEPLOYMENT_VERIFIED_ADMISSION_SHA256="${taira_deployment_admission_sha}"
export IOS_TAIRA_DEPLOYMENT_VERIFIED_ADMISSION_SHA256

snapshot_input() {
    snapshot_source="$1"
    snapshot_bound="$2"
    snapshot_label="$3"
    snapshot_name="$4"
    snapshot_destination="${snapshot_directory}/${snapshot_name}"
    /usr/bin/python3 -I -S "${json_validator}" snapshot \
        "${snapshot_source}" \
        "${snapshot_destination}" \
        "${snapshot_bound}" >/dev/null ||
        fail "${snapshot_label} could not be captured as one stable private snapshot"
    /usr/bin/printf '%s\n' "${snapshot_destination}"
}

controller_trust="$(snapshot_input "${controller_trust}" "${maximum_json_bytes}" "controller trust root" trust.json)"
controller_public_key="$(snapshot_input "${controller_public_key}" "${maximum_public_key_bytes}" "controller public key" controller-public-key.pem)"
qualification_receipt="$(snapshot_input "${qualification_receipt}" "${maximum_json_bytes}" "upstream production qualification receipt" qualification.json)"
qualification_signature="$(snapshot_input "${qualification_signature}" "${maximum_signature_bytes}" "upstream production qualification signature" qualification.sig)"
artifact_receipt="$(snapshot_input "${artifact_receipt}" "${maximum_json_bytes}" "artifact identity receipt" artifact.json)"
artifact_signature="$(snapshot_input "${artifact_signature}" "${maximum_signature_bytes}" "artifact identity signature" artifact.sig)"
pi_probe="$(snapshot_input "${pi_probe}" "${maximum_json_bytes}" "PI production probe receipt" pi.json)"
pi_probe_signature="$(snapshot_input "${pi_probe_signature}" "${maximum_signature_bytes}" "PI production probe signature" pi.sig)"
rollout_receipt="$(snapshot_input "${rollout_receipt}" "${maximum_json_bytes}" "rollout qualification receipt" rollout.json)"
rollout_signature="$(snapshot_input "${rollout_signature}" "${maximum_signature_bytes}" "rollout qualification signature" rollout.sig)"
if [ "${target}" = "5" ] || [ "${target}" = "25" ] || [ "${target}" = "100" ]; then
    prior_1_receipt="$(snapshot_input "${prior_1_receipt}" "${maximum_json_bytes}" "rollout 1% receipt" prior-1.json)"
    prior_1_signature="$(snapshot_input "${prior_1_signature}" "${maximum_signature_bytes}" "rollout 1% signature" prior-1.sig)"
    prior_1_pi_probe="$(snapshot_input "${prior_1_pi_probe}" "${maximum_json_bytes}" "rollout 1% PI receipt" prior-1-pi.json)"
    prior_1_pi_signature="$(snapshot_input "${prior_1_pi_signature}" "${maximum_signature_bytes}" "rollout 1% PI signature" prior-1-pi.sig)"
fi
if [ "${target}" = "25" ] || [ "${target}" = "100" ]; then
    prior_5_receipt="$(snapshot_input "${prior_5_receipt}" "${maximum_json_bytes}" "rollout 5% receipt" prior-5.json)"
    prior_5_signature="$(snapshot_input "${prior_5_signature}" "${maximum_signature_bytes}" "rollout 5% signature" prior-5.sig)"
    prior_5_pi_probe="$(snapshot_input "${prior_5_pi_probe}" "${maximum_json_bytes}" "rollout 5% PI receipt" prior-5-pi.json)"
    prior_5_pi_signature="$(snapshot_input "${prior_5_pi_signature}" "${maximum_signature_bytes}" "rollout 5% PI signature" prior-5-pi.sig)"
    prior_5_telemetry_attestation="$(snapshot_input "${prior_5_telemetry_attestation}" "${maximum_json_bytes}" "rollout 5% telemetry attestation" prior-5-telemetry.json)"
    prior_5_telemetry_signature="$(snapshot_input "${prior_5_telemetry_signature}" "${maximum_signature_bytes}" "rollout 5% telemetry signature" prior-5-telemetry.sig)"
    prior_5_distribution_attestation="$(snapshot_input "${prior_5_distribution_attestation}" "${maximum_json_bytes}" "rollout 5% distribution attestation" prior-5-distribution.json)"
    prior_5_distribution_signature="$(snapshot_input "${prior_5_distribution_signature}" "${maximum_signature_bytes}" "rollout 5% distribution signature" prior-5-distribution.sig)"
fi
if [ "${target}" = "100" ]; then
    prior_25_receipt="$(snapshot_input "${prior_25_receipt}" "${maximum_json_bytes}" "rollout 25% receipt" prior-25.json)"
    prior_25_signature="$(snapshot_input "${prior_25_signature}" "${maximum_signature_bytes}" "rollout 25% signature" prior-25.sig)"
    prior_25_pi_probe="$(snapshot_input "${prior_25_pi_probe}" "${maximum_json_bytes}" "rollout 25% PI receipt" prior-25-pi.json)"
    prior_25_pi_signature="$(snapshot_input "${prior_25_pi_signature}" "${maximum_signature_bytes}" "rollout 25% PI signature" prior-25-pi.sig)"
    prior_25_telemetry_attestation="$(snapshot_input "${prior_25_telemetry_attestation}" "${maximum_json_bytes}" "rollout 25% telemetry attestation" prior-25-telemetry.json)"
    prior_25_telemetry_signature="$(snapshot_input "${prior_25_telemetry_signature}" "${maximum_signature_bytes}" "rollout 25% telemetry signature" prior-25-telemetry.sig)"
    prior_25_distribution_attestation="$(snapshot_input "${prior_25_distribution_attestation}" "${maximum_json_bytes}" "rollout 25% distribution attestation" prior-25-distribution.json)"
    prior_25_distribution_signature="$(snapshot_input "${prior_25_distribution_signature}" "${maximum_signature_bytes}" "rollout 25% distribution signature" prior-25-distribution.sig)"
fi
if [ "${target}" != "1" ]; then
    telemetry_attestation="$(snapshot_input "${telemetry_attestation}" "${maximum_json_bytes}" "aggregate telemetry attestation" telemetry.json)"
    telemetry_signature="$(snapshot_input "${telemetry_signature}" "${maximum_signature_bytes}" "aggregate telemetry signature" telemetry.sig)"
    distribution_attestation="$(snapshot_input "${distribution_attestation}" "${maximum_json_bytes}" "distribution-platform attestation" distribution.json)"
    distribution_signature="$(snapshot_input "${distribution_signature}" "${maximum_signature_bytes}" "distribution-platform signature" distribution.sig)"
fi

case "${candidate_ipa}" in
    *.ipa) ;;
    *) fail "exported IPA path must end in .ipa" ;;
esac
is_lower_hex_64 "${expected_trust_sha}" ||
    fail "PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256 must be an independently pinned lowercase SHA-256"
is_lower_hex_40 "${expected_source_revision}" ||
    fail "PRODUCTION_CANDIDATE_SOURCE_REVISION must be the exact lowercase 40-character release revision"
is_lower_hex_64 "${expected_keychain_access_groups_sha}" ||
    fail "PRODUCTION_KEYCHAIN_ACCESS_GROUPS_SHA256 must independently pin the retained production groups"

actual_trust_sha="$(secure_sha256 "${controller_trust}" "${maximum_json_bytes}" "controller trust root")"
[ "${actual_trust_sha}" = "${expected_trust_sha}" ] ||
    fail "controller trust root differs from the independently protected release value"
IOS_PRODUCTION_ROLLOUT_TRUST_VERIFIED_SHA256="${actual_trust_sha}"
export IOS_PRODUCTION_ROLLOUT_TRUST_VERIFIED_SHA256

# The checked-in root is deliberately blocked until an authorized controller key
# is reviewed. No receipt can qualify while it remains blocked.
/usr/bin/python3 -I -S "${json_validator}" trust "${controller_trust}" ||
    fail "production rollout controller trust root remains explicitly blocked"
controller_id="$(json_raw controllerId "${controller_trust}")"
controller_key_sha="$(json_raw publicKeySha256 "${controller_trust}")"
[ -n "${controller_id}" ] || fail "qualified controller trust root lacks its controller identity"
is_lower_hex_64 "${controller_key_sha}" || fail "qualified controller trust root lacks its public-key hash"
actual_controller_key_sha="$(
    secure_sha256 "${controller_public_key}" "${maximum_public_key_bytes}" "controller public key"
)"
[ "${actual_controller_key_sha}" = "${controller_key_sha}" ] ||
    fail "controller public key differs from the independently pinned trust root"

[ -x /usr/bin/openssl ] || fail "reviewed ECDSA receipt verification requires /usr/bin/openssl"
secure_openssl ec -pubin -in "${controller_public_key}" -noout >/dev/null 2>&1 ||
    fail "controller public key is not a valid reviewed EC public key"
controller_curve="$({
    secure_openssl ec -pubin -in "${controller_public_key}" -text -noout 2>/dev/null
} || /usr/bin/true)"
/usr/bin/printf '%s\n' "${controller_curve}" |
    /usr/bin/grep -Eq 'ASN1 OID: prime256v1|NIST CURVE: P-256' ||
    fail "controller public key is not ECDSA P-256"

verify_signed_receipt() {
    signed_file="$1"
    signature_file="$2"
    signed_label="$3"
    signed_sha="$(secure_sha256 "${signed_file}" "${maximum_json_bytes}" "${signed_label}")"
    signature_sha="$(
        secure_sha256 "${signature_file}" "${maximum_signature_bytes}" "${signed_label} detached signature"
    )"
    is_lower_hex_64 "${signature_sha}" || fail "${signed_label} signature SHA-256 is invalid"
    [ "$(json_raw controllerId "${signed_file}")" = "${controller_id}" ] ||
        fail "${signed_label} was not issued by the trusted rollout controller"
    secure_openssl dgst -sha256 \
        -verify "${controller_public_key}" \
        -signature "${signature_file}" \
        "${signed_file}" >/dev/null 2>&1 ||
        fail "${signed_label} detached ECDSA signature is invalid"
    [ "$(secure_sha256 "${signed_file}" "${maximum_json_bytes}" "${signed_label}")" = "${signed_sha}" ] ||
        fail "${signed_label} changed during signature verification"
    [ "$(secure_sha256 "${signature_file}" "${maximum_signature_bytes}" "${signed_label} detached signature")" = "${signature_sha}" ] ||
        fail "${signed_label} signature changed during verification"
    /usr/bin/printf '%s\n' "${signed_sha}"
}

candidate_sha="$(secure_sha256 "${candidate_ipa}" "${maximum_ipa_bytes}" "exported IPA")"
[ "${candidate_sha}" = "${migration_admitted_ipa_sha256}" ] ||
    fail "exported IPA differs from the authenticated post-archive migration admission"

/usr/bin/python3 -I -S "${json_validator}" qualification "${qualification_receipt}" ||
    fail "upstream production qualification receipt is not exact and fully qualified"
qualification_sha="$(
    verify_signed_receipt \
        "${qualification_receipt}" \
        "${qualification_signature}" \
        "upstream production qualification receipt"
)"

IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256="$(
    secure_sha256 "${artifact_receipt}" "${maximum_json_bytes}" "artifact identity receipt"
)"
export IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256
/usr/bin/python3 -I -S "${json_validator}" artifact "${artifact_receipt}" "${candidate_ipa}" "${taira_deployment_admission}" ||
    fail "controller artifact identity does not match the actual bounded IPA structure and application bytes"
artifact_sha="$(
    verify_signed_receipt \
        "${artifact_receipt}" \
        "${artifact_signature}" \
        "artifact identity receipt"
)"

/usr/bin/python3 -I -S "${json_validator}" pi "${pi_probe}" "${taira_deployment_admission}" ||
    fail "PI production probe is not an exact canonical multi-network checkpoint receipt"
pi_probe_sha="$(
    verify_signed_receipt \
        "${pi_probe}" \
        "${pi_probe_signature}" \
        "PI production probe receipt"
)"

/usr/bin/python3 -I -S "${json_validator}" rollout "${rollout_receipt}" "${target}" "${taira_deployment_admission}" ||
    fail "rollout qualification receipt does not satisfy the exact v3 target schema"
rollout_receipt_sha="$(
    verify_signed_receipt \
        "${rollout_receipt}" \
        "${rollout_signature}" \
        "rollout qualification receipt"
)"

evaluated_at="$(json_raw evaluatedAtEpochSeconds "${rollout_receipt}")"
is_epoch_seconds "${evaluated_at}" ||
    fail "rollout evaluation epoch is absent before funded-canary admission"
funded_canary_result="$(
    PRODUCTION_RELEASE_EVALUATED_AT_EPOCH_SECONDS="${evaluated_at}" \
        /bin/sh "${funded_canary_validator}" --verify-admission
)" || fail "funded Taira and Minamoto canary admission is not qualified for this candidate"
funded_admission_sha="$(/usr/bin/printf '%s\n' "${funded_canary_result}" | /usr/bin/sed -n 's/^admissionReceiptSha256=//p')"
funded_taira_sha="$(/usr/bin/printf '%s\n' "${funded_canary_result}" | /usr/bin/sed -n 's/^tairaReceiptSha256=//p')"
funded_minamoto_sha="$(/usr/bin/printf '%s\n' "${funded_canary_result}" | /usr/bin/sed -n 's/^minamotoReceiptSha256=//p')"
is_lower_hex_64 "${funded_admission_sha}" &&
    is_lower_hex_64 "${funded_taira_sha}" &&
    is_lower_hex_64 "${funded_minamoto_sha}" &&
    [ "$(/usr/bin/printf '%s\n' "${funded_canary_result}" | /usr/bin/awk 'END { print NR }')" -eq 3 ] &&
    [ "${funded_admission_sha}" != "${funded_taira_sha}" ] &&
    [ "${funded_admission_sha}" != "${funded_minamoto_sha}" ] &&
    [ "${funded_taira_sha}" != "${funded_minamoto_sha}" ] ||
    fail "funded Nexus admission output is not the exact three-digest contract"

qualification_source_revision="$(json_raw sourceRevision "${qualification_receipt}")"
artifact_source_revision="$(json_raw sourceRevision "${artifact_receipt}")"
qualification_manifest_sha="$(json_raw candidateBuildManifestSha256 "${qualification_receipt}")"
artifact_manifest_sha="$(json_raw candidateBuildManifestSha256 "${artifact_receipt}")"
artifact_qualification_sha="$(json_raw productionQualificationReceiptSha256 "${artifact_receipt}")"
artifact_candidate_sha="$(json_raw ipa.sha256 "${artifact_receipt}")"
artifact_app_version="$(json_raw application.appVersion "${artifact_receipt}")"
artifact_build_number="$(json_raw application.buildNumber "${artifact_receipt}")"
artifact_app_store_build="$(json_raw application.appStoreBuildIdentifier "${artifact_receipt}")"
artifact_keychain_access_groups_sha="$(json_raw signing.keychainAccessGroupsSha256 "${artifact_receipt}")"
artifact_taira_manifest_sha="$(json_raw tairaDeployment.manifestSha256 "${artifact_receipt}")"
artifact_taira_admission_sha="$(json_raw tairaDeployment.admissionSha256 "${artifact_receipt}")"
artifact_taira_chain_id="$(json_raw tairaDeployment.currentChainId "${artifact_receipt}")"
artifact_taira_genesis_hash="$(json_raw tairaDeployment.currentGenesisHash "${artifact_receipt}")"
artifact_taira_torii="$(json_raw tairaDeployment.canonicalToriiBaseUrl "${artifact_receipt}")"
artifact_taira_mcp="$(json_raw tairaDeployment.publicMcpEndpoint "${artifact_receipt}")"
artifact_taira_explorer="$(json_raw tairaDeployment.explorerBaseUrl "${artifact_receipt}")"
artifact_recorded_at="$(json_raw recordedAtEpochSeconds "${artifact_receipt}")"
qualification_recorded_at="$(json_raw recordedAtEpochSeconds "${qualification_receipt}")"

[ "${qualification_source_revision}" = "${expected_source_revision}" ] &&
    [ "${artifact_source_revision}" = "${expected_source_revision}" ] &&
    [ "${artifact_manifest_sha}" = "${qualification_manifest_sha}" ] &&
    [ "${artifact_qualification_sha}" = "${qualification_sha}" ] &&
    [ "${artifact_candidate_sha}" = "${candidate_sha}" ] &&
    [ "${artifact_taira_manifest_sha}" = "${taira_deployment_manifest_sha}" ] &&
    [ "${artifact_taira_admission_sha}" = "${taira_deployment_admission_sha}" ] &&
    [ "${artifact_taira_chain_id}" = "${taira_current_chain_id}" ] &&
    [ "${artifact_taira_genesis_hash}" = "${taira_current_genesis_hash}" ] &&
    [ "${artifact_taira_torii}" = "${taira_canonical_torii}" ] &&
    [ "${artifact_taira_mcp}" = "${taira_public_mcp}" ] &&
    [ "${artifact_taira_explorer}" = "${taira_explorer}" ] ||
    fail "actual IPA, source revision, build manifest, and upstream production qualification are not transitively bound"
[ "${artifact_keychain_access_groups_sha}" = "${expected_keychain_access_groups_sha}" ] ||
    fail "signed Keychain access groups differ from the independently retained production identity"

minimum_fresh_epoch=$((current_epoch - maximum_freshness_seconds))
probe_captured_at="$(json_raw capturedAtEpochSeconds "${pi_probe}")"
worker_last_success="$(json_raw health.workerLastSuccessfulIndexTimestamp "${pi_probe}")"
is_epoch_seconds "${probe_captured_at}" &&
    is_epoch_seconds "${worker_last_success}" &&
    [ "${probe_captured_at}" -ge "${minimum_fresh_epoch}" ] &&
    [ "${probe_captured_at}" -le "${current_epoch}" ] &&
    [ "${worker_last_success}" -ge "${minimum_fresh_epoch}" ] &&
    [ "${worker_last_success}" -le "${probe_captured_at}" ] ||
    fail "PI probe capture and last successful indexing must both be no more than five minutes old"

sora2_height="$(json_raw health.workerLatestFinalizedBlock "${pi_probe}")"
sora2_hash="$(json_raw health.workerLatestFinalizedBlockHash "${pi_probe}")"
sora2_genesis="$(json_raw health.genesisHash "${pi_probe}")"
minamoto_height="$(json_raw networkCheckpoints.minamoto.finalizedHeight "${pi_probe}")"
minamoto_hash="$(json_raw networkCheckpoints.minamoto.finalizedBlockHash "${pi_probe}")"
minamoto_genesis="$(json_raw networkCheckpoints.minamoto.genesisHash "${pi_probe}")"
taira_height="$(json_raw networkCheckpoints.taira.finalizedHeight "${pi_probe}")"
taira_hash="$(json_raw networkCheckpoints.taira.finalizedBlockHash "${pi_probe}")"
taira_genesis="$(json_raw networkCheckpoints.taira.genesisHash "${pi_probe}")"
config_revision="$(json_raw capabilities.configRevision "${pi_probe}")"

capability_sha="$(
    /usr/bin/printf 'schemaVersion=3\nconfigRevision=%s\nendpoint=https://pi.soramitsu.io/graphql\nserviceId=pi.soramitsu.io\necosystem=sora2\nchainId=sora:mainnet\nnetwork=mainnet\nreadOnly=true\nworkerReady=true\nmobileConfigHealthBound=true\nhistoryBlockHeightContractDeployed=true\nnexusAvailable=true\nnexusSendsAvailable=true\npolkamarktVisible=true\npolkamarktMutationsAvailable=true\ntairaDefaultVisible=true' \
        "${config_revision}" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"
checkpoint_sha="$(
    /usr/bin/printf 'piProbeReceiptSha256=%s\nsora2GenesisHash=%s\nsora2FinalizedHeight=%s\nsora2FinalizedBlockHash=%s\nminamotoChainId=00000000-0000-0000-0000-000000000753\nminamotoGenesisHash=%s\nminamotoFinalizedHeight=%s\nminamotoFinalizedBlockHash=%s\ntairaChainId=%s\ntairaGenesisHash=%s\ntairaFinalizedHeight=%s\ntairaFinalizedBlockHash=%s' \
        "${pi_probe_sha}" \
        "${sora2_genesis}" \
        "${sora2_height}" \
        "${sora2_hash}" \
        "${minamoto_genesis}" \
        "${minamoto_height}" \
        "${minamoto_hash}" \
        "${taira_current_chain_id}" \
        "${taira_genesis}" \
        "${taira_height}" \
        "${taira_hash}" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"
candidate_binding="$(
    /usr/bin/printf 'platform=ios\ncandidateArtifactSha256=%s\nartifactIdentityReceiptSha256=%s\nproductionQualificationReceiptSha256=%s\nfundedNexusCanaryAdmissionReceiptSha256=%s\nfundedTairaCanaryReceiptSha256=%s\nfundedMinamotoCanaryReceiptSha256=%s\ntairaDeploymentManifestSha256=%s\ntairaDeploymentAdmissionSha256=%s\ntairaCurrentChainId=%s\ntairaCurrentGenesisHash=%s\nsourceRevision=%s\ncandidateBuildManifestSha256=%s\nbundleIdentifier=%s\ndevelopmentTeam=%s\nappVersion=%s\nbuildNumber=%s\nappStoreBuildIdentifier=%s\nsora2NetworkRevision=%s\nruntimeSpecVersion=130\nruntimeTransactionVersion=130\nruntimeMetadataSha256=%s' \
        "${candidate_sha}" \
        "${artifact_sha}" \
        "${qualification_sha}" \
        "${funded_admission_sha}" \
        "${funded_taira_sha}" \
        "${funded_minamoto_sha}" \
        "${taira_deployment_manifest_sha}" \
        "${taira_deployment_admission_sha}" \
        "${taira_current_chain_id}" \
        "${taira_current_genesis_hash}" \
        "${expected_source_revision}" \
        "${qualification_manifest_sha}" \
        "${production_bundle_identifier}" \
        "${production_development_team}" \
        "${artifact_app_version}" \
        "${artifact_build_number}" \
        "${artifact_app_store_build}" \
        "${sora2_revision}" \
        "${reviewed_runtime_metadata_sha256}" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"

authorized_at="$(json_raw authorizedAtEpochSeconds "${rollout_receipt}")"
minimum_evaluation_epoch=$((current_epoch - maximum_freshness_seconds))
is_epoch_seconds "${evaluated_at}" &&
    is_epoch_seconds "${authorized_at}" &&
    [ "${evaluated_at}" -ge "${minimum_evaluation_epoch}" ] &&
    [ "${evaluated_at}" -le "${current_epoch}" ] &&
    [ "${authorized_at}" -ge "${evaluated_at}" ] &&
    [ $((authorized_at - evaluated_at)) -le "${maximum_authorization_delay_seconds}" ] &&
    [ "${authorized_at}" -le "${current_epoch}" ] &&
    [ "${probe_captured_at}" -le "${evaluated_at}" ] &&
    [ $((evaluated_at - probe_captured_at)) -le "${maximum_freshness_seconds}" ] &&
    [ "${qualification_recorded_at}" -le "${artifact_recorded_at}" ] &&
    [ "${artifact_recorded_at}" -le "${evaluated_at}" ] ||
    fail "qualification, artifact, PI, evaluation, and authorization chronology is invalid"

evaluation_binding="$(
    /usr/bin/printf 'candidateBindingSha256=%s\npiProbeReceiptSha256=%s\npiCapturedAtEpochSeconds=%s\ncapabilitySnapshotSha256=%s\nfinalizedCheckpointBindingSha256=%s\nsequenceNumber=%s\nfromCohortPercent=%s\ntargetCohortPercent=%s\nevaluatedAtEpochSeconds=%s\nauthorizedAtEpochSeconds=%s' \
        "${candidate_binding}" \
        "${pi_probe_sha}" \
        "${probe_captured_at}" \
        "${capability_sha}" \
        "${checkpoint_sha}" \
        "${sequence_number}" \
        "${expected_from}" \
        "${target}" \
        "${evaluated_at}" \
        "${authorized_at}" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"

[ "$(json_raw identity.candidateBindingSha256 "${rollout_receipt}")" = "${candidate_binding}" ] &&
    [ "$(json_raw identity.evaluationBindingSha256 "${rollout_receipt}")" = "${evaluation_binding}" ] &&
    [ "$(json_raw identity.candidateArtifactSha256 "${rollout_receipt}")" = "${candidate_sha}" ] &&
    [ "$(json_raw identity.artifactIdentityReceiptSha256 "${rollout_receipt}")" = "${artifact_sha}" ] &&
    [ "$(json_raw identity.productionQualificationReceiptSha256 "${rollout_receipt}")" = "${qualification_sha}" ] &&
    [ "$(json_raw identity.fundedNexusCanaryAdmissionReceiptSha256 "${rollout_receipt}")" = "${funded_admission_sha}" ] &&
    [ "$(json_raw identity.fundedTairaCanaryReceiptSha256 "${rollout_receipt}")" = "${funded_taira_sha}" ] &&
    [ "$(json_raw identity.fundedMinamotoCanaryReceiptSha256 "${rollout_receipt}")" = "${funded_minamoto_sha}" ] &&
    [ "$(json_raw identity.tairaDeploymentManifestSha256 "${rollout_receipt}")" = "${taira_deployment_manifest_sha}" ] &&
    [ "$(json_raw identity.tairaDeploymentAdmissionSha256 "${rollout_receipt}")" = "${taira_deployment_admission_sha}" ] &&
    [ "$(json_raw identity.tairaCurrentChainId "${rollout_receipt}")" = "${taira_current_chain_id}" ] &&
    [ "$(json_raw identity.tairaCurrentGenesisHash "${rollout_receipt}")" = "${taira_current_genesis_hash}" ] &&
    [ "$(json_raw identity.piProbeReceiptSha256 "${rollout_receipt}")" = "${pi_probe_sha}" ] &&
    [ "$(json_raw identity.piCapturedAtEpochSeconds "${rollout_receipt}")" = "${probe_captured_at}" ] &&
    [ "$(json_raw identity.sourceRevision "${rollout_receipt}")" = "${expected_source_revision}" ] &&
    [ "$(json_raw identity.bundleIdentifier "${rollout_receipt}")" = "${production_bundle_identifier}" ] &&
    [ "$(json_raw identity.developmentTeam "${rollout_receipt}")" = "${production_development_team}" ] &&
    [ "$(json_raw identity.appVersion "${rollout_receipt}")" = "${artifact_app_version}" ] &&
    [ "$(json_raw identity.buildNumber "${rollout_receipt}")" = "${artifact_build_number}" ] &&
    [ "$(json_raw identity.appStoreBuildIdentifier "${rollout_receipt}")" = "${artifact_app_store_build}" ] &&
    [ "$(json_raw identity.capabilitySnapshotSha256 "${rollout_receipt}")" = "${capability_sha}" ] &&
    [ "$(json_raw identity.finalizedCheckpointBindingSha256 "${rollout_receipt}")" = "${checkpoint_sha}" ] &&
    [ "$(json_raw identity.sora2GenesisHash "${rollout_receipt}")" = "${sora2_genesis}" ] &&
    [ "$(json_raw identity.sora2FinalizedHeight "${rollout_receipt}")" = "${sora2_height}" ] &&
    [ "$(json_raw identity.sora2FinalizedBlockHash "${rollout_receipt}")" = "${sora2_hash}" ] &&
    [ "$(json_raw identity.minamotoGenesisHash "${rollout_receipt}")" = "${minamoto_genesis}" ] &&
    [ "$(json_raw identity.minamotoFinalizedHeight "${rollout_receipt}")" = "${minamoto_height}" ] &&
    [ "$(json_raw identity.minamotoFinalizedBlockHash "${rollout_receipt}")" = "${minamoto_hash}" ] &&
    [ "$(json_raw identity.tairaGenesisHash "${rollout_receipt}")" = "${taira_genesis}" ] &&
    [ "$(json_raw identity.tairaFinalizedHeight "${rollout_receipt}")" = "${taira_height}" ] &&
    [ "$(json_raw identity.tairaFinalizedBlockHash "${rollout_receipt}")" = "${taira_hash}" ] ||
    fail "rollout receipt is not bound to the exact candidate, signing review, funded Nexus canaries, upstream qualification, PI receipt, and finalized checkpoints"

validate_stored_rollout_binding() {
    stored_receipt="$1"
    stored_target="$2"
    stored_pi_probe="$3"
    stored_pi_signature="$4"
    case "${stored_target}" in
        1) stored_sequence=1; stored_from=0 ;;
        5) stored_sequence=2; stored_from=1 ;;
        25) stored_sequence=3; stored_from=5 ;;
        100) stored_sequence=4; stored_from=25 ;;
        *) fail "stored rollout receipt has an invalid target" ;;
    esac
    /usr/bin/python3 -I -S "${json_validator}" rollout "${stored_receipt}" "${stored_target}" "${taira_deployment_admission}" ||
        fail "stored rollout ${stored_target}% receipt is not an exact qualified v3 gate"
    /usr/bin/python3 -I -S "${json_validator}" pi "${stored_pi_probe}" "${taira_deployment_admission}" ||
        fail "stored rollout ${stored_target}% PI evidence is not an exact canonical checkpoint receipt"

    stored_pi_sha="$(
        verify_signed_receipt \
            "${stored_pi_probe}" \
            "${stored_pi_signature}" \
            "rollout ${stored_target}% PI receipt"
    )"
    stored_pi_captured_at="$(json_raw capturedAtEpochSeconds "${stored_pi_probe}")"
    stored_worker_last_success="$(json_raw health.workerLastSuccessfulIndexTimestamp "${stored_pi_probe}")"
    stored_sora2_genesis="$(json_raw health.genesisHash "${stored_pi_probe}")"
    stored_sora2_height="$(json_raw health.workerLatestFinalizedBlock "${stored_pi_probe}")"
    stored_sora2_hash="$(json_raw health.workerLatestFinalizedBlockHash "${stored_pi_probe}")"
    stored_minamoto_genesis="$(json_raw networkCheckpoints.minamoto.genesisHash "${stored_pi_probe}")"
    stored_minamoto_height="$(json_raw networkCheckpoints.minamoto.finalizedHeight "${stored_pi_probe}")"
    stored_minamoto_hash="$(json_raw networkCheckpoints.minamoto.finalizedBlockHash "${stored_pi_probe}")"
    stored_taira_genesis="$(json_raw networkCheckpoints.taira.genesisHash "${stored_pi_probe}")"
    stored_taira_height="$(json_raw networkCheckpoints.taira.finalizedHeight "${stored_pi_probe}")"
    stored_taira_hash="$(json_raw networkCheckpoints.taira.finalizedBlockHash "${stored_pi_probe}")"
    stored_config_revision="$(json_raw capabilities.configRevision "${stored_pi_probe}")"
    stored_capability_sha="$(
        /usr/bin/printf 'schemaVersion=3\nconfigRevision=%s\nendpoint=https://pi.soramitsu.io/graphql\nserviceId=pi.soramitsu.io\necosystem=sora2\nchainId=sora:mainnet\nnetwork=mainnet\nreadOnly=true\nworkerReady=true\nmobileConfigHealthBound=true\nhistoryBlockHeightContractDeployed=true\nnexusAvailable=true\nnexusSendsAvailable=true\npolkamarktVisible=true\npolkamarktMutationsAvailable=true\ntairaDefaultVisible=true' \
            "${stored_config_revision}" |
            /usr/bin/shasum -a 256 |
            /usr/bin/awk '{print $1}'
    )"
    stored_checkpoint_sha="$(
        /usr/bin/printf 'piProbeReceiptSha256=%s\nsora2GenesisHash=%s\nsora2FinalizedHeight=%s\nsora2FinalizedBlockHash=%s\nminamotoChainId=00000000-0000-0000-0000-000000000753\nminamotoGenesisHash=%s\nminamotoFinalizedHeight=%s\nminamotoFinalizedBlockHash=%s\ntairaChainId=%s\ntairaGenesisHash=%s\ntairaFinalizedHeight=%s\ntairaFinalizedBlockHash=%s' \
            "${stored_pi_sha}" \
            "${stored_sora2_genesis}" \
            "${stored_sora2_height}" \
            "${stored_sora2_hash}" \
            "${stored_minamoto_genesis}" \
            "${stored_minamoto_height}" \
            "${stored_minamoto_hash}" \
            "${taira_current_chain_id}" \
            "${stored_taira_genesis}" \
            "${stored_taira_height}" \
            "${stored_taira_hash}" |
            /usr/bin/shasum -a 256 |
            /usr/bin/awk '{print $1}'
    )"
    stored_evaluated_at="$(json_raw evaluatedAtEpochSeconds "${stored_receipt}")"
    stored_authorized_at="$(json_raw authorizedAtEpochSeconds "${stored_receipt}")"
    stored_evaluation_binding="$(
        /usr/bin/printf 'candidateBindingSha256=%s\npiProbeReceiptSha256=%s\npiCapturedAtEpochSeconds=%s\ncapabilitySnapshotSha256=%s\nfinalizedCheckpointBindingSha256=%s\nsequenceNumber=%s\nfromCohortPercent=%s\ntargetCohortPercent=%s\nevaluatedAtEpochSeconds=%s\nauthorizedAtEpochSeconds=%s' \
            "${candidate_binding}" \
            "${stored_pi_sha}" \
            "${stored_pi_captured_at}" \
            "${stored_capability_sha}" \
            "${stored_checkpoint_sha}" \
            "${stored_sequence}" \
            "${stored_from}" \
            "${stored_target}" \
            "${stored_evaluated_at}" \
            "${stored_authorized_at}" |
            /usr/bin/shasum -a 256 |
            /usr/bin/awk '{print $1}'
    )"

    is_epoch_seconds "${stored_evaluated_at}" &&
        is_epoch_seconds "${stored_authorized_at}" &&
        is_epoch_seconds "${stored_pi_captured_at}" &&
        is_epoch_seconds "${stored_worker_last_success}" &&
        [ "${stored_worker_last_success}" -le "${stored_pi_captured_at}" ] &&
        [ $((stored_pi_captured_at - stored_worker_last_success)) -le "${maximum_freshness_seconds}" ] &&
        [ "${stored_pi_captured_at}" -le "${stored_evaluated_at}" ] &&
        [ $((stored_evaluated_at - stored_pi_captured_at)) -le "${maximum_freshness_seconds}" ] &&
        [ "${stored_evaluated_at}" -ge "${artifact_recorded_at}" ] &&
        [ "${stored_authorized_at}" -ge "${stored_evaluated_at}" ] &&
        [ $((stored_authorized_at - stored_evaluated_at)) -le "${maximum_authorization_delay_seconds}" ] &&
        [ "${stored_authorized_at}" -le "${current_epoch}" ] &&
        [ "$(json_raw identity.candidateBindingSha256 "${stored_receipt}")" = "${candidate_binding}" ] &&
        [ "$(json_raw identity.evaluationBindingSha256 "${stored_receipt}")" = "${stored_evaluation_binding}" ] &&
        [ "$(json_raw identity.candidateArtifactSha256 "${stored_receipt}")" = "${candidate_sha}" ] &&
        [ "$(json_raw identity.artifactIdentityReceiptSha256 "${stored_receipt}")" = "${artifact_sha}" ] &&
        [ "$(json_raw identity.productionQualificationReceiptSha256 "${stored_receipt}")" = "${qualification_sha}" ] &&
        [ "$(json_raw identity.fundedNexusCanaryAdmissionReceiptSha256 "${stored_receipt}")" = "${funded_admission_sha}" ] &&
        [ "$(json_raw identity.fundedTairaCanaryReceiptSha256 "${stored_receipt}")" = "${funded_taira_sha}" ] &&
        [ "$(json_raw identity.fundedMinamotoCanaryReceiptSha256 "${stored_receipt}")" = "${funded_minamoto_sha}" ] &&
        [ "$(json_raw identity.tairaDeploymentManifestSha256 "${stored_receipt}")" = "${taira_deployment_manifest_sha}" ] &&
        [ "$(json_raw identity.tairaDeploymentAdmissionSha256 "${stored_receipt}")" = "${taira_deployment_admission_sha}" ] &&
        [ "$(json_raw identity.tairaCurrentChainId "${stored_receipt}")" = "${taira_current_chain_id}" ] &&
        [ "$(json_raw identity.tairaCurrentGenesisHash "${stored_receipt}")" = "${taira_current_genesis_hash}" ] &&
        [ "$(json_raw identity.piProbeReceiptSha256 "${stored_receipt}")" = "${stored_pi_sha}" ] &&
        [ "$(json_raw identity.piCapturedAtEpochSeconds "${stored_receipt}")" = "${stored_pi_captured_at}" ] &&
        [ "$(json_raw identity.sourceRevision "${stored_receipt}")" = "${expected_source_revision}" ] &&
        [ "$(json_raw identity.bundleIdentifier "${stored_receipt}")" = "${production_bundle_identifier}" ] &&
        [ "$(json_raw identity.developmentTeam "${stored_receipt}")" = "${production_development_team}" ] &&
        [ "$(json_raw identity.appVersion "${stored_receipt}")" = "${artifact_app_version}" ] &&
        [ "$(json_raw identity.buildNumber "${stored_receipt}")" = "${artifact_build_number}" ] &&
        [ "$(json_raw identity.appStoreBuildIdentifier "${stored_receipt}")" = "${artifact_app_store_build}" ] &&
        [ "${stored_capability_sha}" = "${capability_sha}" ] &&
        [ "$(json_raw identity.capabilitySnapshotSha256 "${stored_receipt}")" = "${stored_capability_sha}" ] &&
        [ "$(json_raw identity.finalizedCheckpointBindingSha256 "${stored_receipt}")" = "${stored_checkpoint_sha}" ] &&
        [ "$(json_raw identity.sora2GenesisHash "${stored_receipt}")" = "${stored_sora2_genesis}" ] &&
        [ "$(json_raw identity.sora2FinalizedHeight "${stored_receipt}")" = "${stored_sora2_height}" ] &&
        [ "$(json_raw identity.sora2FinalizedBlockHash "${stored_receipt}")" = "${stored_sora2_hash}" ] &&
        [ "$(json_raw identity.minamotoGenesisHash "${stored_receipt}")" = "${stored_minamoto_genesis}" ] &&
        [ "$(json_raw identity.minamotoFinalizedHeight "${stored_receipt}")" = "${stored_minamoto_height}" ] &&
        [ "$(json_raw identity.minamotoFinalizedBlockHash "${stored_receipt}")" = "${stored_minamoto_hash}" ] &&
        [ "$(json_raw identity.tairaGenesisHash "${stored_receipt}")" = "${stored_taira_genesis}" ] &&
        [ "$(json_raw identity.tairaFinalizedHeight "${stored_receipt}")" = "${stored_taira_height}" ] &&
        [ "$(json_raw identity.tairaFinalizedBlockHash "${stored_receipt}")" = "${stored_taira_hash}" ] ||
        fail "stored rollout ${stored_target}% identity or evaluation binding is inconsistent"
}

validate_prior_link() {
    link_current_receipt="$1"
    link_current_signature="$2"
    link_current_target="$3"
    link_current_pi_probe="$4"
    link_current_pi_signature="$5"
    link_prior_receipt="$6"
    link_prior_signature="$7"
    link_prior_target="$8"
    link_prior_pi_probe="$9"
    link_prior_pi_signature="${10}"

    validate_stored_rollout_binding \
        "${link_current_receipt}" "${link_current_target}" \
        "${link_current_pi_probe}" "${link_current_pi_signature}"
    validate_stored_rollout_binding \
        "${link_prior_receipt}" "${link_prior_target}" \
        "${link_prior_pi_probe}" "${link_prior_pi_signature}"
    verify_signed_receipt \
        "${link_current_receipt}" \
        "${link_current_signature}" \
        "rollout ${link_current_target}% receipt" >/dev/null
    link_prior_sha="$(
        verify_signed_receipt \
            "${link_prior_receipt}" \
            "${link_prior_signature}" \
            "rollout ${link_prior_target}% receipt"
    )"
    [ "$(json_raw priorReceiptSha256 "${link_current_receipt}")" = "${link_prior_sha}" ] ||
        fail "rollout ${link_current_target}% receipt does not append the exact ${link_prior_target}% gate"

    link_prior_authorized_at="$(json_raw authorizedAtEpochSeconds "${link_prior_receipt}")"
    link_current_evaluated_at="$(json_raw evaluatedAtEpochSeconds "${link_current_receipt}")"
    link_cohort_started_at="$(json_raw completedCohort.startedAtEpochSeconds "${link_current_receipt}")"
    link_cohort_ended_at="$(json_raw completedCohort.endedAtEpochSeconds "${link_current_receipt}")"
    is_epoch_seconds "${link_prior_authorized_at}" &&
        is_epoch_seconds "${link_current_evaluated_at}" &&
        is_epoch_seconds "${link_cohort_started_at}" &&
        is_epoch_seconds "${link_cohort_ended_at}" &&
        [ "${link_cohort_started_at}" -gt "${link_prior_authorized_at}" ] &&
        [ "${link_cohort_ended_at}" -ge "${link_cohort_started_at}" ] &&
        [ $((link_cohort_ended_at - link_cohort_started_at)) -ge "${minimum_dwell_seconds}" ] &&
        [ "${link_cohort_ended_at}" -le "${link_current_evaluated_at}" ] &&
        [ "$(json_raw completedCohort.candidateBindingSha256 "${link_current_receipt}")" = "${candidate_binding}" ] ||
        fail "rollout ${link_current_target}% cohort is not strictly sequenced after ${link_prior_target}% with a full 48-hour dwell"

    link_current_sora2_height="$(json_raw identity.sora2FinalizedHeight "${link_current_receipt}")"
    link_current_sora2_hash="$(json_raw identity.sora2FinalizedBlockHash "${link_current_receipt}")"
    link_prior_sora2_height="$(json_raw identity.sora2FinalizedHeight "${link_prior_receipt}")"
    link_prior_sora2_hash="$(json_raw identity.sora2FinalizedBlockHash "${link_prior_receipt}")"
    link_current_minamoto_height="$(json_raw identity.minamotoFinalizedHeight "${link_current_receipt}")"
    link_current_minamoto_hash="$(json_raw identity.minamotoFinalizedBlockHash "${link_current_receipt}")"
    link_prior_minamoto_height="$(json_raw identity.minamotoFinalizedHeight "${link_prior_receipt}")"
    link_prior_minamoto_hash="$(json_raw identity.minamotoFinalizedBlockHash "${link_prior_receipt}")"
    link_current_taira_height="$(json_raw identity.tairaFinalizedHeight "${link_current_receipt}")"
    link_current_taira_hash="$(json_raw identity.tairaFinalizedBlockHash "${link_current_receipt}")"
    link_prior_taira_height="$(json_raw identity.tairaFinalizedHeight "${link_prior_receipt}")"
    link_prior_taira_hash="$(json_raw identity.tairaFinalizedBlockHash "${link_prior_receipt}")"
    [ "$(json_raw identity.sora2GenesisHash "${link_current_receipt}")" = "$(json_raw identity.sora2GenesisHash "${link_prior_receipt}")" ] &&
        [ "$(json_raw identity.minamotoGenesisHash "${link_current_receipt}")" = "$(json_raw identity.minamotoGenesisHash "${link_prior_receipt}")" ] &&
        [ "$(json_raw identity.tairaGenesisHash "${link_current_receipt}")" = "$(json_raw identity.tairaGenesisHash "${link_prior_receipt}")" ] &&
        [ "${link_current_sora2_height}" -ge "${link_prior_sora2_height}" ] &&
        [ "${link_current_minamoto_height}" -ge "${link_prior_minamoto_height}" ] &&
        [ "${link_current_taira_height}" -ge "${link_prior_taira_height}" ] ||
        fail "network genesis changed or a finalized checkpoint regressed between ${link_prior_target}% and ${link_current_target}%"
    [ "${link_current_sora2_height}" != "${link_prior_sora2_height}" ] || [ "${link_current_sora2_hash}" = "${link_prior_sora2_hash}" ] ||
        fail "SORA2 finalized hash changed at the same height across rollout gates"
    [ "${link_current_minamoto_height}" != "${link_prior_minamoto_height}" ] || [ "${link_current_minamoto_hash}" = "${link_prior_minamoto_hash}" ] ||
        fail "Minamoto finalized hash changed at the same height across rollout gates"
    [ "${link_current_taira_height}" != "${link_prior_taira_height}" ] || [ "${link_current_taira_hash}" = "${link_prior_taira_hash}" ] ||
        fail "Taira finalized hash changed at the same height across rollout gates"
}

validate_cohort_attestation_set() {
    attested_rollout_receipt="$1"
    attested_target="$2"
    attested_telemetry="$3"
    attested_telemetry_signature="$4"
    attested_distribution="$5"
    attested_distribution_signature="$6"
    /usr/bin/python3 -I -S "${json_validator}" attestations \
        "${attested_rollout_receipt}" \
        "${attested_telemetry}" \
        "${attested_distribution}" \
        "${attested_target}" \
        "${taira_deployment_admission}" ||
        fail "rollout ${attested_target}% signed telemetry/distribution attestations do not exactly match its completed cohort"
    attested_telemetry_sha="$(
        verify_signed_receipt \
            "${attested_telemetry}" \
            "${attested_telemetry_signature}" \
            "rollout ${attested_target}% aggregate telemetry attestation"
    )"
    attested_distribution_sha="$(
        verify_signed_receipt \
            "${attested_distribution}" \
            "${attested_distribution_signature}" \
            "rollout ${attested_target}% distribution-platform attestation"
    )"
    [ "$(json_raw completedCohort.telemetryAttestationSha256 "${attested_rollout_receipt}")" = "${attested_telemetry_sha}" ] &&
        [ "$(json_raw completedCohort.distributionPlatformAttestationSha256 "${attested_rollout_receipt}")" = "${attested_distribution_sha}" ] ||
        fail "rollout ${attested_target}% completed cohort does not bind its exact signed telemetry and distribution attestations"
}

if [ "${target}" = "1" ]; then
    [ -z "${telemetry_attestation}" ] &&
        [ -z "${telemetry_signature}" ] &&
        [ -z "${distribution_attestation}" ] &&
        [ -z "${distribution_signature}" ] ||
        fail "target 1 may not carry fabricated prior-cohort evidence"
else
    validate_cohort_attestation_set \
        "${rollout_receipt}" \
        "${target}" \
        "${telemetry_attestation}" \
        "${telemetry_signature}" \
        "${distribution_attestation}" \
        "${distribution_signature}"

    case "${target}" in
        5)
            validate_prior_link \
                "${rollout_receipt}" "${rollout_signature}" 5 "${pi_probe}" "${pi_probe_signature}" \
                "${prior_1_receipt}" "${prior_1_signature}" 1 "${prior_1_pi_probe}" "${prior_1_pi_signature}"
            ;;
        25)
            validate_cohort_attestation_set \
                "${prior_5_receipt}" 5 \
                "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" \
                "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}"
            validate_prior_link \
                "${prior_5_receipt}" "${prior_5_signature}" 5 "${prior_5_pi_probe}" "${prior_5_pi_signature}" \
                "${prior_1_receipt}" "${prior_1_signature}" 1 "${prior_1_pi_probe}" "${prior_1_pi_signature}"
            validate_prior_link \
                "${rollout_receipt}" "${rollout_signature}" 25 "${pi_probe}" "${pi_probe_signature}" \
                "${prior_5_receipt}" "${prior_5_signature}" 5 "${prior_5_pi_probe}" "${prior_5_pi_signature}"
            ;;
        100)
            validate_cohort_attestation_set \
                "${prior_5_receipt}" 5 \
                "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" \
                "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}"
            validate_cohort_attestation_set \
                "${prior_25_receipt}" 25 \
                "${prior_25_telemetry_attestation}" "${prior_25_telemetry_signature}" \
                "${prior_25_distribution_attestation}" "${prior_25_distribution_signature}"
            validate_prior_link \
                "${prior_5_receipt}" "${prior_5_signature}" 5 "${prior_5_pi_probe}" "${prior_5_pi_signature}" \
                "${prior_1_receipt}" "${prior_1_signature}" 1 "${prior_1_pi_probe}" "${prior_1_pi_signature}"
            validate_prior_link \
                "${prior_25_receipt}" "${prior_25_signature}" 25 "${prior_25_pi_probe}" "${prior_25_pi_signature}" \
                "${prior_5_receipt}" "${prior_5_signature}" 5 "${prior_5_pi_probe}" "${prior_5_pi_signature}"
            validate_prior_link \
                "${rollout_receipt}" "${rollout_signature}" 100 "${pi_probe}" "${pi_probe_signature}" \
                "${prior_25_receipt}" "${prior_25_signature}" 25 "${prior_25_pi_probe}" "${prior_25_pi_signature}"
            ;;
    esac
fi

# Final path revalidation closes ordinary mutation races. The release controller
# must additionally provide these inputs from an access-controlled immutable area.
final_candidate_sha="$(secure_sha256 "${candidate_ipa}" "${maximum_ipa_bytes}" "exported IPA")"
[ "${final_candidate_sha}" = "${candidate_sha}" ] &&
    [ "${final_candidate_sha}" = "${migration_admitted_ipa_sha256}" ] ||
    fail "exported IPA changed or differs from migration admission during qualification"
[ "$(secure_sha256 "${controller_trust}" "${maximum_json_bytes}" "controller trust root")" = "${actual_trust_sha}" ] ||
    fail "controller trust root changed during qualification"
[ "$(secure_sha256 "${controller_public_key}" "${maximum_public_key_bytes}" "controller public key")" = "${controller_key_sha}" ] ||
    fail "controller public key changed during qualification"
verify_signed_receipt "${qualification_receipt}" "${qualification_signature}" "upstream production qualification receipt" >/dev/null
verify_signed_receipt "${artifact_receipt}" "${artifact_signature}" "artifact identity receipt" >/dev/null
verify_signed_receipt "${pi_probe}" "${pi_probe_signature}" "PI production probe receipt" >/dev/null
verify_signed_receipt "${rollout_receipt}" "${rollout_signature}" "rollout qualification receipt" >/dev/null
if [ "${target}" = "5" ] || [ "${target}" = "25" ] || [ "${target}" = "100" ]; then
    verify_signed_receipt "${prior_1_receipt}" "${prior_1_signature}" "rollout 1% receipt" >/dev/null
    verify_signed_receipt "${prior_1_pi_probe}" "${prior_1_pi_signature}" "rollout 1% PI receipt" >/dev/null
fi
if [ "${target}" = "25" ] || [ "${target}" = "100" ]; then
    verify_signed_receipt "${prior_5_receipt}" "${prior_5_signature}" "rollout 5% receipt" >/dev/null
    verify_signed_receipt "${prior_5_pi_probe}" "${prior_5_pi_signature}" "rollout 5% PI receipt" >/dev/null
    verify_signed_receipt "${prior_5_telemetry_attestation}" "${prior_5_telemetry_signature}" "rollout 5% aggregate telemetry attestation" >/dev/null
    verify_signed_receipt "${prior_5_distribution_attestation}" "${prior_5_distribution_signature}" "rollout 5% distribution-platform attestation" >/dev/null
fi
if [ "${target}" = "100" ]; then
    verify_signed_receipt "${prior_25_receipt}" "${prior_25_signature}" "rollout 25% receipt" >/dev/null
    verify_signed_receipt "${prior_25_pi_probe}" "${prior_25_pi_signature}" "rollout 25% PI receipt" >/dev/null
    verify_signed_receipt "${prior_25_telemetry_attestation}" "${prior_25_telemetry_signature}" "rollout 25% aggregate telemetry attestation" >/dev/null
    verify_signed_receipt "${prior_25_distribution_attestation}" "${prior_25_distribution_signature}" "rollout 25% distribution-platform attestation" >/dev/null
fi
if [ "${target}" != "1" ]; then
    verify_signed_receipt "${telemetry_attestation}" "${telemetry_signature}" "aggregate telemetry attestation" >/dev/null
    verify_signed_receipt "${distribution_attestation}" "${distribution_signature}" "distribution-platform attestation" >/dev/null
fi

/usr/bin/printf 'production rollout v3 gate to %s%% qualified; signed result receipt SHA-256 %s\n' \
    "${target}" \
    "${rollout_receipt_sha}"
