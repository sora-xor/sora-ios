#!/bin/sh
set -eu

if [ -n "${PROJECT_DIR:-}" ]; then
    root="${PROJECT_DIR}"
else
    root="$(
        CDPATH= cd "$(/usr/bin/dirname "$0")/../.." &&
            /bin/pwd -P
    )"
fi
root="$(
    CDPATH= cd "${root}" && /bin/pwd -P
)" || {
    echo "error: iOS project root could not be resolved canonically" >&2
    exit 1
}

# The iOS build gate. It is the first build phase of both app targets, and
# scripts/archive-app-store.sh runs it in lint mode
# (--lint-ios-migration-release-source-gate) for every App Store archive.
#
# It checks, in seconds:
# - source lints that guard wallet safety and build order: the Google Sign-In
#   Info.plist phase order, ReachabilityManager listener locking, the retained
#   15/18/21-word phrase policy, the scope of the startup-lease regressions, a
#   Swift parse of the pinned sources, and the migration test inventory
#   (WalletModernizationTests 237, WalletRecoveryCapabilityGateTests 11,
#   WalletRecoveryExporterTests 12 test methods);
# - reviewed dependencies: exact requirements in the vendored manifests,
#   Package.resolved by SHA-256 and pin count (ModernizationDependencies.conf),
#   the Xcode package references, and no prebuilt or closed-source binary in
#   the tree (scan-repository-binaries.py);
# - in a Release build, the resolved main-target identity. A Release build
#   outside the archive script then stops: App Store archives go through
#   scripts/archive-app-store.sh, and production signing stays blocked here.
#
# The retained-device qualification, exact-IPA evidence, production-promotion,
# funded-canary and rollout framework that used to follow these checks never
# produced a shipped build and was removed on 2026-11-18 (see git history).

manifest="${root}/SoraPassport/Configs/ModernizationDependencies.conf"
project="${root}/SoraPassport.xcodeproj/project.pbxproj"
production_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassport.xcscheme"
unit_test_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportTests.xcscheme"
release_xcconfig="${root}/SoraPassport/Configs/SoraPassport.release.xcconfig"
production_info_plist="${root}/SoraPassport/Info.plist"
shared_features_manifest="${root}/VendorPackages/shared-features-spm/Package.swift"
rswift_manifest="${root}/VendorPackages/Rswift/Package.swift"
google_signin_manifest="${root}/VendorPackages/GoogleSignIn-iOS/Package.swift"
google_api_manifest="${root}/VendorPackages/google-api-objectivec-client-for-rest/Package.swift"
jose_manifest="${root}/VendorPackages/JOSESwift/Package.swift"
swiftpm_resolution="${root}/SoraPassport.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
rswift_resolution="${root}/VendorPackages/Rswift/Package.resolved"
binary_scanner="${root}/SoraPassport/Scripts/scan-repository-binaries.py"
release_test_runner="${root}/SoraPassport/Scripts/run-ios-release-tests.sh"
wallet_network_model="${root}/SoraPassport/Common/Model/WalletNetworkModel.swift"
root_interactor="${root}/SoraPassport/ModulesRedesign/Root/RootInteractor.swift"
modernization_tests="${root}/SoraPassportTests/Common/Modernization/WalletModernizationTests.swift"
recovery_gate_tests="${root}/SoraPassportTests/Common/Modernization/WalletRecoveryCapabilityGateTests.swift"
recovery_export_tests="${root}/SoraPassportTests/Common/Modernization/WalletRecoveryExporterTests.swift"
account_creation_helper="${root}/SoraPassportTests/Helpers/AccountCreationHelper.swift"
jsonrpc_tests="${root}/SoraPassportIntegrationTests/Substrate/JSONRPCTests.swift"
websocket_engine="${root}/VendorPackages/shared-features-spm/Sources/SSFUtils/SSFUtils/Classes/Network/WebSocketEngine.swift"
reachability_manager="${root}/VendorPackages/shared-features-spm/Sources/SSFUtils/SSFUtils/Classes/Network/Reachability/ReachabilityManager.swift"

verify_google_signin_info_plist_phase_dependencies() {
    ios_google_signin_project="$1"
    if [ ! -f "${ios_google_signin_project}" ] || [ -L "${ios_google_signin_project}" ]; then
        echo "error: Google Sign-In phase Xcode project is absent, non-regular, or symbolic" >&2
        return 1
    fi
    /usr/bin/python3 -I -S - "${ios_google_signin_project}" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path


def fail(message):
    raise SystemExit(f"error: {message}")


project_path = Path(sys.argv[1])
converted = subprocess.run(
    ["/usr/bin/plutil", "-convert", "json", "-o", "-", str(project_path)],
    check=False,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if converted.returncode != 0:
    diagnostic = converted.stderr.decode("utf-8", errors="replace").strip()
    fail(f"Google Sign-In phase Xcode project cannot be parsed: {diagnostic or 'plutil failed'}")
try:
    document = json.loads(converted.stdout.decode("utf-8"))
except (UnicodeError, json.JSONDecodeError) as error:
    fail(f"Google Sign-In phase Xcode project JSON is invalid: {error}")
objects = document.get("objects")
if not isinstance(objects, dict):
    fail("Google Sign-In phase Xcode project objects are malformed")


def require_object(object_id, label):
    if not isinstance(object_id, str) or re.fullmatch(r"[0-9A-F]{24}", object_id) is None:
        fail(f"{label} is not a canonical Xcode object identifier")
    value = objects.get(object_id)
    if not isinstance(value, dict):
        fail(f"{label} does not resolve to an Xcode object")
    return value


root = require_object(document.get("rootObject"), "PBXProject rootObject")
target_ids = root.get("targets")
if not isinstance(target_ids, list) or len(target_ids) != len(set(target_ids)):
    fail("PBXProject target list is absent, malformed, or duplicated")

expected_target_names = {"SoraPassport", "SoraPassportDev"}
expected_input_paths = ["$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)"]
# set -e makes a failure of the script fail the phase (60ebe419). The
# IrohaConnect URL types are in Info.plist for every configuration.
expected_script = (
    'set -e\n'
    '/bin/sh "$PROJECT_DIR/SoraPassport/Scripts/inject-google-signin-info-plist.sh"\n'
)
observed = {}
for target_id in target_ids:
    target = require_object(target_id, "PBXProject target")
    target_name = target.get("name")
    if target_name not in expected_target_names:
        continue
    if (
        target.get("isa") != "PBXNativeTarget"
        or target.get("productType") != "com.apple.product-type.application"
        or target_name in observed
    ):
        fail(f"{target_name} Google Sign-In phase target identity drifted")
    phase_ids = target.get("buildPhases")
    if not isinstance(phase_ids, list) or len(phase_ids) != len(set(phase_ids)):
        fail(f"{target_name} build phase list is absent, malformed, or duplicated")
    matches = []
    for phase_id in phase_ids:
        phase = require_object(phase_id, f"{target_name} build phase")
        if phase.get("name") == "Inject Google Sign-In Info.plist":
            matches.append((phase_id, phase))
    if len(matches) != 1:
        fail(f"{target_name} must contain exactly one Google Sign-In Info.plist phase")
    phase_id, phase = matches[0]
    if (
        phase.get("isa") != "PBXShellScriptBuildPhase"
        or phase.get("shellPath") != "/bin/sh"
        or phase.get("shellScript") != expected_script
        or phase.get("inputPaths") != expected_input_paths
        or phase.get("inputFileListPaths") != []
        or str(phase.get("buildActionMask")) != "2147483647"
        or str(phase.get("runOnlyForDeploymentPostprocessing")) != "0"
    ):
        fail(
            f"{target_name} Google Sign-In phase must declare the exact processed "
            "Info.plist input dependency"
        )
    observed[target_name] = phase_id

if set(observed) != expected_target_names:
    fail("canonical Google Sign-In application targets are absent or ambiguous")
named_phase_ids = {
    object_id
    for object_id, value in objects.items()
    if isinstance(value, dict)
    and value.get("isa") == "PBXShellScriptBuildPhase"
    and value.get("name") == "Inject Google Sign-In Info.plist"
}
if named_phase_ids != set(observed.values()):
    fail("Google Sign-In Info.plist phases are detached, duplicated, or unexpected")
PY
}

verify_reachability_listener_synchronization() {
    ios_reachability_manager="$1"
    if [ ! -f "${ios_reachability_manager}" ] || [ -L "${ios_reachability_manager}" ]; then
        echo "error: synchronized ReachabilityManager source is absent, non-regular, or symbolic" >&2
        return 1
    fi
    /usr/bin/python3 -I -S - "${ios_reachability_manager}" <<'PY'
import re
import sys
from pathlib import Path


def fail(message):
    raise SystemExit(f"error: {message}")


source = Path(sys.argv[1]).read_text(encoding="utf-8")


def function_range(signature):
    start = source.find(signature)
    if start < 0 or source.find(signature, start + 1) >= 0:
        fail(f"ReachabilityManager must contain exactly one {signature.strip()}")
    opening = source.find("{", start + len(signature))
    if opening < 0:
        fail(f"ReachabilityManager {signature.strip()} has no body")
    depth = 0
    for offset in range(opening, len(source)):
        character = source[offset]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return start, offset + 1
    fail(f"ReachabilityManager {signature.strip()} body is unbalanced")


locked_signatures = (
    "    private func addListenerIfNeeded(",
    "    private func removeListener(",
    "    private func hasLiveListeners()",
    "    private func liveListenersSnapshot()",
)
locked_ranges = [function_range(signature) for signature in locked_signatures]
lock_helper_range = function_range("    private func withListenersLock<T>(")
notify_range = function_range("    func notifyListeners()")
add_range = function_range("    public func add(listener:")
remove_range = function_range("    public func remove(listener:")

if source.count("    private var listeners: [ReachabilityListenerWrapper] = []") != 1:
    fail("ReachabilityManager weak listener storage identity drifted")
if source.count("    private let listenersLock = NSLock()") != 1:
    fail("ReachabilityManager listener lock is absent or ambiguous")
if source.count("    private let notifierLock = NSLock()") != 1:
    fail("ReachabilityManager notifier lifecycle lock is absent or ambiguous")
if source.count("    init?() {") != 1:
    fail("ReachabilityManager isolated internal test initializer is absent or ambiguous")

lock_helper = source[slice(*lock_helper_range)]
if (
    "listenersLock.lock()" not in lock_helper
    or "defer { listenersLock.unlock() }" not in lock_helper
    or lock_helper.index("listenersLock.lock()")
    > lock_helper.index("defer { listenersLock.unlock() }")
    or lock_helper.index("defer { listenersLock.unlock() }")
    > lock_helper.index("return try body()")
):
    fail("ReachabilityManager listener lock helper is not fail-closed")

for start, end in locked_ranges:
    body = source[start:end]
    if "withListenersLock {" not in body:
        fail("ReachabilityManager weak listener access escaped the listener lock")

declaration_offset = source.index(
    "    private var listeners: [ReachabilityListenerWrapper] = []"
)
for match in re.finditer(r"\blisteners\b", source):
    offset = match.start()
    if offset == declaration_offset + len("    private var "):
        continue
    if not any(start <= offset < end for start, end in locked_ranges):
        fail("ReachabilityManager contains weak listener storage access outside locked helpers")

snapshot = source[slice(*locked_ranges[-1])]
if (
    "listeners = listeners.filter { $0.listener != nil }" not in snapshot
    or "return listeners.compactMap { $0.listener }" not in snapshot
    or snapshot.index("listeners = listeners.filter { $0.listener != nil }")
    > snapshot.index("return listeners.compactMap { $0.listener }")
):
    fail("ReachabilityManager does not prune and strongly snapshot live listeners under lock")

notify = source[slice(*notify_range)]
if (
    "let liveListeners = liveListenersSnapshot()" not in notify
    or "liveListeners.forEach { $0.didChangeReachability(by: self) }" not in notify
    or notify.index("let liveListeners = liveListenersSnapshot()")
    > notify.index("liveListeners.forEach { $0.didChangeReachability(by: self) }")
    or "withListenersLock" in notify
    or "listenersLock" in notify
):
    fail("ReachabilityManager callbacks are not delivered from an unlocked strong snapshot")

if source.count("self?.notifyListeners()") != 2:
    fail("ReachabilityManager reachability callbacks bypass synchronized delivery")
for operation_range in (add_range, remove_range):
    operation = source[slice(*operation_range)]
    if (
        "notifierLock.lock()" not in operation
        or "defer { notifierLock.unlock() }" not in operation
    ):
        fail("ReachabilityManager notifier lifecycle is not serialized")
PY
}

verify_ios_migration_shared_lifecycle_test_scope() {
    # These five regressions intentionally exercise the production startup lease.
    # Other modernization fixtures must continue using isolated coordinators.
    /usr/bin/python3 -B -I -S - "$1" <<'PY'
from pathlib import Path
import re
import sys

expected = {
    "testGenericStartupRecoveryResumesTransientPreflightWriteFailure":
        "let competing = WalletLifecycleCoordinator.shared.tryAcquire()",
    "testGenericStartupRecoveryResumesCanonicalDatabaseJournals":
        "let competing = WalletLifecycleCoordinator.shared.tryAcquire()",
    "testGenericStartupRecoveryResumesCanonicalLegacyAccountJournals":
        "let competing = WalletLifecycleCoordinator.shared.tryAcquire()",
    "testGenericStartupJournalRecoveryPreservesConflictingEvidenceAndMarkerCAS":
        "let outerLease = WalletLifecycleCoordinator.shared.acquire()",
    "testGenericStartupRecoveryReprovesFailedDatabaseAttemptAndRetainsFailure":
        "let lease = WalletLifecycleCoordinator.shared.acquire()",
}
observed = {}
method = None
for line in Path(sys.argv[1]).read_text().splitlines():
    declaration = re.match(r"^    (?:private )?func (\w+)\(", line)
    if declaration:
        method = declaration.group(1)
    if "WalletLifecycleCoordinator.shared" in line:
        if method not in expected or method in observed or line.strip() != expected[method]:
            raise SystemExit("error: production lifecycle use escaped the five startup recovery regressions")
        observed[method] = line.strip()
if observed != expected:
    raise SystemExit("error: startup recovery production lifecycle regression coverage changed")
PY
}

verify_ios_retained_mnemonic_policy() {
    ios_policy_model="$1"
    ios_policy_root="$2"
    if [ ! -f "${ios_policy_model}" ] || [ -L "${ios_policy_model}" ] ||
       [ ! -f "${ios_policy_root}" ] || [ -L "${ios_policy_root}" ]; then
        echo "error: retained mnemonic policy sources are absent or symbolic" >&2
        return 1
    fi
    /usr/bin/python3 -I -S - "${ios_policy_model}" "${ios_policy_root}" <<'PY'
import re
import sys
from pathlib import Path


model = Path(sys.argv[1]).read_text(encoding="utf-8")
root = Path(sys.argv[2]).read_text(encoding="utf-8")


def require(condition: bool, detail: str) -> None:
    if not condition:
        raise SystemExit(f"error: retained 15/18/21-word SORA2-only policy drifted: {detail}")


require(model.count("var supportsNexusDerivation: Bool") == 1, "source classification")
require(
    re.search(
        r"var\s+supportsNexusDerivation:\s*Bool\s*\{\s*self\s*==\s*\.mnemonicEntropy\s*\}",
        model,
    ) is not None,
    "legacy mnemonic source may derive Nexus children",
)
require(
    re.search(
        r"guard\s+WalletMnemonicWordPolicy\.isUserImportWordCount\(words\.count\)\s+else",
        model,
    ) is not None,
    "Nexus derivation accepts retained-only word counts",
)
require("allowingTairaBackfill" not in model, "legacy recovery permits child backfill")
require("isHistoricalLegacyMnemonic" not in model, "legacy snapshot topology permits children")
require(root.count("let expectedNetworks: Set<NetworkId>") == 1, "activation topology")
require(
    re.search(
        r"let\s+expectedNetworks:\s*Set<NetworkId>\s*=\s*"
        r"expectedSource\s*==\s*\.legacyMnemonicEntropy\s*"
        r"\?\s*\[\s*\.sora2\s*\]\s*:\s*"
        r"NexusNetworkConfiguration\.admittedWalletNetworkIds",
        root,
    ) is not None,
    "legacy activation requires Nexus children",
)
PY
}


json_raw() {
    /usr/bin/plutil -extract "$1" raw "$2" 2>/dev/null || /usr/bin/true
}

json_array_equals() {
    json_array_path="$1"
    json_array_file="$2"
    shift 2
    [ "$(json_raw "${json_array_path}" "${json_array_file}")" = "$#" ] ||
        return 1
    json_array_index=0
    for json_array_expected in "$@"; do
        [ "$(json_raw "${json_array_path}.${json_array_index}" "${json_array_file}")" = "${json_array_expected}" ] ||
            return 1
        json_array_index=$((json_array_index + 1))
    done
}

is_lower_hex_length() {
    value="$1"
    expected_length="$2"

    [ "${#value}" -eq "${expected_length}" ] || return 1
    case "${value}" in
        *[!0-9a-f]*)
            return 1
            ;;
    esac

    return 0
}

require_reviewed_sha256() {
    label="$1"
    value="$2"

    if ! is_lower_hex_length "${value}" 64; then
        echo "error: ${label} is not a reviewed SHA-256 identity"
        exit 1
    fi
}

require_reviewed_sha1() {
    label="$1"
    value="$2"

    if ! is_lower_hex_length "${value}" 40; then
        echo "error: ${label} is not a reviewed SHA-1 identity"
        exit 1
    fi
}


sha256_file() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}


verify_main_release_source_identity() {
    /usr/bin/python3 -I -S - \
        "${project}" \
        "${production_scheme}" \
        "${release_xcconfig}" \
        "${production_info_plist}" <<'PY'
import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def fail(message):
    raise SystemExit(f"error: {message}")


def require_dictionary(value, label):
    if not isinstance(value, dict):
        fail(f"{label} is not a dictionary")
    return value


def require_string(mapping, key, label):
    value = mapping.get(key)
    if not isinstance(value, str):
        fail(f"{label} {key} is absent or malformed")
    return value


def require_object_id(value, label):
    if not isinstance(value, str) or re.fullmatch(r"[0-9A-F]{24}", value) is None:
        fail(f"{label} is not a canonical Xcode object identifier")
    return value


def require_id_list(mapping, key, label, *, allow_empty=False):
    values = mapping.get(key)
    if not isinstance(values, list) or (not allow_empty and not values):
        fail(f"{label} {key} is absent or malformed")
    identifiers = [require_object_id(value, f"{label} {key}") for value in values]
    if len(set(identifiers)) != len(identifiers):
        fail(f"{label} {key} contains duplicate object identifiers")
    return identifiers


try:
    project_path, scheme_path, xcconfig_path, info_path = map(Path, sys.argv[1:])
except ValueError:
    fail("source identity verifier arguments are incomplete")

for path, label in (
    (project_path, "Xcode project"),
    (scheme_path, "shared production scheme"),
    (xcconfig_path, "Release xcconfig"),
    (info_path, "production Info.plist"),
):
    if not path.is_file() or path.is_symlink():
        fail(f"{label} is absent, non-regular, or symbolic")

try:
    converted = subprocess.run(
        ["/usr/bin/plutil", "-convert", "json", "-o", "-", str(project_path)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
except OSError as error:
    fail(f"Xcode project parser could not be launched: {error}")
if converted.returncode != 0:
    diagnostic = converted.stderr.decode("utf-8", errors="replace").strip()
    fail(f"Xcode project cannot be converted strictly: {diagnostic or 'plutil failed'}")
try:
    project_document = require_dictionary(
        json.loads(converted.stdout.decode("utf-8")), "Xcode project"
    )
except (UnicodeError, json.JSONDecodeError) as error:
    fail(f"Xcode project JSON conversion is invalid: {error}")
objects = require_dictionary(project_document.get("objects"), "Xcode project objects")


def resolve_object(object_id, label):
    object_id = require_object_id(object_id, label)
    if object_id not in objects:
        fail(f"{label} does not resolve to an Xcode project object")
    return require_dictionary(objects[object_id], label)


project_id = require_object_id(project_document.get("rootObject"), "Xcode rootObject")
project = resolve_object(project_id, "PBXProject rootObject")
if require_string(project, "isa", "PBXProject rootObject") != "PBXProject":
    fail("Xcode rootObject is not a PBXProject")
main_group_id = require_object_id(project.get("mainGroup"), "PBXProject mainGroup")
main_group = resolve_object(main_group_id, "PBXProject mainGroup")
if require_string(main_group, "isa", "PBXProject mainGroup") != "PBXGroup":
    fail("PBXProject mainGroup is not a PBXGroup")
if require_string(main_group, "sourceTree", "PBXProject mainGroup") != "<group>":
    fail("PBXProject mainGroup source tree drifted")
if main_group.get("path") not in (None, ""):
    fail("PBXProject mainGroup unexpectedly changes the repository-relative path")

target_ids = require_id_list(project, "targets", "PBXProject")
native_targets = []
for candidate_id in target_ids:
    candidate = resolve_object(candidate_id, "PBXProject target")
    if require_string(candidate, "isa", "PBXProject target") != "PBXNativeTarget":
        fail("PBXProject target list contains a non-native target")
    if (
        candidate.get("name") == "SoraPassport"
        and candidate.get("productName") == "SoraPassport"
        and candidate.get("productType") == "com.apple.product-type.application"
    ):
        native_targets.append((candidate_id, candidate))
if len(native_targets) != 1:
    fail("main SoraPassport application target is absent or ambiguous")
target_id, target = native_targets[0]

product_reference_id = require_object_id(
    target.get("productReference"), "main target productReference"
)
product_reference = resolve_object(product_reference_id, "main target productReference")
if (
    require_string(product_reference, "isa", "main target productReference")
    != "PBXFileReference"
    or product_reference.get("explicitFileType") != "wrapper.application"
    or product_reference.get("path") != "SoraPassport.app"
    or product_reference.get("sourceTree") != "BUILT_PRODUCTS_DIR"
):
    fail("main target product reference is not the production SoraPassport.app")

configuration_list_id = require_object_id(
    target.get("buildConfigurationList"), "main target buildConfigurationList"
)
configuration_list = resolve_object(
    configuration_list_id, "main target XCConfigurationList"
)
if require_string(
    configuration_list, "isa", "main target XCConfigurationList"
) != "XCConfigurationList":
    fail("main target configuration-list reference has the wrong object type")
if configuration_list.get("defaultConfigurationName") != "Release":
    fail("main target default configuration is not Release")
configuration_ids = require_id_list(
    configuration_list,
    "buildConfigurations",
    "main target XCConfigurationList",
)
configurations = []
configuration_names = []
for configuration_id in configuration_ids:
    configuration = resolve_object(
        configuration_id, "main target XCBuildConfiguration"
    )
    if require_string(
        configuration, "isa", "main target XCBuildConfiguration"
    ) != "XCBuildConfiguration":
        fail("main target configuration list contains the wrong object type")
    configuration_name = require_string(
        configuration, "name", "main target XCBuildConfiguration"
    )
    configuration_names.append(configuration_name)
    configurations.append((configuration_id, configuration))
if len(set(configuration_names)) != len(configuration_names):
    fail("main target configuration names are ambiguous")
release_configurations = [
    (configuration_id, configuration)
    for configuration_id, configuration in configurations
    if configuration.get("name") == "Release"
]
if len(release_configurations) != 1:
    fail("main target Release configuration mapping is absent or ambiguous")
_, release_configuration = release_configurations[0]

base_configuration_id = require_object_id(
    release_configuration.get("baseConfigurationReference"),
    "main target Release baseConfigurationReference",
)
base_configuration = resolve_object(
    base_configuration_id, "Release xcconfig PBXFileReference"
)
if (
    require_string(base_configuration, "isa", "Release xcconfig reference")
    != "PBXFileReference"
    or base_configuration.get("path") != "SoraPassport.release.xcconfig"
    or base_configuration.get("sourceTree") != "<group>"
):
    fail("main target Release xcconfig reference drifted")


def group_children(group_id, label):
    group = resolve_object(group_id, label)
    if require_string(group, "isa", label) != "PBXGroup":
        fail(f"{label} is not a PBXGroup")
    return require_id_list(group, "children", label, allow_empty=True)


base_configuration_paths = []


def walk_group(group_id, path, active):
    if group_id in active:
        fail("PBXGroup hierarchy contains a cycle")
    next_active = set(active)
    next_active.add(group_id)
    for child_id in group_children(group_id, "reachable PBXGroup"):
        if child_id == base_configuration_id:
            base_configuration_paths.append(list(path))
        child = resolve_object(child_id, "PBXGroup child")
        if child.get("isa") == "PBXGroup":
            walk_group(child_id, path + [child_id], next_active)


walk_group(main_group_id, [main_group_id], set())
if len(base_configuration_paths) != 1:
    fail("Release xcconfig is not uniquely reachable from PBXProject.mainGroup")
group_path = base_configuration_paths[0]
if len(group_path) != 3:
    fail("Release xcconfig group depth drifted")
source_group = resolve_object(group_path[1], "SoraPassport source group")
config_group = resolve_object(group_path[2], "Release xcconfig parent group")
if (
    source_group.get("isa") != "PBXGroup"
    or source_group.get("path") != "SoraPassport"
    or source_group.get("sourceTree") != "<group>"
):
    fail("Release xcconfig is not under the canonical SoraPassport source group")
if (
    config_group.get("isa") != "PBXGroup"
    or config_group.get("path") != "Configs"
    or config_group.get("sourceTree") != "<group>"
):
    fail("Release xcconfig parent group is not the canonical Configs group")

repository_root = project_path.parent.parent
expected_paths = {
    project_path: Path("SoraPassport.xcodeproj", "project.pbxproj"),
    scheme_path: Path(
        "SoraPassport.xcodeproj", "xcshareddata", "xcschemes", "SoraPassport.xcscheme"
    ),
    xcconfig_path: Path("SoraPassport", "Configs", "SoraPassport.release.xcconfig"),
    info_path: Path("SoraPassport", "Info.plist"),
}
for candidate_path, expected_relative_path in expected_paths.items():
    try:
        observed_relative_path = candidate_path.relative_to(repository_root)
    except ValueError:
        fail(f"{candidate_path.name} is outside the canonical iOS repository root")
    if observed_relative_path != expected_relative_path:
        fail(f"{candidate_path.name} canonical repository path drifted")

build_settings = require_dictionary(
    release_configuration.get("buildSettings"),
    "main target Release build settings",
)
expected_settings = {
    "CODE_SIGN_ENTITLEMENTS": "SoraPassport/SoraPassport.entitlements",
    "CODE_SIGN_IDENTITY": "iPhone Developer",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "YLWWUD25VZ",
    "INFOPLIST_FILE": "SoraPassport/Info.plist",
    "PRODUCT_BUNDLE_IDENTIFIER": "co.jp.soramitsu.sora",
    "PRODUCT_NAME": "$(TARGET_NAME)",
}
for key, expected in expected_settings.items():
    matching_keys = [
        configured_key
        for configured_key in build_settings
        if configured_key == key or configured_key.startswith(f"{key}[")
    ]
    if matching_keys != [key] or build_settings.get(key) != expected:
        fail(f"main target Release {key} drifted")

build_phase_ids = require_id_list(target, "buildPhases", "main SoraPassport target")
verifier_name = "Verify production modernization dependencies"
verifier_script = (
    '/bin/sh "${PROJECT_DIR}/SoraPassport/Scripts/'
    'verify-modernization-dependencies.sh"\n'
)
verifier_needle = "verify-modernization-dependencies.sh"
verifier_phases = []
for phase_id in build_phase_ids:
    phase = resolve_object(phase_id, "main target build phase")
    shell_script = phase.get("shellScript")
    if isinstance(shell_script, str) and verifier_needle in shell_script:
        verifier_phases.append(phase)
if len(verifier_phases) != 1:
    fail("main target verifier build phase is absent or duplicated")
verifier_phase = verifier_phases[0]
if (
    verifier_phase.get("isa") != "PBXShellScriptBuildPhase"
    or verifier_phase.get("name") != verifier_name
    or verifier_phase.get("shellPath") != "/bin/sh"
    or verifier_phase.get("shellScript") != verifier_script
    # plutil's OpenStep-project conversion represents scalar build settings as
    # strings, including unquoted numeric PBX fields. Match the exact semantic
    # value instead of imposing a JSON type that the authoritative parser never
    # emits for this project format.
    or str(verifier_phase.get("buildActionMask")) != "2147483647"
    or str(verifier_phase.get("alwaysOutOfDate")) != "1"
    or str(verifier_phase.get("runOnlyForDeploymentPostprocessing")) != "0"
):
    fail("main target verifier build phase is not the exact always-on production gate")

try:
    xcconfig_source = xcconfig_path.read_text(encoding="utf-8")
except (OSError, UnicodeError) as error:
    fail(f"Release xcconfig cannot be read strictly: {error}")
xcconfig_assignments = {}
for line_number, line in enumerate(xcconfig_source.splitlines(), start=1):
    stripped = line.strip()
    if not stripped or stripped.startswith("//"):
        continue
    if stripped.startswith("#"):
        fail(f"Release xcconfig line {line_number} contains a forbidden directive")
    match = re.fullmatch(
        r"[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*(.*?)[ \t]*",
        line,
    )
    if match is None:
        fail(f"Release xcconfig line {line_number} is not a flat assignment")
    key, value = match.groups()
    if key in xcconfig_assignments:
        fail(f"Release xcconfig key {key} is duplicated")
    xcconfig_assignments[key] = value
if xcconfig_assignments.get("SORA_APPLICATION_CONFIG") != "Release":
    fail("Release xcconfig application configuration drifted")
if xcconfig_assignments.get("SORA_NAME") != "SORA":
    fail("Release display name is not exactly SORA")

try:
    with info_path.open("rb") as info_file:
        info = require_dictionary(plistlib.load(info_file), "production Info.plist")
except (OSError, plistlib.InvalidFileException) as error:
    fail(f"production Info.plist cannot be parsed strictly: {error}")
if info.get("CFBundleDisplayName") != "${SORA_NAME}":
    fail("CFBundleDisplayName is not bound to SORA_NAME")
if info.get("CFBundleIdentifier") != "$(PRODUCT_BUNDLE_IDENTIFIER)":
    fail("CFBundleIdentifier is not bound to PRODUCT_BUNDLE_IDENTIFIER")
if info.get("CFBundleName") != "$(PRODUCT_NAME)":
    fail("CFBundleName is not bound to PRODUCT_NAME")

try:
    scheme = ET.parse(scheme_path).getroot()
except (OSError, ET.ParseError) as error:
    fail(f"shared production scheme cannot be parsed strictly: {error}")
if scheme.tag != "Scheme":
    fail("shared production scheme root is not Scheme")
build_actions = scheme.findall("./BuildAction")
if len(build_actions) != 1:
    fail("shared production scheme BuildAction is absent or ambiguous")
entry_containers = build_actions[0].findall("./BuildActionEntries")
if len(entry_containers) != 1:
    fail("shared production scheme BuildActionEntries is absent or ambiguous")
archive_actions = scheme.findall("./ArchiveAction")
if len(archive_actions) != 1 or archive_actions[0].get("buildConfiguration") != "Release":
    fail("shared production scheme ArchiveAction is not exactly Release")
archive_entries = [
    entry
    for entry in entry_containers[0].findall("./BuildActionEntry")
    if entry.get("buildForArchiving") == "YES"
]
if len(archive_entries) != 1:
    fail("shared production scheme archive target is absent or ambiguous")
references = archive_entries[0].findall("./BuildableReference")
if len(references) != 1:
    fail("shared production scheme archive reference is absent or ambiguous")
reference = references[0]
if (
    reference.get("BuildableIdentifier") != "primary"
    or reference.get("BlueprintIdentifier") != target_id
    or reference.get("BlueprintName") != "SoraPassport"
    or reference.get("BuildableName") != "SoraPassport.app"
    or reference.get("ReferencedContainer") != "container:SoraPassport.xcodeproj"
):
    fail("shared production scheme does not archive the main SoraPassport target")
PY
}


verify_reviewed_dependencies() {
if [ ! -f "${manifest}" ]; then
    echo "error: missing reviewed modernization dependency manifest"
    exit 1
fi

# shellcheck disable=SC1090
. "${manifest}"

if ! /usr/bin/python3 -I -S - "${unit_test_scheme}" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
try:
    scheme = ET.parse(path).getroot()
except (OSError, ET.ParseError):
    raise SystemExit(1)
actions = scheme.findall("TestAction")
if len(actions) != 1:
    raise SystemExit(1)
action = actions[0]
arguments = action.findall("./CommandLineArguments/CommandLineArgument")
if (
    action.get("buildConfiguration") != "Debug"
    or action.get("shouldUseLaunchSchemeArgsEnv") != "NO"
    or len(arguments) != 1
    or arguments[0].get("argument") != "-UNITTEST"
    or arguments[0].get("isEnabled") != "YES"
):
    raise SystemExit(1)
PY
then
    echo "error: iOS unit-test host can execute production startup or has an ambiguous launch contract"
    exit 1
fi

# The shared-features package links no prebuilt binary (XNetworking, sorawallet,
# MPQRCoreSDK and the crypto xcframeworks were removed or rebuilt from source).
if [ ! -f "${shared_features_manifest}" ] ||
   /usr/bin/grep -Fq '.binaryTarget(' "${shared_features_manifest}" ||
   /usr/bin/grep -Fq 'XNetworking' "${shared_features_manifest}"; then
    echo "error: shared-features package declares a prebuilt binary target"
    exit 1
fi

for swiftpm_manifest in \
    "${shared_features_manifest}" \
    "${rswift_manifest}" \
    "${google_signin_manifest}" \
    "${google_api_manifest}"
do
    if [ ! -f "${swiftpm_manifest}" ] ||
       [ -L "${swiftpm_manifest}" ]; then
        echo "error: reviewed SwiftPM dependency manifest is absent or replaced"
        exit 1
    fi
done

if /usr/bin/grep -E \
    'from:|upToNextMajor|upToNextMinor|\.branch\(|\.range\(|\.\.<' \
    "${shared_features_manifest}" \
    "${rswift_manifest}" \
    "${google_signin_manifest}" \
    "${google_api_manifest}" >/dev/null; then
    echo "error: Release dependency manifests contain a dynamic SwiftPM requirement"
    exit 1
fi

# 3.9.x removed the unused JOSESwift (7520a9f6) and SoraDocuments (2e901e32)
# packages. Nothing may link them again without a review of this gate.
if [ -e "${jose_manifest}" ] ||
   [ -e "${root}/VendorPackages/SoraDocuments/Package.swift" ] ||
   /usr/bin/grep -Fq 'JOSESwift' "${project}" ||
   /usr/bin/grep -Fq 'SoraDocuments' "${project}"; then
    echo "error: removed JOSESwift or SoraDocuments package is referenced again"
    exit 1
fi

if [ "$(/usr/bin/grep -Fc 'exact: "' "${shared_features_manifest}")" != "5" ] ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/Boilertalk/secp256k1.swift.git", exact: "0.1.7")' "${shared_features_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", exact: "1.1.0")' "${shared_features_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/ashleymills/Reachability.swift", exact: "5.2.3")' "${shared_features_manifest}" ||
   ! /usr/bin/grep -Fq '.package(path: "../fearless-starscream")' "${shared_features_manifest}" ||
   [ ! -f "${root}/VendorPackages/fearless-starscream/UPSTREAM.json" ] ||
   [ -L "${root}/VendorPackages/fearless-starscream" ] ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/attaswift/BigInt.git", exact: "5.7.0")' "${shared_features_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/daisuke-t-jp/xxHash-Swift", exact: "1.1.1")' "${shared_features_manifest}" ||
   /usr/bin/grep -Fq 'github.com/soramitsu/web3-swift' "${shared_features_manifest}"; then
    echo "error: shared-features SwiftPM requirements drifted from the reviewed exact versions"
    exit 1
fi

if ! /usr/bin/grep -Fq '// swift-tools-version:5.0' "${rswift_manifest}" ||
   [ "$(/usr/bin/grep -Fc '.exact("' "${rswift_manifest}")" != "2" ] ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/kylef/Commander.git", .exact("0.9.2"))' "${rswift_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/tomlokhorst/XcodeEdit", .exact("2.8.0"))' "${rswift_manifest}"; then
    echo "error: R.swift build-tool dependencies are not exact"
    exit 1
fi

if ! /usr/bin/grep -Fq '// swift-tools-version:5.6' "${google_signin_manifest}" ||
   [ "$(/usr/bin/grep -Fc '.exact("' "${google_signin_manifest}")" != "3" ] ||
   [ "$(/usr/bin/grep -Fc 'url: "https://' "${google_signin_manifest}")" != "3" ] ||
   ! /usr/bin/grep -Fq '.exact("1.7.6"))' "${google_signin_manifest}" ||
   ! /usr/bin/grep -Fq '.exact("4.1.1"))' "${google_signin_manifest}" ||
   ! /usr/bin/grep -Fq '.exact("3.5.0"))' "${google_signin_manifest}" ||
   /usr/bin/grep -Fq '.revision(' "${google_signin_manifest}" ||
   /usr/bin/grep -Fq '.branch(' "${google_signin_manifest}"; then
    echo "error: vendored GoogleSignIn dependencies are not exact immutable requirements"
    exit 1
fi

if ! /usr/bin/grep -Fq '// swift-tools-version:5.6' "${google_api_manifest}" ||
   [ "$(/usr/bin/grep -Fc 'exact: "' "${google_api_manifest}")" != "1" ] ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/google/gtm-session-fetcher.git", exact: "3.5.0")' "${google_api_manifest}"; then
    echo "error: vendored Google API dependency is not exact"
    exit 1
fi

if [ ! -f "${swiftpm_resolution}" ] ||
   [ -L "${swiftpm_resolution}" ] ||
   [ "$(json_raw version "${swiftpm_resolution}")" != "3" ] ||
   [ "$(sha256_file "${swiftpm_resolution}")" != "${SWIFTPM_RESOLUTION_SHA256:-}" ] ||
   [ "$(json_raw pins "${swiftpm_resolution}")" != "${SWIFTPM_RESOLVED_PIN_COUNT:-}" ]; then
    echo "error: reviewed SwiftPM transitive resolution is absent or has drifted"
    exit 1
fi

case "${SWIFTPM_RESOLVED_PIN_COUNT:-}" in
    ""|*[!0-9]*)
        echo "error: reviewed SwiftPM pin count is invalid"
        exit 1
        ;;
esac

swiftpm_pin_index=0
while [ "${swiftpm_pin_index}" -lt "${SWIFTPM_RESOLVED_PIN_COUNT}" ]
do
    swiftpm_identity="$(json_raw "pins.${swiftpm_pin_index}.identity" "${swiftpm_resolution}")"
    swiftpm_kind="$(json_raw "pins.${swiftpm_pin_index}.kind" "${swiftpm_resolution}")"
    swiftpm_location="$(json_raw "pins.${swiftpm_pin_index}.location" "${swiftpm_resolution}")"
    swiftpm_revision="$(json_raw "pins.${swiftpm_pin_index}.state.revision" "${swiftpm_resolution}")"
    swiftpm_branch="$(json_raw "pins.${swiftpm_pin_index}.state.branch" "${swiftpm_resolution}")"

    if [ -z "${swiftpm_identity}" ] ||
       [ "${swiftpm_kind}" != "remoteSourceControl" ] ||
       [ -n "${swiftpm_branch}" ]; then
        echo "error: SwiftPM pin ${swiftpm_pin_index} is local, branch-based, or malformed"
        exit 1
    fi
    case "${swiftpm_location}" in
        https://*)
            ;;
        *)
            echo "error: SwiftPM pin ${swiftpm_identity} does not use a reviewed HTTPS source"
            exit 1
            ;;
    esac
    require_reviewed_sha1 "SwiftPM pin ${swiftpm_identity}" "${swiftpm_revision}"
    swiftpm_pin_index=$((swiftpm_pin_index + 1))
done

if [ ! -f "${rswift_resolution}" ] ||
   [ -L "${rswift_resolution}" ] ||
   [ "$(json_raw version "${rswift_resolution}")" != "1" ] ||
   [ "$(sha256_file "${rswift_resolution}")" != "${RSWIFT_SWIFTPM_RESOLUTION_SHA256:-}" ] ||
   [ "$(json_raw object.pins "${rswift_resolution}")" != "${RSWIFT_SWIFTPM_RESOLVED_PIN_COUNT:-}" ]; then
    echo "error: reviewed R.swift build-tool resolution is absent or has drifted"
    exit 1
fi

if [ "${RSWIFT_SWIFTPM_RESOLVED_PIN_COUNT:-}" != "3" ]; then
    echo "error: reviewed R.swift pin count is invalid"
    exit 1
fi

rswift_pin_index=0
while [ "${rswift_pin_index}" -lt "${RSWIFT_SWIFTPM_RESOLVED_PIN_COUNT}" ]
do
    rswift_identity="$(json_raw "object.pins.${rswift_pin_index}.package" "${rswift_resolution}")"
    rswift_location="$(json_raw "object.pins.${rswift_pin_index}.repositoryURL" "${rswift_resolution}")"
    rswift_revision="$(json_raw "object.pins.${rswift_pin_index}.state.revision" "${rswift_resolution}")"
    rswift_branch="$(json_raw "object.pins.${rswift_pin_index}.state.branch" "${rswift_resolution}")"

    if [ -z "${rswift_identity}" ] ||
       [ -n "${rswift_branch}" ]; then
        echo "error: R.swift pin ${rswift_pin_index} is branch-based or malformed"
        exit 1
    fi
    case "${rswift_location}" in
        https://*)
            ;;
        *)
            echo "error: R.swift pin ${rswift_identity} does not use a reviewed HTTPS source"
            exit 1
            ;;
    esac
    require_reviewed_sha1 "R.swift pin ${rswift_identity}" "${rswift_revision}"
    rswift_pin_index=$((rswift_pin_index + 1))
done

project_remote_package_count="$(
    /usr/bin/grep -c 'isa = XCRemoteSwiftPackageReference;' "${project}"
)"
project_exact_requirement_count="$(
    /usr/bin/grep -c 'kind = exactVersion;' "${project}"
)"
project_local_package_count="$(
    /usr/bin/grep -c 'isa = XCLocalSwiftPackageReference;' "${project}"
)"
project_vendored_local_count="$(
    /usr/bin/grep -c 'relativePath = .*VendorPackages/' "${project}"
)"
if [ "${project_remote_package_count}" != "11" ] ||
   [ "${project_exact_requirement_count}" != "${project_remote_package_count}" ] ||
   [ "${project_local_package_count}" != "11" ] ||
   [ "${project_vendored_local_count}" != "${project_local_package_count}" ] ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/NexusTransferCodec;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = "VendorPackages/google-api-objectivec-client-for-rest";' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SSFStorageQueryKit;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraWalletBinary;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraUI;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraUIKit;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/FireMock;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraFoundation;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = "VendorPackages/GoogleSignIn-iOS";' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = "VendorPackages/shared-features-spm";' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/fearless-starscream;' "${project}"; then
    echo "error: Xcode package references contain a dynamic requirement or local substitution"
    exit 1
fi

for reviewed_local_package in \
    VendorPackages/NexusTransferCodec \
    VendorPackages/google-api-objectivec-client-for-rest \
    VendorPackages/SSFStorageQueryKit \
    VendorPackages/SoraWalletBinary \
    VendorPackages/SoraUI \
    VendorPackages/SoraUIKit \
    VendorPackages/FireMock \
    VendorPackages/SoraFoundation \
    VendorPackages/GoogleSignIn-iOS \
    VendorPackages/shared-features-spm \
    VendorPackages/fearless-starscream
do
    if [ ! -d "${root}/${reviewed_local_package}" ] ||
       [ -L "${root}/${reviewed_local_package}" ]; then
        echo "error: reviewed local Swift package is absent or substituted: ${reviewed_local_package}"
        exit 1
    fi
done
}

count_test_methods() {
    /usr/bin/grep -Ec '^[[:space:]]*(override )?func test[A-Za-z0-9_]*\(' "$1" || /usr/bin/true
}

run_release_source_gate() {
    for required in \
        "${manifest}" \
        "${project}" \
        "${production_scheme}" \
        "${unit_test_scheme}" \
        "${binary_scanner}" \
        "${release_test_runner}" \
        "${wallet_network_model}" \
        "${root_interactor}" \
        "${modernization_tests}" \
        "${recovery_gate_tests}" \
        "${recovery_export_tests}" \
        "${account_creation_helper}" \
        "${jsonrpc_tests}" \
        "${websocket_engine}" \
        "${reachability_manager}"
    do
        if [ ! -f "${required}" ] || [ -L "${required}" ]; then
            echo "error: iOS release source is absent, non-regular, or symbolic: ${required}" >&2
            return 1
        fi
    done

    if ! verify_google_signin_info_plist_phase_dependencies "${project}"; then
        echo "error: Google Sign-In Info.plist build-order dependency drifted" >&2
        return 1
    fi
    if ! verify_reachability_listener_synchronization "${reachability_manager}"; then
        echo "error: ReachabilityManager weak listener synchronization drifted" >&2
        return 1
    fi
    if ! verify_ios_retained_mnemonic_policy "${wallet_network_model}" "${root_interactor}"; then
        return 1
    fi

    for shell_entry in \
        "${root}/SoraPassport/Scripts/verify-modernization-dependencies.sh" \
        "${root}/SoraPassport/Scripts/run-ios-release-tests.sh" \
        "${root}/SoraPassport/Scripts/run-ios-code-coverage.sh" \
        "${root}/SoraPassport/Scripts/inject-google-signin-info-plist.sh"
    do
        if [ ! -f "${shell_entry}" ] || [ -L "${shell_entry}" ] ||
           ! /bin/sh -n "${shell_entry}"; then
            echo "error: iOS shell entry point is absent, symbolic, or malformed: ${shell_entry}" >&2
            return 1
        fi
    done

    if [ ! -x /usr/bin/xcrun ]; then
        echo "error: Xcode Swift parser is unavailable for the iOS release source gate" >&2
        return 1
    fi
    for swift_source in \
        "${modernization_tests}" \
        "${account_creation_helper}" \
        "${jsonrpc_tests}" \
        "${websocket_engine}" \
        "${reachability_manager}"
    do
        if ! /usr/bin/xcrun swiftc -frontend -parse "${swift_source}"; then
            echo "error: iOS release Swift source does not parse: ${swift_source}" >&2
            return 1
        fi
    done

    if [ "$(/usr/bin/grep -Fc 'recoveryGate: isolatedRecoveryGate(settings: settings)' "${account_creation_helper}")" -ne 3 ] ||
       ! /usr/bin/grep -Fq 'settings: SettingsManagerProtocol &' "${account_creation_helper}" ||
       ! /usr/bin/grep -Fq 'SelectedWalletSettingsProtocol' "${account_creation_helper}" ||
       ! /usr/bin/grep -Fq 'settings.save(value: accountItem)' "${account_creation_helper}" ||
       /usr/bin/grep -Fq 'SelectedWalletSettings.shared' "${account_creation_helper}" ||
       ! /usr/bin/grep -Fq '@testable import SSFUtils' "${jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'func testReachabilityListenersAreSynchronizedAndCallbacksAreReentrant() throws {' "${jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'let manager = try XCTUnwrap(SSFUtils.ReachabilityManager())' "${jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'attributes: .concurrent' "${jsonrpc_tests}" ||
       [ "$(/usr/bin/grep -Fc 'manager.notifyListeners()' "${jsonrpc_tests}")" -ne 3 ] ||
       ! /usr/bin/grep -Fq 'manager.remove(listener: self)' "${jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'private func makeIsolatedRecoveryGate(' "${modernization_tests}" ||
       ! /usr/bin/grep -Fq 'private func makeWalletNetworkStore(' "${modernization_tests}" ||
       ! /usr/bin/grep -Fq 'private func makeLifecycleCoordinator()' "${modernization_tests}" ||
       ! verify_ios_migration_shared_lifecycle_test_scope "${modernization_tests}" ||
       ! /usr/bin/grep -Fq 'Task { [weak self] in' "${websocket_engine}" ||
       ! /usr/bin/grep -Fq 'let previousState = oldValue' "${websocket_engine}" ||
       ! /usr/bin/grep -Fq 'let currentState = state' "${websocket_engine}" ||
       [ "$(/usr/bin/grep -Fc 'COMPILER_FLAGS = "-warnings-as-errors";' "${project}")" -ne 4 ]; then
        echo "error: iOS release test isolation, socket or compiler-warning pin drifted" >&2
        return 1
    fi

    # The wallet-opening regressions: deleting one must be a reviewed change here.
    if [ "$(count_test_methods "${modernization_tests}")" != "237" ] ||
       [ "$(count_test_methods "${recovery_gate_tests}")" != "11" ] ||
       [ "$(count_test_methods "${recovery_export_tests}")" != "12" ]; then
        echo "error: the migration test inventory (237 + 11 + 12 test methods) changed" >&2
        return 1
    fi

    verify_reviewed_dependencies

    if ! /usr/bin/python3 -B -I -S "${binary_scanner}" --scan-repository; then
        return 1
    fi

    /usr/bin/printf 'iOS release source gate: OK (lints, migration test inventory 260, reviewed dependencies, binary scan)\n'
}

if [ "$#" -eq 2 ] && [ "$1" = "--lint-ios-google-signin-phase-dependencies" ]; then
    verify_google_signin_info_plist_phase_dependencies "$2"
    exit 0
fi
if [ "$#" -eq 2 ] && [ "$1" = "--lint-ios-reachability-listener-synchronization" ]; then
    verify_reachability_listener_synchronization "$2"
    exit 0
fi
if [ "$#" -eq 3 ] && [ "$1" = "--lint-ios-retained-mnemonic-policy" ]; then
    verify_ios_retained_mnemonic_policy "$2" "$3"
    exit 0
fi
if [ "$#" -eq 1 ] && [ "$1" = "--lint-ios-migration-release-source-gate" ]; then
    run_release_source_gate
    exit 0
fi
if [ "$#" -ne 0 ]; then
    echo "error: usage: verify-modernization-dependencies.sh [--lint-ios-migration-release-source-gate | --lint-ios-google-signin-phase-dependencies PROJECT | --lint-ios-reachability-listener-synchronization SOURCE | --lint-ios-retained-mnemonic-policy MODEL ROOT]" >&2
    exit 64
fi

# run-ios-release-tests.sh builds the app with Release optimization for the
# simulator and ad-hoc signs the test host so Keychain operations work.
release_test_mode="${SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE:-}"
release_test_action="${SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION:-}"
if [ -z "${release_test_mode}" ] && [ -n "${release_test_action}" ]; then
    echo "error: iOS Release-test action lacks its exact capability" >&2
    exit 1
fi
if [ -n "${release_test_mode}" ]; then
    if [ "${release_test_mode}" != "sora-ios-nonpromoting-release-simulator-test-v1" ] ||
       [ "${release_test_action}" != "test" ] ||
       [ "${ACTION:-}" != "build" ] ||
       [ "${CONFIGURATION:-}" != "Release" ] ||
       [ "${PLATFORM_NAME:-}" != "iphonesimulator" ] ||
       [ "${EFFECTIVE_PLATFORM_NAME:-}" != "-iphonesimulator" ] ||
       [ "${DEPLOYMENT_LOCATION:-NO}" != "NO" ] ||
       [ "${TARGET_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "co.jp.soramitsu.sora" ] ||
       [ "${DEVELOPMENT_TEAM:-}" != "YLWWUD25VZ" ] ||
       [ "${CODE_SIGN_ENTITLEMENTS:-}" != "SoraPassport/SoraPassport.entitlements" ] ||
       [ "${INFOPLIST_FILE:-}" != "SoraPassport/Info.plist" ] ||
       [ "${SORA_APPLICATION_CONFIG:-}" != "Release" ] ||
       [ "${SORA_NAME:-}" != "SORA" ] ||
       [ "${CODE_SIGN_IDENTITY:-}" != "-" ] ||
       [ "${EXPANDED_CODE_SIGN_IDENTITY:-}" != "-" ] ||
       [ "${CODE_SIGNING_ALLOWED:-}" != "YES" ] ||
       [ "${CODE_SIGNING_REQUIRED:-}" != "YES" ] ||
       [ "${ENABLE_TESTABILITY:-NO}" != "YES" ] ||
       [ "${ONLY_ACTIVE_ARCH:-NO}" != "YES" ] ||
       [ "${ARCHS:-}" != "arm64" ] ||
       [ "${EXCLUDED_ARCHS:-}" != "x86_64" ]; then
        echo "error: iOS Release simulator test capability is invalid" >&2
        exit 1
    fi
    case "${SDK_NAME:-}" in
        iphonesimulator*) ;;
        *)
            echo "error: iOS Release tests require the simulator SDK" >&2
            exit 1
            ;;
    esac
    run_release_source_gate
    echo "warning: optimized simulator XCTest build; this is not an App Store archive" >&2
    exit 0
fi

# Debug, Dev, Staging and Test builds.
if [ -n "${CONFIGURATION:-}" ] && [ "${CONFIGURATION}" != "Release" ]; then
    run_release_source_gate
    exit 0
fi

# In an actual Release build, trust Xcode's resolved main-target values rather
# than the presence of matching tokens elsewhere in the project file.
if [ "${CONFIGURATION:-}" = "Release" ]; then
    if [ "${TARGET_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "co.jp.soramitsu.sora" ] ||
       [ "${DEVELOPMENT_TEAM:-}" != "YLWWUD25VZ" ] ||
       [ "${CODE_SIGN_ENTITLEMENTS:-}" != "SoraPassport/SoraPassport.entitlements" ] ||
       [ "${INFOPLIST_FILE:-}" != "SoraPassport/Info.plist" ] ||
       [ "${SORA_APPLICATION_CONFIG:-}" != "Release" ] ||
       [ "${SORA_NAME:-}" != "SORA" ]; then
        echo "error: resolved iOS main-target Release identity drifted" >&2
        exit 1
    fi
fi

if ! verify_main_release_source_identity; then
    echo "error: iOS main-target Release source identity drifted"
    exit 1
fi
run_release_source_gate

# A standalone run (no Xcode configuration) is a source audit and ends here.
if [ -z "${CONFIGURATION:-}" ]; then
    exit 0
fi

# Release builds reach the App Store only through scripts/archive-app-store.sh,
# which runs this gate in lint mode. Production signing is not admitted here.
echo "error: iOS production signing identity remains explicitly blocked (archive with scripts/archive-app-store.sh)"
exit 1
