#!/bin/sh
set -eu

# Produce one observed, non-authorizing proof that the Release build-for-testing
# host is canonically derived from the exact exported production IPA.

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"
tool="${root}/SoraPassport/Scripts/derive-ios-migration-test-host.py"
contract_tool="${root}/SoraPassport/Scripts/ios-migration-qualification-contract.py"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

lint_contract() {
    for source in "${tool}" "${contract_tool}"
    do
        [ -f "${source}" ] && [ ! -L "${source}" ] ||
            fail "test-host derivation source is absent or symbolic"
    done
    /usr/bin/python3 -I -S "${tool}" --repository-root "${root}" --lint-contract >/dev/null ||
        fail "canonical test-host projector contract is invalid"
    /usr/bin/python3 -I -S "${contract_tool}" \
        --repository-root "${root}" --print-sha >/dev/null ||
        fail "migration qualification source contract is invalid"
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS migration observed test-host derivation wrapper: OK\n'
    exit 0
fi

if [ "$#" -ne 7 ] ||
   [ "$1" != "--derive" ] ||
   [ "$2" != "--ipa" ] ||
   [ "$4" != "--test-host" ] ||
   [ "$6" != "--output" ]; then
    fail "usage: derive-ios-migration-test-host.sh --lint-contract | --derive --ipa /private/Sora.ipa --test-host /private/SoraPassport.app --output /private/test-host-derivation.json"
fi

ipa="$3"
test_host="$5"
output="$7"
for path in "${ipa}" "${test_host}" "${output}"
do
    case "${path}" in /*) ;; *) fail "derivation paths must be absolute" ;; esac
    [ "${path}" != "/" ] || fail "derivation paths must not be the filesystem root"
done
[ "${ipa}" != "${test_host}" ] && [ "${ipa}" != "${output}" ] && [ "${test_host}" != "${output}" ] ||
    fail "derivation paths must be distinct"

# No signing, qualification, canary, rollout, or mutation authority is valid in
# this structural observation lane.
for forbidden_name in \
    IOS_MIGRATION_QUALIFICATION_SEQUENCE_NUMBER \
    IOS_MIGRATION_QUALIFICATION_DEVICE_EVIDENCE_PRODUCER_PRIVATE_KEY \
    IOS_MIGRATION_QUALIFICATION_INDEPENDENT_REVIEWER_PRIVATE_KEY \
    IOS_MIGRATION_QUALIFICATION_RECEIPT_REVIEWER_SIGNATURE_PATH \
    IOS_MIGRATION_QUALIFICATION_EVIDENCE_DEVICE_SIGNATURE_PATH \
    IOS_MIGRATION_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH \
    IOS_PRODUCTION_ROLLOUT_CONTROLLER_PRIVATE_KEY \
    IOS_FUNDED_CANARY_APPROVAL_PRIVATE_KEY \
    IOS_PRODUCTION_MUTATIONS_ENABLED
do
    eval "forbidden_value=\${${forbidden_name}:-}"
    [ -z "${forbidden_value}" ] ||
        fail "observed test-host derivation received forbidden authority: ${forbidden_name}"
done

lint_contract
qualification_contract_sha="$({
    /usr/bin/python3 -I -S "${contract_tool}" \
        --repository-root "${root}" --print-sha
})" || fail "qualification source contract cannot be derived"
case "${qualification_contract_sha}" in ''|*[!0-9a-f]*) fail "qualification source contract returned an invalid SHA-256" ;; esac
[ "${#qualification_contract_sha}" -eq 64 ] ||
    fail "qualification source contract returned an invalid SHA-256"

result="$({
    /usr/bin/python3 -I -S "${tool}" \
        --repository-root "${root}" \
        --derive \
        --ipa "${ipa}" \
        --test-host "${test_host}" \
        --output "${output}" \
        --qualification-contract-sha "${qualification_contract_sha}"
})" || fail "canonical test-host derivation failed"

current_contract_sha="$({
    /usr/bin/python3 -I -S "${contract_tool}" \
        --repository-root "${root}" --print-sha
})" || fail "qualification source contract cannot be rederived"
[ "${current_contract_sha}" = "${qualification_contract_sha}" ] ||
    fail "qualification source contract changed during test-host derivation"

/usr/bin/python3 -I -S "${tool}" \
    --repository-root "${root}" \
    --verify-raw \
    --ipa "${ipa}" \
    --test-host "${test_host}" \
    --receipt "${output}" \
    --expected-qualification-contract-sha "${qualification_contract_sha}" >/dev/null ||
    fail "published test-host derivation failed independent recomputation"

[ "$(/usr/bin/printf '%s\n' "${result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" = "1" ] ||
    fail "test-host derivation returned a multiline result"
token_count="$(/usr/bin/printf '%s\n' "${result}" | /usr/bin/tr ' ' '\n' | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')"
[ "${token_count}" = "8" ] || fail "test-host derivation returned an unexpected result inventory"
for key in ipaSha256 testHostRawTreeSha256 canonicalProjectionSha256 testHostExecutableSha256 derivationReceiptSha256
do
    value="$(/usr/bin/printf '%s\n' "${result}" | /usr/bin/tr ' ' '\n' | /usr/bin/awk -F= -v key="${key}" '$1 == key { print $2 }')"
    case "${value}" in ''|*[!0-9a-f]*) fail "test-host derivation omitted ${key}" ;; esac
    [ "${#value}" -eq 64 ] || fail "test-host derivation returned an invalid ${key}"
    [ "$(/usr/bin/printf '%s\n' "${result}" | /usr/bin/tr ' ' '\n' | /usr/bin/awk -F= -v key="${key}" '$1 == key { count += 1 } END { print count + 0 }')" = "1" ] ||
        fail "test-host derivation returned an ambiguous ${key}"
done
for key in testHostRawTreeRecordByteCount canonicalProjectionRecordByteCount testHostExecutableByteCount
do
    value="$(/usr/bin/printf '%s\n' "${result}" | /usr/bin/tr ' ' '\n' | /usr/bin/awk -F= -v key="${key}" '$1 == key { print $2 }')"
    case "${value}" in ''|*[!0-9]*) fail "test-host derivation omitted ${key}" ;; esac
    [ "${value}" -gt 0 ] || fail "test-host derivation returned an invalid ${key}"
    [ "$(/usr/bin/printf '%s\n' "${result}" | /usr/bin/tr ' ' '\n' | /usr/bin/awk -F= -v key="${key}" '$1 == key { count += 1 } END { print count + 0 }')" = "1" ] ||
        fail "test-host derivation returned an ambiguous ${key}"
done

/usr/bin/printf '%s\n' "${result}"
