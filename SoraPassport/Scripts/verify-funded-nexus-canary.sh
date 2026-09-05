#!/bin/sh
set -eu

# Funded Nexus canaries are post-export production-admission evidence. Ordinary
# builds validate only the checked-in blocked templates. Missing evidence or a
# missing mode is never interpreted as qualification.

root="$({ CDPATH= cd "$(/usr/bin/dirname "$0")/../.." && /bin/pwd -P; })"
json_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary-json.py"
rollout_json_validator="${root}/SoraPassport/Scripts/verify-production-rollout-json.py"
taira_deployment_validator="${root}/SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
taira_template="${root}/Fixtures/Modernization/taira-funded-canary.json"
minamoto_template="${root}/Fixtures/Modernization/minamoto-funded-canary.json"
trust_root="${root}/Fixtures/Modernization/funded-nexus-canary-trust.json"
rollout_trust_root="${root}/Fixtures/Modernization/production-rollout-controller-trust.json"
readiness="${root}/Fixtures/Modernization/iroha-production-send-readiness.json"
maximum_json_bytes=262144
maximum_receipt_bytes=65536
maximum_signature_bytes=4096
maximum_public_key_bytes=65536
maximum_ipa_bytes=4294967296
maximum_path_characters=4096
maximum_taira_deployment_rollout_age_seconds=604800

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
    case "${value}" in *[!0-9a-f]*) return 1 ;; esac
    [ "${value}" != "0000000000000000000000000000000000000000000000000000000000000000" ]
}

is_lower_hex_40() {
    value="$1"
    [ "${#value}" -eq 40 ] || return 1
    case "${value}" in *[!0-9a-f]*) return 1 ;; esac
    [ "${value}" != "0000000000000000000000000000000000000000" ]
}

is_epoch() {
    value="$1"
    case "${value}" in ""|*[!0-9]*) return 1 ;; esac
    [ "${#value}" -le 10 ] && [ "${value}" -gt 0 ] 2>/dev/null && [ "${value}" -le 9999999999 ] 2>/dev/null
}

is_exact_sequence() {
    value="$1"
    case "${value}" in
        ""|0|0*|*[!0-9]*) return 1 ;;
    esac
    [ "${#value}" -le 16 ] &&
        [ "${value}" -le 9007199254740991 ] 2>/dev/null
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

require_absolute_path() {
    checked_path="$1"
    checked_label="$2"
    [ -n "${checked_path}" ] || fail "${checked_label} path is missing"
    [ "${#checked_path}" -le "${maximum_path_characters}" ] || fail "${checked_label} path is too long"
    case "${checked_path}" in /*) ;; *) fail "${checked_label} path must be absolute" ;; esac
}

json_raw() {
    /usr/bin/plutil -extract "$1" raw "$2" 2>/dev/null || /usr/bin/true
}

secure_sha256() {
    hashed_path="$1"
    byte_bound="$2"
    hashed_label="$3"
    require_absolute_path "${hashed_path}" "${hashed_label}"
    result="$(/usr/bin/python3 -I -S "${rollout_json_validator}" hash "${hashed_path}" "${byte_bound}")" ||
        fail "${hashed_label} is not one stable regular non-symlink file"
    is_lower_hex_64 "${result}" || fail "${hashed_label} SHA-256 is invalid"
    /usr/bin/printf '%s\n' "${result}"
}

validate_templates() {
    for source_path in \
        "${json_validator}" \
        "${rollout_json_validator}" \
        "${taira_deployment_validator}" \
        "${taira_template}" \
        "${minamoto_template}" \
        "${trust_root}"
    do
        [ -f "${source_path}" ] && [ ! -L "${source_path}" ] ||
            fail "funded canary contract input is missing or symbolic: ${source_path}"
    done
    /usr/bin/python3 -I -S "${json_validator}" templates \
        "${taira_template}" \
        "${minamoto_template}" \
        "${trust_root}" ||
        fail "funded Taira/Minamoto templates or trust root are not exact and fail-closed"
    /usr/bin/python3 -B -I -S "${taira_deployment_validator}" --lint-contract >/dev/null ||
        fail "Taira deployment manifest contract is not blocked and exact"
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-templates" ]; then
    validate_templates
    /usr/bin/printf 'funded Nexus canary blocked templates are fail-closed\n'
    exit 0
fi

if [ "$#" -gt 1 ]; then
    fail "funded canary validator accepts only --lint-templates, --verify-admission, or no argument"
fi
if [ "$#" -eq 1 ] && [ "$1" != "--verify-admission" ]; then
    fail "unknown funded canary validator argument"
fi

validate_templates

candidate_ipa="${PRODUCTION_ROLLOUT_IPA_PATH:-}"
artifact_receipt="${PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH:-}"
artifact_signature="${PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH:-}"
rollout_controller_key="${PRODUCTION_ROLLOUT_CONTROLLER_PUBLIC_KEY_PATH:-}"
rollout_trust_sha="${PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256:-}"
source_revision="${PRODUCTION_CANDIDATE_SOURCE_REVISION:-}"
evaluation_epoch="${PRODUCTION_RELEASE_EVALUATED_AT_EPOCH_SECONDS:-}"
funded_trust_sha="${FUNDED_NEXUS_CANARY_TRUST_ROOT_SHA256:-}"
operator_key="${FUNDED_NEXUS_CANARY_RELEASE_OPERATOR_PUBLIC_KEY_PATH:-}"
approver_key="${FUNDED_NEXUS_CANARY_INDEPENDENT_APPROVER_PUBLIC_KEY_PATH:-}"
reviewer_key="${FUNDED_NEXUS_CANARY_INDEPENDENT_REVIEWER_PUBLIC_KEY_PATH:-}"
ledger_key="${FUNDED_NEXUS_CANARY_CONSUMPTION_LEDGER_PUBLIC_KEY_PATH:-}"
admission_receipt="${FUNDED_NEXUS_CANARY_ADMISSION_RECEIPT_PATH:-}"
admission_signature="${FUNDED_NEXUS_CANARY_ADMISSION_SIGNATURE_PATH:-}"
taira_receipt="${TAIRA_FUNDED_CANARY_RECEIPT_PATH:-}"
taira_receipt_signature="${TAIRA_FUNDED_CANARY_RECEIPT_SIGNATURE_PATH:-}"
minamoto_receipt="${MINAMOTO_FUNDED_CANARY_RECEIPT_PATH:-}"
minamoto_receipt_signature="${MINAMOTO_FUNDED_CANARY_RECEIPT_SIGNATURE_PATH:-}"
taira_deployment_manifest="${IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH:-}"
taira_deployment_operator_signature="${IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH:-}"
taira_deployment_reviewer_signature="${IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH:-}"
taira_deployment_operator_key="${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH:-}"
taira_deployment_reviewer_key="${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH:-}"
taira_deployment_operator_key_sha="${IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256:-}"
taira_deployment_reviewer_key_sha="${IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256:-}"
taira_deployment_expected_sequence="${IOS_TAIRA_DEPLOYMENT_EXPECTED_MANIFEST_SEQUENCE_NUMBER:-}"
taira_deployment_evaluation_epoch="${IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS:-}"

for path_and_label in \
    "${candidate_ipa}|signed production IPA" \
    "${artifact_receipt}|artifact identity receipt" \
    "${artifact_signature}|artifact identity signature" \
    "${rollout_controller_key}|rollout controller public key" \
    "${reviewer_key}|independent reviewer public key" \
    "${admission_receipt}|funded canary admission receipt" \
    "${admission_signature}|funded canary admission signature" \
    "${taira_receipt}|funded Taira canary receipt" \
    "${taira_receipt_signature}|funded Taira canary signature" \
    "${minamoto_receipt}|funded Minamoto canary receipt" \
    "${minamoto_receipt_signature}|funded Minamoto canary signature" \
    "${taira_deployment_manifest}|Taira deployment manifest" \
    "${taira_deployment_operator_signature}|Taira deployment operator signature" \
    "${taira_deployment_reviewer_signature}|Taira deployment reviewer signature" \
    "${taira_deployment_operator_key}|Taira deployment operator public key" \
    "${taira_deployment_reviewer_key}|Taira deployment reviewer public key"
do
    require_absolute_path "${path_and_label%%|*}" "${path_and_label#*|}"
done
is_lower_hex_64 "${rollout_trust_sha}" || fail "rollout trust root must be independently SHA-256 pinned"
is_lower_hex_64 "${funded_trust_sha}" || fail "funded canary trust root must be independently SHA-256 pinned"
is_lower_hex_40 "${source_revision}" || fail "candidate source revision must be an exact lowercase commit"
is_epoch "${evaluation_epoch}" || fail "explicit production release evaluation epoch is required"
is_lower_hex_64 "${taira_deployment_operator_key_sha}" || fail "Taira deployment operator key requires an independent SHA-256 pin"
is_lower_hex_64 "${taira_deployment_reviewer_key_sha}" || fail "Taira deployment reviewer key requires an independent SHA-256 pin"
is_exact_sequence "${taira_deployment_expected_sequence}" || fail "protected exact Taira deployment manifest sequence is required"
is_epoch "${taira_deployment_evaluation_epoch}" || fail "explicit Taira deployment evaluation epoch is required"
current_epoch="$(/bin/date +%s)"
minimum_taira_deployment_epoch=$((current_epoch - maximum_taira_deployment_rollout_age_seconds))
[ "${taira_deployment_evaluation_epoch}" -ge "${minimum_taira_deployment_epoch}" ] &&
    [ "${taira_deployment_evaluation_epoch}" -le "${current_epoch}" ] ||
    fail "Taira deployment admission must be no more than seven days old and not future-dated for funded-canary admission"

snapshot_directory="$(/usr/bin/mktemp -d /private/tmp/sora-ios-funded-canary.XXXXXX)" ||
    fail "cannot create private funded-canary evidence directory"
cleanup_snapshots() { /bin/rm -rf -- "${snapshot_directory}"; }
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
taira_deployment_admission_sha="$(admission_projection_value "${taira_deployment_result}" admissionSha256)"
taira_deployment_manifest_sequence="$(admission_projection_value "${taira_deployment_result}" manifestSequenceNumber)"
is_lower_hex_64 "${taira_deployment_admission_sha}" || fail "Taira deployment admission digest is invalid"
[ "${taira_deployment_manifest_sequence}" = "${taira_deployment_expected_sequence}" ] ||
    fail "Taira deployment admission sequence differs from protected release sequence"
IOS_TAIRA_DEPLOYMENT_VERIFIED_ADMISSION_SHA256="${taira_deployment_admission_sha}"
export IOS_TAIRA_DEPLOYMENT_VERIFIED_ADMISSION_SHA256

snapshot_input() {
    source_path="$1"
    byte_bound="$2"
    label="$3"
    name="$4"
    destination="${snapshot_directory}/${name}"
    /usr/bin/python3 -I -S "${rollout_json_validator}" snapshot \
        "${source_path}" "${destination}" "${byte_bound}" >/dev/null ||
        fail "${label} could not be captured as one stable private snapshot"
    /usr/bin/printf '%s\n' "${destination}"
}

rollout_trust_snapshot="$(snapshot_input "${rollout_trust_root}" "${maximum_receipt_bytes}" "rollout trust root" rollout-trust.json)"
funded_trust_snapshot="$(snapshot_input "${trust_root}" "${maximum_receipt_bytes}" "funded canary trust root" funded-trust.json)"
readiness_snapshot="$(snapshot_input "${readiness}" "${maximum_json_bytes}" "Iroha send readiness" readiness.json)"
taira_template_snapshot="$(snapshot_input "${taira_template}" "${maximum_receipt_bytes}" "blocked Taira template" taira-template.json)"
minamoto_template_snapshot="$(snapshot_input "${minamoto_template}" "${maximum_receipt_bytes}" "blocked Minamoto template" minamoto-template.json)"
artifact_snapshot="$(snapshot_input "${artifact_receipt}" "${maximum_json_bytes}" "artifact identity receipt" artifact.json)"
artifact_signature_snapshot="$(snapshot_input "${artifact_signature}" "${maximum_signature_bytes}" "artifact identity signature" artifact.sig)"
controller_key_snapshot="$(snapshot_input "${rollout_controller_key}" "${maximum_public_key_bytes}" "rollout controller key" controller.pem)"
reviewer_key_snapshot="$(snapshot_input "${reviewer_key}" "${maximum_public_key_bytes}" "independent reviewer key" reviewer.pem)"
admission_snapshot="$(snapshot_input "${admission_receipt}" "${maximum_receipt_bytes}" "funded canary admission" admission.json)"
admission_signature_snapshot="$(snapshot_input "${admission_signature}" "${maximum_signature_bytes}" "funded canary admission signature" admission.sig)"
taira_snapshot="$(snapshot_input "${taira_receipt}" "${maximum_receipt_bytes}" "funded Taira receipt" taira.json)"
taira_signature_snapshot="$(snapshot_input "${taira_receipt_signature}" "${maximum_signature_bytes}" "funded Taira signature" taira.sig)"
minamoto_snapshot="$(snapshot_input "${minamoto_receipt}" "${maximum_receipt_bytes}" "funded Minamoto receipt" minamoto.json)"
minamoto_signature_snapshot="$(snapshot_input "${minamoto_receipt_signature}" "${maximum_signature_bytes}" "funded Minamoto signature" minamoto.sig)"

rollout_trust_snapshot_sha="$(secure_sha256 "${rollout_trust_snapshot}" "${maximum_receipt_bytes}" "rollout trust root")"
[ "${rollout_trust_snapshot_sha}" = "${rollout_trust_sha}" ] ||
    fail "rollout trust root differs from its independent pin"
[ "$(secure_sha256 "${funded_trust_snapshot}" "${maximum_receipt_bytes}" "funded trust root")" = "${funded_trust_sha}" ] ||
    fail "funded canary trust root differs from its independent pin"
IOS_PRODUCTION_ROLLOUT_TRUST_VERIFIED_SHA256="${rollout_trust_snapshot_sha}"
export IOS_PRODUCTION_ROLLOUT_TRUST_VERIFIED_SHA256
/usr/bin/python3 -I -S "${rollout_json_validator}" trust "${rollout_trust_snapshot}" ||
    fail "rollout controller trust root remains blocked"
/usr/bin/python3 -I -S "${json_validator}" trust "${funded_trust_snapshot}" ||
    fail "funded canary authority trust root remains blocked"

validate_p256_key() {
    key_path="$1"
    expected_sha="$2"
    label="$3"
    [ "$(secure_sha256 "${key_path}" "${maximum_public_key_bytes}" "${label}")" = "${expected_sha}" ] ||
        fail "${label} differs from the reviewed trust root"
    secure_openssl ec -pubin -in "${key_path}" -noout >/dev/null 2>&1 ||
        fail "${label} is not a valid EC public key"
    curve="$({ secure_openssl ec -pubin -in "${key_path}" -text -noout 2>/dev/null; } || /usr/bin/true)"
    /usr/bin/printf '%s\n' "${curve}" | /usr/bin/grep -Eq 'ASN1 OID: prime256v1|NIST CURVE: P-256' ||
        fail "${label} is not ECDSA P-256"
}

[ -x /usr/bin/openssl ] || fail "P-256 receipt verification requires /usr/bin/openssl"
controller_key_sha="$(json_raw publicKeySha256 "${rollout_trust_snapshot}")"
reviewer_key_sha="$(json_raw authorities.independentReviewer.publicKeyPemSha256 "${funded_trust_snapshot}")"
validate_p256_key "${controller_key_snapshot}" "${controller_key_sha}" "rollout controller key"
validate_p256_key "${reviewer_key_snapshot}" "${reviewer_key_sha}" "independent reviewer key"

verify_signature() {
    payload="$1"
    signature="$2"
    key="$3"
    label="$4"
    before_payload="$(secure_sha256 "${payload}" "${maximum_json_bytes}" "${label}")"
    before_signature="$(secure_sha256 "${signature}" "${maximum_signature_bytes}" "${label} signature")"
    secure_openssl dgst -sha256 -verify "${key}" -signature "${signature}" "${payload}" >/dev/null 2>&1 ||
        fail "${label} detached P-256 signature is invalid"
    [ "$(secure_sha256 "${payload}" "${maximum_json_bytes}" "${label}")" = "${before_payload}" ] &&
        [ "$(secure_sha256 "${signature}" "${maximum_signature_bytes}" "${label} signature")" = "${before_signature}" ] ||
        fail "${label} changed during signature verification"
}

[ "$(json_raw controllerId "${artifact_snapshot}")" = "$(json_raw controllerId "${rollout_trust_snapshot}")" ] ||
    fail "artifact identity names a different rollout controller"
verify_signature "${artifact_snapshot}" "${artifact_signature_snapshot}" "${controller_key_snapshot}" "artifact identity receipt"
IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256="$(
    secure_sha256 "${artifact_snapshot}" "${maximum_json_bytes}" "artifact identity receipt"
)"
export IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256
/usr/bin/python3 -I -S "${rollout_json_validator}" artifact "${artifact_snapshot}" "${candidate_ipa}" "${taira_deployment_admission}" ||
    fail "artifact identity does not bind the actual signed IPA"
verify_signature "${taira_snapshot}" "${taira_signature_snapshot}" "${reviewer_key_snapshot}" "funded Taira canary receipt"
verify_signature "${minamoto_snapshot}" "${minamoto_signature_snapshot}" "${reviewer_key_snapshot}" "funded Minamoto canary receipt"
verify_signature "${admission_snapshot}" "${admission_signature_snapshot}" "${reviewer_key_snapshot}" "funded canary admission receipt"

admission_result="$(
    /usr/bin/python3 -I -S "${json_validator}" admission \
        "${admission_snapshot}" \
        "${funded_trust_snapshot}" \
        "${artifact_snapshot}" \
        "${candidate_ipa}" \
        "${taira_snapshot}" \
        "${minamoto_snapshot}" \
        "${readiness_snapshot}" \
        "${source_revision}" \
        "${evaluation_epoch}" \
        "${taira_deployment_admission}"
)" || fail "funded canary admission does not bind both network receipts to the exact candidate"

for path_and_label in \
    "${operator_key}|release operator public key" \
    "${approver_key}|independent approver public key" \
    "${ledger_key}|consumption ledger public key"
do
    require_absolute_path "${path_and_label%%|*}" "${path_and_label#*|}"
done
operator_key_snapshot="$(snapshot_input "${operator_key}" "${maximum_public_key_bytes}" "release operator key" operator.pem)"
approver_key_snapshot="$(snapshot_input "${approver_key}" "${maximum_public_key_bytes}" "independent approver key" approver.pem)"
ledger_key_snapshot="$(snapshot_input "${ledger_key}" "${maximum_public_key_bytes}" "consumption ledger key" ledger.pem)"
validate_p256_key "${operator_key_snapshot}" "$(json_raw authorities.releaseOperator.publicKeyPemSha256 "${funded_trust_snapshot}")" "release operator key"
validate_p256_key "${approver_key_snapshot}" "$(json_raw authorities.independentApprover.publicKeyPemSha256 "${funded_trust_snapshot}")" "independent approver key"
validate_p256_key "${ledger_key_snapshot}" "$(json_raw authorities.consumptionLedger.publicKeyPemSha256 "${funded_trust_snapshot}")" "consumption ledger key"

finality_manifest="${PRODUCTION_FINALITY_TRUST_MANIFEST_RECEIPT_PATH:-}"
finality_manifest_signature="${PRODUCTION_FINALITY_TRUST_MANIFEST_SIGNATURE_PATH:-}"
native_canary="${IROHA_REVIEWED_NATIVE_CANARY_RECEIPT_PATH:-}"
native_canary_signature="${IROHA_REVIEWED_NATIVE_CANARY_SIGNATURE_PATH:-}"
finality_native_canary="${IROHA_REVIEWED_FINALITY_NATIVE_CANARY_RECEIPT_PATH:-}"
finality_native_signature="${IROHA_REVIEWED_FINALITY_NATIVE_CANARY_SIGNATURE_PATH:-}"
for path_and_label in \
    "${finality_manifest}|finality trust manifest" \
    "${finality_manifest_signature}|finality trust manifest signature" \
    "${native_canary}|reviewed native signer canary" \
    "${native_canary_signature}|reviewed native signer canary signature" \
    "${finality_native_canary}|reviewed finality native canary" \
    "${finality_native_signature}|reviewed finality native canary signature"
do
    require_absolute_path "${path_and_label%%|*}" "${path_and_label#*|}"
done
finality_manifest_snapshot="$(snapshot_input "${finality_manifest}" "${maximum_receipt_bytes}" "finality trust manifest" finality-manifest.json)"
finality_manifest_signature_snapshot="$(snapshot_input "${finality_manifest_signature}" "${maximum_signature_bytes}" "finality trust manifest signature" finality-manifest.sig)"
native_canary_snapshot="$(snapshot_input "${native_canary}" "${maximum_receipt_bytes}" "native signer canary" native-canary.json)"
native_canary_signature_snapshot="$(snapshot_input "${native_canary_signature}" "${maximum_signature_bytes}" "native signer canary signature" native-canary.sig)"
finality_native_snapshot="$(snapshot_input "${finality_native_canary}" "${maximum_receipt_bytes}" "finality native canary" finality-native.json)"
finality_native_signature_snapshot="$(snapshot_input "${finality_native_signature}" "${maximum_signature_bytes}" "finality native canary signature" finality-native.sig)"
verify_signature "${finality_manifest_snapshot}" "${finality_manifest_signature_snapshot}" "${reviewer_key_snapshot}" "finality trust manifest"
verify_signature "${native_canary_snapshot}" "${native_canary_signature_snapshot}" "${reviewer_key_snapshot}" "native signer canary"
verify_signature "${finality_native_snapshot}" "${finality_native_signature_snapshot}" "${reviewer_key_snapshot}" "finality native canary"

verify_network() {
    network_id="$1"
    receipt_snapshot="$2"
    template_path="$3"
    case "${network_id}" in
        taira)
            approval="${TAIRA_FUNDED_CANARY_APPROVAL_RECEIPT_PATH:-}"
            approval_operator_signature="${TAIRA_FUNDED_CANARY_APPROVAL_OPERATOR_SIGNATURE_PATH:-}"
            approval_independent_signature="${TAIRA_FUNDED_CANARY_APPROVAL_INDEPENDENT_SIGNATURE_PATH:-}"
            policy="${TAIRA_FUNDED_CANARY_LOW_VALUE_POLICY_PATH:-}"
            consumption="${TAIRA_FUNDED_CANARY_CONSUMPTION_RECEIPT_PATH:-}"
            consumption_signature="${TAIRA_FUNDED_CANARY_CONSUMPTION_SIGNATURE_PATH:-}"
            evidence="${TAIRA_FUNDED_CANARY_EVIDENCE_BUNDLE_PATH:-}"
            evidence_signature="${TAIRA_FUNDED_CANARY_EVIDENCE_SIGNATURE_PATH:-}"
            network_trust="${TAIRA_FUNDED_CANARY_FINALITY_TRUST_CONTEXT_PATH:-}"
            network_trust_signature="${TAIRA_FUNDED_CANARY_FINALITY_TRUST_CONTEXT_SIGNATURE_PATH:-}"
            pi_receipt="${TAIRA_FUNDED_CANARY_PI_RECEIPT_PATH:-}"
            pi_signature="${TAIRA_FUNDED_CANARY_PI_SIGNATURE_PATH:-}"
            ;;
        minamoto)
            approval="${MINAMOTO_FUNDED_CANARY_APPROVAL_RECEIPT_PATH:-}"
            approval_operator_signature="${MINAMOTO_FUNDED_CANARY_APPROVAL_OPERATOR_SIGNATURE_PATH:-}"
            approval_independent_signature="${MINAMOTO_FUNDED_CANARY_APPROVAL_INDEPENDENT_SIGNATURE_PATH:-}"
            policy="${MINAMOTO_FUNDED_CANARY_LOW_VALUE_POLICY_PATH:-}"
            consumption="${MINAMOTO_FUNDED_CANARY_CONSUMPTION_RECEIPT_PATH:-}"
            consumption_signature="${MINAMOTO_FUNDED_CANARY_CONSUMPTION_SIGNATURE_PATH:-}"
            evidence="${MINAMOTO_FUNDED_CANARY_EVIDENCE_BUNDLE_PATH:-}"
            evidence_signature="${MINAMOTO_FUNDED_CANARY_EVIDENCE_SIGNATURE_PATH:-}"
            network_trust="${MINAMOTO_FUNDED_CANARY_FINALITY_TRUST_CONTEXT_PATH:-}"
            network_trust_signature="${MINAMOTO_FUNDED_CANARY_FINALITY_TRUST_CONTEXT_SIGNATURE_PATH:-}"
            pi_receipt="${MINAMOTO_FUNDED_CANARY_PI_RECEIPT_PATH:-}"
            pi_signature="${MINAMOTO_FUNDED_CANARY_PI_SIGNATURE_PATH:-}"
            ;;
        *) fail "unsupported funded canary network" ;;
    esac
    for path_and_label in \
        "${approval}|${network_id} approval receipt" \
        "${approval_operator_signature}|${network_id} operator approval signature" \
        "${approval_independent_signature}|${network_id} independent approval signature" \
        "${policy}|${network_id} low-value policy" \
        "${consumption}|${network_id} consumption receipt" \
        "${consumption_signature}|${network_id} consumption signature" \
        "${evidence}|${network_id} evidence bundle" \
        "${evidence_signature}|${network_id} evidence signature" \
        "${network_trust}|${network_id} finality trust context" \
        "${network_trust_signature}|${network_id} finality trust signature" \
        "${pi_receipt}|${network_id} PI receipt" \
        "${pi_signature}|${network_id} PI signature"
    do
        require_absolute_path "${path_and_label%%|*}" "${path_and_label#*|}"
    done
    approval_snapshot="$(snapshot_input "${approval}" "${maximum_receipt_bytes}" "${network_id} approval" "${network_id}-approval.json")"
    approval_operator_signature_snapshot="$(snapshot_input "${approval_operator_signature}" "${maximum_signature_bytes}" "${network_id} operator approval signature" "${network_id}-approval-operator.sig")"
    approval_independent_signature_snapshot="$(snapshot_input "${approval_independent_signature}" "${maximum_signature_bytes}" "${network_id} independent approval signature" "${network_id}-approval-independent.sig")"
    policy_snapshot="$(snapshot_input "${policy}" "${maximum_receipt_bytes}" "${network_id} policy" "${network_id}-policy.json")"
    consumption_snapshot="$(snapshot_input "${consumption}" "${maximum_receipt_bytes}" "${network_id} consumption" "${network_id}-consumption.json")"
    consumption_signature_snapshot="$(snapshot_input "${consumption_signature}" "${maximum_signature_bytes}" "${network_id} consumption signature" "${network_id}-consumption.sig")"
    evidence_snapshot="$(snapshot_input "${evidence}" "${maximum_json_bytes}" "${network_id} evidence" "${network_id}-evidence.json")"
    evidence_signature_snapshot="$(snapshot_input "${evidence_signature}" "${maximum_signature_bytes}" "${network_id} evidence signature" "${network_id}-evidence.sig")"
    network_trust_snapshot="$(snapshot_input "${network_trust}" "${maximum_receipt_bytes}" "${network_id} finality trust" "${network_id}-finality-trust.json")"
    network_trust_signature_snapshot="$(snapshot_input "${network_trust_signature}" "${maximum_signature_bytes}" "${network_id} finality trust signature" "${network_id}-finality-trust.sig")"
    pi_snapshot="$(snapshot_input "${pi_receipt}" "${maximum_json_bytes}" "${network_id} PI receipt" "${network_id}-pi.json")"
    pi_signature_snapshot="$(snapshot_input "${pi_signature}" "${maximum_signature_bytes}" "${network_id} PI signature" "${network_id}-pi.sig")"
    verify_signature "${approval_snapshot}" "${approval_operator_signature_snapshot}" "${operator_key_snapshot}" "${network_id} operator approval"
    verify_signature "${approval_snapshot}" "${approval_independent_signature_snapshot}" "${approver_key_snapshot}" "${network_id} independent approval"
    verify_signature "${consumption_snapshot}" "${consumption_signature_snapshot}" "${ledger_key_snapshot}" "${network_id} append-only consumption"
    verify_signature "${evidence_snapshot}" "${evidence_signature_snapshot}" "${reviewer_key_snapshot}" "${network_id} evidence bundle"
    verify_signature "${network_trust_snapshot}" "${network_trust_signature_snapshot}" "${reviewer_key_snapshot}" "${network_id} finality trust context"
    verify_signature "${pi_snapshot}" "${pi_signature_snapshot}" "${controller_key_snapshot}" "${network_id} PI capability receipt"
    /usr/bin/python3 -I -S "${rollout_json_validator}" pi "${pi_snapshot}" "${taira_deployment_admission}" ||
        fail "${network_id} PI receipt is not an exact qualified capability checkpoint"
    /usr/bin/python3 -I -S "${json_validator}" qualified \
        "${receipt_snapshot}" \
        "${template_path}" \
        "${approval_snapshot}" \
        "${policy_snapshot}" \
        "${consumption_snapshot}" \
        "${evidence_snapshot}" \
        "${finality_manifest_snapshot}" \
        "${network_trust_snapshot}" \
        "${pi_snapshot}" \
        "${readiness_snapshot}" \
        "${native_canary_snapshot}" \
        "${finality_native_snapshot}" \
        "${artifact_snapshot}" \
        "${candidate_ipa}" \
        "${funded_trust_snapshot}" \
        "${network_id}" \
        "${source_revision}" \
        "${evaluation_epoch}" \
        "${taira_deployment_admission}" >/dev/null || fail "${network_id} funded canary is not fully qualified"
}

verify_network taira "${taira_snapshot}" "${taira_template_snapshot}"
verify_network minamoto "${minamoto_snapshot}" "${minamoto_template_snapshot}"
/usr/bin/printf '%s\n' "${admission_result}"
