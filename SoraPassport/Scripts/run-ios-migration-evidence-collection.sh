#!/bin/sh
set -eu

umask 077

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"
collector="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.sh"
collector_tests="${root}/SoraPassport/Scripts/test-ios-migration-evidence-collector.py"
derivation_tests="${root}/SoraPassport/Scripts/test-ios-migration-test-host-derivation.py"
contract_tool="${root}/SoraPassport/Scripts/ios-migration-qualification-contract.py"

usage() {
    echo "usage: $0 --raw-input-root ABSOLUTE_PATH --output-root ABSOLUTE_PATH" >&2
    exit 64
}

raw_input_root=""
output_root=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --raw-input-root)
            [ "$#" -ge 2 ] || usage
            raw_input_root="$2"
            shift 2
            ;;
        --output-root)
            [ "$#" -ge 2 ] || usage
            output_root="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

case "${raw_input_root}" in
    /*) ;;
    *) usage ;;
esac
case "${output_root}" in
    /*) ;;
    *) usage ;;
esac
[ "${raw_input_root}" != "/" ] || usage
[ "${output_root}" != "/" ] || usage
[ "${raw_input_root}" != "${output_root}" ] || usage

# This lane is deliberately incapable of promotion. Qualification credentials,
# receipt signatures, append-only sequence authority, rollout/canary authority,
# and mutation controls must not be present in its environment.
for forbidden_name in \
    IOS_MIGRATION_QUALIFICATION_SEQUENCE_NUMBER \
    IOS_MIGRATION_QUALIFICATION_DEVICE_EVIDENCE_PRODUCER_PRIVATE_KEY \
    IOS_MIGRATION_QUALIFICATION_INDEPENDENT_REVIEWER_PRIVATE_KEY \
    IOS_MIGRATION_QUALIFICATION_RECEIPT_REVIEWER_SIGNATURE_PATH \
    IOS_MIGRATION_QUALIFICATION_EVIDENCE_DEVICE_SIGNATURE_PATH \
    IOS_MIGRATION_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH \
    IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PRIVATE_KEY \
    IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PRIVATE_KEY \
    IOS_PRODUCTION_ROLLOUT_CONTROLLER_PRIVATE_KEY \
    IOS_FUNDED_CANARY_APPROVAL_PRIVATE_KEY \
    IOS_PRODUCTION_MUTATIONS_ENABLED
do
    eval "forbidden_value=\${${forbidden_name}:-}"
    if [ -n "${forbidden_value}" ]; then
        echo "error: non-promoting migration collection received forbidden authority: ${forbidden_name}" >&2
        exit 1
    fi
done

for required_file in "${collector}" "${collector_tests}" "${derivation_tests}" "${contract_tool}"
do
    if [ ! -f "${required_file}" ] || [ -L "${required_file}" ]; then
        echo "error: migration evidence collection source is absent or symbolic" >&2
        exit 1
    fi
done

/bin/sh "${collector}" --lint-contract >/dev/null
/usr/bin/python3 -I -S "${collector_tests}"
/usr/bin/python3 -I -S "${derivation_tests}"
/usr/bin/python3 -I -S "${contract_tool}" \
    --repository-root "${root}" \
    --print-sha >/dev/null

exec /bin/sh "${collector}" \
    --collect \
    --input-root "${raw_input_root}" \
    --output-root "${output_root}"
