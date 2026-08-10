#!/bin/sh
set -eu

# Execute every simulator-eligible application XCTest with Release optimization
# on arm64 without creating, signing, exporting, uploading, or promoting an iOS
# artifact. Four exact protected-evidence methods are excluded because they
# require a registered physical device, an installable clone of the exact IPA,
# and signed authorization. Their dedicated schemes and admission gates remain
# mandatory. The main-target build phase admits this route only through an exact
# non-promoting capability checked below and in verify-modernization-dependencies.sh.

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." && /bin/pwd -P
)"
dependency_gate="${root}/SoraPassport/Scripts/verify-modernization-dependencies.sh"
project="${root}/SoraPassport.xcodeproj"
scheme="${project}/xcshareddata/xcschemes/SoraPassport.xcscheme"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

lint_contract() {
    [ -f "${dependency_gate}" ] && [ ! -L "${dependency_gate}" ] ||
        fail "production modernization dependency gate is missing or symbolic"
    [ -d "${project}" ] && [ ! -L "${project}" ] ||
        fail "SoraPassport project is missing or symbolic"
    [ -f "${scheme}" ] && [ ! -L "${scheme}" ] ||
        fail "SoraPassport scheme is missing or symbolic"
    /usr/bin/grep -Fq \
        'sora-ios-nonpromoting-release-simulator-test-v1' \
        "${dependency_gate}" ||
        fail "dependency gate lacks the exact non-promoting Release-test capability"
    /usr/bin/grep -Fq \
        'SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION' \
        "${dependency_gate}" ||
        fail "dependency gate lacks the Release-test action binding"
    for test_bundle in \
        SoraPassportTests.xctest \
        SoraPassportIntegrationTests.xctest \
        SoraPassportUITests.xctest
    do
        /usr/bin/grep -Fq "BuildableName = \"${test_bundle}\"" "${scheme}" ||
            fail "SoraPassport scheme omits ${test_bundle}"
    done
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS non-promoting Release simulator test contract: OK\n'
    exit 0
fi

if [ "$#" -ne 7 ] ||
   [ "$1" != "--test" ] ||
   [ "$2" != "--destination" ] ||
   [ "$4" != "--derived-data-path" ] ||
   [ "$6" != "--result-bundle-path" ]; then
    fail "usage: run-ios-release-tests.sh --lint-contract | --test --destination 'platform=iOS Simulator,...,arch=arm64' --derived-data-path /absolute/new-derived-data --result-bundle-path /absolute/new.xcresult"
fi

destination="$3"
derived_data_path="$5"
result_bundle_path="$7"

case "${destination}" in
    "platform=iOS Simulator,"*) ;;
    *) fail "Release tests require an iOS Simulator destination" ;;
esac
case "${destination}" in
    *,arch=arm64|*,arch=arm64,*) ;;
    *) fail "Release tests require the active arm64 simulator architecture" ;;
esac
destination_without_line_breaks="$(
    /usr/bin/printf '%s' "${destination}" | /usr/bin/tr -d '\r\n'
)"
[ "${destination}" = "${destination_without_line_breaks}" ] ||
    fail "Release-test destination contains a line break"

validate_new_output() {
    output_path="$1"
    output_label="$2"
    case "${output_path}" in
        /*) ;;
        *) fail "${output_label} must be absolute" ;;
    esac
    output_without_line_breaks="$(
        /usr/bin/printf '%s' "${output_path}" | /usr/bin/tr -d '\r\n'
    )"
    [ "${output_path}" = "${output_without_line_breaks}" ] ||
        fail "${output_label} contains a line break"
    [ "${output_path}" != "/" ] || fail "${output_label} must not be the filesystem root"
    [ ! -e "${output_path}" ] && [ ! -L "${output_path}" ] ||
        fail "${output_label} must be a fresh path"
    output_parent="$(/usr/bin/dirname "${output_path}")"
    output_name="$(/usr/bin/basename "${output_path}")"
    [ -d "${output_parent}" ] && [ ! -L "${output_parent}" ] ||
        fail "${output_label} parent must be an existing non-symbolic directory"
    output_parent_canonical="$(CDPATH= cd "${output_parent}" && /bin/pwd -P)" ||
        fail "${output_label} parent could not be resolved"
    [ "${output_parent}" = "${output_parent_canonical}" ] ||
        fail "${output_label} parent must already be canonical"
    [ "${output_name}" != "." ] && [ "${output_name}" != ".." ] ||
        fail "${output_label} leaf is invalid"
    [ "$(/usr/bin/stat -f '%u' "${output_parent_canonical}")" = "$(/usr/bin/id -u)" ] ||
        fail "${output_label} parent must be owned by the current user"
    [ "$(/usr/bin/stat -f '%Lp' "${output_parent_canonical}")" = "700" ] ||
        fail "${output_label} parent must have mode 0700"
    case "${output_parent_canonical}/${output_name}" in
        "${root}"|"${root}"/*)
            fail "${output_label} must stay outside the repository"
            ;;
    esac
    /usr/bin/printf '%s/%s\n' "${output_parent_canonical}" "${output_name}"
}

derived_data_path="$(validate_new_output "${derived_data_path}" "derived-data path")"
result_bundle_path="$(validate_new_output "${result_bundle_path}" "result-bundle path")"
[ "${derived_data_path}" != "${result_bundle_path}" ] ||
    fail "derived-data and result-bundle paths must be distinct"
case "${result_bundle_path}" in
    *.xcresult) ;;
    *) fail "result-bundle path must end in .xcresult" ;;
esac

lint_contract
[ -x /usr/bin/xcodebuild ] || fail "xcodebuild is unavailable"

exec /usr/bin/xcodebuild \
    test \
    -project "${project}" \
    -scheme SoraPassport \
    -configuration Release \
    -destination "${destination}" \
    -derivedDataPath "${derived_data_path}" \
    -resultBundlePath "${result_bundle_path}" \
    -skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding \
    -skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence \
    -skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence \
    -skip-testing:SoraPassportUITests/RetainedMigrationEvidenceUITests/testExecuteAuthorizedRetainedMigrationCase \
    SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE=sora-ios-nonpromoting-release-simulator-test-v1 \
    SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION=test \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    ENABLE_TESTABILITY=YES \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    EXCLUDED_ARCHS=x86_64
