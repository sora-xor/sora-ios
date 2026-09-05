#!/bin/sh
set -eu

# Post-archive migration admission only. This script authenticates the complete
# owner-only independently reproduced package first, then authenticates the
# schema-v8 qualification and exact IPA and cross-checks its receipt. It never
# builds or uploads.

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"
validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.sh"
json_validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.py"
release_package_validator="${root}/SoraPassport/Scripts/verify-ios-release-reproducibility-package.py"
signing_identity_validator="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.sh"
vendored_binary_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

lint_contract() {
    [ -f "${validator}" ] && [ ! -L "${validator}" ] ||
        fail "migration qualification validator is missing or symbolic"
    [ -f "${json_validator}" ] && [ ! -L "${json_validator}" ] ||
        fail "migration qualification JSON validator is missing or symbolic"
    [ -f "${release_package_validator}" ] && [ ! -L "${release_package_validator}" ] ||
        fail "iOS Release reproduction/package validator is missing or symbolic"
    [ -f "${signing_identity_validator}" ] && [ ! -L "${signing_identity_validator}" ] ||
        fail "iOS production signing-identity validator is missing or symbolic"
    [ -f "${vendored_binary_validator}" ] && [ ! -L "${vendored_binary_validator}" ] ||
        fail "iOS vendored-binary validator is missing or symbolic"
    /usr/bin/grep -Fq -- '--verify-qualified-ipa' "${json_validator}" ||
        fail "migration qualification validator lacks exact-IPA admission"
    /usr/bin/grep -Fq 'verify_qualified_ipa' "${json_validator}" ||
        fail "migration qualification validator lacks stable IPA verification"
    /usr/bin/python3 -B -I -S "${release_package_validator}" --lint-contract >/dev/null ||
        fail "iOS Release reproduction/package contract is invalid"
    /bin/sh "${signing_identity_validator}" --lint-templates >/dev/null ||
        fail "iOS production signing-identity templates are invalid"
    /bin/sh "${vendored_binary_validator}" --lint-templates >/dev/null ||
        fail "iOS vendored-binary templates are invalid"
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS migration post-archive admission contract: OK\n'
    exit 0
fi

if [ "$#" -ne 2 ] || [ "$1" != "--verify-qualified-ipa" ]; then
    fail "usage: verify-ios-migration-promotion-ipa.sh --lint-contract | --verify-qualified-ipa /absolute/completed.ipa"
fi
candidate_ipa="$2"
case "${candidate_ipa}" in
    /*) ;;
    *) fail "completed IPA path must be absolute" ;;
esac
[ "${candidate_ipa}" != "/" ] || fail "completed IPA path must not be the filesystem root"

lint_contract
: "${IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH:?owner-only sealed qualified-IPA package path is required}"
: "${IOS_MIGRATION_QUALIFICATION_RECEIPT_SIGNATURE_PATH:?protected qualification receipt signature path is required}"
qualification_receipt="${root}/Fixtures/Modernization/ios-migration-qualification.json"
signing_result="$({
    /bin/sh "${signing_identity_validator}" --verify-qualified
})" || fail "production signing-continuity receipt is not authenticated at promotion"
case "${signing_result}" in
    receiptSha256=????????????????????????????????????????????????????????????????)
        signing_receipt_sha="${signing_result#receiptSha256=}"
        ;;
    *) fail "production signing-continuity verifier returned an invalid result" ;;
esac
vendored_result="$({
    /bin/sh "${vendored_binary_validator}" --verify-qualified
})" || fail "vendored-binary receipt is not authenticated at promotion"
case "${vendored_result}" in
    receiptSha256=????????????????????????????????????????????????????????????????)
        vendored_receipt_sha="${vendored_result#receiptSha256=}"
        ;;
    *) fail "vendored-binary verifier returned an invalid result" ;;
esac
package_result="$({
    /usr/bin/python3 -B -I -S "${release_package_validator}" \
        --verify-download \
        --package "${IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH}" \
        --expected-primary-ipa "${candidate_ipa}" \
        --expected-qualification-receipt "${qualification_receipt}" \
        --expected-qualification-signature "${IOS_MIGRATION_QUALIFICATION_RECEIPT_SIGNATURE_PATH}"
})" ||
    fail "completed IPA lacks its immutable independently reproduced qualified package"
case "${package_result}" in
    candidateIpaSha256=????????????????????????????????????????????????????????????????\ qualificationReceiptSha256=????????????????????????????????????????????????????????????????\ signingReceiptSha256=????????????????????????????????????????????????????????????????\ vendoredReceiptSha256=????????????????????????????????????????????????????????????????\ packageStatus=sealed-qualified-candidate) ;;
    *) fail "qualified-IPA package verifier returned an invalid result" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${package_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "qualified-IPA package verifier returned multiple records"
package_receipt_sha="${package_result#* qualificationReceiptSha256=}"
package_receipt_sha="${package_receipt_sha%% *}"
package_candidate_sha="${package_result#candidateIpaSha256=}"
package_candidate_sha="${package_candidate_sha%% *}"
package_signing_sha="${package_result#* signingReceiptSha256=}"
package_signing_sha="${package_signing_sha%% *}"
package_vendored_sha="${package_result#* vendoredReceiptSha256=}"
package_vendored_sha="${package_vendored_sha%% *}"
[ "${package_signing_sha}" = "${signing_receipt_sha}" ] ||
    fail "sealed package signing receipt differs from authenticated promotion input"
[ "${package_vendored_sha}" = "${vendored_receipt_sha}" ] ||
    fail "sealed package vendored-binary receipt differs from authenticated promotion input"

qualification_result="$({
    /bin/sh "${validator}" --verify-qualified-ipa "${candidate_ipa}"
})" || fail "completed IPA lacks authenticated retained-device qualification"
case "${qualification_result}" in
    receiptSha256=????????????????????????????????????????????????????????????????\ ipaSha256=????????????????????????????????????????????????????????????????) ;;
    *) fail "migration qualification returned an invalid exact-IPA result" ;;
esac
[ "$({ /usr/bin/printf '%s\n' "${qualification_result}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]'; })" = "1" ] ||
    fail "migration qualification returned multiple records"
qualification_receipt_sha="${qualification_result#receiptSha256=}"
qualification_receipt_sha="${qualification_receipt_sha%% *}"
qualification_ipa_sha="${qualification_result#* ipaSha256=}"
[ "${qualification_receipt_sha}" = "${package_receipt_sha}" ] ||
    fail "authenticated qualification receipt differs from the sealed package"
[ "${qualification_ipa_sha}" = "${package_candidate_sha}" ] ||
    fail "migration-qualified IPA differs from the independently reproduced package candidate"

package_final_result="$({
    /usr/bin/python3 -B -I -S "${release_package_validator}" \
        --verify-download \
        --package "${IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH}" \
        --expected-primary-ipa "${candidate_ipa}" \
        --expected-qualification-receipt "${qualification_receipt}" \
        --expected-qualification-signature "${IOS_MIGRATION_QUALIFICATION_RECEIPT_SIGNATURE_PATH}"
})" || fail "completed IPA failed its final stable package recheck"
[ "${package_final_result}" = "${package_result}" ] ||
    fail "qualified package or candidate identity changed during promotion admission"
signing_recheck="$({
    /bin/sh "${signing_identity_validator}" --verify-qualified
})" || fail "production signing-continuity receipt failed its promotion recheck"
[ "${signing_recheck}" = "receiptSha256=${signing_receipt_sha}" ] ||
    fail "production signing-continuity receipt changed during package admission"
vendored_recheck="$({
    /bin/sh "${vendored_binary_validator}" --verify-qualified
})" || fail "vendored-binary receipt failed its promotion recheck"
[ "${vendored_recheck}" = "receiptSha256=${vendored_receipt_sha}" ] ||
    fail "vendored-binary receipt changed during package admission"

/usr/bin/printf '%s\n' "${qualification_result}"
