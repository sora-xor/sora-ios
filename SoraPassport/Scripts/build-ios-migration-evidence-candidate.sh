#!/bin/sh
set -eu

# This wrapper exposes one deliberately non-promoting Release build action. It
# exists only to compile the retained-device unit/integration bundle or UI test
# runner before migration evidence has been qualified. It cannot invoke Xcode's
# test, archive, export, or install actions.

root="$(
    CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
        /bin/pwd -P
)"
scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidence.xcscheme"
ui_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidenceUI.xcscheme"
project="${root}/SoraPassport.xcodeproj"
mode="sora-ios-migration-observed-only-build-v1"

fail() {
    /usr/bin/printf 'error: %s\n' "$1" >&2
    exit 1
}

lint_contract() {
    [ -f "${scheme}" ] && [ ! -L "${scheme}" ] ||
        fail "dedicated migration evidence scheme is missing or symbolic"
    [ -f "${ui_scheme}" ] && [ ! -L "${ui_scheme}" ] ||
        fail "dedicated migration evidence UI scheme is missing or symbolic"
    [ -f "${project}/project.pbxproj" ] && [ ! -L "${project}/project.pbxproj" ] ||
        fail "iOS project is missing or symbolic"

    /usr/bin/python3 -I -S - "${scheme}" <<'PY'
import sys
import xml.etree.ElementTree as ET


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


try:
    root = ET.parse(sys.argv[1]).getroot()
except (OSError, ET.ParseError) as error:
    fail(f"dedicated migration evidence scheme is invalid: {error}")
if root.tag != "Scheme":
    fail("dedicated migration evidence scheme root is invalid")
build_actions = root.findall("./BuildAction")
if len(build_actions) != 1:
    fail("dedicated migration evidence BuildAction is absent or ambiguous")
containers = build_actions[0].findall("./BuildActionEntries")
if len(containers) != 1:
    fail("dedicated migration evidence build entries are absent or ambiguous")
entries = containers[0].findall("./BuildActionEntry")
if len(entries) != 3 or any(entry.get("buildForArchiving") != "NO" for entry in entries):
    fail("dedicated migration evidence scheme must contain three non-archivable entries")
references = []
for entry in entries:
    children = entry.findall("./BuildableReference")
    if len(children) != 1:
        fail("dedicated migration evidence build reference is absent or ambiguous")
    references.append(children[0])
if [reference.get("BlueprintName") for reference in references] != [
    "SoraPassport",
    "SoraPassportTests",
    "SoraPassportIntegrationTests",
]:
    fail("dedicated migration evidence target inventory drifted")
test_actions = root.findall("./TestAction")
if len(test_actions) != 1 or test_actions[0].get("buildConfiguration") != "Release":
    fail("dedicated migration evidence TestAction is not exactly Release")
selected = [
    node.get("Identifier")
    for node in test_actions[0].findall("./Testables/TestableReference/SelectedTests/Test")
]
if selected != [
    "WalletModernizationTests",
    "WalletRecoveryCapabilityGateTests",
    "WalletRecoveryExporterTests",
    "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding()",
    "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence()",
    "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence()",
]:
    fail("dedicated migration evidence test inventory drifted")
archive_actions = root.findall("./ArchiveAction")
if len(archive_actions) != 1 or archive_actions[0].get("buildConfiguration") != "Release":
    fail("dedicated migration evidence ArchiveAction shape drifted")
if any(entry.get("buildForArchiving") == "YES" for entry in entries):
    fail("dedicated migration evidence scheme unexpectedly authorizes archiving")
PY

    /usr/bin/python3 -I -S - "${ui_scheme}" <<'PY'
import sys
import xml.etree.ElementTree as ET


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


try:
    root = ET.parse(sys.argv[1]).getroot()
except (OSError, ET.ParseError) as error:
    fail(f"dedicated migration evidence UI scheme is invalid: {error}")
entries = root.findall("./BuildAction/BuildActionEntries/BuildActionEntry")
if len(entries) != 2 or any(entry.get("buildForArchiving") != "NO" for entry in entries):
    fail("migration evidence UI build inventory is not exactly non-archivable")
names = []
for entry in entries:
    references = entry.findall("./BuildableReference")
    if len(references) != 1:
        fail("migration evidence UI build reference is absent or ambiguous")
    names.append(references[0].get("BlueprintName"))
if names != ["SoraPassport", "SoraPassportUITests"]:
    fail("migration evidence UI target inventory drifted")
actions = root.findall("./TestAction")
if len(actions) != 1 or actions[0].get("buildConfiguration") != "Release":
    fail("migration evidence UI TestAction is not exactly Release")
testables = actions[0].findall("./Testables/TestableReference")
if len(testables) != 1:
    fail("migration evidence UI testable inventory is ambiguous")
references = testables[0].findall("./BuildableReference")
selected = testables[0].findall("./SelectedTests/Test")
if (
    len(references) != 1
    or references[0].get("BlueprintName") != "SoraPassportUITests"
    or [item.get("Identifier") for item in selected]
    != ["RetainedMigrationEvidenceUITests/testExecuteAuthorizedRetainedMigrationCase()"]
):
    fail("migration evidence UI test selection drifted")
PY
}

if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    lint_contract
    /usr/bin/printf 'iOS migration observed-only build contract: OK\n'
    exit 0
fi

if [ "$#" -ne 5 ] ||
   [ "$2" != "--destination" ] ||
   [ "$4" != "--derived-data-path" ]; then
    fail "usage: build-ios-migration-evidence-candidate.sh --lint-contract | --build-for-testing|--build-ui-for-testing --destination platform=iOS,id=DEVICE --derived-data-path /private/path"
fi

case "$1" in
    --build-for-testing) scheme_name="SoraPassportMigrationEvidence" ;;
    --build-ui-for-testing) scheme_name="SoraPassportMigrationEvidenceUI" ;;
    *) fail "build action must be --build-for-testing or --build-ui-for-testing" ;;
esac

destination="$3"
derived_data="$5"
case "${destination}" in
    platform=iOS,id=*) ;;
    *) fail "evidence destination must identify one physical iOS device" ;;
esac
device_identifier="${destination#platform=iOS,id=}"
case "${device_identifier}" in
    ''|*[!A-Za-z0-9-]*) fail "physical iOS destination identifier is invalid" ;;
esac
[ "${#device_identifier}" -ge 8 ] && [ "${#device_identifier}" -le 128 ] ||
    fail "physical iOS destination identifier length is invalid"

case "${derived_data}" in
    /*) ;;
    *) fail "derived-data path must be absolute" ;;
esac
[ "${derived_data}" != "/" ] || fail "derived-data path must not be the filesystem root"
derived_parent="$(/usr/bin/dirname "${derived_data}")"
derived_leaf="$(/usr/bin/basename "${derived_data}")"
case "${derived_leaf}" in
    ''|.|..|*[!A-Za-z0-9._-]*) fail "derived-data leaf name is invalid" ;;
esac
[ -d "${derived_parent}" ] && [ ! -L "${derived_parent}" ] ||
    fail "derived-data parent must be an existing non-symbolic directory"
canonical_parent="$(CDPATH= cd "${derived_parent}" && /bin/pwd -P)" ||
    fail "derived-data parent cannot be resolved canonically"
[ "${canonical_parent}" != "/" ] ||
    fail "derived-data parent must not be the filesystem root"
derived_data="${canonical_parent}/${derived_leaf}"
[ "${derived_data}" != "${root}" ] || fail "derived-data path must not be the repository root"
case "${derived_data}/" in
    "${root}/"*) fail "derived-data path must be outside the repository" ;;
esac
[ ! -e "${derived_data}" ] && [ ! -L "${derived_data}" ] ||
    fail "derived-data path must not already exist"

lint_contract
umask 077
/bin/mkdir -m 700 "${derived_data}" || fail "derived-data directory cannot be created exclusively"

/usr/bin/printf '%s\n' \
    'warning: building observed-only migration evidence host; this action creates no archive or promotion authority' >&2

exec /usr/bin/xcodebuild \
    -project "${project}" \
    -scheme "${scheme_name}" \
    -configuration Release \
    -destination "${destination}" \
    -derivedDataPath "${derived_data}" \
    -allowProvisioningUpdates \
    -parallel-testing-enabled NO \
    ENABLE_TESTABILITY=YES \
    "SORA_IOS_MIGRATION_EVIDENCE_BUILD_MODE=${mode}" \
    SORA_IOS_MIGRATION_EVIDENCE_BUILD_ACTION=build-for-testing \
    build-for-testing
