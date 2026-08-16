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

# This is the executable, source-side half of the iOS migration Release gate.
# It deliberately consumes no signing credential, retained-device identifier,
# private evidence, or qualification receipt. Those protected inputs remain
# mandatory at the archive/exact-IPA/qualification boundaries below.
run_exact_ios_migration_suite() {
    ios_gate_suite_path="$1"
    ios_gate_suite_expected="$2"
    ios_gate_suite_label="$3"
    if ! ios_gate_suite_output="$(
        /usr/bin/python3 -B -I -S "${ios_gate_suite_path}" 2>&1
    )"; then
        /usr/bin/printf '%s\n' "${ios_gate_suite_output}" >&2
        /usr/bin/printf 'error: iOS migration %s suite failed\n' \
            "${ios_gate_suite_label}" >&2
        return 1
    fi
    ios_gate_suite_observed="$(
        /usr/bin/printf '%s\n' "${ios_gate_suite_output}" |
            /usr/bin/awk '
                /^Ran [0-9]+ tests? in / {
                    count += 1
                    observed = $2
                }
                END {
                    if (count == 1) {
                        print observed
                    }
                }
            '
    )"
    if [ "${ios_gate_suite_observed}" != "${ios_gate_suite_expected}" ] ||
       ! /usr/bin/printf '%s\n' "${ios_gate_suite_output}" |
            /usr/bin/grep -Fxq 'OK'; then
        /usr/bin/printf '%s\n' "${ios_gate_suite_output}" >&2
        /usr/bin/printf \
            'error: iOS migration %s suite did not close exactly %s passing tests\n' \
            "${ios_gate_suite_label}" "${ios_gate_suite_expected}" >&2
        return 1
    fi
}

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
expected_script = '/bin/sh "$PROJECT_DIR/SoraPassport/Scripts/inject-google-signin-info-plist.sh"\n'
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

run_ios_migration_release_source_gate() {
    ios_gate_projector="${root}/SoraPassport/Scripts/derive-ios-migration-test-host.py"
    ios_gate_clone="${root}/SoraPassport/Scripts/create-ios-migration-installable-clone.py"
    ios_gate_controller="${root}/SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py"
    ios_gate_sanitizer="${root}/SoraPassport/Scripts/sanitize-ios-migration-xctestrun.py"
    ios_gate_collector="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.py"
    ios_gate_qualifier="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.py"
    ios_gate_builder="${root}/SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh"
    ios_gate_archiver="${root}/SoraPassport/Scripts/archive-ios-migration-candidate.sh"
    ios_gate_internal_testflight="${root}/SoraPassport/Scripts/upload-ios-internal-testflight.sh"
    ios_gate_internal_testflight_delivery="${root}/SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py"
    ios_gate_internal_testflight_export_options="${root}/SoraPassport/Configs/ios-internal-testflight-export-options.plist"
    ios_gate_source_contract="${root}/Fixtures/Modernization/ios-migration-qualification-contract-v1.json"
    ios_gate_promotion="${root}/SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"
    ios_gate_rollout="${root}/SoraPassport/Scripts/verify-production-rollout.sh"
    ios_gate_release_package="${root}/SoraPassport/Scripts/verify-ios-release-reproducibility-package.py"
    ios_gate_taira_deployment="${root}/SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
    ios_gate_signing_identity="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.py"
    ios_gate_release_test_runner="${root}/SoraPassport/Scripts/run-ios-release-tests.sh"
    ios_gate_production_promotion="${root}/SoraPassport/Scripts/run-ios-production-promotion.py"
    ios_gate_production_promotion_pipeline="${root}/Jenkinsfile.production-promotion"
    ios_gate_ci_workflow="${root}/.github/workflows/ios_modernization.yml"
    ios_gate_projector_suite="${root}/SoraPassport/Scripts/test-ios-migration-test-host-derivation.py"
    ios_gate_clone_suite="${root}/SoraPassport/Scripts/test-ios-migration-installable-clone.py"
    ios_gate_controller_suite="${root}/SoraPassport/Scripts/test-ios-migration-exact-ipa-evidence.py"
    ios_gate_sanitizer_suite="${root}/SoraPassport/Scripts/test-ios-migration-xctestrun-sanitizer.py"
    ios_gate_collector_suite="${root}/SoraPassport/Scripts/test-ios-migration-evidence-collector.py"
    ios_gate_boundary_suite="${root}/SoraPassport/Scripts/test-ios-migration-release-boundary.py"
    ios_gate_internal_testflight_suite="${root}/SoraPassport/Scripts/test-ios-internal-testflight-upload.py"
    ios_gate_release_package_suite="${root}/SoraPassport/Scripts/test-ios-release-reproducibility-package.py"
    ios_gate_taira_deployment_suite="${root}/SoraPassport/Scripts/test-ios-taira-deployment-manifest.py"
    ios_gate_vendored_binary_suite="${root}/SoraPassport/Scripts/test-ios-vendored-binary-qualification.py"
    ios_gate_signing_identity_suite="${root}/SoraPassport/Scripts/test-ios-production-signing-identity.py"
    ios_gate_production_promotion_suite="${root}/SoraPassport/Scripts/test-ios-production-promotion.py"
    ios_gate_project="${root}/SoraPassport.xcodeproj/project.pbxproj"
    ios_gate_harness="${root}/SoraPassport/Common/MigrationEvidence/RetainedMigrationEvidenceHarness.swift"
    ios_gate_integration_producer="${root}/SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests.swift"
    ios_gate_ui_runner="${root}/SoraPassportUITests/RetainedMigrationEvidenceUITests.swift"
    ios_gate_modernization_tests="${root}/SoraPassportTests/Common/Modernization/WalletModernizationTests.swift"
    ios_gate_account_creation_helper="${root}/SoraPassportTests/Helpers/AccountCreationHelper.swift"
    ios_gate_jsonrpc_tests="${root}/SoraPassportIntegrationTests/Substrate/JSONRPCTests.swift"
    ios_gate_websocket_engine="${root}/VendorPackages/shared-features-spm/Sources/SSFUtils/SSFUtils/Classes/Network/WebSocketEngine.swift"
    ios_gate_reachability_manager="${root}/VendorPackages/shared-features-spm/Sources/SSFUtils/SSFUtils/Classes/Network/Reachability/ReachabilityManager.swift"
    ios_gate_evidence_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidence.xcscheme"
    ios_gate_ui_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidenceUI.xcscheme"

    for ios_gate_required in \
        "${ios_gate_projector}" \
        "${ios_gate_clone}" \
        "${ios_gate_controller}" \
        "${ios_gate_sanitizer}" \
        "${ios_gate_collector}" \
        "${ios_gate_qualifier}" \
        "${ios_gate_builder}" \
        "${ios_gate_archiver}" \
        "${ios_gate_internal_testflight}" \
        "${ios_gate_internal_testflight_delivery}" \
        "${ios_gate_internal_testflight_export_options}" \
        "${ios_gate_source_contract}" \
        "${ios_gate_promotion}" \
        "${ios_gate_rollout}" \
        "${ios_gate_release_package}" \
        "${ios_gate_taira_deployment}" \
        "${ios_gate_signing_identity}" \
        "${ios_gate_release_test_runner}" \
        "${ios_gate_production_promotion}" \
        "${ios_gate_production_promotion_pipeline}" \
        "${ios_gate_ci_workflow}" \
        "${ios_gate_projector_suite}" \
        "${ios_gate_clone_suite}" \
        "${ios_gate_controller_suite}" \
        "${ios_gate_sanitizer_suite}" \
        "${ios_gate_collector_suite}" \
        "${ios_gate_boundary_suite}" \
        "${ios_gate_internal_testflight_suite}" \
        "${ios_gate_release_package_suite}" \
        "${ios_gate_taira_deployment_suite}" \
        "${ios_gate_vendored_binary_suite}" \
        "${ios_gate_signing_identity_suite}" \
        "${ios_gate_production_promotion_suite}" \
        "${ios_gate_project}" \
        "${ios_gate_harness}" \
        "${ios_gate_integration_producer}" \
        "${ios_gate_ui_runner}" \
        "${ios_gate_modernization_tests}" \
        "${ios_gate_account_creation_helper}" \
        "${ios_gate_jsonrpc_tests}" \
        "${ios_gate_websocket_engine}" \
        "${ios_gate_reachability_manager}" \
        "${ios_gate_evidence_scheme}" \
        "${ios_gate_ui_scheme}"
    do
        if [ ! -f "${ios_gate_required}" ] || [ -L "${ios_gate_required}" ]; then
            echo "error: iOS migration Release source is absent, non-regular, or symbolic: ${ios_gate_required}" >&2
            return 1
        fi
    done

    if ! verify_google_signin_info_plist_phase_dependencies "${ios_gate_project}"; then
        echo "error: Google Sign-In Info.plist build-order dependency drifted" >&2
        return 1
    fi
    if ! verify_reachability_listener_synchronization "${ios_gate_reachability_manager}"; then
        echo "error: ReachabilityManager weak listener synchronization drifted" >&2
        return 1
    fi

    # Thirteen source-contract/template lints. Keep this inventory explicit: a new
    # producer is not admitted merely because one aggregate wrapper still lints.
    if ! /usr/bin/python3 -B -I -S "${ios_gate_projector}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_clone}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_controller}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_sanitizer}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_collector}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_qualifier}" --lint-templates >/dev/null ||
       ! /bin/sh "${ios_gate_builder}" --lint-contract >/dev/null ||
       ! /bin/sh "${ios_gate_internal_testflight}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_release_package}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_taira_deployment}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_signing_identity}" --lint-templates >/dev/null ||
       ! /bin/sh "${ios_gate_release_test_runner}" --lint-contract >/dev/null ||
       ! /usr/bin/python3 -B -I -S "${ios_gate_production_promotion}" --lint-contract >/dev/null; then
        echo "error: one of thirteen iOS migration Release contract/template lints failed" >&2
        return 1
    fi

    ios_gate_test_total=0
    run_exact_ios_migration_suite "${ios_gate_projector_suite}" 30 projector || return 1
    ios_gate_test_total=$((ios_gate_test_total + 30))
    run_exact_ios_migration_suite "${ios_gate_clone_suite}" 3 installable-clone || return 1
    ios_gate_test_total=$((ios_gate_test_total + 3))
    run_exact_ios_migration_suite "${ios_gate_controller_suite}" 24 exact-IPA-controller || return 1
    ios_gate_test_total=$((ios_gate_test_total + 24))
    run_exact_ios_migration_suite "${ios_gate_sanitizer_suite}" 6 xctestrun-sanitizer || return 1
    ios_gate_test_total=$((ios_gate_test_total + 6))
    run_exact_ios_migration_suite "${ios_gate_collector_suite}" 15 collector || return 1
    ios_gate_test_total=$((ios_gate_test_total + 15))
    run_exact_ios_migration_suite "${ios_gate_boundary_suite}" 15 release-boundary || return 1
    ios_gate_test_total=$((ios_gate_test_total + 15))
    [ "${ios_gate_test_total}" -eq 93 ] || {
        echo "error: iOS migration Release source suite inventory is not exactly 93 tests" >&2
        return 1
    }
    run_exact_ios_migration_suite "${ios_gate_internal_testflight_suite}" 8 internal-testflight-upload || return 1
    run_exact_ios_migration_suite "${ios_gate_release_package_suite}" 17 release-reproducibility-package || return 1
    run_exact_ios_migration_suite "${ios_gate_taira_deployment_suite}" 13 taira-deployment-admission || return 1
    run_exact_ios_migration_suite "${ios_gate_vendored_binary_suite}" 10 vendored-binary-qualification || return 1
    run_exact_ios_migration_suite "${ios_gate_signing_identity_suite}" 10 production-signing-identity || return 1
    run_exact_ios_migration_suite "${ios_gate_production_promotion_suite}" 17 production-promotion-controller || return 1

    for ios_gate_shell in \
        "${root}/SoraPassport/Scripts/archive-ios-migration-candidate.sh" \
        "${root}/SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh" \
        "${root}/SoraPassport/Scripts/collect-ios-migration-evidence.sh" \
        "${root}/SoraPassport/Scripts/create-ios-migration-installable-clone.sh" \
        "${root}/SoraPassport/Scripts/derive-ios-migration-test-host.sh" \
        "${root}/SoraPassport/Scripts/run-ios-migration-evidence-collection.sh" \
        "${root}/SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.sh" \
        "${root}/SoraPassport/Scripts/run-ios-release-tests.sh" \
        "${root}/SoraPassport/Scripts/upload-ios-internal-testflight.sh" \
        "${root}/SoraPassport/Scripts/verify-ios-migration-qualification.sh" \
        "${root}/SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh" \
        "${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.sh" \
        "${root}/SoraPassport/Scripts/verify-funded-nexus-canary.sh" \
        "${root}/SoraPassport/Scripts/verify-production-rollout.sh" \
        "${root}/SoraPassport/Scripts/verify-modernization-dependencies.sh"
    do
        if [ ! -f "${ios_gate_shell}" ] || [ -L "${ios_gate_shell}" ] ||
           ! /bin/sh -n "${ios_gate_shell}"; then
            echo "error: iOS migration Release shell entry point is absent, symbolic, or malformed: ${ios_gate_shell}" >&2
            return 1
        fi
    done

    if [ ! -x /usr/bin/xcrun ]; then
        echo "error: Xcode Swift parser is unavailable for the iOS migration Release source gate" >&2
        return 1
    fi
    for ios_gate_swift in \
        "${ios_gate_harness}" \
        "${ios_gate_integration_producer}" \
        "${ios_gate_ui_runner}" \
        "${ios_gate_modernization_tests}" \
        "${ios_gate_account_creation_helper}" \
        "${ios_gate_jsonrpc_tests}" \
        "${ios_gate_websocket_engine}" \
        "${ios_gate_reachability_manager}"
    do
        if ! /usr/bin/xcrun swiftc -frontend -parse "${ios_gate_swift}"; then
            echo "error: iOS migration Release Swift source does not parse: ${ios_gate_swift}" >&2
            return 1
        fi
    done

    ios_gate_release_test_action="$(
        /usr/bin/awk '
            /^exec \/usr\/bin\/xcodebuild/ { emit = 1 }
            emit { print }
        ' "${ios_gate_release_test_runner}"
    )"
    ios_gate_authorization_key_count="$(
        /usr/bin/awk '
            /static let exactKeys: Set<String> = \[/ {
                active = 1
                next
            }
            active && /^        \]$/ {
                print count
                exit
            }
            active && /^            "[^"]+",?$/ {
                count += 1
            }
        ' "${ios_gate_harness}"
    )"
    if [ "${ios_gate_authorization_key_count}" != "26" ] ||
       ! /usr/bin/grep -Fq 'guard Set(root.keys) == exactKeys else {' "${ios_gate_harness}" ||
       ! /usr/bin/grep -Fq 'productionProjectionSha == installedProjectionSha' "${ios_gate_harness}" ||
       ! /usr/bin/grep -Fq 'len(REQUEST_KEYS) != 26' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq 'installable clone was not reinstalled immediately before XCTest' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq '"/usr/bin/xcodebuild",' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq '"test-without-building",' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq '["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app_path)]' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq 'inspect_production_signature_identity' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq '"/usr/bin/security", "cms", "-D", "-i", str(profile_path)' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq 'verify_sanitized_xctestrun' "${ios_gate_controller}" ||
       ! /usr/bin/grep -Fq 'target.get("UITargetAppPath") != str(clone_app)' "${ios_gate_sanitizer}" ||
       ! /usr/bin/grep -Fq 'contains_rebuilt_host_path' "${ios_gate_sanitizer}" ||
       ! /usr/bin/grep -Fq 'installedCloneCodeSignatureDeepStrictVerified' "${ios_gate_clone}" ||
       ! /usr/bin/grep -Fq 'WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding()' "${ios_gate_evidence_scheme}" ||
       ! /usr/bin/grep -Fq 'buildConfiguration = "Release"' "${ios_gate_evidence_scheme}" ||
       [ "$(/usr/bin/grep -Fc 'buildForArchiving = "NO"' "${ios_gate_evidence_scheme}")" -ne 3 ] ||
       ! /usr/bin/grep -Fq 'RetainedMigrationEvidenceUITests/testExecuteAuthorizedRetainedMigrationCase()' "${ios_gate_ui_scheme}" ||
       [ "$(/usr/bin/grep -Fc 'buildForArchiving = "NO"' "${ios_gate_ui_scheme}")" -ne 2 ] ||
       ! /usr/bin/grep -Fq 'while launches < 8 {' "${ios_gate_ui_runner}" ||
       ! /usr/bin/grep -Fq 'application.terminate()' "${ios_gate_ui_runner}" ||
       ! /usr/bin/grep -Fq 'productionCanonicalProjectionSha256 == installedCanonicalProjectionSha256' "${ios_gate_integration_producer}" ||
       [ "$(/usr/bin/grep -Fc 'recoveryGate: isolatedRecoveryGate(settings: settings)' "${ios_gate_account_creation_helper}")" -ne 3 ] ||
       ! /usr/bin/grep -Fq 'settings: SettingsManagerProtocol &' "${ios_gate_account_creation_helper}" ||
       ! /usr/bin/grep -Fq 'SelectedWalletSettingsProtocol' "${ios_gate_account_creation_helper}" ||
       ! /usr/bin/grep -Fq 'settings.save(value: accountItem)' "${ios_gate_account_creation_helper}" ||
       /usr/bin/grep -Fq 'SelectedWalletSettings.shared' "${ios_gate_account_creation_helper}" ||
       ! /usr/bin/grep -Fq '@testable import SSFUtils' "${ios_gate_jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'func testReachabilityListenersAreSynchronizedAndCallbacksAreReentrant() throws {' "${ios_gate_jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'let manager = try XCTUnwrap(SSFUtils.ReachabilityManager())' "${ios_gate_jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'attributes: .concurrent' "${ios_gate_jsonrpc_tests}" ||
       [ "$(/usr/bin/grep -Fc 'manager.notifyListeners()' "${ios_gate_jsonrpc_tests}")" -ne 3 ] ||
       ! /usr/bin/grep -Fq 'manager.remove(listener: self)' "${ios_gate_jsonrpc_tests}" ||
       ! /usr/bin/grep -Fq 'private func makeIsolatedRecoveryGate(' "${ios_gate_modernization_tests}" ||
       ! /usr/bin/grep -Fq 'private func makeWalletNetworkStore(' "${ios_gate_modernization_tests}" ||
       ! /usr/bin/grep -Fq 'private func makeLifecycleCoordinator()' "${ios_gate_modernization_tests}" ||
       /usr/bin/grep -Fq 'WalletLifecycleCoordinator.shared' "${ios_gate_modernization_tests}" ||
       ! /usr/bin/grep -Fq 'Task { [weak self] in' "${ios_gate_websocket_engine}" ||
       ! /usr/bin/grep -Fq 'let previousState = oldValue' "${ios_gate_websocket_engine}" ||
       ! /usr/bin/grep -Fq 'let currentState = state' "${ios_gate_websocket_engine}" ||
       [ "$(/usr/bin/grep -Fc 'COMPILER_FLAGS = "-warnings-as-errors";' "${ios_gate_project}")" -ne 3 ] ||
       /usr/bin/grep -Fq 'SWIFT_TREAT_WARNINGS_AS_ERRORS=YES' "${ios_gate_builder}" ||
       /usr/bin/grep -Fq 'GCC_TREAT_WARNINGS_AS_ERRORS=YES' "${ios_gate_builder}" ||
       /usr/bin/grep -Fq 'SWIFT_TREAT_WARNINGS_AS_ERRORS=YES' "${ios_gate_archiver}" ||
       /usr/bin/grep -Fq 'GCC_TREAT_WARNINGS_AS_ERRORS=YES' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '-allowProvisioningUpdates' "${ios_gate_builder}" ||
       ! /usr/bin/grep -Fq 'ENABLE_TESTABILITY=YES' "${ios_gate_builder}" ||
       ! /usr/bin/grep -Fq -- '-exportArchive' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '-exportOptionsPlist "${export_options_snapshot}"' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '--verify-snapshot "${qualification_contract_snapshot}"' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq '["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app_path)]' "${ios_gate_collector}" ||
       ! /usr/bin/grep -Fq '["/usr/bin/security", "cms", "-D", "-i", str(profile_path)]' "${ios_gate_collector}" ||
       ! /usr/bin/grep -Fq -- '--verify-qualified-ipa' "${ios_gate_promotion}" ||
       ! /usr/bin/grep -Fq '/bin/sh "${migration_promotion_admission}" --verify-qualified-ipa "${candidate_ipa}"' "${ios_gate_rollout}" ||
       ! /usr/bin/grep -Fq 'IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq 'SORA_TAIRA_DEPLOYMENT_ADMISSION_SHA256' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq 'sora-ios-nonpromoting-release-simulator-test-v1' "${ios_gate_release_test_runner}" ||
       ! /usr/bin/grep -Fq 'result-bundle path must end in .xcresult' "${ios_gate_release_test_runner}" ||
       ! /usr/bin/grep -Fq 'must stay outside the repository' "${ios_gate_release_test_runner}" ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq 'exec /usr/bin/xcodebuild' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    test \' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    -configuration Release \' ||
       [ "$(/usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fc -- '-skip-testing:')" -ne 4 ] ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq -- '-skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq -- '-skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq -- '-skip-testing:SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq -- '-skip-testing:SoraPassportUITests/RetainedMigrationEvidenceUITests/testExecuteAuthorizedRetainedMigrationCase' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    CODE_SIGNING_ALLOWED=NO \' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    CODE_SIGNING_REQUIRED=NO \' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    ENABLE_TESTABILITY=YES \' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    ARCHS=arm64 \' ||
       ! /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Fq '    EXCLUDED_ARCHS=x86_64' ||
       /usr/bin/printf '%s\n' "${ios_gate_release_test_action}" | /usr/bin/grep -Eq '(^|[[:space:]])archive([[:space:]]|$)|-exportArchive|upload|allowProvisioningUpdates' ||
       ! /usr/bin/grep -Fq 'KNOWN_CHAIN_IDS' "${ios_gate_taira_deployment}" ||
       ! /usr/bin/grep -Fq 'quarantine-recovery-only' "${ios_gate_taira_deployment}" ||
       ! /usr/bin/grep -Fq 'CONVENIENCE_HOST = "taira.sora.org"' "${ios_gate_taira_deployment}"; then
        echo "error: iOS migration Release source, scheme, test, archive, or signing hook is fail-open" >&2
        return 1
    fi
    if ! /usr/bin/grep -Fq 'canonical-signed-application-equivalence-v1' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'exact-ipa-bytes-v1' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'sora-ios-qualified-ipa-package-v4' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'sora-ios-release-build-manifest-v4' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'sora-ios-release-reproducibility-equivalence-v4' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'application_signing_certificate_sha256' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'require_retained_signing_identity' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'signing-identity-receipt.json' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'vendored-binary-qualification-receipt.json' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'vendoredBinaryReceiptSha256' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'CandidateCDHashFull sha256=' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'primaryCandidateImmutable' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'epochs[0] <= epochs[1]' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq 'int(raw) > MAX_SAFE_INTEGER' "${ios_gate_release_package}" ||
       ! /usr/bin/grep -Fq -- '--capture-build-manifest' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '--signing-receipt-sha "${signing_identity_sha}"' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '--vendored-receipt-sha "${vendored_binary_sha}"' "${ios_gate_archiver}" ||
       [ "$(/usr/bin/grep -Fc '"CURRENT_PROJECT_VERSION=${build_number}"' "${ios_gate_archiver}")" -ne 2 ] ||
       ! /usr/bin/grep -Fq 'IOS_APP_STORE_BUILD_NUMBER_LOWER_BOUND' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '--build-number "${build_number}"' "${ios_gate_archiver}" ||
       ! /usr/bin/grep -Fq -- '--app-store-build-lower-bound "${app_store_build_number_lower_bound}"' "${ios_gate_archiver}" ||
       [ "$(/usr/bin/grep -Fc '/bin/sh "${signing_identity_tool}" --verify-qualified' "${ios_gate_archiver}")" -ne 2 ] ||
       [ "$(/usr/bin/grep -Fc '/bin/sh "${vendored_binary_tool}" --verify-qualified' "${ios_gate_archiver}")" -ne 2 ] ||
       ! /usr/bin/grep -Fq -- '-derivedDataPath "${derived_data_path}"' "${ios_gate_archiver}" ||
       [ "$(/usr/bin/grep -Fc -- '--verify-download' "${ios_gate_promotion}")" -ne 2 ] ||
       [ "$(/usr/bin/grep -Fc '/bin/sh "${signing_identity_validator}" --verify-qualified' "${ios_gate_promotion}")" -ne 2 ] ||
       [ "$(/usr/bin/grep -Fc '/bin/sh "${vendored_binary_validator}" --verify-qualified' "${ios_gate_promotion}")" -ne 2 ] ||
       ! /usr/bin/grep -Fq 'package_vendored_sha' "${ios_gate_promotion}" ||
       ! /usr/bin/grep -Fq '[ "${qualification_ipa_sha}" = "${package_candidate_sha}" ]' "${ios_gate_promotion}" ||
       ! /usr/bin/grep -Fq '[ "${package_final_result}" = "${package_result}" ]' "${ios_gate_promotion}" ||
       ! /usr/bin/grep -Fq 'IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH' "${ios_gate_promotion}"; then
        echo "error: iOS independently reproduced Release package gate is fail-open" >&2
        return 1
    fi
    if ! /usr/bin/grep -Fq 'pull_request:' "${ios_gate_ci_workflow}" ||
       /usr/bin/grep -Fq 'pull_request_target:' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'permissions:' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'contents: read' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'Modernization Source Contract' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'Full Release XCTest Closure' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq -- '--lint-ios-migration-release-source-gate' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'run-ios-release-tests.sh' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'SoraPassport-Release-${{ github.sha }}' "${ios_gate_ci_workflow}" ||
       ! /usr/bin/grep -Fq 'if-no-files-found: error' "${ios_gate_ci_workflow}"; then
        echo "error: iOS pull-request modernization closure workflow is absent or fail-open" >&2
        return 1
    fi
    if /usr/bin/grep -Fq 'extractedAppRawTreeSha256' "${ios_gate_harness}" ||
       /usr/bin/grep -Fq 'extractedAppRawTreeSha256' "${ios_gate_controller}" ||
       /usr/bin/grep -Fq 'Simulator' "${ios_gate_evidence_scheme}" ||
       /usr/bin/grep -Fq 'Simulator' "${ios_gate_ui_scheme}" ||
       /usr/bin/grep -Fq -- '-exportArchive' "${ios_gate_builder}"; then
        echo "error: iOS migration Release source gate admitted a stale or unsafe source shape" >&2
        return 1
    fi

    /usr/bin/printf \
        'iOS migration Release source gate: OK (93 migration tests + 8 internal-TestFlight tests + 17 Release-package tests + 13 Taira-admission tests + 10 vendored-binary tests + 10 signing-identity tests + 17 production-promotion tests, 13 lints, shell/Swift parse)\n'
}

if [ "$#" -eq 2 ] && [ "$1" = "--lint-ios-google-signin-phase-dependencies" ]; then
    verify_google_signin_info_plist_phase_dependencies "$2"
    exit 0
fi
if [ "$#" -eq 2 ] && [ "$1" = "--lint-ios-reachability-listener-synchronization" ]; then
    verify_reachability_listener_synchronization "$2"
    exit 0
fi
if [ "$#" -eq 1 ] && [ "$1" = "--lint-ios-migration-release-source-gate" ]; then
    unset SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE
    unset SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION
    unset SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER
    unset SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION
    unset SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256
    run_ios_migration_release_source_gate
    exit 0
fi
if [ "$#" -ne 0 ]; then
    echo "error: usage: verify-modernization-dependencies.sh [--lint-ios-migration-release-source-gate | --lint-ios-google-signin-phase-dependencies PROJECT | --lint-ios-reachability-listener-synchronization SOURCE]" >&2
    exit 64
fi

# The production candidate archive is the artifact that retained-device
# qualification must bind. This explicit archive capability continues through
# the entire Release verifier; only the receipt-dependent migration section is
# deferred because the exact exported IPA does not exist yet. The wrapper that
# sets it has no upload or promotion action.
release_test_mode="${SORA_IOS_NONPROMOTING_RELEASE_TEST_MODE:-}"
release_test_action="${SORA_IOS_NONPROMOTING_RELEASE_TEST_ACTION:-}"
if [ -z "${release_test_mode}" ] && [ -n "${release_test_action}" ]; then
    echo "error: iOS non-promoting Release-test action lacks its exact capability" >&2
    exit 1
fi
internal_testflight_mode="${SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE:-}"
internal_testflight_action="${SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION:-}"
if [ -z "${internal_testflight_mode}" ] && [ -n "${internal_testflight_action}" ]; then
    echo "error: iOS internal TestFlight action lacks its exact capability" >&2
    exit 1
fi
if [ -n "${internal_testflight_mode}" ]; then
    internal_testflight_wrapper="${root}/SoraPassport/Scripts/upload-ios-internal-testflight.sh"
    internal_testflight_export_options="${root}/SoraPassport/Configs/ios-internal-testflight-export-options.plist"
    internal_testflight_build_number="${SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER:-}"
    internal_testflight_source_revision="${SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION:-}"
    internal_testflight_export_options_sha="${SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256:-}"
    if [ "${internal_testflight_mode}" != "sora-ios-internal-testflight-upload-v1" ] ||
       [ "${internal_testflight_action}" != "archive" ] ||
       [ -n "${SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE:-}" ] ||
       [ -n "${SORA_IOS_MIGRATION_EVIDENCE_BUILD_MODE:-}" ] ||
       [ -n "${release_test_mode}" ] ||
       [ "${ACTION:-}" != "install" ] ||
       [ "${CONFIGURATION:-}" != "Release" ] ||
       [ "${PLATFORM_NAME:-}" != "iphoneos" ] ||
       [ "${EFFECTIVE_PLATFORM_NAME:-}" != "-iphoneos" ] ||
       [ "${DEPLOYMENT_LOCATION:-}" != "YES" ] ||
       [ "${TARGET_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "co.jp.soramitsu.sora" ] ||
       [ "${DEVELOPMENT_TEAM:-}" != "YLWWUD25VZ" ] ||
       [ "${CODE_SIGN_STYLE:-}" != "Automatic" ] ||
       [ "${CODE_SIGN_IDENTITY:-}" != "iPhone Developer" ] ||
       [ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ] ||
       [ "${internal_testflight_build_number}" != "2026081601" ] ||
       [ "${CURRENT_PROJECT_VERSION:-}" != "${internal_testflight_build_number}" ] ||
       [ "${CODE_SIGN_ENTITLEMENTS:-}" != "SoraPassport/SoraPassport.entitlements" ] ||
       [ "${INFOPLIST_FILE:-}" != "SoraPassport/Info.plist" ] ||
       [ "${SORA_APPLICATION_CONFIG:-}" != "Release" ] ||
       [ "${SORA_NAME:-}" != "SORA" ] ||
       [ "${CODE_SIGNING_ALLOWED:-YES}" != "YES" ] ||
       [ "${CODE_SIGNING_REQUIRED:-YES}" != "YES" ] ||
       [ "${#internal_testflight_source_revision}" -ne 40 ] ||
       [ "${internal_testflight_source_revision}" != "${SORA_MIGRATION_EVIDENCE_SOURCE_REVISION:-}" ]; then
        echo "error: iOS internal-only TestFlight archive capability is invalid" >&2
        exit 1
    fi
    case "${internal_testflight_source_revision}" in
        *[!0-9a-f]*)
            echo "error: iOS internal-only TestFlight source revision is invalid" >&2
            exit 1
            ;;
    esac
    case "${SDK_NAME:-}" in
        iphoneos*) ;;
        *)
            echo "error: iOS internal-only TestFlight archive requires the physical-device SDK" >&2
            exit 1
            ;;
    esac
    if [ ! -f "${internal_testflight_wrapper}" ] || [ -L "${internal_testflight_wrapper}" ] ||
       [ ! -f "${internal_testflight_export_options}" ] || [ -L "${internal_testflight_export_options}" ] ||
       [ "${#internal_testflight_export_options_sha}" -ne 64 ] ||
       [ "$({ /usr/bin/shasum -a 256 "${internal_testflight_export_options}" | /usr/bin/awk '{print $1}'; })" != "${internal_testflight_export_options_sha}" ]; then
        echo "error: iOS internal-only TestFlight upload boundary is missing or unstable" >&2
        exit 1
    fi
    if [ ! -x /usr/bin/git ] ||
       [ "$(/usr/bin/git -C "${root}" rev-parse HEAD 2>/dev/null)" != "${internal_testflight_source_revision}" ] ||
       [ "$(/usr/bin/git -C "${root}" rev-parse '@{upstream}' 2>/dev/null)" != "${internal_testflight_source_revision}" ] ||
       [ "$(/usr/bin/git -C "${root}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" != "origin/modernize" ] ||
       [ "$(/usr/bin/git -C "${root}" rev-parse HEAD^ 2>/dev/null)" != "d657f9ccc55ba1f9558c474229bc470375a71bfd" ] ||
       [ "$(/usr/bin/git -C "${root}" rev-list --count "d657f9ccc55ba1f9558c474229bc470375a71bfd..${internal_testflight_source_revision}" 2>/dev/null)" != "1" ] ||
       [ "$(/usr/bin/git -C "${root}" diff --name-only --no-renames "d657f9ccc55ba1f9558c474229bc470375a71bfd..${internal_testflight_source_revision}" 2>/dev/null)" != 'SoraPassport/Scripts/test-ios-internal-testflight-upload.py
SoraPassport/Scripts/test-ios-migration-release-boundary.py
SoraPassport/Scripts/upload-ios-internal-testflight.sh
SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py
SoraPassport/Scripts/verify-modernization-dependencies.sh
VendorPackages/JOSESwift/Package.swift' ] ||
       [ -n "$(/usr/bin/git -C "${root}" status --porcelain=v1 --untracked-files=normal)" ]; then
        echo "error: iOS internal-only TestFlight source is not the exact clean pushed revision" >&2
        exit 1
    fi
    unset SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_MODE
    unset SORA_IOS_INTERNAL_TESTFLIGHT_UPLOAD_ACTION
    unset SORA_IOS_INTERNAL_TESTFLIGHT_BUILD_NUMBER
    unset SORA_IOS_INTERNAL_TESTFLIGHT_SOURCE_REVISION
    unset SORA_IOS_INTERNAL_TESTFLIGHT_EXPORT_OPTIONS_SHA256
    run_ios_migration_release_source_gate
    /bin/sh "${internal_testflight_wrapper}" --lint-contract >/dev/null
    /usr/bin/printf '%s\n' \
        'warning: internal-TestFlight-only archive is non-authorizing; protected migration, canary, rollout, and promotion admission are not granted' >&2
    exit 0
fi
migration_candidate_archive_mode="${SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_MODE:-}"
migration_candidate_archive_active=false
if [ -n "${migration_candidate_archive_mode}" ]; then
    if [ "${migration_candidate_archive_mode}" != "sora-ios-migration-observed-only-candidate-archive-v1" ] ||
       [ "${SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION:-}" != "archive" ] ||
       [ -n "${SORA_IOS_MIGRATION_EVIDENCE_BUILD_MODE:-}" ] ||
       [ -n "${release_test_mode}" ] ||
       [ "${ACTION:-}" != "install" ] ||
       [ "${CONFIGURATION:-}" != "Release" ] ||
       [ "${PLATFORM_NAME:-}" != "iphoneos" ] ||
       [ "${EFFECTIVE_PLATFORM_NAME:-}" != "-iphoneos" ] ||
       [ "${DEPLOYMENT_LOCATION:-}" != "YES" ] ||
       [ "${TARGET_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "co.jp.soramitsu.sora" ] ||
       [ "${DEVELOPMENT_TEAM:-}" != "YLWWUD25VZ" ] ||
       [ "${CODE_SIGN_ENTITLEMENTS:-}" != "SoraPassport/SoraPassport.entitlements" ] ||
       [ "${INFOPLIST_FILE:-}" != "SoraPassport/Info.plist" ] ||
       [ "${SORA_APPLICATION_CONFIG:-}" != "Release" ] ||
       [ "${SORA_NAME:-}" != "SORA" ] ||
       [ "${CODE_SIGNING_ALLOWED:-YES}" != "YES" ] ||
       [ "${CODE_SIGNING_REQUIRED:-YES}" != "YES" ]; then
        echo "error: iOS migration observed-only candidate archive capability is invalid" >&2
        exit 1
    fi
    case "${SDK_NAME:-}" in
        iphoneos*) ;;
        *)
            echo "error: iOS migration candidate archive requires the physical-device SDK" >&2
            exit 1
            ;;
    esac
    migration_candidate_archive_active=true
fi

# A dedicated physical-device Release build-for-testing is allowed to precede
# migration qualification because it is an input producer, not a promotion
# action. The caller must opt into the exact observed-only capability and Xcode
# must still report a non-deployment build of the preserved production target.
migration_evidence_build_mode="${SORA_IOS_MIGRATION_EVIDENCE_BUILD_MODE:-}"
if [ -n "${migration_evidence_build_mode}" ]; then
    if [ "${migration_evidence_build_mode}" != "sora-ios-migration-observed-only-build-v1" ] ||
       [ "${SORA_IOS_MIGRATION_EVIDENCE_BUILD_ACTION:-}" != "build-for-testing" ] ||
       [ -n "${release_test_mode}" ] ||
       [ "${ACTION:-}" != "build" ] ||
       [ "${CONFIGURATION:-}" != "Release" ] ||
       [ "${PLATFORM_NAME:-}" != "iphoneos" ] ||
       [ "${EFFECTIVE_PLATFORM_NAME:-}" != "-iphoneos" ] ||
       [ "${DEPLOYMENT_LOCATION:-NO}" != "NO" ] ||
       [ "${TARGET_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_NAME:-}" != "SoraPassport" ] ||
       [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "co.jp.soramitsu.sora" ] ||
       [ "${DEVELOPMENT_TEAM:-}" != "YLWWUD25VZ" ] ||
       [ "${CODE_SIGN_ENTITLEMENTS:-}" != "SoraPassport/SoraPassport.entitlements" ] ||
       [ "${INFOPLIST_FILE:-}" != "SoraPassport/Info.plist" ] ||
       [ "${SORA_APPLICATION_CONFIG:-}" != "Release" ] ||
       [ "${SORA_NAME:-}" != "SORA" ]; then
        echo "error: iOS migration observed-only Release build capability is invalid" >&2
        exit 1
    fi
    case "${SDK_NAME:-}" in
        iphoneos*) ;;
        *)
            echo "error: iOS migration observed-only build requires a physical-device SDK" >&2
            exit 1
            ;;
    esac

    rollout_validator="${root}/SoraPassport/Scripts/verify-production-rollout.sh"
    rollout_regression_harness="${root}/SoraPassport/Scripts/test-production-rollout-contract.py"
    funded_canary_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary.sh"
    migration_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.sh"
    migration_collector_validator="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.sh"
    migration_collector_harness="${root}/SoraPassport/Scripts/test-ios-migration-evidence-collector.py"
    migration_evidence_builder="${root}/SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh"
    migration_candidate_archiver="${root}/SoraPassport/Scripts/archive-ios-migration-candidate.sh"
    migration_candidate_handoff="${root}/SoraPassport/Scripts/create-ios-migration-candidate-handoff.py"
    migration_promotion_admission="${root}/SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"
    migration_release_boundary_harness="${root}/SoraPassport/Scripts/test-ios-migration-release-boundary.py"
    vendored_binary_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh"
    if [ ! -f "${migration_evidence_builder}" ] || [ -L "${migration_evidence_builder}" ] ||
       [ ! -f "${migration_candidate_archiver}" ] || [ -L "${migration_candidate_archiver}" ] ||
       [ ! -f "${migration_candidate_handoff}" ] || [ -L "${migration_candidate_handoff}" ] ||
       [ ! -f "${migration_promotion_admission}" ] || [ -L "${migration_promotion_admission}" ] ||
       [ ! -f "${migration_release_boundary_harness}" ] || [ -L "${migration_release_boundary_harness}" ]; then
        echo "error: iOS migration observed-only build boundary is missing or symbolic" >&2
        exit 1
    fi
    run_ios_migration_release_source_gate
    /bin/sh "${migration_candidate_archiver}" --lint-contract >/dev/null
    /bin/sh "${migration_promotion_admission}" --lint-contract >/dev/null
    /bin/sh "${rollout_validator}" --lint-templates >/dev/null
    /bin/sh "${funded_canary_validator}" --lint-templates >/dev/null
    /bin/sh "${vendored_binary_qualification_validator}" --lint-templates >/dev/null
    /usr/bin/python3 -B -I -S "${rollout_regression_harness}" >/dev/null
    exit 0
fi

# Release simulator tests need the optimized application binary, but an unsigned
# simulator product is neither an archive nor migration/rollout evidence. Admit
# only the exact wrapper capability and resolved main-target settings, run the
# complete hermetic source contract, and exit before every protected production
# identity, receipt, archive, funded-canary, or promotion branch below.
if [ -n "${release_test_mode}" ]; then
    if [ "${release_test_mode}" != "sora-ios-nonpromoting-release-simulator-test-v1" ] ||
       [ "${release_test_action}" != "test" ] ||
       [ -n "${migration_candidate_archive_mode}" ] ||
       [ -n "${migration_evidence_build_mode}" ] ||
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
       [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ] ||
       [ "${CODE_SIGNING_REQUIRED:-YES}" != "NO" ] ||
       [ "${ENABLE_TESTABILITY:-NO}" != "YES" ] ||
       [ "${ONLY_ACTIVE_ARCH:-NO}" != "YES" ] ||
       [ "${ARCHS:-}" != "arm64" ] ||
       [ "${EXCLUDED_ARCHS:-}" != "x86_64" ]; then
        echo "error: iOS non-promoting Release simulator test capability is invalid" >&2
        exit 1
    fi
    case "${SDK_NAME:-}" in
        iphonesimulator*) ;;
        *)
            echo "error: iOS non-promoting Release tests require the simulator SDK" >&2
            exit 1
            ;;
    esac

    rollout_validator="${root}/SoraPassport/Scripts/verify-production-rollout.sh"
    rollout_regression_harness="${root}/SoraPassport/Scripts/test-production-rollout-contract.py"
    funded_canary_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary.sh"
    vendored_binary_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh"
    for release_test_required in \
        "${rollout_validator}" \
        "${rollout_regression_harness}" \
        "${funded_canary_validator}" \
        "${vendored_binary_qualification_validator}"
    do
        if [ ! -f "${release_test_required}" ] || [ -L "${release_test_required}" ]; then
            echo "error: iOS non-promoting Release-test source is missing or symbolic" >&2
            exit 1
        fi
    done
    run_ios_migration_release_source_gate
    /bin/sh "${rollout_validator}" --lint-templates >/dev/null
    /bin/sh "${funded_canary_validator}" --lint-templates >/dev/null
    /bin/sh "${vendored_binary_qualification_validator}" --lint-templates >/dev/null
    /usr/bin/python3 -B -I -S "${rollout_regression_harness}" >/dev/null
    echo "warning: optimized simulator XCTest build is non-authorizing and cannot satisfy physical-device, signing, archive, migration, canary, or rollout admission" >&2
    exit 0
fi

# Every configuration executes the hermetic, non-promoting rollout contract.
# Only Release or explicit standalone qualification continues into the strict
# production dependency/evidence gates below.
if [ -n "${CONFIGURATION:-}" ] && [ "${CONFIGURATION}" != "Release" ]; then
    rollout_validator="${root}/SoraPassport/Scripts/verify-production-rollout.sh"
    rollout_regression_harness="${root}/SoraPassport/Scripts/test-production-rollout-contract.py"
    funded_canary_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary.sh"
    migration_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.sh"
    migration_qualification_json_validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.py"
    migration_collector_validator="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.sh"
    migration_collector_harness="${root}/SoraPassport/Scripts/test-ios-migration-evidence-collector.py"
    migration_evidence_builder="${root}/SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh"
    migration_candidate_archiver="${root}/SoraPassport/Scripts/archive-ios-migration-candidate.sh"
    migration_candidate_handoff="${root}/SoraPassport/Scripts/create-ios-migration-candidate-handoff.py"
    migration_promotion_admission="${root}/SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"
    migration_release_boundary_harness="${root}/SoraPassport/Scripts/test-ios-migration-release-boundary.py"
    vendored_binary_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh"
    vendored_binary_qualification_json_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.py"
    signing_identity_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.sh"
    signing_identity_qualification_json_validator="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.py"
    if [ ! -f "${rollout_validator}" ] ||
       [ -L "${rollout_validator}" ] ||
       [ ! -f "${rollout_regression_harness}" ] ||
       [ -L "${rollout_regression_harness}" ] ||
       [ ! -f "${funded_canary_validator}" ] ||
       [ -L "${funded_canary_validator}" ] ||
       [ ! -f "${migration_qualification_validator}" ] ||
       [ -L "${migration_qualification_validator}" ] ||
       [ ! -f "${migration_qualification_json_validator}" ] ||
       [ -L "${migration_qualification_json_validator}" ] ||
       [ ! -f "${migration_collector_validator}" ] ||
       [ -L "${migration_collector_validator}" ] ||
       [ ! -f "${migration_collector_harness}" ] ||
       [ -L "${migration_collector_harness}" ] ||
       [ ! -f "${migration_evidence_builder}" ] ||
       [ -L "${migration_evidence_builder}" ] ||
       [ ! -f "${migration_candidate_archiver}" ] ||
       [ -L "${migration_candidate_archiver}" ] ||
       [ ! -f "${migration_candidate_handoff}" ] ||
       [ -L "${migration_candidate_handoff}" ] ||
       [ ! -f "${migration_promotion_admission}" ] ||
       [ -L "${migration_promotion_admission}" ] ||
       [ ! -f "${migration_release_boundary_harness}" ] ||
       [ -L "${migration_release_boundary_harness}" ] ||
       [ ! -f "${vendored_binary_qualification_validator}" ] ||
       [ -L "${vendored_binary_qualification_validator}" ] ||
       [ ! -f "${vendored_binary_qualification_json_validator}" ] ||
       [ -L "${vendored_binary_qualification_json_validator}" ] ||
       [ ! -f "${signing_identity_qualification_validator}" ] ||
       [ -L "${signing_identity_qualification_validator}" ] ||
       [ ! -f "${signing_identity_qualification_json_validator}" ] ||
       [ -L "${signing_identity_qualification_json_validator}" ]; then
        echo "error: hermetic production rollout contract regression is missing or symbolic"
        exit 1
    fi
    /bin/sh "${rollout_validator}" --lint-templates >/dev/null
    /bin/sh "${funded_canary_validator}" --lint-templates >/dev/null
    /bin/sh "${migration_qualification_validator}" --lint-templates >/dev/null
    /bin/sh "${migration_collector_validator}" --lint-contract >/dev/null
    /usr/bin/python3 -I -S "${migration_collector_harness}" >/dev/null
    /bin/sh "${migration_evidence_builder}" --lint-contract >/dev/null
    /bin/sh "${migration_candidate_archiver}" --lint-contract >/dev/null
    /bin/sh "${migration_promotion_admission}" --lint-contract >/dev/null
    /usr/bin/python3 -I -S "${migration_release_boundary_harness}" >/dev/null
    /bin/sh "${vendored_binary_qualification_validator}" --lint-templates >/dev/null
    /bin/sh "${signing_identity_qualification_validator}" --lint-templates >/dev/null
    /usr/bin/python3 -I -S "${rollout_regression_harness}" >/dev/null
    exit 0
fi

# In an actual Release build, trust Xcode's resolved main-target values rather
# than the presence of matching tokens elsewhere in the project file. Standalone
# audit/template invocations have no CONFIGURATION and are source-resolved below.
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

manifest="${root}/SoraPassport/Configs/ModernizationDependencies.conf"
iroha_source="${root}/Vendor/IrohaSwift"
bridge="${root}/Vendor/NoritoBridge.xcframework"
project="${root}/SoraPassport.xcodeproj/project.pbxproj"
production_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassport.xcscheme"
unit_test_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportTests.xcscheme"
release_xcconfig="${root}/SoraPassport/Configs/SoraPassport.release.xcconfig"
production_info_plist="${root}/SoraPassport/Info.plist"
ci_pipeline="${root}/Jenkinsfile"
xnetworking_manifest="${root}/VendorPackages/shared-features-spm/Package.swift"
rswift_manifest="${root}/VendorPackages/Rswift/Package.swift"
google_signin_manifest="${root}/VendorPackages/GoogleSignIn-iOS/Package.swift"
google_api_manifest="${root}/VendorPackages/google-api-objectivec-client-for-rest/Package.swift"
jose_manifest="${root}/VendorPackages/JOSESwift/Package.swift"
swiftpm_resolution="${root}/SoraPassport.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
rswift_resolution="${root}/VendorPackages/Rswift/Package.resolved"
wallet_derivation_fixture="${root}/Fixtures/Modernization/wallet-derivation-v1.json"
release_probe="${root}/Fixtures/Modernization/release-probe-evidence-2026-08-02.json"
iroha_readiness="${root}/Fixtures/Modernization/iroha-production-send-readiness.json"
native_canary_qualification="${root}/Fixtures/Modernization/iroha-native-canary-qualification-v1.json"
vendored_binary_readiness="${root}/Fixtures/Modernization/ios-vendored-binary-readiness.json"
vendored_binary_qualification="${root}/Fixtures/Modernization/ios-vendored-binary-qualification.json"
vendored_binary_qualification_blocked="${root}/Fixtures/Modernization/ios-vendored-binary-qualification.blocked.json"
vendored_binary_evidence_blocked="${root}/Fixtures/Modernization/ios-vendored-binary-qualification-evidence.blocked.json"
vendored_binary_trust_blocked="${root}/Fixtures/Modernization/ios-vendored-binary-qualification-trust.blocked.json"
vendored_binary_documentation="${root}/Fixtures/Modernization/ios-vendored-binary-qualification-README.md"
vendored_binary_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh"
vendored_binary_qualification_json_validator="${root}/SoraPassport/Scripts/verify-ios-vendored-binary-qualification.py"
vendored_binary_qualification_harness="${root}/SoraPassport/Scripts/test-ios-vendored-binary-qualification.py"
ios_signing_identity="${root}/Fixtures/Modernization/ios-production-signing-identity.json"
ios_signing_qualification="${root}/Fixtures/Modernization/ios-production-signing-identity-qualification.json"
ios_signing_qualification_trust="${root}/Fixtures/Modernization/ios-production-signing-identity-qualification-trust.json"
ios_signing_qualification_blocked="${root}/Fixtures/Modernization/ios-production-signing-identity-qualification.blocked.json"
ios_signing_qualification_trust_blocked="${root}/Fixtures/Modernization/ios-production-signing-identity-qualification-trust.blocked.json"
ios_signing_qualification_documentation="${root}/Fixtures/Modernization/ios-production-signing-identity-qualification-README.md"
ios_signing_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.sh"
ios_signing_qualification_json_validator="${root}/SoraPassport/Scripts/verify-ios-production-signing-identity.py"
ios_signing_qualification_harness="${root}/SoraPassport/Scripts/test-ios-production-signing-identity.py"
ios_entitlements="${root}/SoraPassport/SoraPassport.entitlements"
polkamarkt_contract="${root}/Fixtures/Modernization/polkamarkt-runtime-v130.json"
migration_qualification="${root}/Fixtures/Modernization/ios-migration-qualification.json"
migration_qualification_validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.sh"
migration_qualification_json_validator="${root}/SoraPassport/Scripts/verify-ios-migration-qualification.py"
migration_collector_validator="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.sh"
migration_collector_json_validator="${root}/SoraPassport/Scripts/collect-ios-migration-evidence.py"
migration_collector_harness="${root}/SoraPassport/Scripts/test-ios-migration-evidence-collector.py"
migration_collection_runner="${root}/SoraPassport/Scripts/run-ios-migration-evidence-collection.sh"
migration_collection_pipeline="${root}/Jenkinsfile.migration-evidence"
migration_evidence_builder="${root}/SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh"
migration_candidate_archiver="${root}/SoraPassport/Scripts/archive-ios-migration-candidate.sh"
internal_testflight_uploader="${root}/SoraPassport/Scripts/upload-ios-internal-testflight.sh"
internal_testflight_delivery_verifier="${root}/SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py"
internal_testflight_export_options="${root}/SoraPassport/Configs/ios-internal-testflight-export-options.plist"
internal_testflight_harness="${root}/SoraPassport/Scripts/test-ios-internal-testflight-upload.py"
internal_testflight_source_contract_manifest="${root}/Fixtures/Modernization/ios-migration-qualification-contract-v1.json"
migration_candidate_handoff="${root}/SoraPassport/Scripts/create-ios-migration-candidate-handoff.py"
migration_test_host_deriver="${root}/SoraPassport/Scripts/derive-ios-migration-test-host.sh"
migration_test_host_projector="${root}/SoraPassport/Scripts/derive-ios-migration-test-host.py"
migration_test_host_projector_harness="${root}/SoraPassport/Scripts/test-ios-migration-test-host-derivation.py"
migration_candidate_export_options="${root}/SoraPassport/Configs/ios-migration-candidate-export-options.plist"
migration_promotion_admission="${root}/SoraPassport/Scripts/verify-ios-migration-promotion-ipa.sh"
migration_release_boundary_harness="${root}/SoraPassport/Scripts/test-ios-migration-release-boundary.py"
release_test_runner="${root}/SoraPassport/Scripts/run-ios-release-tests.sh"
migration_evidence_scheme="${root}/SoraPassport.xcodeproj/xcshareddata/xcschemes/SoraPassportMigrationEvidence.xcscheme"
migration_evidence_tests="${root}/SoraPassportIntegrationTests/WalletMigrationRetainedDeviceEvidenceTests.swift"
user_data_model_v1="${root}/SoraPassport/Common/Storage/UserDataModel.xcdatamodeld/UserDataModel.xcdatamodel/contents"
user_data_model_v2="${root}/SoraPassport/Common/Storage/UserDataModel.xcdatamodeld/UserDataModel 2.xcdatamodel/contents"
minamoto_canary="${root}/Fixtures/Modernization/minamoto-funded-canary.json"
taira_canary="${root}/Fixtures/Modernization/taira-funded-canary.json"
funded_canary_trust="${root}/Fixtures/Modernization/funded-nexus-canary-trust.json"
funded_canary_documentation="${root}/Fixtures/Modernization/funded-nexus-canary-README.md"
funded_canary_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary.sh"
funded_canary_json_validator="${root}/SoraPassport/Scripts/verify-funded-nexus-canary-json.py"
taira_deployment_blocked="${root}/Fixtures/Modernization/ios-taira-deployment-manifest.blocked.json"
taira_deployment_validator="${root}/SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
taira_deployment_harness="${root}/SoraPassport/Scripts/test-ios-taira-deployment-manifest.py"
rollout_candidate_template="${root}/Fixtures/Modernization/production-rollout-candidate.blocked.json"
rollout_template="${root}/Fixtures/Modernization/production-rollout-advancement.blocked.json"
rollout_controller_trust="${root}/Fixtures/Modernization/production-rollout-controller-trust.json"
rollout_documentation="${root}/Fixtures/Modernization/production-rollout-README.md"
dependency_verifier="${root}/SoraPassport/Scripts/verify-modernization-dependencies.sh"
rollout_validator="${root}/SoraPassport/Scripts/verify-production-rollout.sh"
rollout_json_validator="${root}/SoraPassport/Scripts/verify-production-rollout-json.py"
rollout_regression_harness="${root}/SoraPassport/Scripts/test-production-rollout-contract.py"
application_info_plist="${root}/SoraPassport/Info.plist"
nexus_service="${root}/SoraPassport/Common/Model/NexusWalletService.swift"
nexus_ui="${root}/SoraPassport/ModulesRedesign/MoreMenu/NexusPortfolioViewController.swift"
more_menu_presenter="${root}/SoraPassport/ModulesRedesign/MoreMenu/MoreMenuPresenter.swift"
app_settings_presenter="${root}/SoraPassport/ModulesRedesign/AppSettings/AppSettingsPresenter.swift"
app_delegate="${root}/SoraPassport/AppDelegate.swift"
service_coordinator="${root}/SoraPassport/Common/Services/ServiceCoordinator.swift"
splash_interactor="${root}/SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift"
more_menu_view="${root}/SoraPassport/ModulesRedesign/MoreMenu/MoreMenuViewController.swift"
more_menu_wireframe="${root}/SoraPassport/ModulesRedesign/MoreMenu/MoreMenuWireframe.swift"
main_tab_wireframe="${root}/SoraPassport/ModulesRedesign/MainTabBar/MainTabBarWireframe.swift"
pi_client="${root}/SoraPassport/Common/Network/Subquery/PIIndexerClient.swift"
pi_history_operation="${root}/SoraPassport/Common/Network/Subquery/SubqueryHistoryOperation.swift"
pi_referral_operation="${root}/SoraPassport/Common/Network/Subquery/ReferrerRewards/SubqueryReferralRewardsOperation.swift"
pi_config_operation="${root}/SoraPassport/Common/Config/SubqueryConfigInfoOperation.swift"
config_service="${root}/SoraPassport/Common/Config/ConfigService.swift"
application_configs="${root}/SoraPassport/Common/Configs/ApplicationConfigs.swift"
settings_extension="${root}/SoraPassport/Common/Extensions/SettingsExtension.swift"
storage_migrator="${root}/SoraPassport/Common/Migration/StorageMigrator.swift"
user_storage_version="${root}/SoraPassport/Common/Migration/UserStorageVersion.swift"
user_data_storage_facade="${root}/SoraPassport/Common/Storage/UserDataStorageFacade.swift"
persistent_store_extensions="${root}/SoraPassport/Common/Storage/PersistentStoreCoordinator+Extensions.swift"
keystore_extensions="${root}/SoraPassport/Common/Extensions/KeystoreExtensions.swift"
keystore_protocol="${root}/VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/Keychain/KeystoreProtocols.swift"
keystore_implementation="${root}/VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/Keychain/Keychain.swift"
settings_protocol="${root}/VendorPackages/shared-features-spm/Sources/SoraKeystore/Classes/UserDefaults/SettingsProtocols.swift"
modernization_tests="${root}/SoraPassportTests/Common/Modernization/WalletModernizationTests.swift"
json_rpc_integration_tests="${root}/SoraPassportIntegrationTests/Substrate/JSONRPCTests.swift"
json_rpc_pool_integration_tests="${root}/SoraPassportIntegrationTests/Substrate/JSONRPCPoolXYKTests.swift"
assets_info_integration_tests="${root}/SoraPassportIntegrationTests/AssetsInfoProviderTests.swift"
module_mocks="${root}/SoraPassportTests/Mocks/ModuleMocks.swift"
recovery_gate_tests="${root}/SoraPassportTests/Common/Modernization/WalletRecoveryCapabilityGateTests.swift"
recovery_exporter="${root}/SoraPassport/Common/Migration/WalletRecoveryExporter.swift"
recovery_export_tests="${root}/SoraPassportTests/Common/Modernization/WalletRecoveryExporterTests.swift"
wallet_network_model="${root}/SoraPassport/Common/Model/WalletNetworkModel.swift"
iroha_address_codec="${root}/SoraPassport/Common/Model/IrohaAddressCodec.swift"
selected_wallet_settings="${root}/SoraPassport/Common/Storage/SelectedWalletSettings.swift"
account_options="${root}/SoraPassport/ModulesRedesign/AccountOptions/AccountOptionsInteractor.swift"
account_options_presenter="${root}/SoraPassport/ModulesRedesign/AccountOptions/AccountOptionsPresenter.swift"
account_options_wireframe="${root}/SoraPassport/ModulesRedesign/AccountOptions/AccountOptionsWireframe.swift"
raw_seed_export="${root}/SoraPassport/ModulesRedesign/ExportRawSeed/AccountExportRawSeedInteractor.swift"
json_wallet_export="${root}/SoraPassport/ModulesRedesign/ExportJson/AccountExportInteractor.swift"
keystore_import_service="${root}/SoraPassport/Common/URLHandling/KeystoreImportService.swift"
wallet_context_factory="${root}/SoraPassport/Common/WalletContext/WalletContextFactory.swift"
legacy_migration_service="${root}/SoraPassport/ModulesRedesign/Migration/MigrationService.swift"
transferable_item_service="${root}/SoraPassport/ModulesRedesign/AssetDetails/Transferable/TransferableItemService.swift"
sora_history_wallet_mapper="${root}/SoraPassport/Common/Network/Subquery/SoraHistoryItem+Wallet.swift"
history_transaction_mapper="${root}/SoraPassport/Common/HistoryService/HistoryTransactionMapper.swift"
subquery_history_wallet_mapper="${root}/SoraPassport/Common/Network/Subquery/SubqueryHistoryElement+Wallet.swift"
snapshot_hot_boot_builder="${root}/SoraPassport/Common/Services/ChainRegistry/RuntimeProviderPool/SnapshotHotBootBuilder.swift"
runtime_snapshot_factory="${root}/SoraPassport/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeSnapshotOperationFactory.swift"
runtime_hot_snapshot_factory="${root}/SoraPassport/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeHotBootSnapshotFactory.swift"
runtime_sync_service="${root}/SoraPassport/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeSyncService.swift"
runtime_provider="${root}/SoraPassport/Common/Services/ChainRegistry/RuntimeProviderPool/RuntimeProvider.swift"
common_types_sync_service="${root}/SoraPassport/Common/Services/ChainRegistry/RuntimeProviderPool/CommonTypesSyncService.swift"
chain_registry_factory="${root}/SoraPassport/Common/Services/ChainRegistry/ChainRegistryFactory.swift"
runtime_default_types="${root}/SoraPassport/Resources/runtime-default.json"
runtime_sora_types="${root}/SoraPassport/Resources/runtime-sora.json"
polkamarkt_runtime="${root}/SoraPassport/Common/Model/PolkamarktRuntime.swift"
polkamarkt_ui="${root}/SoraPassport/ModulesRedesign/MoreMenu/PolkamarktViewController.swift"
market_cap_operation="${root}/SoraPassport/Common/MarketCap/SubqueryMarketCapOperation.swift"
market_cap_service="${root}/SoraPassport/Common/MarketCap/MarketCapService.swift"
fiat_service="${root}/SoraPassport/Common/Fiat/FiatService.swift"
fiat_operation="${root}/SoraPassport/Common/Fiat/SubqueryFiatInfoOperation.swift"
apy_service="${root}/SoraPassport/Common/APY/APYService.swift"
apy_operation="${root}/SoraPassport/Common/Network/Subquery/Pools/SubqueryApyInfoOperation.swift"
signing_wrapper="${root}/SoraPassport/Common/Crypto/SigningWrapper.swift"
signing_protocol="${root}/SoraPassport/Common/Crypto/SigningWrapperProtocol.swift"
ed25519_seed_signer="${root}/VendorPackages/shared-features-spm/Sources/IrohaCrypto/Classes/ed25519/EDSeedSigner.m"
ed25519_legacy_signer="${root}/VendorPackages/shared-features-spm/Sources/IrohaCrypto/Classes/ed25519/EDSigner.m"
ed25519_umbrella="${root}/VendorPackages/shared-features-spm/Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h"
ssf_transaction_signer="${root}/VendorPackages/shared-features-spm/Sources/SSFSigner/SSFSigner/Classes/TransactionSigner.swift"
iroha_signing_decorator="${root}/SoraPassport/Common/Crypto/IRSigningDecorator.swift"
extrinsic_service="${root}/SoraPassport/Common/Services/ExtrinsicService.swift"
account_create="${root}/SoraPassport/ModulesRedesign/AccountCreate/AccountCreateInteractor.swift"
account_import="${root}/SoraPassport/ModulesRedesign/AccountImport/BaseAccountImportInteractor.swift"
account_import_commit="${root}/SoraPassport/ModulesRedesign/AccountImport/AccountImportInteractor.swift"
account_import_factory="${root}/SoraPassport/ModulesRedesign/AccountImport/AccountImportViewFactory.swift"
account_confirm="${root}/SoraPassport/ModulesRedesign/AccountConfirm/AccountConfirmInteractor.swift"
add_account_import="${root}/SoraPassport/ModulesRedesign/AccountAdd/Interactors/AddAccountImportInteractor.swift"
add_account_confirm="${root}/SoraPassport/ModulesRedesign/AccountAdd/Interactors/AddAccountConfirmInteractor.swift"
create_account_service="${root}/SoraPassport/ModulesRedesign/SetupPassword/CreateAccountService.swift"
change_account="${root}/SoraPassport/ModulesRedesign/ChangeAccount/ChangeAccountPresenter.swift"
event_center="${root}/SoraPassport/Common/EventCenter/EventCenter.swift"
event_protocols="${root}/SoraPassport/Common/EventCenter/EventProtocols.swift"
asset_manager="${root}/SoraPassport/Common/Helpers/AssetManager.swift"
account_factory="${root}/SoraPassport/Common/Operation/AccountOperationFactory.swift"
splash_interactor="${root}/SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift"
root_interactor="${root}/SoraPassport/ModulesRedesign/Root/RootInteractor.swift"
root_wireframe="${root}/SoraPassport/ModulesRedesign/Root/RootWireframe.swift"
pin_setup="${root}/SoraPassport/ModulesRedesign/Pincode/PinSetup/PinSetupInteractor.swift"
local_auth="${root}/SoraPassport/ModulesRedesign/Pincode/LocalAuthentification/LocalAuthInteractor.swift"
polkaswap_slippage="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Common/SlippageTolerance/SlippageToleranceView.swift"
polkaswap_accessory="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Common/AccessoryView/InputAccessoryView.swift"
polkaswap_swap="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Swap/SwapViewModel.swift"
polkaswap_confirm_swap="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Swap/ConfirmSwapViewModel.swift"
polkaswap_liquidity_wireframe="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Liquidity/LiquidityWireframe.swift"
polkaswap_confirm_supply="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Liquidity/Supply/ConfirmSupplyLiquidityViewModel.swift"
polkaswap_confirm_remove="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Liquidity/Remove/ConfirmRemoveLiquidityViewModel.swift"
polkaswap_supply="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Liquidity/Supply/SupplyLiquidityViewModel.swift"
polkaswap_remove="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Liquidity/Remove/RemoveLiquidityViewModel.swift"
account_pools_service="${root}/SoraPassport/Common/Pools/AccountPoolsService.swift"
polkaswap_transfer_info="${root}/SoraPassport/Common/Extensions/Wallet/TransferInfo+Type.swift"
polkaswap_network_factory="${root}/SoraPassport/Common/Network/SubstrateWallet/WalletNetworkOperationFactory+Protocol.swift"
wallet_network_factory_protocol="${root}/SoraPassport/Common/Legacy/WalletNetworkOperationFactoryProtocol.swift"
wallet_network_factory_mock="${root}/SoraPassportTests/Mocks/WalletNetworkOperationFactoryProtocolMock.swift"
wallet_network_factory_impl="${root}/SoraPassport/Common/Network/SubstrateWallet/WalletNetworkOperationFactory.swift"
extrinsic_service="${root}/SoraPassport/Common/Services/ExtrinsicService.swift"
extrinsic_builder="${root}/SoraPassport/Common/Services/ExtrinsicBuilder.swift"
confirm_view_controller="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Common/Confirm/ConfirmViewController.swift"
confirm_sending="${root}/SoraPassport/ModulesRedesign/ConfirmSending/ConfirmSendingViewModel.swift"
input_asset_amount="${root}/SoraPassport/ModulesRedesign/InputAssetAmount/InputAssetAmountViewModel.swift"
generate_qr="${root}/SoraPassport/ModulesRedesign/GenerateQR/GenerateQRViewModel.swift"
wallet_service_protocol="${root}/SoraPassport/Common/WalletService/WalletServiceProtocols.swift"
wallet_service="${root}/SoraPassport/Common/WalletService/WalletService.swift"
runtime_dispatch_info="${root}/SoraPassport/Common/Network/JSONRPC/RuntimeDispatchInfo.swift"
polkaswap_wallet_facade_protocol="${root}/SoraPassport/Common/Network/SubstrateWallet/WalletNetworkFacade+Protocol.swift"
wallet_history_facade="${root}/SoraPassport/Common/Network/SubstrateWallet/WalletNetworkFacade+TxHistory.swift"
polkaswap_balance_storage="${root}/SoraPassport/Common/Network/SubstrateWallet/WalletNetworkFacade+Storage.swift"
polkaswap_history="${root}/SoraPassport/Common/Extensions/Wallet/TransactionHistoryItem+Wallet.swift"
polkaswap_history_mapper="${root}/SoraPassport/Common/Extensions/Wallet/AssetTransactionData+HistoryItemData.swift"
history_merge_manager="${root}/SoraPassport/Common/Helpers/TransactionHistoryMergeManager.swift"
polkaswap_call_path="${root}/SoraPassport/Common/Substrate/Types/CallCodingPath.swift"
polkaswap_fee_provider="${root}/SoraPassport/Common/Substrate/FeeProvider.swift"
polkaswap_pool_facade="${root}/SoraPassport/Common/Network/SubstrateWallet/WalletNetworkFacade+Pools.swift"
demeter_farming_service="${root}/SoraPassport/Common/DemeterFarming/DemeterFarmingService.swift"
polkaswap_pool_detail="${root}/SoraPassport/ModulesRedesign/PolkaswapProducts/Common/PoolDetails/PoolDetailFactory.swift"
edit_farm_service="${root}/SoraPassport/ModulesRedesign/EditFarm/EditFarmItemService.swift"
edit_farm_cell="${root}/SoraPassport/ModulesRedesign/EditFarm/EditFarmCell.swift"

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

require_exact_json_object_keys() {
    object_label="$1"
    object_key_path="$2"
    object_file="$3"
    shift 3

    expected_object_keys="$(/usr/bin/printf '%s\n' "$@" | /usr/bin/sort)"
    actual_object_keys="$(json_raw "${object_key_path}" "${object_file}" | /usr/bin/sort)"
    if [ "${actual_object_keys}" != "${expected_object_keys}" ]; then
        echo "error: ${object_label} contains missing or unreviewed fields"
        exit 1
    fi
}

require_exact_json_root_keys() {
    object_label="$1"
    object_file="$2"
    shift 2

    expected_object_keys="$(/usr/bin/printf '%s\n' "$@" | /usr/bin/sort)"
    actual_object_keys="$(
        /usr/bin/plutil -p "${object_file}" 2>/dev/null |
            /usr/bin/awk '
                /^  "[^"]+" =>/ {
                    key = $0
                    sub(/^  "/, "", key)
                    sub(/" =>.*$/, "", key)
                    print key
                }
            ' |
            /usr/bin/sort
    )"
    if [ "${actual_object_keys}" != "${expected_object_keys}" ]; then
        echo "error: ${object_label} contains missing or unreviewed fields"
        exit 1
    fi
}

is_uuid() {
    value="$1"

    /usr/bin/printf '%s\n' "${value}" |
        /usr/bin/grep -Eq '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
}

is_unsigned_integer() {
    case "$1" in
        ""|*[!0-9]*)
            return 1
            ;;
    esac
    return 0
}

sha256_file() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

repository_regular_file_is_unaliased() {
    relative_path="$1"
    case "${relative_path}" in
        ""|/*|.|..|../*|*/../*|*/..|*//*)
            return 1
            ;;
    esac

    relative_parent="$(/usr/bin/dirname "${relative_path}")"
    if [ "${relative_parent}" = "." ]; then
        expected_parent="${root}"
    else
        expected_parent="${root}/${relative_parent}"
    fi
    physical_parent="$(
        CDPATH= cd "${expected_parent}" && /bin/pwd -P
    )" 2>/dev/null || return 1
    [ "${physical_parent}" = "${expected_parent}" ] || return 1
    [ -f "${root}/${relative_path}" ] && [ ! -L "${root}/${relative_path}" ]
}

qualification_contract_sha256() {
    [ "$#" -eq 0 ] || return 1
    contract_snapshot="${verification_tmp}/ios-migration-qualification-contract-snapshot.json"
    /usr/bin/python3 -I -S \
        "${root}/SoraPassport/Scripts/ios-migration-qualification-contract.py" \
        --repository-root "${root}" \
        --snapshot "${contract_snapshot}"
}

verify_qualification_contract_unchanged() {
    contract_snapshot="${verification_tmp}/ios-migration-qualification-contract-snapshot.json"
    /usr/bin/python3 -I -S \
        "${root}/SoraPassport/Scripts/ios-migration-qualification-contract.py" \
        --repository-root "${root}" \
        --verify-snapshot "${contract_snapshot}" \
        --expected-sha "${migration_qualification_contract_hash}" >/dev/null
}

verify_complete_sha256_tree() {
    tree_root="$1"
    manifest_path="$2"
    expected_count="$3"
    receipt_kind="$4"
    label="$5"
    work_prefix="$6"

    if [ ! -d "${tree_root}" ] ||
       [ ! -f "${manifest_path}" ] ||
       [ -L "${manifest_path}" ]; then
        echo "error: ${label} tree or reviewed content manifest is absent"
        exit 1
    fi

    unexpected_node="$(
        cd "${tree_root}" &&
            /usr/bin/find . ! -type d ! -type f -print -quit
    )"
    if [ -n "${unexpected_node}" ]; then
        echo "error: ${label} contains an unreviewed symlink or special node: ${unexpected_node}"
        exit 1
    fi

    manifest_paths_unsorted="${verification_tmp}/${work_prefix}-manifest-paths-unsorted"
    manifest_paths="${verification_tmp}/${work_prefix}-manifest-paths"
    actual_paths_unsorted="${verification_tmp}/${work_prefix}-actual-paths-unsorted"
    actual_paths="${verification_tmp}/${work_prefix}-actual-paths"

    if ! /usr/bin/awk '
        {
            digest = substr($0, 1, 64)
            separator = substr($0, 65, 2)
            path = substr($0, 67)
            if (length(digest) != 64 ||
                digest !~ /^[0-9a-f]+$/ ||
                separator != "  " ||
                path == "" ||
                path ~ /^\// ||
                path ~ /(^|\/)\.\.?($|\/)/ ||
                seen[path]++) {
                exit 1
            }
            print path
        }
        END {
            if (NR == 0) {
                exit 1
            }
        }
    ' "${manifest_path}" > "${manifest_paths_unsorted}"; then
        echo "error: ${label} reviewed content manifest is malformed, unsafe, or contains duplicates"
        exit 1
    fi

    LC_ALL=C /usr/bin/sort "${manifest_paths_unsorted}" > "${manifest_paths}"

    (
        cd "${tree_root}"
        /usr/bin/find . -type f -print
    ) > "${actual_paths_unsorted}"

    case "${receipt_kind}" in
        iroha-source)
            /usr/bin/sed 's#^\./##' "${actual_paths_unsorted}" |
                /usr/bin/awk '
                    $0 != "PINNED_REVISION" &&
                    $0 != "PINNED_TAG" &&
                    $0 != "PROVENANCE.json" &&
                    $0 != "REVIEWED_CONTENTS.sha256"
                ' |
                LC_ALL=C /usr/bin/sort > "${actual_paths}"
            ;;
        norito-xcframework)
            /usr/bin/sed 's#^\./##' "${actual_paths_unsorted}" |
                /usr/bin/awk '
                    $0 != "UPSTREAM_ZIP_SHA256" &&
                    $0 != "PROVENANCE.json" &&
                    $0 != "REVIEWED_CONTENTS.sha256"
                ' |
                LC_ALL=C /usr/bin/sort > "${actual_paths}"
            ;;
        external-binary)
            /usr/bin/sed 's#^\./##' "${actual_paths_unsorted}" |
                LC_ALL=C /usr/bin/sort > "${actual_paths}"
            ;;
        *)
            echo "error: internal provenance verifier receipt kind is invalid"
            exit 1
            ;;
    esac

    manifest_count="$(
        /usr/bin/wc -l < "${manifest_paths}" |
            /usr/bin/tr -d '[:space:]'
    )"
    if [ "${manifest_count}" != "${expected_count}" ]; then
        echo "error: ${label} reviewed content count does not match its pinned receipt"
        exit 1
    fi

    if ! /usr/bin/cmp -s "${manifest_paths}" "${actual_paths}"; then
        echo "error: ${label} has missing or unlisted content"
        exit 1
    fi

    if ! (
        cd "${tree_root}"
        /usr/bin/shasum -a 256 -c "${manifest_path}" >/dev/null
    ); then
        echo "error: ${label} content checksum verification failed"
        exit 1
    fi
}

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

require_reviewed_sha1 \
    "Jenkins shared-library revision" \
    "${JENKINS_LIBRARY_REVISION:-}"
require_reviewed_sha1 \
    "Jenkins shared-library tree" \
    "${JENKINS_LIBRARY_TREE_OBJECT:-}"
require_reviewed_sha1 \
    "Jenkins shared-library last iOS source revision" \
    "${JENKINS_LIBRARY_LAST_IOS_SOURCE_REVISION:-}"
for jenkins_library_blob in \
    "${JENKINS_LIBRARY_IOS_APP_PIPELINE_BLOB:-}" \
    "${JENKINS_LIBRARY_IOS_PARAMS_BLOB:-}" \
    "${JENKINS_LIBRARY_IOS_FASTFILE_BLOB:-}" \
    "${JENKINS_LIBRARY_IOS_GEMFILE_BLOB:-}" \
    "${JENKINS_LIBRARY_IOS_MAIN_PIPELINE_BLOB:-}"
do
    require_reviewed_sha1 "Jenkins shared-library reviewed blob" "${jenkins_library_blob}"
done
for jenkins_library_sha256 in \
    "${JENKINS_LIBRARY_IOS_APP_PIPELINE_SHA256:-}" \
    "${JENKINS_LIBRARY_IOS_PARAMS_SHA256:-}" \
    "${JENKINS_LIBRARY_IOS_FASTFILE_SHA256:-}" \
    "${JENKINS_LIBRARY_IOS_GEMFILE_SHA256:-}" \
    "${JENKINS_LIBRARY_IOS_MAIN_PIPELINE_SHA256:-}"
do
    require_reviewed_sha256 \
        "Jenkins shared-library reviewed source" \
        "${jenkins_library_sha256}"
done

if [ "${JENKINS_LIBRARY_REPOSITORY:-}" != "https://github.com/soramitsu/jenkins-library.git" ] ||
   [ "${JENKINS_LIBRARY_DEFAULT_BRANCH:-}" != "master" ] ||
   [ "${JENKINS_LIBRARY_DEFAULT_BRANCH_PROTECTED:-}" != "false" ] ||
   [ "${JENKINS_LIBRARY_SOURCE_REVIEW_STATUS:-}" != "source-qualified" ] ||
   [ "${JENKINS_LIBRARY_COMMIT_VERIFICATION:-}" != "github-valid" ] ||
   [ "${JENKINS_LIBRARY_REVISION:-}" != "65079bbe356bca4a3d5a1964e360498735afa1f0" ] ||
   [ "${JENKINS_LIBRARY_TREE_OBJECT:-}" != "d48928bf7706be3fd7d6bb37aae43593c3ba5100" ] ||
   [ "${JENKINS_LIBRARY_LAST_IOS_SOURCE_REVISION:-}" != "0ca60fc620f80471f643ce7d9afe7f9f615b9626" ] ||
   [ "${JENKINS_LIBRARY_IOS_APP_PIPELINE_BLOB:-}" != "3bae5f60c7f54ba5ad85152485bd4fdc4a199bed" ] ||
   [ "${JENKINS_LIBRARY_IOS_APP_PIPELINE_SHA256:-}" != "7ad468a15c3bc361315b34fe2376a161e406419f51e47c41506fa4008e60a41a" ] ||
   [ "${JENKINS_LIBRARY_IOS_PARAMS_BLOB:-}" != "8a30884cb08c4f135d7c0ef98f7485ae47144f06" ] ||
   [ "${JENKINS_LIBRARY_IOS_PARAMS_SHA256:-}" != "0a660c3ca2a13000443a99aa0fe582ca04c6d9fd6d2b5004b6ce5ca06f47619d" ] ||
   [ "${JENKINS_LIBRARY_IOS_FASTFILE_BLOB:-}" != "247fec2da393632f0c84835bf9e47d316beebb53" ] ||
   [ "${JENKINS_LIBRARY_IOS_FASTFILE_SHA256:-}" != "2edde0b8c367caf0de553417384089cad01b9d1aec947cff90ada6c69e1ffaaf" ] ||
   [ "${JENKINS_LIBRARY_IOS_GEMFILE_BLOB:-}" != "9565262c3d04813065a83c8616c9c2b5ec2fb9a7" ] ||
   [ "${JENKINS_LIBRARY_IOS_GEMFILE_SHA256:-}" != "f1b125ebdd02c1b7d3b2fc832bdbfdeea55a595c0d413ce7138d728dcee4422e" ] ||
   [ "${JENKINS_LIBRARY_IOS_MAIN_PIPELINE_BLOB:-}" != "b42fc38ec57a091f46c8190a467fb7e374d0dccf" ] ||
   [ "${JENKINS_LIBRARY_IOS_MAIN_PIPELINE_SHA256:-}" != "a3623df5c044cd2a2188818745b9b58462c2f31e2b3342f0531ea1486fd7cc5e" ]; then
    echo "error: iOS production CI dependency provenance drifted"
    exit 1
fi

expected_jenkins_library_declaration="@Library('jenkins-library@${JENKINS_LIBRARY_REVISION}') _"
if [ ! -f "${ci_pipeline}" ] ||
   [ -L "${ci_pipeline}" ] ||
   ! /usr/bin/grep -Fxq "${expected_jenkins_library_declaration}" "${ci_pipeline}" ||
   ! /usr/bin/grep -Fq "appTests: true" "${ci_pipeline}" ||
   /usr/bin/grep -Fq "appTests: false" "${ci_pipeline}" ||
   ! /usr/bin/grep -Fq "new org.ios.AppPipeline(" "${ci_pipeline}" ||
   ! /usr/bin/grep -Fq "pipeline.runPipeline('sora')" "${ci_pipeline}"; then
    echo "error: iOS production CI or its immutable shared-library revision is incomplete"
    exit 1
fi

require_reviewed_sha1 "IrohaSwift upstream revision" "${IROHA_SWIFT_REVISION:-}"

if [ "${IROHA_SWIFT_UPSTREAM_TAG:-}" != "v2.0.0-rc.2.1-fearless-mobile-sdk.3" ] ||
   [ "${IROHA_SWIFT_REVISION:-}" != "4f8cfbdd17aa6a3b049e619f23ec02501e5297b6" ]; then
    echo "error: IrohaSwift upstream identity drifted from the assessed mobile SDK revision"
    exit 1
fi

if [ "${NORITO_BRIDGE_OBSERVED_MUTABLE_ARCHIVE_SHA256:-}" != "475035c7173fa6a3ea660ceae2c3f524089826dcfc78b2f74273aff43965919e" ] ||
   [ "${NORITO_BRIDGE_OBSERVED_ARTIFACT_MANIFEST_SHA256:-}" != "5c21c01528aac1de1d89f102a30201cd60d7af02decd9d23ca90db451ab87d13" ]; then
    echo "error: observation-only NoritoBridge release evidence drifted"
    exit 1
fi

if [ "${XNETWORKING_UPSTREAM_COMMIT:-}" != "b7657d4dad68dd3afee6b29b8b2909848afd38a2" ] ||
   [ "${XNETWORKING_ARCHIVE_SHA256:-}" != "43319ac6f215e95edc215366116264205902a18d480b87aa4a8c40d381a3b61a" ]; then
    echo "error: XNetworking source-rebuild provenance is not the reviewed identity"
    exit 1
fi

if [ ! -f "${xnetworking_manifest}" ] ||
   ! /usr/bin/grep -Fq "${XNETWORKING_URL}" "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq "${XNETWORKING_ARCHIVE_SHA256}" "${xnetworking_manifest}"; then
    echo "error: XNetworking package does not pin the reviewed immutable archive"
    exit 1
fi

for swiftpm_manifest in \
    "${xnetworking_manifest}" \
    "${rswift_manifest}" \
    "${google_signin_manifest}" \
    "${google_api_manifest}" \
    "${jose_manifest}"
do
    if [ ! -f "${swiftpm_manifest}" ] ||
       [ -L "${swiftpm_manifest}" ]; then
        echo "error: reviewed SwiftPM dependency manifest is absent or replaced"
        exit 1
    fi
done

if /usr/bin/grep -E \
    'from:|upToNextMajor|upToNextMinor|\.branch\(|\.range\(|\.\.<' \
    "${xnetworking_manifest}" \
    "${rswift_manifest}" \
    "${google_signin_manifest}" \
    "${google_api_manifest}" >/dev/null; then
    echo "error: Release dependency manifests contain a dynamic SwiftPM requirement"
    exit 1
fi

if ! /usr/bin/grep -Fq '.library(name: "JOSESwift", type: .static, targets: ["JOSESwift"])' "${jose_manifest}" ||
   /usr/bin/grep -Fq '.library(name: "JOSESwift", type: .dynamic' "${jose_manifest}"; then
    echo "error: JOSESwift must remain statically linked so archived apps have no unembedded runtime dependency"
    exit 1
fi

if [ "$(/usr/bin/grep -Fc 'exact: "' "${xnetworking_manifest}")" != "9" ] ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/Boilertalk/secp256k1.swift.git", exact: "0.1.7")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", exact: "1.1.0")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/ashleymills/Reachability.swift", exact: "5.2.3")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/soramitsu/fearless-starscream", exact: "4.0.12")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/attaswift/BigInt.git", exact: "5.7.0")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/daisuke-t-jp/xxHash-Swift", exact: "1.1.1")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", exact: "2.1.1")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.50.4")' "${xnetworking_manifest}" ||
   ! /usr/bin/grep -Fq '.package(url: "https://github.com/soramitsu/web3-swift", exact: "7.7.7")' "${xnetworking_manifest}"; then
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
   [ "$(/usr/bin/grep -Fc '.exact("' "${google_signin_manifest}")" != "4" ] ||
   [ "$(/usr/bin/grep -Fc 'url: "https://' "${google_signin_manifest}")" != "5" ] ||
   ! /usr/bin/grep -Fq '.exact("1.7.6"))' "${google_signin_manifest}" ||
   ! /usr/bin/grep -Fq '.exact("4.1.1"))' "${google_signin_manifest}" ||
   ! /usr/bin/grep -Fq '.exact("3.5.0"))' "${google_signin_manifest}" ||
   ! /usr/bin/grep -Fq '.exact("8.1.0"))' "${google_signin_manifest}" ||
   ! /usr/bin/grep -Fq '.revision("7291762d3551c5c7e31c49cce40a0e391a52e889")' "${google_signin_manifest}"; then
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
if [ "${project_remote_package_count}" != "14" ] ||
   [ "${project_exact_requirement_count}" != "${project_remote_package_count}" ] ||
   [ "${project_local_package_count}" != "11" ] ||
   [ "${project_vendored_local_count}" != "${project_local_package_count}" ] ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/JOSESwift;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = "VendorPackages/google-api-objectivec-client-for-rest";' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SSFStorageQueryKit;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraWalletBinary;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraUI;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraUIKit;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/FireMock;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraFoundation;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = VendorPackages/SoraDocuments;' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = "VendorPackages/GoogleSignIn-iOS";' "${project}" ||
   ! /usr/bin/grep -Fq 'relativePath = "VendorPackages/shared-features-spm";' "${project}"; then
    echo "error: Xcode package references contain a dynamic requirement or local substitution"
    exit 1
fi

for reviewed_local_package in \
    VendorPackages/JOSESwift \
    VendorPackages/google-api-objectivec-client-for-rest \
    VendorPackages/SSFStorageQueryKit \
    VendorPackages/SoraWalletBinary \
    VendorPackages/SoraUI \
    VendorPackages/SoraUIKit \
    VendorPackages/FireMock \
    VendorPackages/SoraFoundation \
    VendorPackages/SoraDocuments \
    VendorPackages/GoogleSignIn-iOS \
    VendorPackages/shared-features-spm
do
    if [ ! -d "${root}/${reviewed_local_package}" ] ||
       [ -L "${root}/${reviewed_local_package}" ]; then
        echo "error: reviewed local Swift package is absent or substituted: ${reviewed_local_package}"
        exit 1
    fi
done

if [ ! -f "${vendored_binary_readiness}" ] ||
   [ -L "${vendored_binary_readiness}" ] ||
   [ ! -f "${vendored_binary_qualification_blocked}" ] ||
   [ -L "${vendored_binary_qualification_blocked}" ] ||
   [ ! -f "${vendored_binary_evidence_blocked}" ] ||
   [ -L "${vendored_binary_evidence_blocked}" ] ||
   [ ! -f "${vendored_binary_trust_blocked}" ] ||
   [ -L "${vendored_binary_trust_blocked}" ] ||
   [ ! -f "${vendored_binary_documentation}" ] ||
   [ -L "${vendored_binary_documentation}" ] ||
   [ ! -f "${vendored_binary_qualification_validator}" ] ||
   [ -L "${vendored_binary_qualification_validator}" ] ||
   [ ! -f "${vendored_binary_qualification_json_validator}" ] ||
   [ -L "${vendored_binary_qualification_json_validator}" ] ||
   [ ! -f "${vendored_binary_qualification_harness}" ] ||
   [ -L "${vendored_binary_qualification_harness}" ] ||
   ! /bin/sh "${vendored_binary_qualification_validator}" --lint-templates >/dev/null; then
    echo "error: authenticated iOS vendored-binary qualification contract is absent or malformed"
    exit 1
fi

if ! /usr/bin/grep -Fq 'exec /usr/bin/python3 -I -S "${validator}" "$@"' "${vendored_binary_qualification_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_VENDORED_BINARY_QUALIFICATION_TRUST_SHA256' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_SHA256' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_SHA256' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'duplicate_rejecting_object' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'parse_json_integer' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'reject_json_float' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'exact_typed_equal' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'inventory_tree' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'verify_signature' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'SAFE_OPENSSL_ENV' "${vendored_binary_qualification_json_validator}" ||
   [ "$(/usr/bin/grep -Fc 'env=SAFE_OPENSSL_ENV' "${vendored_binary_qualification_json_validator}")" -ne 3 ] ||
   ! /usr/bin/grep -Fq 'sora-ios-vendored-binary-provenance-v2' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'inputs.recheck_all()' "${vendored_binary_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'test_qualified_dual_signature_and_six_tree_path_succeeds' "${vendored_binary_qualification_harness}" ||
   ! /usr/bin/grep -Fq 'test_repository_sorawallet_trees_are_currently_byte_identical' "${vendored_binary_qualification_harness}" ||
   ! /usr/bin/grep -Fq 'values inside repository JSON cannot authorize themselves' "${vendored_binary_documentation}" ||
   ! /usr/bin/grep -Fq 'Boolean review claims and self-referential' "${vendored_binary_documentation}" ||
   [ "$(/usr/bin/grep -Fc '/bin/sh "${vendored_binary_qualification_validator}" --lint-templates >/dev/null' "${dependency_verifier}")" -lt 3 ] ||
   [ "$(/usr/bin/grep -Fc '/bin/sh "${vendored_binary_qualification_validator}" --verify-qualified' "${dependency_verifier}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/ios-vendored-binary-qualification.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/ios-vendored-binary-qualification-evidence.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/ios-vendored-binary-qualification-trust.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/ios-vendored-binary-qualification-README.md' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-ios-vendored-binary-qualification.py' "${project}")" -lt 2 ]; then
    echo "error: authenticated iOS vendored-binary admission is missing or fail-open"
    exit 1
fi

if [ ! -f "${migration_collector_validator}" ] ||
   [ -L "${migration_collector_validator}" ] ||
   [ ! -f "${migration_collector_json_validator}" ] ||
   [ -L "${migration_collector_json_validator}" ] ||
   [ ! -f "${migration_collector_harness}" ] ||
   [ -L "${migration_collector_harness}" ] ||
   [ ! -f "${migration_collection_runner}" ] ||
   [ -L "${migration_collection_runner}" ] ||
   [ ! -f "${migration_collection_pipeline}" ] ||
   [ -L "${migration_collection_pipeline}" ] ||
   [ ! -f "${migration_evidence_builder}" ] ||
   [ -L "${migration_evidence_builder}" ] ||
   [ ! -f "${migration_candidate_archiver}" ] ||
   [ -L "${migration_candidate_archiver}" ] ||
   [ ! -f "${internal_testflight_uploader}" ] ||
   [ -L "${internal_testflight_uploader}" ] ||
   [ ! -f "${internal_testflight_delivery_verifier}" ] ||
   [ -L "${internal_testflight_delivery_verifier}" ] ||
   [ ! -f "${internal_testflight_export_options}" ] ||
   [ -L "${internal_testflight_export_options}" ] ||
   [ ! -f "${internal_testflight_harness}" ] ||
   [ -L "${internal_testflight_harness}" ] ||
   [ ! -f "${internal_testflight_source_contract_manifest}" ] ||
   [ -L "${internal_testflight_source_contract_manifest}" ] ||
   [ ! -f "${migration_candidate_handoff}" ] ||
   [ -L "${migration_candidate_handoff}" ] ||
   [ ! -f "${migration_test_host_deriver}" ] ||
   [ -L "${migration_test_host_deriver}" ] ||
   [ ! -f "${migration_test_host_projector}" ] ||
   [ -L "${migration_test_host_projector}" ] ||
   [ ! -f "${migration_test_host_projector_harness}" ] ||
   [ -L "${migration_test_host_projector_harness}" ] ||
   [ ! -f "${migration_candidate_export_options}" ] ||
   [ -L "${migration_candidate_export_options}" ] ||
   [ ! -f "${migration_promotion_admission}" ] ||
   [ -L "${migration_promotion_admission}" ] ||
   [ ! -f "${migration_release_boundary_harness}" ] ||
   [ -L "${migration_release_boundary_harness}" ] ||
   [ ! -f "${release_test_runner}" ] ||
   [ -L "${release_test_runner}" ] ||
   [ ! -f "${migration_evidence_scheme}" ] ||
   [ -L "${migration_evidence_scheme}" ] ||
   [ ! -f "${migration_evidence_tests}" ] ||
   [ -L "${migration_evidence_tests}" ] ||
   ! run_ios_migration_release_source_gate >/dev/null ||
   ! /bin/sh "${migration_candidate_archiver}" --lint-contract >/dev/null ||
   ! /bin/sh "${internal_testflight_uploader}" --lint-contract >/dev/null ||
   ! /bin/sh "${migration_test_host_deriver}" --lint-contract >/dev/null ||
   ! /bin/sh "${migration_promotion_admission}" --lint-contract >/dev/null ||
   ! /bin/sh "${migration_collector_validator}" --lint-contract >/dev/null; then
    echo "error: raw-bound iOS migration collector contract is absent or malformed"
    exit 1
fi

if ! /usr/bin/grep -Fq 'exec /usr/bin/python3 -I -S "${validator}" "$@"' "${migration_qualification_validator}" ||
   ! /usr/bin/grep -Fq 'exec /usr/bin/python3 -I -S "${collector}" "$@"' "${migration_collector_validator}" ||
   ! /usr/bin/grep -Fq '/usr/bin/python3 -I -S "${collector_tests}"' "${migration_collection_runner}" ||
   ! /usr/bin/grep -Fq '/usr/bin/python3 -I -S "${derivation_tests}"' "${migration_collection_runner}" ||
   ! /usr/bin/grep -Fq 'SAFE_OPENSSL_ENV' "${migration_qualification_json_validator}" ||
   [ "$(/usr/bin/grep -Fc 'env=SAFE_OPENSSL_ENV' "${migration_qualification_json_validator}")" -ne 4 ] ||
   ! /usr/bin/grep -Fq 'read_unique_regular' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'pass_fds=(key_file.fileno(), signature_file.fileno())' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'input=payload_raw' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'hash_anchored_named_regular' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'recheck_input_digest' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_MIGRATION_QUALIFICATION_RAW_INPUT_ROOT' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_MIGRATION_QUALIFICATION_RAW_INPUT_SET_SHA256' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_MIGRATION_QUALIFICATION_RUN_CHALLENGE_SHA256' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_MIGRATION_QUALIFICATION_COLLECTION_RECEIPT_SHA256' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-wallet-migration-qualification-v8' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-wallet-migration-evidence-v4' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'evidence_produced - finished' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'migration artifact {key} does not byte-reproduce from protected raw input' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'load_contract_source_entries' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'read_contract_bound_source' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'verify_test_host_derivation' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'verify_release_test_host_code_signature' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'validate_installable_clone_receipt' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'canonicalProjectionReceiptVerified' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'canonicalProjectorSourceVerified' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-wallet-migration-test-host-derivation-v2' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'sora-ios-wallet-migration-canonical-app-projection-v2' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'sora-ios-wallet-migration-raw-app-tree-v1' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'allEntitlementSlotsMappedAndSemanticallyMatched' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'allNonSignatureFileRangesPrecedeTerminalSignature' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'PlugIns/SoraPassportIntegrationTests.xctest' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'Frameworks/libXCTestBundleInject.dylib' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq '"releaseAuthorized": False' "${migration_test_host_projector}" ||
   ! /usr/bin/grep -Fq 'canonicalProjectionEqualToProduction' "${migration_evidence_tests}" ||
   ! /usr/bin/grep -Fq 'canonicalProjectorSourceSha256' "${migration_evidence_tests}" ||
   ! /usr/bin/grep -Fq 'eventProjectionSha256' "${migration_collector_json_validator}" ||
   ! /usr/bin/grep -Fq -- '--verify-qualified-ipa' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'verify_qualified_ipa' "${migration_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-migration-observed-only-build-v1' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq '[ "${ACTION:-}" != "build" ]' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'sora-ios-nonpromoting-release-simulator-test-v1' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq '[ "${PLATFORM_NAME:-}" != "iphonesimulator" ]' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq '[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq '[ "${CODE_SIGNING_REQUIRED:-YES}" != "NO" ]' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq '[ "${ARCHS:-}" != "arm64" ]' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'optimized simulator XCTest build is non-authorizing' "${dependency_verifier}" ||
   ! /bin/sh "${release_test_runner}" --lint-contract >/dev/null ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/run-ios-release-tests.sh' "${project}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq 'sora-ios-migration-observed-only-candidate-archive-v1' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq '[ "${ACTION:-}" != "install" ]' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'if [ "${migration_candidate_archive_active}" = "true" ]; then' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'migration_post_export_admission_deferred=true' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'migration and IPA-bound post-export admission are deferred' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'funded-canary and rollout receipt admission require the exported IPA' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'SORA_IOS_MIGRATION_EVIDENCE_BUILD_ACTION=build-for-testing' "${migration_evidence_builder}" ||
   ! /usr/bin/grep -Fq 'build-for-testing' "${migration_evidence_builder}" ||
   /usr/bin/grep -Fq -- '-exportArchive' "${migration_evidence_builder}" ||
   ! /usr/bin/grep -Fq 'SORA_IOS_MIGRATION_CANDIDATE_ARCHIVE_ACTION=archive' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '-scheme SoraPassport' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '-configuration Release' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '-exportArchive' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '--snapshot-export-options "${export_options_snapshot}"' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '-exportOptionsPlist "${export_options_snapshot}"' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '--verify-snapshot "${qualification_contract_snapshot}"' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '--verify-export-options-source "${export_options_sha}"' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq -- '--export-options-sha "${export_options_sha}"' "${migration_candidate_archiver}" ||
   /usr/bin/grep -Fq 'verify-production-rollout' "${migration_candidate_archiver}" ||
   ! /usr/bin/grep -Fq 'sora-ios-internal-testflight-upload-v1' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'internal-TestFlight-only archive is non-authorizing' "${dependency_verifier}" ||
   ! /usr/bin/grep -Fq 'testFlightInternalTestingOnly' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'testFlightInternalTestingOnly' "${internal_testflight_export_options}" ||
   ! /usr/bin/grep -Fq '<string>automatic</string>' "${internal_testflight_export_options}" ||
   /usr/bin/grep -Fq '<key>signingCertificate</key>' "${internal_testflight_export_options}" ||
   /usr/bin/grep -Fq '<key>provisioningProfiles</key>' "${internal_testflight_export_options}" ||
   ! /usr/bin/grep -Fq 'rev-parse '\''@{upstream}'\''' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'reviewed_base_revision="d657f9ccc55ba1f9558c474229bc470375a71bfd"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'reviewed_upstream="origin/modernize"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'reviewed_build_number="2026081601"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq -- '--verify-app-runtime-closure "${archived_app}"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'verify_app_runtime_dependency_closure' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'test_runtime_dependency_closure_rejects_missing_framework' "${internal_testflight_harness}" ||
   ! /usr/bin/grep -Fq 'reviewed_signing_certificate_sha256="d830d54bce8e583089f2ed8cf927fc12b60c9d591e560ffe6f5d2a71c91317fb"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'reviewed_profile_sha256="19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'reviewed_archive_signing_certificate_sha256="b479b9064f19cf90085926479768088416407c9e99e1537662014ba6805c179d"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'reviewed_archive_profile_sha256="ede945565f09b23b4d92eca0752cb6ad52fe47b8a6ebb0e38f424ce64de79235"' "${internal_testflight_uploader}" ||
   /usr/bin/grep -Fq '"CODE_SIGN_IDENTITY=' "${internal_testflight_uploader}" ||
   /usr/bin/grep -Fq '"CODE_SIGN_STYLE=' "${internal_testflight_uploader}" ||
   /usr/bin/grep -Fq '"PROVISIONING_PROFILE_SPECIFIER=' "${internal_testflight_uploader}" ||
   [ "$(/usr/bin/grep -Fc -- '-allowProvisioningUpdates' "${internal_testflight_uploader}")" -ne 1 ] ||
   ! /usr/bin/grep -Fq -- '--xcodebuild-log "${export_log}"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq -- '--reviewed-profile "${reviewed_profile_path}"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq '/bin/chmod 400 "${export_options_snapshot}"' "${internal_testflight_uploader}" ||
   [ "$(/usr/bin/grep -Fc 'sha256_file "${export_options_snapshot}"' "${internal_testflight_uploader}")" -ne 3 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Configs/ios-internal-testflight-export-options.plist' "${internal_testflight_source_contract_manifest}")" -ne 1 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/test-ios-internal-testflight-upload.py' "${internal_testflight_source_contract_manifest}")" -ne 1 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/upload-ios-internal-testflight.sh' "${internal_testflight_source_contract_manifest}")" -ne 1 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py' "${internal_testflight_source_contract_manifest}")" -ne 1 ] ||
   ! /usr/bin/grep -Fq 'sora-ios-xcode-apple-upload-receipt-v1' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'certificateSha1' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'provisioningProfileSha256' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'provisioningProfileIsXcodeManaged' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'testFlightInternalTestingOnly' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'Xcode effective export options drifted' "${internal_testflight_delivery_verifier}" ||
   ! /usr/bin/grep -Fq 'SORA_MIGRATION_EVIDENCE_SOURCE_REVISION=${source_revision}' "${internal_testflight_uploader}" ||
   [ "$(/usr/bin/grep -Fc -- '--verify-snapshot "${contract_snapshot}"' "${internal_testflight_uploader}")" -ne 2 ] ||
   ! /usr/bin/grep -Fq 'appleDeliveryId": delivery_id' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'appleUploadState": "success"' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'productionRolloutAuthorized": False' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq -- '-exportArchive' "${internal_testflight_uploader}" ||
   /usr/bin/grep -Fq 'ITSAppUsesNonExemptEncryption' "${internal_testflight_uploader}" ||
   ! /usr/bin/grep -Fq 'sora-ios-wallet-migration-candidate-handoff-v1' "${migration_candidate_handoff}" ||
   ! /usr/bin/grep -Fq '"releaseAuthorized": False' "${migration_candidate_handoff}" ||
   ! /usr/bin/grep -Fq '"promotionAuthorized": False' "${migration_candidate_handoff}" ||
   ! /usr/bin/grep -Fq '"rebuiltTestHostAccepted": False' "${migration_candidate_handoff}" ||
   ! /usr/bin/grep -Fq '/bin/sh "${migration_promotion_admission}" --verify-qualified-ipa "${candidate_ipa}"' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'buildConfiguration = "Release"' "${migration_evidence_scheme}" ||
   /usr/bin/grep -Fq 'Simulator' "${migration_evidence_scheme}" ||
   /usr/bin/grep -Fq 'buildForArchiving = "YES"' "${migration_evidence_scheme}" ||
   [ "$(/usr/bin/grep -Fc 'WalletMigrationRetainedDeviceEvidenceTests/testEmit' "${migration_evidence_scheme}")" -ne 3 ] ||
   ! /usr/bin/grep -Fq '/usr/bin/diff -rq "${first}" "${second}"' "${migration_collection_pipeline}" ||
   [ "$(/usr/bin/grep -Fc 'ios-migration-' "${migration_collection_pipeline}")" -lt 5 ] ||
   /usr/bin/grep -Fq -- '--verify-qualified' "${migration_collection_pipeline}" ||
   /usr/bin/grep -Fq 'PRIVATE_KEY' "${migration_collection_pipeline}" ||
   /usr/bin/grep -Fq 'verify-ios-migration-promotion-ipa' "${migration_collection_pipeline}" ||
   /usr/bin/grep -Fq 'QUALIFICATION_SEQUENCE_NUMBER' "${migration_collection_pipeline}"; then
    echo "error: authenticated raw-bound iOS migration boundary is missing or fail-open"
    exit 1
fi

if [ ! -f "${ios_signing_identity}" ] ||
   [ -L "${ios_signing_identity}" ] ||
   [ ! -f "${ios_signing_qualification_blocked}" ] ||
   [ -L "${ios_signing_qualification_blocked}" ] ||
   [ ! -f "${ios_signing_qualification_trust_blocked}" ] ||
   [ -L "${ios_signing_qualification_trust_blocked}" ] ||
   [ ! -f "${ios_signing_qualification_documentation}" ] ||
   [ -L "${ios_signing_qualification_documentation}" ] ||
   [ ! -f "${ios_signing_qualification_validator}" ] ||
   [ -L "${ios_signing_qualification_validator}" ] ||
   [ ! -f "${ios_signing_qualification_json_validator}" ] ||
   [ -L "${ios_signing_qualification_json_validator}" ] ||
   [ ! -f "${ios_signing_qualification_harness}" ] ||
   [ -L "${ios_signing_qualification_harness}" ] ||
   [ ! -f "${ios_entitlements}" ] ||
   [ -L "${ios_entitlements}" ] ||
   ! /bin/sh "${ios_signing_qualification_validator}" --lint-templates >/dev/null; then
    echo "error: iOS production bundle, team, signing, or entitlements identity drifted"
    exit 1
fi
if ! /usr/bin/grep -Fq 'IOS_SIGNING_IDENTITY_CONTRACT_SHA256' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_SIGNING_IDENTITY_TRUST_SHA256' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_SHA256' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'IOS_SIGNING_IDENTITY_REVIEWER_PUBLIC_KEY_SHA256' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'duplicate_rejecting_object' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'inputs.recheck_all()' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'must not use a repository-controlled path' "${ios_signing_qualification_json_validator}" ||
   ! /usr/bin/grep -Fq 'test_qualified_dual_signature_path_succeeds' "${ios_signing_qualification_harness}" ||
   ! /usr/bin/grep -Fq 'test_non_p256_producer_key_is_rejected' "${ios_signing_qualification_harness}" ||
   ! /usr/bin/grep -Fq 'Editing its nulls and booleans cannot qualify' "${ios_signing_qualification_documentation}" ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/ios-production-signing-identity-qualification.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/ios-production-signing-identity-qualification-trust.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-ios-production-signing-identity.py' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/test-ios-production-signing-identity.py' "${project}")" -lt 2 ]; then
    echo "error: authenticated iOS signing-continuity admission is missing or fail-open"
    exit 1
fi
if ! verify_main_release_source_identity; then
    echo "error: iOS main-target Release source identity drifted"
    exit 1
fi
if ! verify_google_signin_info_plist_phase_dependencies "${project}"; then
    echo "error: Google Sign-In Info.plist build-order dependency drifted"
    exit 1
fi

ios_signing_authentication="$(
    /bin/sh "${ios_signing_qualification_validator}" --verify-qualified 2>/dev/null
)" || {
    echo "error: iOS production signing identity remains explicitly blocked"
    exit 1
}
case "${ios_signing_authentication}" in
    receiptSha256=*)
        ios_signing_authenticated_sha256="${ios_signing_authentication#receiptSha256=}"
        ;;
    *)
        echo "error: iOS signing-continuity authenticator returned an invalid result"
        exit 1
        ;;
esac
if ! is_lower_hex_length "${ios_signing_authenticated_sha256}" 64 ||
   [ "$(/usr/bin/printf '%s\n' "${ios_signing_authentication}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" != "1" ] ||
   [ ! -f "${ios_signing_qualification}" ] ||
   [ -L "${ios_signing_qualification}" ] ||
   [ ! -f "${ios_signing_qualification_trust}" ] ||
   [ -L "${ios_signing_qualification_trust}" ] ||
   [ "$(sha256_file "${ios_signing_qualification}")" != "${ios_signing_authenticated_sha256}" ]; then
    echo "error: authenticated iOS signing-continuity result is malformed"
    exit 1
fi

if [ ! -f "${wallet_derivation_fixture}" ]; then
    echo "error: shared wallet derivation fixture is absent"
    exit 1
fi

fixture_checksum="$(/usr/bin/shasum -a 256 "${wallet_derivation_fixture}" | /usr/bin/awk '{print $1}')"
if [ "${WALLET_DERIVATION_FIXTURE_SHA256:-}" != "9e7cefc3a4a1f69e431e1a8d38733a1d126b350b83cba3516d95a0d2d672ba8b" ] ||
   [ "${fixture_checksum}" != "${WALLET_DERIVATION_FIXTURE_SHA256}" ]; then
    echo "error: shared wallet derivation fixture checksum mismatch"
    exit 1
fi

if ! /usr/bin/grep -Fq "testSharedTwelveAndTwentyFourWordVectorsPreserveSora2Identity" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "SharedWalletDerivationFixture" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq '"bip39-12-abandon", "fearless-default-24"' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "directBip39Seed32Hex" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "legacySora2MiniSeedHex" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "The direct BIP39 seed must never replace the legacy SORA2 mini-seed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "IRBIP39SeedCreator()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "SeedFactory()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "SR25519KeypairFactory().createKeypairFromSeed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "Chain.sora.addressType()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let seedFactory = SeedFactory()" "${account_factory}" ||
   ! /usr/bin/grep -Fq "keypairFactory.createKeypairFromSeed(result.seed.miniSeed" "${account_factory}" ||
   ! /usr/bin/grep -Fq "seed: result.seed.miniSeed" "${account_factory}" ||
   ! /usr/bin/grep -Fq "sourceSeed = try SeedFactory().deriveSeed(" "${signing_wrapper}" ||
   /usr/bin/grep -Fq "IRBIP39SeedCreator" "${account_factory}" ||
   /usr/bin/grep -Fq "IRBIP39SeedCreator" "${signing_wrapper}"; then
    echo "error: shared SORA2 12/24-word derivation vectors are not executable on iOS"
    exit 1
fi

if [ ! -f "${iroha_readiness}" ] ||
   [ "$(json_raw schemaVersion "${iroha_readiness}")" != "4" ] ||
   [ "$(json_raw platform "${iroha_readiness}")" != "ios" ] ||
   [ "$(json_raw upstream.tag "${iroha_readiness}")" != "${IROHA_SWIFT_UPSTREAM_TAG}" ] ||
   [ "$(json_raw upstream.commit "${iroha_readiness}")" != "${IROHA_SWIFT_REVISION}" ] ||
   [ "$(json_raw artifactObservation.observedArchiveSha256 "${iroha_readiness}")" != "${NORITO_BRIDGE_OBSERVED_MUTABLE_ARCHIVE_SHA256}" ] ||
   [ "$(json_raw artifactObservation.artifactManifestSha256 "${iroha_readiness}")" != "${NORITO_BRIDGE_OBSERVED_ARTIFACT_MANIFEST_SHA256}" ] ||
   [ "$(json_raw artifactObservation.githubReleaseImmutable "${iroha_readiness}")" != "false" ] ||
   [ "$(json_raw artifactObservation.qualification "${iroha_readiness}")" != "observation-only" ] ||
   [ "$(json_raw integrationAssessment.appMinimumIOS "${iroha_readiness}")" != "16.0" ] ||
   [ "$(json_raw integrationAssessment.sdkMinimumIOS "${iroha_readiness}")" != "15.0" ] ||
   [ "$(json_raw integrationAssessment.minimumOSCompatible "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw integrationAssessment.appMinimumIOSChangedForSDK "${iroha_readiness}")" != "false" ]; then
    echo "error: structured Iroha production-send readiness evidence is absent or inconsistent"
    exit 1
fi

if [ "$(json_raw status "${iroha_readiness}")" != "${IROHA_PRODUCTION_READINESS_STATUS:-}" ] ||
   [ "$(json_raw sourceReview.status "${iroha_readiness}")" != "${IROHA_SWIFT_INDEPENDENT_REVIEW_STATUS:-}" ] ||
   [ "$(json_raw reviewedArtifact.status "${iroha_readiness}")" != "${NORITO_BRIDGE_INDEPENDENT_REVIEW_STATUS:-}" ]; then
    echo "error: Iroha readiness and dependency review statuses disagree"
    exit 1
fi

require_exact_json_object_keys \
    "production Nexus signer binding" \
    productionSignerBinding \
    "${iroha_readiness}" \
    status \
    adapterType \
    adapterSourcePath \
    adapterSourceSha256 \
    providerSourcePath \
    providerSourceSha256 \
    reviewedNativeArtifactSha256 \
    nativeCanaryReceiptSha256
production_signer_binding_status="$(
    json_raw productionSignerBinding.status "${iroha_readiness}"
)"
production_signer_adapter_type="$(
    json_raw productionSignerBinding.adapterType "${iroha_readiness}"
)"
production_signer_adapter_path="$(
    json_raw productionSignerBinding.adapterSourcePath "${iroha_readiness}"
)"
production_signer_provider_path="$(
    json_raw productionSignerBinding.providerSourcePath "${iroha_readiness}"
)"
case "${production_signer_adapter_path}" in
    ""|/*|*..*)
        echo "error: production signer adapter path is not a reviewed relative path"
        exit 1
        ;;
esac
case "${production_signer_provider_path}" in
    ""|/*|*..*)
        echo "error: production signer provider path is not a reviewed relative path"
        exit 1
        ;;
esac
production_signer_adapter_source="${root}/${production_signer_adapter_path}"
production_signer_provider_source="${root}/${production_signer_provider_path}"
if [ "${production_signer_binding_status}" != "${IROHA_PRODUCTION_SIGNER_BINDING_STATUS:-}" ] ||
   [ "${production_signer_adapter_type}" != "${IROHA_PRODUCTION_SIGNER_ADAPTER_TYPE:-}" ] ||
   [ "${production_signer_adapter_path}" != "${IROHA_PRODUCTION_SIGNER_ADAPTER_SOURCE_PATH:-}" ] ||
   [ "${production_signer_provider_path}" != "${IROHA_PRODUCTION_SIGNER_PROVIDER_SOURCE_PATH:-}" ] ||
   [ ! -f "${production_signer_adapter_source}" ] ||
   [ -L "${production_signer_adapter_source}" ] ||
   [ ! -f "${production_signer_provider_source}" ] ||
   [ -L "${production_signer_provider_source}" ] ||
   [ "$(sha256_file "${production_signer_adapter_source}")" != "${IROHA_PRODUCTION_SIGNER_ADAPTER_SOURCE_SHA256:-}" ] ||
   [ "$(sha256_file "${production_signer_provider_source}")" != "${IROHA_PRODUCTION_SIGNER_PROVIDER_SOURCE_SHA256:-}" ] ||
   [ "$(json_raw productionSignerBinding.adapterSourceSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_SIGNER_ADAPTER_SOURCE_SHA256:-}" ] ||
   [ "$(json_raw productionSignerBinding.providerSourceSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_SIGNER_PROVIDER_SOURCE_SHA256:-}" ] ||
   [ "$(json_raw defaultSigner "${iroha_readiness}")" != "${production_signer_adapter_type}" ]; then
    echo "error: production Nexus signer adapter/provider binding drifted"
    exit 1
fi
case "${production_signer_binding_status}" in
    blocked)
        if [ "${production_signer_adapter_type}" != "UnavailableNexusTransactionSigner" ] ||
           [ -n "$(json_raw productionSignerBinding.reviewedNativeArtifactSha256 "${iroha_readiness}")" ] ||
           [ -n "$(json_raw productionSignerBinding.nativeCanaryReceiptSha256 "${iroha_readiness}")" ]; then
            echo "error: blocked production signer binding claims reviewed release evidence"
            exit 1
        fi
        ;;
    qualified)
        if [ "${production_signer_adapter_type}" = "UnavailableNexusTransactionSigner" ]; then
            echo "error: qualified production signer binding still selects the placeholder"
            exit 1
        fi
        require_reviewed_sha256 \
            "production signer reviewed native artifact" \
            "$(json_raw productionSignerBinding.reviewedNativeArtifactSha256 "${iroha_readiness}")"
        require_reviewed_sha256 \
            "production signer native canary receipt" \
            "$(json_raw productionSignerBinding.nativeCanaryReceiptSha256 "${iroha_readiness}")"
        ;;
    *)
        echo "error: production signer binding status is invalid"
        exit 1
        ;;
esac

require_exact_json_object_keys \
    "production Nexus finality binding" \
    productionFinalityBinding \
    "${iroha_readiness}" \
    status \
    adapterType \
    adapterSourcePath \
    adapterSourceSha256 \
    providerSourcePath \
    providerSourceSha256 \
    attestationRoute \
    attestationResponseType \
    bundleRoute \
    bundleResponseType \
    reviewedVerifierArtifactSha256 \
    reviewedVerifierSourceRevision \
    trustedContextReceiptSha256 \
    nativeCanaryReceiptSha256
production_finality_binding_status="$(
    json_raw productionFinalityBinding.status "${iroha_readiness}"
)"
production_finality_adapter_type="$(
    json_raw productionFinalityBinding.adapterType "${iroha_readiness}"
)"
production_finality_adapter_path="$(
    json_raw productionFinalityBinding.adapterSourcePath "${iroha_readiness}"
)"
production_finality_provider_path="$(
    json_raw productionFinalityBinding.providerSourcePath "${iroha_readiness}"
)"
case "${production_finality_adapter_path}" in
    ""|/*|*..*)
        echo "error: production finality adapter path is not a reviewed relative path"
        exit 1
        ;;
esac
case "${production_finality_provider_path}" in
    ""|/*|*..*)
        echo "error: production finality provider path is not a reviewed relative path"
        exit 1
        ;;
esac
production_finality_adapter_source="${root}/${production_finality_adapter_path}"
production_finality_provider_source="${root}/${production_finality_provider_path}"
if [ "${production_finality_binding_status}" != "${IROHA_PRODUCTION_FINALITY_BINDING_STATUS:-}" ] ||
   [ "${production_finality_adapter_type}" != "${IROHA_PRODUCTION_FINALITY_ADAPTER_TYPE:-}" ] ||
   [ "${production_finality_adapter_path}" != "${IROHA_PRODUCTION_FINALITY_ADAPTER_SOURCE_PATH:-}" ] ||
   [ "${production_finality_provider_path}" != "${IROHA_PRODUCTION_FINALITY_PROVIDER_SOURCE_PATH:-}" ] ||
   [ ! -f "${production_finality_adapter_source}" ] ||
   [ -L "${production_finality_adapter_source}" ] ||
   [ ! -f "${production_finality_provider_source}" ] ||
   [ -L "${production_finality_provider_source}" ] ||
   [ "$(sha256_file "${production_finality_adapter_source}")" != "${IROHA_PRODUCTION_FINALITY_ADAPTER_SOURCE_SHA256:-}" ] ||
   [ "$(sha256_file "${production_finality_provider_source}")" != "${IROHA_PRODUCTION_FINALITY_PROVIDER_SOURCE_SHA256:-}" ] ||
   [ "$(json_raw productionFinalityBinding.adapterSourceSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_FINALITY_ADAPTER_SOURCE_SHA256:-}" ] ||
   [ "$(json_raw productionFinalityBinding.providerSourceSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_FINALITY_PROVIDER_SOURCE_SHA256:-}" ] ||
   [ "$(json_raw defaultFinalityReader "${iroha_readiness}")" != "${production_finality_adapter_type}" ] ||
   [ "$(json_raw productionFinalityBinding.attestationRoute "${iroha_readiness}")" != "/v1/bridge/finality/attestation/{height}" ] ||
   [ "$(json_raw productionFinalityBinding.attestationResponseType "${iroha_readiness}")" != "BridgeFinalityAttestationV1" ] ||
   [ "$(json_raw productionFinalityBinding.bundleRoute "${iroha_readiness}")" != "/v1/bridge/finality/bundle/{height}" ] ||
   [ "$(json_raw productionFinalityBinding.bundleResponseType "${iroha_readiness}")" != "BridgeFinalityBundle" ]; then
    echo "error: production Nexus finality adapter/provider binding drifted"
    exit 1
fi
case "${production_finality_binding_status}" in
    blocked)
        if [ "${production_finality_adapter_type}" != "UnavailableNexusFinalityReader" ] ||
           [ -n "$(json_raw productionFinalityBinding.reviewedVerifierArtifactSha256 "${iroha_readiness}")" ] ||
           [ -n "$(json_raw productionFinalityBinding.reviewedVerifierSourceRevision "${iroha_readiness}")" ] ||
           [ -n "$(json_raw productionFinalityBinding.trustedContextReceiptSha256 "${iroha_readiness}")" ] ||
           [ -n "$(json_raw productionFinalityBinding.nativeCanaryReceiptSha256 "${iroha_readiness}")" ]; then
            echo "error: blocked production finality binding claims reviewed release evidence"
            exit 1
        fi
        ;;
    qualified)
        if [ "${production_finality_adapter_type}" = "UnavailableNexusFinalityReader" ]; then
            echo "error: qualified production finality binding still selects the placeholder"
            exit 1
        fi
        require_reviewed_sha1 \
            "production finality verifier source revision" \
            "$(json_raw productionFinalityBinding.reviewedVerifierSourceRevision "${iroha_readiness}")"
        require_reviewed_sha256 \
            "production finality verifier artifact" \
            "$(json_raw productionFinalityBinding.reviewedVerifierArtifactSha256 "${iroha_readiness}")"
        require_reviewed_sha256 \
            "production finality trust receipt" \
            "$(json_raw productionFinalityBinding.trustedContextReceiptSha256 "${iroha_readiness}")"
        require_reviewed_sha256 \
            "production finality native canary receipt" \
            "$(json_raw productionFinalityBinding.nativeCanaryReceiptSha256 "${iroha_readiness}")"
        if [ "$(json_raw productionFinalityBinding.reviewedVerifierSourceRevision "${iroha_readiness}")" != "${IROHA_PRODUCTION_FINALITY_VERIFIER_SOURCE_REVISION:-}" ] ||
           [ "$(json_raw productionFinalityBinding.reviewedVerifierArtifactSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_FINALITY_VERIFIER_ARTIFACT_SHA256:-}" ] ||
           [ "$(json_raw productionFinalityBinding.trustedContextReceiptSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_FINALITY_TRUST_RECEIPT_SHA256:-}" ] ||
           [ "$(json_raw productionFinalityBinding.nativeCanaryReceiptSha256 "${iroha_readiness}")" != "${IROHA_PRODUCTION_FINALITY_CANARY_RECEIPT_SHA256:-}" ]; then
            echo "error: qualified production finality evidence is not pinned by release configuration"
            exit 1
        fi
        ;;
    *)
        echo "error: production finality binding status is invalid"
        exit 1
        ;;
esac

require_exact_json_object_keys \
    "Nexus finality trust contract" \
    finalityTrustContract \
    "${iroha_readiness}" \
    schemaVersion \
    requiredAttestationVersion \
    serverContractSourceRevision \
    serverOpenApiSha256 \
    serverRouteSourceSha256 \
    attestationRoute \
    attestationResponseType \
    bundleRoute \
    bundleResponseType \
    challengeHeader \
    requiredAccept \
    requiredCacheControl \
    requiredVary \
    requiresUnpredictableNonzeroChallenge \
    requiresExactLowercase64HexChallengeHeader \
    rejectsDuplicateChallengeHeader \
    requiresExactChallengeBinding \
    requiresCanonicalNoritoRoundTrip \
    requiresNoStoreOnSuccessAndError \
    requiresExpectedChainId \
    requiresExpectedNodeKey \
    requiresExpectedNodeBuildFingerprint \
    requiresExpectedProtocolVersion \
    requiresExpectedConsensusMode \
    requiresExpectedValidatorRoster \
    requiresExpectedQuorum \
    requiresCanonicalSignedGenesis \
    requiresSignedGenesisSha256 \
    requiresGenesisPublicKey \
    requiresTrustedFirstHeightContextId \
    requiresStatefulSuccessorVerification \
    requiresBoundedSequentialBundleCatchUp \
    requiresImmediateSuccessorProofs \
    requiresCrashDurableVerifierCheckpoint \
    requiresMonotonicHeightAndContext \
    rejectsAdvancedOrStaleProof \
    requiresFreshAttestationAtSelectedTip \
    requiresGenesisFinalityProof \
    requiresTipFinalityProof \
    requiresFinalizedBlockHashBinding \
    requiresHeaderArtifactAndExecutionBinding \
    requiresNodeSignatureVerification \
    requiresAggregateSignatureVerification \
    requiresSingleStateView \
    acceptsStatusBlocksScalar \
    acceptsSelfDeclaredNodeTrust \
    minamotoTrustedContextReceiptSha256 \
    tairaTrustedContextReceiptSha256
if [ "$(json_raw finalityTrustContract.schemaVersion "${iroha_readiness}")" != "1" ] ||
   [ "$(json_raw finalityTrustContract.requiredAttestationVersion "${iroha_readiness}")" != "1" ] ||
   [ "$(json_raw finalityTrustContract.attestationRoute "${iroha_readiness}")" != "/v1/bridge/finality/attestation/{height}" ] ||
   [ "$(json_raw finalityTrustContract.attestationResponseType "${iroha_readiness}")" != "BridgeFinalityAttestationV1" ] ||
   [ "$(json_raw finalityTrustContract.bundleRoute "${iroha_readiness}")" != "/v1/bridge/finality/bundle/{height}" ] ||
   [ "$(json_raw finalityTrustContract.bundleResponseType "${iroha_readiness}")" != "BridgeFinalityBundle" ] ||
   [ "$(json_raw finalityTrustContract.challengeHeader "${iroha_readiness}")" != "X-Iroha-Finality-Challenge" ] ||
   [ "$(json_raw finalityTrustContract.requiredAccept "${iroha_readiness}")" != "application/x-norito" ] ||
   [ "$(json_raw finalityTrustContract.requiredCacheControl "${iroha_readiness}")" != "no-store" ] ||
   [ "$(json_raw finalityTrustContract.requiredVary "${iroha_readiness}")" != "X-Iroha-Finality-Challenge, Accept" ] ||
   [ "$(json_raw finalityTrustContract.acceptsStatusBlocksScalar "${iroha_readiness}")" != "false" ] ||
   [ "$(json_raw finalityTrustContract.acceptsSelfDeclaredNodeTrust "${iroha_readiness}")" != "false" ]; then
    echo "error: Nexus finality trust contract is absent or weakened"
    exit 1
fi
for finality_requirement in \
    requiresUnpredictableNonzeroChallenge \
    requiresExactLowercase64HexChallengeHeader \
    rejectsDuplicateChallengeHeader \
    requiresExactChallengeBinding \
    requiresCanonicalNoritoRoundTrip \
    requiresNoStoreOnSuccessAndError \
    requiresExpectedChainId \
    requiresExpectedNodeKey \
    requiresExpectedNodeBuildFingerprint \
    requiresExpectedProtocolVersion \
    requiresExpectedConsensusMode \
    requiresExpectedValidatorRoster \
    requiresExpectedQuorum \
    requiresCanonicalSignedGenesis \
    requiresSignedGenesisSha256 \
    requiresGenesisPublicKey \
    requiresTrustedFirstHeightContextId \
    requiresStatefulSuccessorVerification \
    requiresBoundedSequentialBundleCatchUp \
    requiresImmediateSuccessorProofs \
    requiresCrashDurableVerifierCheckpoint \
    requiresMonotonicHeightAndContext \
    rejectsAdvancedOrStaleProof \
    requiresFreshAttestationAtSelectedTip \
    requiresGenesisFinalityProof \
    requiresTipFinalityProof \
    requiresFinalizedBlockHashBinding \
    requiresHeaderArtifactAndExecutionBinding \
    requiresNodeSignatureVerification \
    requiresAggregateSignatureVerification \
    requiresSingleStateView
do
    if [ "$(json_raw "finalityTrustContract.${finality_requirement}" "${iroha_readiness}")" != "true" ]; then
        echo "error: Nexus finality trust requirement is absent: ${finality_requirement}"
        exit 1
    fi
done
if [ "${production_finality_binding_status}" = "blocked" ]; then
    if [ -n "$(json_raw finalityTrustContract.serverContractSourceRevision "${iroha_readiness}")" ] ||
       [ -n "$(json_raw finalityTrustContract.serverOpenApiSha256 "${iroha_readiness}")" ] ||
       [ -n "$(json_raw finalityTrustContract.serverRouteSourceSha256 "${iroha_readiness}")" ] ||
       [ -n "$(json_raw finalityTrustContract.minamotoTrustedContextReceiptSha256 "${iroha_readiness}")" ] ||
       [ -n "$(json_raw finalityTrustContract.tairaTrustedContextReceiptSha256 "${iroha_readiness}")" ]; then
        echo "error: blocked finality trust contract claims reviewed server or network evidence"
        exit 1
    fi
else
    require_reviewed_sha1 \
        "finality server contract source revision" \
        "$(json_raw finalityTrustContract.serverContractSourceRevision "${iroha_readiness}")"
    require_reviewed_sha256 \
        "finality server OpenAPI" \
        "$(json_raw finalityTrustContract.serverOpenApiSha256 "${iroha_readiness}")"
    require_reviewed_sha256 \
        "finality server route source" \
        "$(json_raw finalityTrustContract.serverRouteSourceSha256 "${iroha_readiness}")"
    require_reviewed_sha256 \
        "Minamoto finality trust receipt" \
        "$(json_raw finalityTrustContract.minamotoTrustedContextReceiptSha256 "${iroha_readiness}")"
    require_reviewed_sha256 \
        "Taira finality trust receipt" \
        "$(json_raw finalityTrustContract.tairaTrustedContextReceiptSha256 "${iroha_readiness}")"
    if [ "$(json_raw finalityTrustContract.serverContractSourceRevision "${iroha_readiness}")" != "${IROHA_FINALITY_SERVER_CONTRACT_SOURCE_REVISION:-}" ] ||
       [ "$(json_raw finalityTrustContract.serverOpenApiSha256 "${iroha_readiness}")" != "${IROHA_FINALITY_SERVER_OPENAPI_SHA256:-}" ] ||
       [ "$(json_raw finalityTrustContract.serverRouteSourceSha256 "${iroha_readiness}")" != "${IROHA_FINALITY_SERVER_ROUTE_SOURCE_SHA256:-}" ] ||
       [ "$(json_raw finalityTrustContract.minamotoTrustedContextReceiptSha256 "${iroha_readiness}")" != "${IROHA_MINAMOTO_FINALITY_TRUST_RECEIPT_SHA256:-}" ] ||
       [ "$(json_raw finalityTrustContract.tairaTrustedContextReceiptSha256 "${iroha_readiness}")" != "${IROHA_TAIRA_FINALITY_TRUST_RECEIPT_SHA256:-}" ]; then
        echo "error: Nexus finality trust receipts are not pinned by release configuration"
        exit 1
    fi
fi

if [ "$(json_raw nativeCanaryContract.schemaVersion "${iroha_readiness}")" != "1" ] ||
   [ "$(json_raw nativeCanaryContract.handoffObservedAt "${iroha_readiness}")" != "2026-08-05" ] ||
   [ "$(json_raw nativeCanaryContract.referenceOnly "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw nativeCanaryContract.requiredNativeAbi "${iroha_readiness}")" != "21" ] ||
   [ "$(json_raw nativeCanaryContract.vectorSchema "${iroha_readiness}")" != "iroha.js.validation-fee-release-vector.v1" ] ||
   [ "$(json_raw nativeCanaryContract.vectorSha256 "${iroha_readiness}")" != "5a6ecca9a97d21acf979215e54df00fdd71544900a291270539e8fd374b078ce" ] ||
   [ "$(json_raw nativeCanaryContract.canonicalTypedSbdCbsiId "${iroha_readiness}")" != "7ZepsJTHCVLKsrFFNZGSRGZgvBhv" ] ||
   [ "$(json_raw nativeCanaryContract.policyFingerprint "${iroha_readiness}")" != "4ec93301681c32cc0d44c55939f6020a0c1a1aaa5ad24ff2723a7561873fbbf7" ] ||
   [ "$(json_raw nativeCanaryContract.payoutFingerprint "${iroha_readiness}")" != "c04b52fb6684b555ac69dd3aad026dacf3b325b5e9fa4fcc2b3bd70ca59a31d9" ] ||
   [ "$(json_raw nativeCanaryContract.dirtyLocalDebugArtifactAccepted "${iroha_readiness}")" != "false" ]; then
    echo "error: ABI-21 native canary reference contract is absent or inconsistent"
    exit 1
fi

native_canary_evidence_status="$(json_raw nativeCanaryContract.qualificationEvidence.status "${iroha_readiness}")"
native_canary_evidence_sha256="$(json_raw nativeCanaryContract.qualificationEvidence.receiptSha256 "${iroha_readiness}")"
require_exact_json_object_keys \
    "native canary qualification evidence pointer" \
    nativeCanaryContract.qualificationEvidence \
    "${iroha_readiness}" \
    status \
    receiptPath \
    receiptSha256
if [ "$(json_raw nativeCanaryContract.qualificationEvidence.receiptPath "${iroha_readiness}")" != "Fixtures/Modernization/iroha-native-canary-qualification-v1.json" ]; then
    echo "error: native canary qualification receipt path is not fixed"
    exit 1
fi
case "${native_canary_evidence_status}" in
    missing)
        if [ -n "${native_canary_evidence_sha256}" ] ||
           [ -e "${native_canary_qualification}" ] ||
           [ -L "${native_canary_qualification}" ]; then
            echo "error: missing native canary qualification evidence carries a receipt or hash"
            exit 1
        fi
        ;;
    qualified)
        require_reviewed_sha256 \
            "native canary qualification receipt" \
            "${native_canary_evidence_sha256}"
        ;;
    *)
        echo "error: native canary qualification evidence status is invalid"
        exit 1
        ;;
esac

for canary_qualification_field in \
    reviewedPlatformArtifactPresent \
    requiredExportInventoryQualified \
    transactionBytesParityQualified \
    signingPrehashParityQualified \
    signedEnvelopeParityQualified \
    decodeProjectionParityQualified
do
    case "$(json_raw "nativeCanaryContract.${canary_qualification_field}" "${iroha_readiness}")" in
        true|false) ;;
        *)
            echo "error: native canary qualification field is absent or invalid: ${canary_qualification_field}"
            exit 1
            ;;
    esac
done

if [ "${native_canary_evidence_status}" != "qualified" ]; then
    for canary_qualification_field in \
        reviewedPlatformArtifactPresent \
        requiredExportInventoryQualified \
        transactionBytesParityQualified \
        signingPrehashParityQualified \
        signedEnvelopeParityQualified \
        decodeProjectionParityQualified
    do
        if [ "$(json_raw "nativeCanaryContract.${canary_qualification_field}" "${iroha_readiness}")" != "false" ]; then
            echo "error: native canary qualification is claimed without a receipt"
            exit 1
        fi
    done
fi

unavailable_nexus_signer_source="$(
    /usr/bin/sed -n \
        '/^struct UnavailableNexusTransactionSigner: NexusTransactionSigning {$/,/^struct UnavailableNexusFinalityReader: NexusFinalityReading {$/p' \
        "${nexus_service}" |
        /usr/bin/sed '$d; /^[[:space:]]*\/\/\//d'
)"
if [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Fc 'struct UnavailableNexusTransactionSigner: NexusTransactionSigning {')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Fc 'func isQualified(')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Fc 'func quoteTransfer(')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Fc 'func signTransfer(')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Fc 'func finalizedCheckpoint(')" != "0" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Ec '^[[:space:]]*false[[:space:]]*$')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" | /usr/bin/grep -Ec '^[[:space:]]*throw NexusToriiError\.nativeBridgeUnavailable[[:space:]]*$')" != "2" ] ||
   /usr/bin/printf '%s\n' "${unavailable_nexus_signer_source}" |
       /usr/bin/grep -Eq 'return|URLSession|privateKey|mnemonic|seed|JSON|MCP|^[[:space:]]*true[[:space:]]*$'; then
    echo "error: UnavailableNexusTransactionSigner no longer fails closed"
    exit 1
fi

unavailable_nexus_finality_source="$(
    /usr/bin/sed -n \
        '/^struct UnavailableNexusFinalityReader: NexusFinalityReading {$/,/^enum NexusPendingState: String, Codable {$/p' \
        "${nexus_service}" |
        /usr/bin/sed '$d; /^[[:space:]]*\/\/\//d'
)"
if [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_finality_source}" | /usr/bin/grep -Fc 'struct UnavailableNexusFinalityReader: NexusFinalityReading {')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_finality_source}" | /usr/bin/grep -Fc 'func isQualified(')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_finality_source}" | /usr/bin/grep -Fc 'func finalizedCheckpoint(')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_finality_source}" | /usr/bin/grep -Ec '^[[:space:]]*false[[:space:]]*$')" != "1" ] ||
   [ "$(/usr/bin/printf '%s\n' "${unavailable_nexus_finality_source}" | /usr/bin/grep -Ec '^[[:space:]]*throw NexusToriiError\.finalizedHeadUnavailable[[:space:]]*$')" != "1" ] ||
   /usr/bin/printf '%s\n' "${unavailable_nexus_finality_source}" |
       /usr/bin/grep -Eq 'return|URLSession|submit|quote|sign|privateKey|mnemonic|seed|JSON|MCP'; then
    echo "error: UnavailableNexusFinalityReader no longer fails closed"
    exit 1
fi

if [ "${IROHA_PRODUCTION_READINESS_STATUS:-}" != "qualified" ] ||
   [ "${IROHA_SWIFT_INDEPENDENT_REVIEW_STATUS:-}" != "qualified" ] ||
   [ "${NORITO_BRIDGE_INDEPENDENT_REVIEW_STATUS:-}" != "qualified" ] ||
   [ "${production_signer_binding_status}" != "qualified" ] ||
   [ "${production_finality_binding_status}" != "qualified" ] ||
   [ "$(json_raw releaseEnabled "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw sourceReview.localReviewedSourcePresent "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw reviewedArtifact.localReviewedArtifactPresent "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw reviewedArtifact.headersAndModuleMapsCoveredByContentManifest "${iroha_readiness}")" != "true" ] ||
   [ "${native_canary_evidence_status}" != "qualified" ] ||
   [ "${native_canary_evidence_sha256}" != "${IROHA_NATIVE_CANARY_QUALIFICATION_RECEIPT_SHA256:-}" ] ||
   [ "$(json_raw nativeCanaryContract.reviewedPlatformArtifactPresent "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw nativeCanaryContract.requiredExportInventoryQualified "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw nativeCanaryContract.transactionBytesParityQualified "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw nativeCanaryContract.signingPrehashParityQualified "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw nativeCanaryContract.signedEnvelopeParityQualified "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw nativeCanaryContract.decodeProjectionParityQualified "${iroha_readiness}")" != "true" ] ||
   [ "$(json_raw productionSignerBinding.reviewedNativeArtifactSha256 "${iroha_readiness}")" != "$(json_raw reviewedArtifact.reviewedArchiveSha256 "${iroha_readiness}")" ] ||
   [ "$(json_raw productionSignerBinding.nativeCanaryReceiptSha256 "${iroha_readiness}")" != "${native_canary_evidence_sha256}" ]; then
    echo "error: IrohaSwift/NoritoBridge production readiness remains explicitly blocked"
    exit 1
fi

for qualified_criterion in \
    taggedSourceCompiles \
    sourceToBinaryIdentityProven \
    canonicalTransactionParityQualified \
    licenseAndNoticeReviewed \
    sbomReviewed \
    buildProvenanceReviewed \
    artifactAttestationReviewed \
    minimalLifetimeSecretBoundaryReviewed \
    authoritativeChainAssetAndFeeMappingQualified \
    sdkDeployedNodeCompatibilityQualified \
    nativeAbiAndExportInventoryQualified \
    validationFeeReleaseVectorQualified \
    transactionEnvelopeParityQualified \
    reviewedPlatformCanaryQualified \
    reviewedFinalityVerifierQualified \
    finalityTrustedContextsQualified \
    finalityAttestationCanaryQualified \
    localReceiptHashParityQualified \
    unavailableSignerReplaced \
    unavailableFinalityReaderReplaced
do
    if [ "$(json_raw "releaseCriteria.${qualified_criterion}" "${iroha_readiness}")" != "true" ]; then
        echo "error: Iroha production release criterion remains blocked: ${qualified_criterion}"
        exit 1
    fi
done
if [ "$(json_raw releaseCriteria.fundedTairaCanaryQualified "${iroha_readiness}")" != "false" ] ||
   [ "$(json_raw releaseCriteria.fundedMinamotoCanaryQualified "${iroha_readiness}")" != "false" ]; then
    echo "error: pre-canary readiness must not pre-claim funded Taira or Minamoto qualification"
    exit 1
fi

if [ "$(json_raw defaultSigner "${iroha_readiness}")" = "UnavailableNexusTransactionSigner" ]; then
    echo "error: Iroha readiness still records the fail-closed placeholder signer"
    exit 1
fi

if [ "$(json_raw defaultFinalityReader "${iroha_readiness}")" = "UnavailableNexusFinalityReader" ]; then
    echo "error: Iroha readiness still records the fail-closed finality reader"
    exit 1
fi

require_reviewed_sha1 "IrohaSwift source tree object" "${IROHA_SWIFT_SOURCE_TREE_OBJECT:-}"
require_reviewed_sha256 "IrohaSwift source manifest" "${IROHA_SWIFT_SOURCE_MANIFEST_SHA256:-}"
require_reviewed_sha256 "IrohaSwift provenance receipt" "${IROHA_SWIFT_PROVENANCE_RECEIPT_SHA256:-}"
require_reviewed_sha256 "NoritoBridge reviewed archive" "${NORITO_BRIDGE_REVIEWED_ARCHIVE_SHA256:-}"
require_reviewed_sha256 "NoritoBridge provenance receipt" "${NORITO_BRIDGE_PROVENANCE_RECEIPT_SHA256:-}"
require_reviewed_sha256 "NoritoBridge content manifest" "${NORITO_BRIDGE_CONTENT_MANIFEST_SHA256:-}"
require_reviewed_sha256 "NoritoBridge Info.plist" "${NORITO_BRIDGE_INFO_PLIST_SHA256:-}"
require_reviewed_sha256 "NoritoBridge ios-arm64 binary" "${NORITO_BRIDGE_IOS_ARM64_BINARY_SHA256:-}"
require_reviewed_sha256 "NoritoBridge simulator binary" "${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_SHA256:-}"
require_reviewed_sha256 "NoritoBridge macos-arm64 binary" "${NORITO_BRIDGE_MACOS_ARM64_BINARY_SHA256:-}"
require_reviewed_sha256 \
    "native canary qualification receipt" \
    "${IROHA_NATIVE_CANARY_QUALIFICATION_RECEIPT_SHA256:-}"

case "${IROHA_SWIFT_SOURCE_FILE_COUNT:-}" in
    ""|*[!0-9]*)
        echo "error: reviewed IrohaSwift source file count is not pinned"
        exit 1
        ;;
esac
if [ "${IROHA_SWIFT_SOURCE_FILE_COUNT}" -le 0 ] ||
   [ "${NORITO_BRIDGE_EXPECTED_CONTENT_FILE_COUNT:-}" != "13" ]; then
    echo "error: reviewed dependency content counts are invalid"
    exit 1
fi

if [ "$(json_raw sourceReview.sourceTreeObject "${iroha_readiness}")" != "${IROHA_SWIFT_SOURCE_TREE_OBJECT}" ] ||
   [ "$(json_raw sourceReview.sourceFileCount "${iroha_readiness}")" != "${IROHA_SWIFT_SOURCE_FILE_COUNT}" ] ||
   [ "$(json_raw sourceReview.sourceManifestSha256 "${iroha_readiness}")" != "${IROHA_SWIFT_SOURCE_MANIFEST_SHA256}" ] ||
   [ "$(json_raw sourceReview.provenanceReceiptSha256 "${iroha_readiness}")" != "${IROHA_SWIFT_PROVENANCE_RECEIPT_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.reviewedArchiveSha256 "${iroha_readiness}")" != "${NORITO_BRIDGE_REVIEWED_ARCHIVE_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.provenanceReceiptSha256 "${iroha_readiness}")" != "${NORITO_BRIDGE_PROVENANCE_RECEIPT_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.contentManifestSha256 "${iroha_readiness}")" != "${NORITO_BRIDGE_CONTENT_MANIFEST_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.infoPlistSha256 "${iroha_readiness}")" != "${NORITO_BRIDGE_INFO_PLIST_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.expectedContentFileCount "${iroha_readiness}")" != "${NORITO_BRIDGE_EXPECTED_CONTENT_FILE_COUNT}" ] ||
   [ "$(json_raw reviewedArtifact.binarySliceSha256.ios-arm64 "${iroha_readiness}")" != "${NORITO_BRIDGE_IOS_ARM64_BINARY_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.binarySliceSha256.ios-arm64_x86_64-simulator "${iroha_readiness}")" != "${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_SHA256}" ] ||
   [ "$(json_raw reviewedArtifact.binarySliceSha256.macos-arm64 "${iroha_readiness}")" != "${NORITO_BRIDGE_MACOS_ARM64_BINARY_SHA256}" ] ||
   [ "${native_canary_evidence_sha256}" != "${IROHA_NATIVE_CANARY_QUALIFICATION_RECEIPT_SHA256}" ]; then
    echo "error: qualified readiness evidence does not match the pinned reviewed dependency identities"
    exit 1
fi

if [ ! -f "${native_canary_qualification}" ] ||
   [ -L "${root}/Fixtures" ] ||
   [ -L "${root}/Fixtures/Modernization" ] ||
   [ -L "${native_canary_qualification}" ] ||
   [ ! -s "${native_canary_qualification}" ] ||
   [ "$(/usr/bin/stat -f '%z' "${native_canary_qualification}" 2>/dev/null || /usr/bin/printf '0')" -gt 65536 ] ||
   [ "$(sha256_file "${native_canary_qualification}")" != "${IROHA_NATIVE_CANARY_QUALIFICATION_RECEIPT_SHA256}" ] ||
   [ "$(json_raw schemaVersion "${native_canary_qualification}")" != "1" ] ||
   [ "$(json_raw platform "${native_canary_qualification}")" != "ios" ] ||
   [ "$(json_raw status "${native_canary_qualification}")" != "qualified" ] ||
   [ "$(json_raw privacy.containsSecrets "${native_canary_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.containsPrivateKeys "${native_canary_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.containsRawSignedPayloads "${native_canary_qualification}")" != "false" ] ||
   [ "$(json_raw artifactBinding.artifactClass "${native_canary_qualification}")" != "reviewed-platform-release" ] ||
   [ "$(json_raw artifactBinding.sourceTreeClean "${native_canary_qualification}")" != "true" ] ||
   [ "$(json_raw artifactBinding.upstreamRevision "${native_canary_qualification}")" != "${IROHA_SWIFT_REVISION}" ] ||
   [ "$(json_raw artifactBinding.sourceTreeObject "${native_canary_qualification}")" != "${IROHA_SWIFT_SOURCE_TREE_OBJECT}" ] ||
   [ "$(json_raw artifactBinding.sourceManifestSha256 "${native_canary_qualification}")" != "${IROHA_SWIFT_SOURCE_MANIFEST_SHA256}" ] ||
   [ "$(json_raw artifactBinding.sourceProvenanceReceiptSha256 "${native_canary_qualification}")" != "${IROHA_SWIFT_PROVENANCE_RECEIPT_SHA256}" ] ||
   [ "$(json_raw artifactBinding.reviewedArchiveSha256 "${native_canary_qualification}")" != "${NORITO_BRIDGE_REVIEWED_ARCHIVE_SHA256}" ] ||
   [ "$(json_raw artifactBinding.artifactProvenanceReceiptSha256 "${native_canary_qualification}")" != "${NORITO_BRIDGE_PROVENANCE_RECEIPT_SHA256}" ] ||
   [ "$(json_raw artifactBinding.contentManifestSha256 "${native_canary_qualification}")" != "${NORITO_BRIDGE_CONTENT_MANIFEST_SHA256}" ] ||
   [ "$(json_raw artifactBinding.infoPlistSha256 "${native_canary_qualification}")" != "${NORITO_BRIDGE_INFO_PLIST_SHA256}" ] ||
   [ "$(json_raw artifactBinding.binarySliceSha256.ios-arm64 "${native_canary_qualification}")" != "${NORITO_BRIDGE_IOS_ARM64_BINARY_SHA256}" ] ||
   [ "$(json_raw artifactBinding.binarySliceSha256.ios-arm64_x86_64-simulator "${native_canary_qualification}")" != "${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_SHA256}" ] ||
   [ "$(json_raw artifactBinding.binarySliceSha256.macos-arm64 "${native_canary_qualification}")" != "${NORITO_BRIDGE_MACOS_ARM64_BINARY_SHA256}" ] ||
   [ "$(json_raw nativeContract.requiredNativeAbi "${native_canary_qualification}")" != "21" ] ||
   [ "$(json_raw nativeContract.vectorSchema "${native_canary_qualification}")" != "iroha.js.validation-fee-release-vector.v1" ] ||
   [ "$(json_raw nativeContract.vectorSha256 "${native_canary_qualification}")" != "5a6ecca9a97d21acf979215e54df00fdd71544900a291270539e8fd374b078ce" ] ||
   [ "$(json_raw nativeContract.canonicalTypedSbdCbsiId "${native_canary_qualification}")" != "7ZepsJTHCVLKsrFFNZGSRGZgvBhv" ] ||
   [ "$(json_raw nativeContract.policyFingerprint "${native_canary_qualification}")" != "4ec93301681c32cc0d44c55939f6020a0c1a1aaa5ad24ff2723a7561873fbbf7" ] ||
   [ "$(json_raw nativeContract.payoutFingerprint "${native_canary_qualification}")" != "c04b52fb6684b555ac69dd3aad026dacf3b325b5e9fa4fcc2b3bd70ca59a31d9" ] ||
   [ "$(json_raw nativeAbi.required "${native_canary_qualification}")" != "21" ] ||
   [ "$(json_raw nativeAbi.observed "${native_canary_qualification}")" != "21" ] ||
   [ "$(json_raw nativeAbi.qualified "${native_canary_qualification}")" != "true" ]; then
    echo "error: native canary qualification receipt is absent or not bound to the reviewed Apple inputs"
    exit 1
fi

require_exact_json_root_keys \
    "native canary qualification receipt" \
    "${native_canary_qualification}" \
    schemaVersion \
    platform \
    status \
    privacy \
    artifactBinding \
    nativeContract \
    nativeAbi \
    parityEvidence
require_exact_json_object_keys \
    "native canary privacy evidence" \
    privacy \
    "${native_canary_qualification}" \
    containsSecrets \
    containsPrivateKeys \
    containsRawSignedPayloads
require_exact_json_object_keys \
    "native canary artifact binding" \
    artifactBinding \
    "${native_canary_qualification}" \
    artifactClass \
    sourceTreeClean \
    upstreamRevision \
    sourceTreeObject \
    sourceManifestSha256 \
    sourceProvenanceReceiptSha256 \
    reviewedArchiveSha256 \
    artifactProvenanceReceiptSha256 \
    contentManifestSha256 \
    infoPlistSha256 \
    binarySliceSha256
require_exact_json_object_keys \
    "native canary binary slice binding" \
    artifactBinding.binarySliceSha256 \
    "${native_canary_qualification}" \
    ios-arm64 \
    ios-arm64_x86_64-simulator \
    macos-arm64
require_exact_json_object_keys \
    "native canary reference contract" \
    nativeContract \
    "${native_canary_qualification}" \
    requiredNativeAbi \
    vectorSchema \
    vectorSha256 \
    canonicalTypedSbdCbsiId \
    policyFingerprint \
    payoutFingerprint
require_exact_json_object_keys \
    "native canary ABI evidence" \
    nativeAbi \
    "${native_canary_qualification}" \
    required \
    observed \
    qualified
require_exact_json_object_keys \
    "native canary parity evidence" \
    parityEvidence \
    "${native_canary_qualification}" \
    requiredExportInventory \
    transactionBytes \
    signingPrehash \
    signedEnvelope \
    decodeProjection
require_exact_json_object_keys \
    "native canary export inventory evidence" \
    parityEvidence.requiredExportInventory \
    "${native_canary_qualification}" \
    referenceSha256 \
    platformSha256 \
    referenceCount \
    platformCount \
    qualified

native_canary_export_reference_sha256="$(json_raw parityEvidence.requiredExportInventory.referenceSha256 "${native_canary_qualification}")"
native_canary_export_platform_sha256="$(json_raw parityEvidence.requiredExportInventory.platformSha256 "${native_canary_qualification}")"
native_canary_export_reference_count="$(json_raw parityEvidence.requiredExportInventory.referenceCount "${native_canary_qualification}")"
native_canary_export_platform_count="$(json_raw parityEvidence.requiredExportInventory.platformCount "${native_canary_qualification}")"
require_reviewed_sha256 \
    "native canary required export inventory reference" \
    "${native_canary_export_reference_sha256}"
if ! is_unsigned_integer "${native_canary_export_reference_count}" ||
   [ "${native_canary_export_reference_count}" -le 0 ] ||
   [ "${native_canary_export_platform_count}" != "${native_canary_export_reference_count}" ] ||
   [ "${native_canary_export_platform_sha256}" != "${native_canary_export_reference_sha256}" ] ||
   [ "$(json_raw parityEvidence.requiredExportInventory.qualified "${native_canary_qualification}")" != "true" ]; then
    echo "error: native canary required export inventory parity is incomplete"
    exit 1
fi

for native_canary_parity_stage in \
    transactionBytes \
    signingPrehash \
    signedEnvelope \
    decodeProjection
do
    require_exact_json_object_keys \
        "native canary ${native_canary_parity_stage} parity evidence" \
        "parityEvidence.${native_canary_parity_stage}" \
        "${native_canary_qualification}" \
        referenceSha256 \
        platformSha256 \
        qualified
    native_canary_reference_sha256="$(json_raw "parityEvidence.${native_canary_parity_stage}.referenceSha256" "${native_canary_qualification}")"
    native_canary_platform_sha256="$(json_raw "parityEvidence.${native_canary_parity_stage}.platformSha256" "${native_canary_qualification}")"
    require_reviewed_sha256 \
        "native canary ${native_canary_parity_stage} reference" \
        "${native_canary_reference_sha256}"
    if [ "${native_canary_platform_sha256}" != "${native_canary_reference_sha256}" ] ||
       [ "$(json_raw "parityEvidence.${native_canary_parity_stage}.qualified" "${native_canary_qualification}")" != "true" ]; then
        echo "error: native canary parity receipt is incomplete: ${native_canary_parity_stage}"
        exit 1
    fi
done

if [ ! -f "${iroha_source}/PINNED_REVISION" ] ||
   [ -L "${iroha_source}/PINNED_REVISION" ] ||
   [ "$(/usr/bin/tr -d '[:space:]' < "${iroha_source}/PINNED_REVISION")" != "${IROHA_SWIFT_REVISION}" ] ||
   [ ! -f "${iroha_source}/PINNED_TAG" ] ||
   [ -L "${iroha_source}/PINNED_TAG" ] ||
   [ "$(/usr/bin/tr -d '[:space:]' < "${iroha_source}/PINNED_TAG")" != "${IROHA_SWIFT_UPSTREAM_TAG}" ]; then
    echo "error: reviewed Vendor/IrohaSwift identity receipts are absent or mismatched"
    exit 1
fi

iroha_provenance="${iroha_source}/PROVENANCE.json"
iroha_content_manifest="${iroha_source}/REVIEWED_CONTENTS.sha256"
if [ ! -f "${iroha_provenance}" ] ||
   [ -L "${iroha_provenance}" ] ||
   [ "$(sha256_file "${iroha_provenance}")" != "${IROHA_SWIFT_PROVENANCE_RECEIPT_SHA256}" ] ||
   [ ! -f "${iroha_content_manifest}" ] ||
   [ -L "${iroha_content_manifest}" ] ||
   [ "$(sha256_file "${iroha_content_manifest}")" != "${IROHA_SWIFT_SOURCE_MANIFEST_SHA256}" ] ||
   [ "$(json_raw format "${iroha_provenance}")" != "sora-ios-iroha-swift-provenance-v1" ] ||
   [ "$(json_raw independentReviewStatus "${iroha_provenance}")" != "qualified" ] ||
   [ "$(json_raw upstreamTag "${iroha_provenance}")" != "${IROHA_SWIFT_UPSTREAM_TAG}" ] ||
   [ "$(json_raw revision "${iroha_provenance}")" != "${IROHA_SWIFT_REVISION}" ] ||
   [ "$(json_raw sourceTreeObject "${iroha_provenance}")" != "${IROHA_SWIFT_SOURCE_TREE_OBJECT}" ] ||
   [ "$(json_raw sourceFileCount "${iroha_provenance}")" != "${IROHA_SWIFT_SOURCE_FILE_COUNT}" ] ||
   [ "$(json_raw sourceManifestSha256 "${iroha_provenance}")" != "${IROHA_SWIFT_SOURCE_MANIFEST_SHA256}" ]; then
    echo "error: Vendor/IrohaSwift lacks an exact independently reviewed whole-tree receipt"
    exit 1
fi

if [ ! -d "${bridge}" ]; then
    echo "error: independently reviewed NoritoBridge.xcframework is absent"
    exit 1
fi

bridge_provenance="${bridge}/PROVENANCE.json"
bridge_content_manifest="${bridge}/REVIEWED_CONTENTS.sha256"
if [ ! -f "${bridge}/UPSTREAM_ZIP_SHA256" ] ||
   [ -L "${bridge}/UPSTREAM_ZIP_SHA256" ] ||
   [ "$(/usr/bin/tr -d '[:space:]' < "${bridge}/UPSTREAM_ZIP_SHA256")" != "${NORITO_BRIDGE_REVIEWED_ARCHIVE_SHA256}" ] ||
   [ ! -f "${bridge_provenance}" ] ||
   [ -L "${bridge_provenance}" ] ||
   [ "$(sha256_file "${bridge_provenance}")" != "${NORITO_BRIDGE_PROVENANCE_RECEIPT_SHA256}" ] ||
   [ ! -f "${bridge_content_manifest}" ] ||
   [ -L "${bridge_content_manifest}" ] ||
   [ "$(sha256_file "${bridge_content_manifest}")" != "${NORITO_BRIDGE_CONTENT_MANIFEST_SHA256}" ] ||
   [ "$(json_raw format "${bridge_provenance}")" != "sora-ios-norito-bridge-provenance-v1" ] ||
   [ "$(json_raw independentReviewStatus "${bridge_provenance}")" != "qualified" ] ||
   [ "$(json_raw upstreamRevision "${bridge_provenance}")" != "${IROHA_SWIFT_REVISION}" ] ||
   [ "$(json_raw observedMutableArchiveSha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_OBSERVED_MUTABLE_ARCHIVE_SHA256}" ] ||
   [ "$(json_raw reviewedArchiveSha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_REVIEWED_ARCHIVE_SHA256}" ] ||
   [ "$(json_raw githubReleaseImmutable "${bridge_provenance}")" != "false" ] ||
   [ "$(json_raw contentManifestSha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_CONTENT_MANIFEST_SHA256}" ] ||
   [ "$(json_raw infoPlistSha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_INFO_PLIST_SHA256}" ] ||
   [ "$(json_raw contentFileCount "${bridge_provenance}")" != "${NORITO_BRIDGE_EXPECTED_CONTENT_FILE_COUNT}" ]; then
    echo "error: NoritoBridge lacks an exact independently reviewed artifact receipt"
    exit 1
fi

verification_tmp="$(
    /usr/bin/mktemp -d "${TMPDIR:-/tmp}/sora-modernization-provenance.XXXXXX"
)"
cleanup_verification_tmp() {
    if [ -n "${verification_tmp:-}" ] && [ -d "${verification_tmp}" ]; then
        /bin/rm -rf "${verification_tmp}"
    fi
}
trap cleanup_verification_tmp EXIT HUP INT TERM

vendored_binary_authentication="$(
    /bin/sh "${vendored_binary_qualification_validator}" --verify-qualified 2>/dev/null
)" || {
    echo "error: production vendored XCFramework evidence is not independently authenticated"
    exit 1
}
case "${vendored_binary_authentication}" in
    receiptSha256=*)
        vendored_binary_authenticated_sha256="${vendored_binary_authentication#receiptSha256=}"
        ;;
    *)
        echo "error: vendored XCFramework authenticator returned an invalid result"
        exit 1
        ;;
esac
if ! is_lower_hex_length "${vendored_binary_authenticated_sha256}" 64 ||
   [ "$(/usr/bin/printf '%s\n' "${vendored_binary_authentication}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" != "1" ] ||
   [ ! -f "${vendored_binary_qualification}" ] ||
   [ -L "${vendored_binary_qualification}" ]; then
    echo "error: authenticated vendored XCFramework receipt result is malformed"
    exit 1
fi
vendored_binary_qualification_snapshot="${verification_tmp}/ios-vendored-binary-qualification.json"
/bin/cp -p "${vendored_binary_qualification}" "${vendored_binary_qualification_snapshot}"
if [ ! -f "${vendored_binary_qualification_snapshot}" ] ||
   [ -L "${vendored_binary_qualification_snapshot}" ] ||
   [ "$(sha256_file "${vendored_binary_qualification_snapshot}")" != "${vendored_binary_authenticated_sha256}" ] ||
   [ "$(sha256_file "${vendored_binary_qualification}")" != "${vendored_binary_authenticated_sha256}" ]; then
    echo "error: vendored XCFramework receipt changed after authentication"
    exit 1
fi

verify_complete_sha256_tree \
    "${iroha_source}" \
    "${iroha_content_manifest}" \
    "${IROHA_SWIFT_SOURCE_FILE_COUNT}" \
    iroha-source \
    "IrohaSwift" \
    iroha

verify_complete_sha256_tree \
    "${bridge}" \
    "${bridge_content_manifest}" \
    "${NORITO_BRIDGE_EXPECTED_CONTENT_FILE_COUNT}" \
    norito-xcframework \
    "NoritoBridge.xcframework" \
    norito

for required_bridge_file in \
    Info.plist \
    ios-arm64/libNoritoBridge.a \
    ios-arm64/Headers/NoritoBridge.h \
    ios-arm64/Headers/connect_norito_bridge.h \
    ios-arm64/Headers/module.modulemap \
    ios-arm64_x86_64-simulator/libNoritoBridge.a \
    ios-arm64_x86_64-simulator/Headers/NoritoBridge.h \
    ios-arm64_x86_64-simulator/Headers/connect_norito_bridge.h \
    ios-arm64_x86_64-simulator/Headers/module.modulemap \
    macos-arm64/libNoritoBridge.a \
    macos-arm64/Headers/NoritoBridge.h \
    macos-arm64/Headers/connect_norito_bridge.h \
    macos-arm64/Headers/module.modulemap
do
    if [ ! -f "${bridge}/${required_bridge_file}" ] ||
       [ -L "${bridge}/${required_bridge_file}" ]; then
        echo "error: reviewed NoritoBridge content is missing: ${required_bridge_file}"
        exit 1
    fi
done

if [ "$(sha256_file "${bridge}/Info.plist")" != "${NORITO_BRIDGE_INFO_PLIST_SHA256}" ] ||
   [ "$(sha256_file "${bridge}/${NORITO_BRIDGE_IOS_ARM64_BINARY_RELATIVE_PATH}")" != "${NORITO_BRIDGE_IOS_ARM64_BINARY_SHA256}" ] ||
   [ "$(sha256_file "${bridge}/${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_RELATIVE_PATH}")" != "${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_SHA256}" ] ||
   [ "$(sha256_file "${bridge}/${NORITO_BRIDGE_MACOS_ARM64_BINARY_RELATIVE_PATH}")" != "${NORITO_BRIDGE_MACOS_ARM64_BINARY_SHA256}" ]; then
    echo "error: reviewed NoritoBridge Info.plist or native slice checksum mismatch"
    exit 1
fi

if [ "$(json_raw libraries.0.identifier "${bridge_provenance}")" != "ios-arm64" ] ||
   [ "$(json_raw libraries.0.binaryRelativePath "${bridge_provenance}")" != "${NORITO_BRIDGE_IOS_ARM64_BINARY_RELATIVE_PATH}" ] ||
   [ "$(json_raw libraries.0.binarySha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_IOS_ARM64_BINARY_SHA256}" ] ||
   [ "$(json_raw libraries.1.identifier "${bridge_provenance}")" != "ios-arm64_x86_64-simulator" ] ||
   [ "$(json_raw libraries.1.binaryRelativePath "${bridge_provenance}")" != "${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_RELATIVE_PATH}" ] ||
   [ "$(json_raw libraries.1.binarySha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_IOS_SIMULATOR_BINARY_SHA256}" ] ||
   [ "$(json_raw libraries.2.identifier "${bridge_provenance}")" != "macos-arm64" ] ||
   [ "$(json_raw libraries.2.binaryRelativePath "${bridge_provenance}")" != "${NORITO_BRIDGE_MACOS_ARM64_BINARY_RELATIVE_PATH}" ] ||
   [ "$(json_raw libraries.2.binarySha256 "${bridge_provenance}")" != "${NORITO_BRIDGE_MACOS_ARM64_BINARY_SHA256}" ] ||
   [ -n "$(json_raw libraries.3.identifier "${bridge_provenance}")" ]; then
    echo "error: NoritoBridge provenance does not cover every native slice exactly once"
    exit 1
fi

for library_index in 0 1 2
do
    if [ "$(json_raw "libraries.${library_index}.headers.0" "${bridge_provenance}")" != "NoritoBridge.h" ] ||
       [ "$(json_raw "libraries.${library_index}.headers.1" "${bridge_provenance}")" != "connect_norito_bridge.h" ] ||
       [ -n "$(json_raw "libraries.${library_index}.headers.2" "${bridge_provenance}")" ] ||
       [ "$(json_raw "libraries.${library_index}.moduleMap" "${bridge_provenance}")" != "module.modulemap" ]; then
        echo "error: NoritoBridge provenance does not cover every slice header and module map"
        exit 1
    fi
done

if ! /usr/bin/plutil -lint "${bridge}/Info.plist" >/dev/null; then
    echo "error: reviewed NoritoBridge Info.plist is invalid"
    exit 1
fi

seen_ios_arm64=false
seen_ios_simulator=false
seen_macos_arm64=false
for library_index in 0 1 2
do
    library_identifier="$(json_raw "AvailableLibraries.${library_index}.LibraryIdentifier" "${bridge}/Info.plist")"
    library_path="$(json_raw "AvailableLibraries.${library_index}.LibraryPath" "${bridge}/Info.plist")"
    headers_path="$(json_raw "AvailableLibraries.${library_index}.HeadersPath" "${bridge}/Info.plist")"
    supported_platform="$(json_raw "AvailableLibraries.${library_index}.SupportedPlatform" "${bridge}/Info.plist")"
    supported_variant="$(json_raw "AvailableLibraries.${library_index}.SupportedPlatformVariant" "${bridge}/Info.plist")"

    if [ "${library_path}" != "libNoritoBridge.a" ] ||
       [ "${headers_path}" != "Headers" ]; then
        echo "error: NoritoBridge Info.plist does not route a reviewed library and header tree"
        exit 1
    fi

    case "${library_identifier}" in
        ios-arm64)
            [ "${supported_platform}" = "ios" ] &&
                [ -z "${supported_variant}" ] &&
                [ "${seen_ios_arm64}" = "false" ] || {
                    echo "error: NoritoBridge ios-arm64 Info.plist identity is invalid"
                    exit 1
                }
            seen_ios_arm64=true
            ;;
        ios-arm64_x86_64-simulator)
            [ "${supported_platform}" = "ios" ] &&
                [ "${supported_variant}" = "simulator" ] &&
                [ "${seen_ios_simulator}" = "false" ] || {
                    echo "error: NoritoBridge simulator Info.plist identity is invalid"
                    exit 1
                }
            seen_ios_simulator=true
            ;;
        macos-arm64)
            [ "${supported_platform}" = "macos" ] &&
                [ -z "${supported_variant}" ] &&
                [ "${seen_macos_arm64}" = "false" ] || {
                    echo "error: NoritoBridge macos-arm64 Info.plist identity is invalid"
                    exit 1
                }
            seen_macos_arm64=true
            ;;
        *)
            echo "error: NoritoBridge Info.plist exposes an unreviewed library identifier"
            exit 1
            ;;
    esac
done

if [ "${seen_ios_arm64}" != "true" ] ||
   [ "${seen_ios_simulator}" != "true" ] ||
   [ "${seen_macos_arm64}" != "true" ] ||
   [ -n "$(json_raw AvailableLibraries.3.LibraryIdentifier "${bridge}/Info.plist")" ]; then
    echo "error: NoritoBridge Info.plist does not contain exactly the three reviewed slices"
    exit 1
fi

if ! /usr/bin/grep -Fq "Vendor/IrohaSwift" "${project}"; then
    echo "error: Xcode project does not use the reviewed local IrohaSwift source tree"
    exit 1
fi

if ! /usr/bin/grep -Fq "NoritoBridge.xcframework" "${project}"; then
    echo "error: Xcode project does not link the reviewed NoritoBridge"
    exit 1
fi

if ! /usr/bin/grep -Fq "IPHONEOS_DEPLOYMENT_TARGET = 16.0;" "${project}" ||
   /usr/bin/grep -E "IPHONEOS_DEPLOYMENT_TARGET = " "${project}" |
       /usr/bin/grep -Fqv "IPHONEOS_DEPLOYMENT_TARGET = 16.0;"; then
    echo "error: SORA's existing iOS 16.0 deployment target changed during SDK integration"
    exit 1
fi

if [ ! -f "${rollout_candidate_template}" ] ||
   [ -L "${rollout_candidate_template}" ] ||
   [ ! -f "${rollout_template}" ] ||
   [ -L "${rollout_template}" ] ||
   [ ! -f "${rollout_controller_trust}" ] ||
   [ -L "${rollout_controller_trust}" ] ||
   [ ! -f "${dependency_verifier}" ] ||
   [ -L "${dependency_verifier}" ] ||
   [ ! -f "${rollout_validator}" ] ||
   [ -L "${rollout_validator}" ] ||
   [ ! -f "${rollout_json_validator}" ] ||
   [ -L "${rollout_json_validator}" ] ||
   [ ! -f "${rollout_regression_harness}" ] ||
   [ -L "${rollout_regression_harness}" ] ||
   [ ! -f "${rollout_documentation}" ] ||
   [ -L "${rollout_documentation}" ] ||
   [ ! -f "${taira_deployment_blocked}" ] ||
   [ -L "${taira_deployment_blocked}" ] ||
   [ ! -f "${taira_deployment_validator}" ] ||
   [ -L "${taira_deployment_validator}" ] ||
   [ ! -f "${taira_deployment_harness}" ] ||
   [ -L "${taira_deployment_harness}" ] ||
   ! /usr/bin/python3 -B -I -S "${taira_deployment_validator}" --lint-contract >/dev/null ||
   ! /usr/bin/python3 -B -I -S "${taira_deployment_harness}" >/dev/null ||
   ! /bin/sh "${rollout_validator}" --lint-templates >/dev/null ||
   ! /usr/bin/python3 -I -S "${rollout_regression_harness}" >/dev/null ||
   [ "$(json_raw schemaVersion "${rollout_candidate_template}")" != "3" ] ||
   [ "$(json_raw contractId "${rollout_candidate_template}")" != "sora-mobile-production-rollout-v3" ] ||
   [ "$(json_raw sequenceNumber "${rollout_candidate_template}")" != "1" ] ||
   [ "$(json_raw fromCohortPercent "${rollout_candidate_template}")" != "0" ] ||
   [ "$(json_raw targetCohortPercent "${rollout_candidate_template}")" != "1" ] ||
   [ "$(json_raw identity.candidateBindingSha256 "${rollout_candidate_template}")" != "UNAVAILABLE" ] ||
   [ "$(json_raw identity.evaluationBindingSha256 "${rollout_candidate_template}")" != "UNAVAILABLE" ] ||
   [ "$(json_raw schemaVersion "${rollout_template}")" != "3" ] ||
   [ "$(json_raw contractId "${rollout_template}")" != "sora-mobile-production-rollout-v3" ] ||
   [ "$(json_raw sequenceNumber "${rollout_template}")" != "2" ] ||
   [ "$(json_raw fromCohortPercent "${rollout_template}")" != "1" ] ||
   [ "$(json_raw targetCohortPercent "${rollout_template}")" != "5" ] ||
   [ "$(json_raw priorReceiptSha256 "${rollout_template}")" != "UNAVAILABLE" ] ||
   ! /usr/bin/grep -Fq 'duplicate JSON key after escape decoding' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'non-canonical negative-zero JSON integer is forbidden' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'exact_keys(value' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'O_NOFOLLOW' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'private evidence snapshot' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'actual IPA path was rebound during qualification' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'IPA must contain exactly one Payload/*.app/Info.plist' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-production-artifact-identity-v2' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-production-qualification-v2' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'tairaDeploymentManifestSha256' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'configure_authenticated_taira' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'configure_authenticated_taira' "${funded_canary_json_validator}" ||
   ! /usr/bin/grep -Fq 'current["deploymentEpoch"] <= retired["deploymentEpoch"]' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'current["deploymentEpoch"] <= retired["deploymentEpoch"]' "${funded_canary_json_validator}" ||
   ! /usr/bin/grep -Fq 'KNOWN_CHAIN_IDS' "${taira_deployment_validator}" ||
   ! /usr/bin/grep -Fq 'CONVENIENCE_HOST = "taira.sora.org"' "${taira_deployment_validator}" ||
   ! /usr/bin/grep -Fq 'operator and reviewer signature/key identities must be distinct' "${taira_deployment_validator}" ||
   ! /usr/bin/grep -Fq 'schema-77 pending rows must preserve UUID' "${taira_deployment_validator}" ||
   ! /usr/bin/grep -Fq 'current["deploymentEpoch"] <= retired["deploymentEpoch"]' "${taira_deployment_validator}" ||
   ! /usr/bin/grep -Fq 'TairaDeploymentBinding' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq 'currentDeploymentEpoch > retiredDeploymentEpoch' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq 'parsed <= 9_007_199_254_740_991' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq 'NexusPendingTairaDeploymentIdentity' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'testSameUUIDLegacyTairaPendingRowRemainsRecoveryOnlyAcrossBothMappings' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v3' "${rollout_json_validator}" ||
   /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v2' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq '"mobileConfigHealthBound"' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq '"historyBlockHeightContractDeployed"' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'require_int(pi.get("schemaVersion"), "pi.schemaVersion", 3, 3)' "${funded_canary_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v3' "${funded_canary_json_validator}" ||
   /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v2' "${funded_canary_json_validator}" ||
   ! /usr/bin/grep -Fq '"mobileConfigHealthBound"' "${funded_canary_json_validator}" ||
   ! /usr/bin/grep -Fq '"historyBlockHeightContractDeployed"' "${funded_canary_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-mobile-production-rollout-v3' "${rollout_json_validator}" ||
   /usr/bin/grep -Fq 'sora-mobile-production-rollout-v2' "${rollout_json_validator}" ||
   /usr/bin/grep -Fq 'exact v2' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'wire-incompatible with v2' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v3' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'PI `sora-pi-production-capability-probe-v2` receipts are wire-incompatible with v3 and are rejected' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'protected producer compatibility remains a hard release blocker' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'schemaVersion=3' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'mobileConfigHealthBound=true' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'historyBlockHeightContractDeployed=true' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'starts a new chain at 1%' "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq 'sora-ios-rollout-telemetry-attestation-v1' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'sora-ios-distribution-cohort-attestation-v1' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TARGET_PERCENT is required; omission is never qualification' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_KEYCHAIN_ACCESS_GROUPS_SHA256' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_QUALIFICATION_RECEIPT_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PI_PRODUCTION_PROBE_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_RECEIPT_1_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_RECEIPT_1_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_RECEIPT_5_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_RECEIPT_5_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_RECEIPT_25_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_RECEIPT_25_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_1_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_1_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_25_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_25_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_25_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_25_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_25_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_25_SIGNATURE_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'validate_stored_rollout_binding' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'validate_prior_link' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'link_cohort_started_at}" -gt' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'piCapturedAtEpochSeconds' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'authorizedAtEpochSeconds' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_PATH' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'minimum_dwell_seconds=172800' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'maximum_freshness_seconds=300' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'maximum_authorization_delay_seconds=30' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'worker_last_success' "${rollout_validator}" ||
   [ "$(/usr/bin/grep -Fc 'schemaVersion=3\nconfigRevision=%s\nendpoint=https://pi.soramitsu.io/graphql' "${rollout_validator}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'workerReady=true\nmobileConfigHealthBound=true\nhistoryBlockHeightContractDeployed=true\nnexusAvailable=true' "${rollout_validator}")" -lt 2 ] ||
   /usr/bin/grep -Fq 'schemaVersion=2\nconfigRevision=%s\nendpoint=https://pi.soramitsu.io/graphql' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'network genesis changed or a finalized checkpoint regressed' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'same height across rollout gates' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'YLWWUD25VZ.co.jp.soramitsu.sora' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'all-zero placeholder' "${rollout_json_validator}" ||
   ! /usr/bin/grep -Fq 'ASN1 OID: prime256v1|NIST CURVE: P-256' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'secure_openssl()' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq '/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/openssl "$@"' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'secure_openssl dgst -sha256' "${rollout_validator}" ||
   ! /usr/bin/grep -Fq 'secure_openssl()' "${funded_canary_validator}" ||
   ! /usr/bin/grep -Fq '/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/openssl "$@"' "${funded_canary_validator}" ||
   ! /usr/bin/grep -Fq 'secure_openssl dgst -sha256' "${funded_canary_validator}" ||
   [ "$(/usr/bin/grep -Fc '/usr/bin/python3' "${rollout_validator}")" -ne "$(/usr/bin/grep -Fc '/usr/bin/python3 -I -S' "${rollout_validator}")" ] ||
   [ "$(/usr/bin/grep -Fc '/usr/bin/python3' "${funded_canary_validator}")" -ne "$(/usr/bin/grep -Fc '/usr/bin/python3 -I -S' "${funded_canary_validator}")" ] ||
   ! /usr/bin/grep -Fq '5 success paths and 35 fail-closed mutations passed' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v3' "${rollout_regression_harness}" ||
   [ "$(/usr/bin/grep -Fc 'sora-pi-production-capability-probe-v2' "${rollout_regression_harness}")" -ne 1 ] ||
   ! /usr/bin/grep -Fq 'LEGACY_PI_V2_CONTRACT_ID_NEGATIVE_TEST_ONLY' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'legacy_pi_v2_capability_binding_negative_test_only' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'legacy_pi_v2_target=1' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'legacy-pi-v2-replay' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'legacy PI v2 negative-test envelope is not exact' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"schemaVersion=2"' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'current_pi_value["capabilities"].pop("mobileConfigHealthBound")' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'current_pi_value["capabilities"].pop("historyBlockHeightContractDeployed")' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"mobileConfigHealthBound": True' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"historyBlockHeightContractDeployed": True' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"mobileConfigHealthBound"] = False' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"historyBlockHeightContractDeployed"] = False' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'false-mobile-config-health-bound' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'false-history-block-height-contract-deployed' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"schemaVersion=3"' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"mobileConfigHealthBound=true"' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq '"historyBlockHeightContractDeployed=true"' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'legacy-rollout-v2-replay' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'HARNESS_TIMEOUT_SECONDS = 1200' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'timeout=bounded_timeout(180)' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'SAFE_TOOL_ENV' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'env=SAFE_TOOL_ENV' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'SORA_ROLLOUT_REGRESSION_CURRENT_EPOCH_SECONDS' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'production rollout clock source shape drifted' "${rollout_regression_harness}" ||
   /usr/bin/grep -Fq 'SORA_ROLLOUT_REGRESSION_CURRENT_EPOCH_SECONDS' "${rollout_validator}" ||
   [ "$(/usr/bin/grep -Fc 'current_epoch="$(/bin/date +%s)"' "${rollout_validator}")" -ne 1 ] ||
   ! /usr/bin/grep -Fq 'rewritten-cohort-candidate' "${rollout_regression_harness}" ||
   ! /usr/bin/grep -Fq 'delayed-authorization' "${rollout_regression_harness}" ||
   [ "$(/usr/bin/grep -Fc '/bin/sh "${rollout_validator}" --lint-templates >/dev/null' "${dependency_verifier}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc '/usr/bin/python3 -I -S "${rollout_regression_harness}" >/dev/null' "${dependency_verifier}")" -lt 2 ] ||
   /usr/bin/grep -Fq "PRODUCTION_ROLLOUT_TARGET_PERCENT" "${ci_pipeline}" ||
   /usr/bin/grep -Fq 'shellScript = "/bin/sh \"${PROJECT_DIR}/SoraPassport/Scripts/verify-production-rollout.sh\"' "${project}" ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/production-rollout-candidate.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/production-rollout-advancement.blocked.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/production-rollout-controller-trust.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/production-rollout-README.md' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/funded-nexus-canary-README.md' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/funded-nexus-canary-trust.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/minamoto-funded-canary.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'Fixtures/Modernization/taira-funded-canary.json' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-funded-nexus-canary.sh' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-funded-nexus-canary-json.py' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-production-rollout.sh' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/verify-production-rollout-json.py' "${project}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'SoraPassport/Scripts/test-production-rollout-contract.py' "${project}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "Current hard blocker" "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq "A missing target is an error" "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq "append-only" "${rollout_documentation}" ||
   ! /usr/bin/grep -Fq "Do not infer missing counters" "${rollout_documentation}"; then
    echo "error: production staged-rollout advancement gate is missing or fail-open"
    exit 1
fi

# Production evidence remains outside ordinary build qualification. Release
# builds execute hermetic qualified success/mutation coverage while the real
# trust root and evidence remain blocked. A reviewed post-export controller must
# supply the final IPA, independently pinned trust root, and detached signed
# evidence before any cohort may be promoted.

if ! /usr/bin/grep -Fq 'static let databaseName = "UserDataModel.sqlite"' "${user_data_storage_facade}" ||
   ! /usr/bin/grep -Fq 'for: .documentDirectory' "${user_data_storage_facade}" ||
   ! /usr/bin/grep -Fq 'appendingPathComponent("CoreData")' "${user_data_storage_facade}" ||
   ! /usr/bin/grep -Fq 'static let incompatibleModelStrategy: IncompatibleModelHandlingStrategy = .ignore' "${user_data_storage_facade}" ||
   ! /usr/bin/grep -Fq 'incompatibleModelStrategy: UserStorageParams.incompatibleModelStrategy' "${user_data_storage_facade}" ||
   /usr/bin/grep -Fq 'incompatibleModelStrategy: .removeStore' "${user_data_storage_facade}" ||
   ! /usr/bin/grep -Fq 'testProductionWalletStorageIdentityRemainsBackwardCompatible' "${modernization_tests}"; then
    echo "error: production wallet Core Data location or non-destructive strategy changed"
    exit 1
fi

if ! /usr/bin/grep -Fq 'kSecClass as String: kSecClassKey,' "${keystore_implementation}" ||
   ! /usr/bin/grep -Fq 'kSecAttrApplicationTag as String: applicationTag,' "${keystore_implementation}" ||
   ! /usr/bin/grep -Fq 'kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,' "${keystore_implementation}" ||
   [ "$(/usr/bin/grep -Fc 'kSecAttrAccessible as String:' "${keystore_implementation}")" -ne 1 ] ||
   [ "$(/usr/bin/grep -Fc 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly' "${keystore_implementation}")" -ne 1 ] ||
   /usr/bin/grep -Fq 'kSecAttrAccessGroup' "${keystore_implementation}" ||
   /usr/bin/grep -Fq 'kSecAttrService' "${keystore_implementation}" ||
   ! /usr/bin/grep -Fq 'case pincode = "pincode"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'case legacyEntropy = "seedEntropy"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'case legacyUsername = "userName"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'address + "-" + "secretKey"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'address + "-" + "entropy"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'address + "-" + "deriv"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'address + "-" + "seed"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'identifier == "privateKey"' "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq 'testProductionKeychainAccessibilityRemainsWhenUnlockedThisDeviceOnly' "${modernization_tests}"; then
    echo "error: production Keychain class, accessibility, access group, or legacy tags changed"
    exit 1
fi

if ! /usr/bin/grep -Fq "static let current: UserStorageVersion = .version2" "${user_storage_version}" ||
   /usr/bin/grep -Fq "fatalError(" "${user_storage_version}" ||
   ! /usr/bin/grep -Fq "case insufficientStorage" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "bundleBytes.multipliedReportingOverflow(by: 4)" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "settingsSelectedAddress" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "backup-manifest.json" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "verifyCopiedLegacyStore(" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "sourceManifest.inventoryEquals(copiedManifest)" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "private static let maximumMigrationAttempts = 16" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "private static let maximumJournalBytes = 64 * 1_024" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "fileSize <= maximumBytes" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "Self.wipeSensitive(&secret)" "${storage_migrator}" ||
   /usr/bin/grep -Fq "destroyPersistentStore" "${persistent_store_extensions}" ||
   ! /usr/bin/grep -Fq "testUnboundedMigrationSafetyNamespaceFailsClosed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testCurrentSchemaRejectsUnreadableCopiedStoreBeforeActivation" "${modernization_tests}"; then
    echo "error: migration destination or copy-on-write backup safety is incomplete"
    exit 1
fi

if ! /usr/bin/grep -Fq "var privacySafeOutcomeCode: String" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "privacySafeRecoveryDescription" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "journal.failureReason = outcome" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq '"Wallet migration outcome: rollback_failed"' "${storage_migrator}" ||
   ! /usr/bin/grep -Fq '"unexpected_failure"' "${storage_migrator}" ||
   /usr/bin/grep -Fq "journal.failureReason = error.localizedDescription" "${storage_migrator}" ||
   /usr/bin/grep -Fq "Logger.shared.error(error.localizedDescription)" "${storage_migrator}" ||
   /usr/bin/grep -Fq "restorationError.localizedDescription" "${storage_migrator}" ||
   /usr/bin/grep -Fq "logger.error(error.localizedDescription)" "${splash_interactor}" ||
   /usr/bin/grep -Fq 'logger.error("Selected account setup failed: \(error)")' "${splash_interactor}" ||
   /usr/bin/grep -Fq "walletMigrationRecoveryReason = error.localizedDescription" "${storage_migrator}" ||
   /usr/bin/grep -Fq "walletMigrationRecoveryReason = error.localizedDescription" "${splash_interactor}" ||
   /usr/bin/grep -Fq "error.localizedDescription" "${selected_wallet_settings}" ||
   /usr/bin/grep -Fq "error.localizedDescription" "${root_interactor}" ||
   /usr/bin/grep -Fq "account.address), \(error.localizedDescription)" "${raw_seed_export}" ||
   /usr/bin/grep -Fq "error.localizedDescription" "${json_wallet_export}" ||
   /usr/bin/grep -Fq 'Imported keystore for address:' "${keystore_import_service}" ||
   /usr/bin/grep -Fq 'parsing keystore from url: \(error)' "${keystore_import_service}" ||
   /usr/bin/grep -Fq 'Loading wallet account: \(selectedAccount.address)' "${wallet_context_factory}" ||
   /usr/bin/grep -Fq 'Did receive extrinsic hash:' "${legacy_migration_service}" ||
   /usr/bin/grep -Fq 'extrinsic \(data.params.result)' "${legacy_migration_service}" ||
   /usr/bin/grep -Fq 'print("balancedata = \(data)")' "${transferable_item_service}" ||
   /usr/bin/grep -Fq 'No tx type for: \(data)' "${sora_history_wallet_mapper}" ||
   /usr/bin/grep -Fq 'No tx type for: \(data)' "${subquery_history_wallet_mapper}" ||
   /usr/bin/grep -Fq 'logger.error(error.localizedDescription)' "${snapshot_hot_boot_builder}" ||
   ! /usr/bin/grep -Fq 'Runtime hot-boot snapshot failed' "${snapshot_hot_boot_builder}" ||
   ! /usr/bin/grep -Fq "privacySafeRecoveryDescription" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "privacySafeRecoveryDescription" "${account_options}" ||
   ! /usr/bin/grep -Fq "testMigrationOutcomeCodesNeverContainWalletIdentifiers" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "NSLocalizedDescriptionKey: walletIdentifier" "${modernization_tests}"; then
    echo "error: wallet migration diagnostics are not privacy-safe outcome classes"
    exit 1
fi

if ! /usr/bin/grep -Fq 'message: "Migration eligibility response received"' "${json_rpc_integration_tests}" ||
   /usr/bin/grep -Eq '(logger\.(debug|info|warning|error)|Logger\.shared\.(debug|info|warning|error)|print\(|NSLog\().*mnemonic|mnemonic.*(logger\.(debug|info|warning|error)|Logger\.shared\.(debug|info|warning|error)|print\(|NSLog\()' "${json_rpc_integration_tests}"; then
    echo "error: an iOS integration test can emit a wallet mnemonic"
    exit 1
fi

if ! /usr/bin/grep -Fq 'Logger.shared.debug("Pool reserves account resolved")' "${json_rpc_pool_integration_tests}" ||
   /usr/bin/grep -Eq '(logger\.(debug|info|warning|error)|Logger\.shared\.(debug|info|warning|error)|print\(|NSLog\().*(account.*address|address.*account|reservesAccountId)|(account.*address|address.*account|reservesAccountId).*(logger\.(debug|info|warning|error)|Logger\.shared\.(debug|info|warning|error)|print\(|NSLog\()' "${json_rpc_pool_integration_tests}"; then
    echo "error: an iOS integration test can emit an account address"
    exit 1
fi

if ! /usr/bin/grep -Fq 'Logger.shared.debug("Asset info keys loaded")' "${assets_info_integration_tests}" ||
   ! /usr/bin/grep -Fq 'Logger.shared.debug("Asset info catalog loaded")' "${assets_info_integration_tests}" ||
   ! /usr/bin/grep -Fq 'Logger.shared.debug("Asset info response received")' "${assets_info_integration_tests}" ||
   ! /usr/bin/grep -Fq 'Logger.shared.debug("Pool account balance response received")' "${json_rpc_pool_integration_tests}" ||
   ! /usr/bin/grep -Fq 'Logger.shared.debug("Account pools response received")' "${json_rpc_pool_integration_tests}" ||
   ! /usr/bin/grep -Fq 'Logger.shared.debug("Pool properties response received")' "${json_rpc_pool_integration_tests}" ||
   ! /usr/bin/grep -Fq 'Logger.shared.debug("Pool reserves response received")' "${json_rpc_pool_integration_tests}" ||
   /usr/bin/grep -Eq '^[[:space:]]*((logger|Logger\.shared)\.[[:alpha:]_][[:alnum:]_]*|(Swift\.)?(print|debugPrint|dump)|NSLog)[[:space:]]*\([^[:cntrl:]]*\\\(' \
       "${json_rpc_integration_tests}" \
       "${json_rpc_pool_integration_tests}" \
       "${assets_info_integration_tests}" ||
   /usr/bin/grep -Eq '^[[:space:]]*XCTFail[[:space:]]*\([^[:cntrl:]]*\\\(' \
       "${json_rpc_integration_tests}" \
       "${json_rpc_pool_integration_tests}" \
       "${assets_info_integration_tests}"; then
    echo "error: an iOS integration test can emit a dynamic wallet or runtime payload"
    exit 1
fi

if ! /usr/bin/grep -Fq "enum DurableFileWriter" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "enum FileProtectionMetadata" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let reviewedRawValues" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq '#if targetEnvironment(simulator)' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq 'com.soramitsu.sora.simulator-file-protection' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq 'Darwin.setxattr(' "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc 'Darwin.getxattr(' "${wallet_network_model}")" -ne 2 ] ||
   ! /usr/bin/grep -Fq 'static func setProtectionClass(' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC" "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc 'Darwin.renameatx_np(' "${wallet_network_model}")" -lt 5 ] ||
   [ "$(/usr/bin/grep -Fc 'UInt32(RENAME_SWAP)' "${wallet_network_model}")" -lt 3 ] ||
   [ "$(/usr/bin/grep -Fc 'UInt32(RENAME_EXCL)' "${wallet_network_model}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "while Darwin.fsync(descriptor) != 0" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "synchronizeAncestorDirectoryEntries(" "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc 'FileProtectionMetadata.setProtectionClass(' "${wallet_network_model}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'FileProtectionMetadata.protectionClass(' "${wallet_network_model}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq '".durable-rollback-\(UUID().uuidString).anchor"' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq '".durable-rollback-\(UUID().uuidString).safety-anchor"' "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc 'Darwin.linkat(' "${wallet_network_model}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'protectOrRemoveHiddenFailedPublication(' "${wallet_network_model}")" -lt 5 ] ||
   [ "$(/usr/bin/grep -Fc 'removeHiddenFailedPublicationIfExact(' "${wallet_network_model}")" -ne 2 ] ||
   ! /usr/bin/grep -Fq "Once linkat succeeds, no defer path" "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc 'restoreOriginalAfterFailedPublication(' "${wallet_network_model}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'discardRollbackAnchorAfterCommit(' "${wallet_network_model}")" -ne 5 ] ||
   [ "$(/usr/bin/grep -Fc 'reverseRejectedAtomicSwap(' "${wallet_network_model}")" -ne 3 ] ||
   ! /usr/bin/grep -Fq "Anchor cleanup" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "must not turn a committed write into an ambiguous" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "preserves at least one exact old-inode" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "intended protection class durably re-established" "${wallet_network_model}" ||
   ! /usr/bin/awk '
       /^[[:space:]]+static func write\(/ && !in_write { in_write = 1 }
       in_write && /Darwin\.linkat\(/ && stage == 0 { stage = 1 }
       in_write && /^        do \{$/ && stage == 1 { stage = 2 }
       in_write && /^            if let originalState \{$/ && stage == 2 { stage = 3 }
       in_write && /let preparedIdentity = temporaryIdentity/ && stage == 3 { stage = 4 }
       in_write && /at: temporaryURL,/ && stage == 4 { stage = 5 }
       in_write && /== retainedProtection/ && stage == 5 { stage = 6 }
       in_write && /UInt32\(RENAME_SWAP\)/ && stage == 6 { stage = 7 }
       in_write && /let displacedIdentity = try entryIdentity\(/ && stage == 7 { stage = 8 }
       in_write && /displacedIdentity == originalState\.identity/ && stage == 8 { stage = 9 }
       in_write && /try afterAtomicPublication\?\(targetURL\)/ && stage == 9 { stage = 10 }
       in_write && /at: targetURL,/ && stage == 10 { stage = 11 }
       in_write && /discardRollbackAnchorAfterCommit\(/ && stage == 11 { stage = 12 }
       in_write && /^        \} catch \{$/ && stage == 12 { stage = 13 }
       in_write && /restoreOriginalAfterFailedPublication\(/ && stage == 13 { stage = 14 }
       in_write && /^    }$/ { in_write = 0 }
       END { exit(stage == 14 ? 0 : 1) }
   ' "${wallet_network_model}" ||
   ! /usr/bin/awk '
       /^[[:space:]]+static func write\(/ && !in_write { in_write = 1 }
       in_write && /initial inventory observed no file/ && stage == 0 { stage = 1 }
       in_write && /let preparedIdentity = temporaryIdentity/ && stage == 1 { stage = 2 }
       in_write && /at: temporaryURL,/ && stage == 2 { stage = 3 }
       in_write && /== retainedProtection/ && stage == 3 { stage = 4 }
       in_write && /UInt32\(RENAME_EXCL\)/ && stage == 4 { stage = 5 }
       in_write && /try afterAtomicPublication\?\(targetURL\)/ && stage == 5 { stage = 6 }
       in_write && /^    }$/ { in_write = 0 }
       END { exit(stage == 6 ? 0 : 1) }
   ' "${wallet_network_model}" ||
   ! /usr/bin/awk '
       /private static func restoreOriginalAfterFailedPublication\(/ && !in_restore { in_restore = 1 }
       in_restore && /safety-anchor/ && stage == 0 { stage = 1 }
       in_restore && /Darwin\.linkat\(/ && stage == 1 { stage = 2 }
       in_restore && /synchronizeAncestorDirectoryEntries\(/ && stage == 2 { stage = 3 }
       in_restore && /UInt32\(RENAME_SWAP\)/ && stage == 3 { stage = 4 }
       in_restore && /displacedIdentity == publishedIdentity/ && stage == 4 { stage = 5 }
       in_restore && /at: targetURL,/ && stage == 5 { stage = 6 }
       in_restore && /try protectOrRemoveHiddenFailedPublication\(/ && stage == 6 { stage = 7 }
       in_restore && /discardRollbackAnchorAfterCommit\(/ && stage == 7 { stage = 8 }
       in_restore && /^    }$/ { in_restore = 0 }
       END { exit(stage == 8 ? 0 : 1) }
   ' "${wallet_network_model}" ||
   ! /usr/bin/awk '
       /private static func removeFailedNewPublication\(/ && !in_remove { in_remove = 1 }
       in_remove && /UInt32\(RENAME_EXCL\)/ { excl += 1 }
       in_remove && /Darwin\.unlinkat\(/ { unsafe_unlink = 1 }
       in_remove && /try protectOrRemoveHiddenFailedPublication\(/ { protected = 1 }
       in_remove && /== retainedProtection/ { rechecked = 1 }
       in_remove && /^    }$/ { in_remove = 0 }
       END { exit(excl >= 2 && !unsafe_unlink && protected && rechecked ? 0 : 1) }
   ' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "stagedState.permissions == permissions" "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc 'DurableFileWriter.write(' "${storage_migrator}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'DurableFileWriter.write(' "${wallet_network_model}")" -lt 4 ] ||
   [ "$(/usr/bin/grep -Fc 'synchronizeRegularFileAndContainingDirectory(' "${storage_migrator}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq 'DurableFileWriter.write(' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'protection: .completeUntilFirstUserAuthentication' "${nexus_service}" ||
   ! /usr/bin/grep -Fq "testDurableFileWriterPreservesProtectionAndPermissions" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let protectionBefore = try FileProtectionMetadata.protectionClass(" "${modernization_tests}" ||
   [ "$(/usr/bin/grep -Fc '#if !targetEnvironment(simulator)' "${modernization_tests}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "XCTAssertEqual(protectionAfter, protectionBefore)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "didWeakenExistingPublicationOnDisk" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "didWeakenAbsentPublicationOnDisk" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'hasPrefix(".durable-failed-")' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq '$0.hasPrefix(".durable-")' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testDurableFileWriterRejectsSymlinkWithoutTouchingLegacyFile" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusPendingJournalUsesCrashDurableProtectedPublication" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusPendingJournalRejectsSymbolicLink" "${modernization_tests}"; then
    echo "error: wallet migration publication is not crash-durable and metadata-preserving"
    exit 1
fi

if ! /usr/bin/grep -Fq "func allKeyIdentifiers() throws -> [String]" "${keystore_protocol}" ||
   ! /usr/bin/grep -Fq "kSecReturnAttributes" "${keystore_implementation}" ||
   ! /usr/bin/grep -Fq "kSecAttrAccessibleWhenUnlockedThisDeviceOnly" "${keystore_implementation}" ||
   ! /usr/bin/grep -Fq "func allKeys() -> [String]" "${settings_protocol}" ||
   ! /usr/bin/grep -Fq "func hasRetainedWalletMaterial() throws -> Bool" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "identifier == KeystoreTag.legacyUsername.rawValue" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "func hasRetainedWalletSettings() -> Bool" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "SettingsKey.decentralizedId.rawValue" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "SettingsKey.publicKeyId.rawValue" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "SettingsKey.hasMigrated.rawValue" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "SettingsKey.migratedAccountsV1.rawValue" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "SettingsKey.migratedAccountsV1.rawValue" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "SettingsKey.walletNetworkStoreVersion.rawValue" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "settings.hasRetainedWalletSettings()" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "settings.hasRetainedWalletSettings()" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "func hasRetainedWatchOnlyWallet() -> Bool" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "keystore.hasRetainedWalletMaterial()" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "settings.hasRetainedWatchOnlyWallet()" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "let activeSnapshot = try loadWalletNetworkSnapshot()" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "activeSnapshot?.wallets.isEmpty == false" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "private func pathExistsNoFollow(_ url: URL) -> Bool" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "Darwin.lstat(path, &metadata) == 0" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "return errno != ENOENT" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "private func storeBundleIsRegularNoFollow(at mainStoreURL: URL) -> Bool" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "regularFileNoFollow(mainStoreURL, mayBeAbsent: false)" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq 'return ["-wal", "-shm", "-journal"].allSatisfy' "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "if pathExistsNoFollow(migrationSafetyDirectory())" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq 'for suffix in ["-wal", "-shm", "-journal"]' "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "testMissingCoreDataStoreWithOnlyScopedKeychainSecretFailsClosed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "KeystoreTag.legacyUsername.rawValue" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "legacyIdentitySettings" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "retainedSettings.hasRetainedWalletSettings()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "activatedSnapshotSettings.hasRetainedWalletSettings()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "an inconsistent wallet upgrade, never a clean installation" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testMissingCoreDataStoreWithOnlyWatchOnlyMarkerFailsClosed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testMissingCoreDataStoreWithRetainedActivatedSafetyBackupFailsClosed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testMissingCoreDataStoreWithOrphanedSQLiteSidecarFailsClosed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testDanglingCoreDataStoreSymlinkCannotBecomeNewWallet" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testReachableCoreDataStoreSymlinkIsRejectedBeforeCoreDataAccess" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testSQLiteSidecarSymlinkIsRejectedBeforeCoreDataAccess" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testSymlinkedLegacyRollbackSourceIsNeverFollowed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testMissingCoreDataAfterExplicitFinalWalletRemovalRemainsClean" "${modernization_tests}"; then
    echo "error: wallet-store admission does not preserve every retained artifact without following links"
    exit 1
fi

if ! /usr/bin/grep -Fq "previousPointerData" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "Self.sha256(snapshotData) == pointer.sha256" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "try validate(snapshot)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let retainedSnapshotCount = 8" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "try pruneSnapshotsUnlocked(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreBoundsSelectionAndNameSnapshots" "${modernization_tests}"; then
    echo "error: wallet-network activation lacks rollback or active-snapshot verification"
    exit 1
fi

if ! /usr/bin/grep -Fq "private static let lock = NSLock()" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "let hasValidSelection = snapshot.wallets.isEmpty" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "throw WalletNetworkMigrationError.missingSnapshot" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq ".explicitRemovalTargetMissing(walletId)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "Set(expectedWalletIds) == Set(currentWalletIds)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "try stageAndActivateUnlocked(next)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "try snapshotsMatch(activated, next)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "try snapshotsMatch(stagedSnapshot, snapshot)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "recordRemovalOperation.addDependency(inventoryOperation)" "${account_options}" ||
   ! /usr/bin/grep -Fq "recordRemovalOperation.addDependency(pendingTransactionPreflight)" "${account_options}" ||
   ! /usr/bin/grep -Fq "WalletPendingDeletionPreflightOperation(" "${account_options}" ||
   ! /usr/bin/grep -Fq "NexusPendingTransactionStore().all()" "${account_options}" ||
   ! /usr/bin/grep -Fq "PolkamarktPendingStore().all()" "${account_options}" ||
   ! /usr/bin/grep -Fq "Sora2PendingSubmissionStore().all()" "${account_options}" ||
   ! /usr/bin/grep -Fq "enum PendingTransactionJournalNamespace" "${nexus_wallet_service}" ||
   ! /usr/bin/grep -Fq '"sora2-signed-v1.json"' "${nexus_wallet_service}" ||
   ! /usr/bin/grep -Fq "allowedJournalNames.contains(entry.lastPathComponent)" "${nexus_wallet_service}" ||
   ! /usr/bin/grep -Fq "PendingTransactionJournalNamespace.validate(" "${nexus_wallet_service}" ||
   ! /usr/bin/grep -Fq "PendingTransactionJournalNamespace.validate(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "transaction.historyReconciledAt == nil" "${account_options}" ||
   ! /usr/bin/grep -Fq "catch let error as WalletPendingDeletionPreflightError" "${account_options}" ||
   ! /usr/bin/grep -Fq "accountDeletionBlocked(" "${account_options}" ||
   ! /usr/bin/grep -Fq "forgetOperation.addDependency(recordRemovalOperation)" "${account_options}" ||
   ! /usr/bin/grep -Fq "countOperation.addDependency(forgetOperation)" "${account_options}" ||
   ! /usr/bin/grep -Fq "guard try WalletNetworkStore().load() == networkSnapshot" "${account_options}" ||
   ! /usr/bin/grep -Fq "verifyAndCommitExplicitRemovalMetadata(" "${account_options}" ||
   ! /usr/bin/grep -Fq "WalletExplicitRemovalIdentityPolicy.verify(" "${account_options}" ||
   ! /usr/bin/grep -Fq "LegacySoraIdentityValidator.validate(" "${account_options}" ||
   ! /usr/bin/grep -Fq "activeSnapshot: snapshot," "${account_options}" ||
   ! /usr/bin/grep -Fq "activeSnapshot: current," "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "recoveryGate: WalletRecoveryCapabilityGate" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "recoveryGate: recoveryGate" "${keystore_extensions}" ||
   ! /usr/bin/grep -Fq "identityPreflightOperation.addDependency(" "${account_options}" ||
   ! /usr/bin/grep -Fq "removesRetainedLegacyEntropy" "${account_options}" ||
   ! /usr/bin/grep -Fq "MigrationAccountCompletionStore.remove(" "${account_options}" ||
   ! /usr/bin/grep -Fq "settings.removeValue(for: watchOnlyKey)" "${account_options}" ||
   ! /usr/bin/grep -Fq "lifecycleLease: lifecycleLease" "${account_options}" ||
   ! /usr/bin/grep -Fq "try keystore.deleteWalletMaterial(for: address)" "${account_options}" ||
   ! /usr/bin/grep -Fq "testWalletDeletionPreflightBlocksEveryUnresolvedMutation" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPendingTransactionStoresRejectInterruptedDurablePublicationEvidence" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testAllPendingTransactionJournalsShareTheProtectedNamespace" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let unresolvedNexusStates: [NexusPendingState]" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".committedPendingReconciliation" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let unresolvedPolkamarktStates: [PolkamarktPendingState]" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreExplicitRemovalFailsClosedWithoutActiveTarget" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreExplicitRemovalSelectsRetainedWallet" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "WalletExplicitRemovalIdentityPolicy.verify(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "MigrationAccountCompletionStore.remove(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "corruptedKeychain" "${modernization_tests}"; then
    echo "error: explicit wallet removal is not copy-on-write, ordered, verified, and fail-closed"
    exit 1
fi

metadata_commit_line="$(
    /usr/bin/grep -Fn "verifyAndCommitExplicitRemovalMetadata(" "${account_options}" |
        /usr/bin/head -n 1 |
        /usr/bin/cut -d: -f1
)"
keychain_cleanup_line="$(
    /usr/bin/grep -Fn "cleanKeystore(leavingPin:" "${account_options}" |
        /usr/bin/head -n 1 |
        /usr/bin/cut -d: -f1
)"
if [ -z "${metadata_commit_line}" ] ||
   [ -z "${keychain_cleanup_line}" ] ||
   [ "${keychain_cleanup_line}" -le "${metadata_commit_line}" ]; then
    echo "error: Keychain cleanup must follow verified explicit-removal metadata commits"
    exit 1
fi

if ! /usr/bin/grep -Fq "rawSeed == mnemonicSeed" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "seed.resetBytes(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "defer { wipeSensitive(&sourceSeed) }" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "defer { wipeSensitive(&expectedSecret) }" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "defer { wipeSensitive(&signingSecret) }" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "Self.wipeSensitive(&entropy)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "Self.wipeSensitive(&rawSeed)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "Self.wipeSensitive(&legacySecret)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "phrase.removeAll(keepingCapacity: false)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "child.privateKey.resetBytes(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "child.chainCode.resetBytes(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "testLegacyMnemonicMigrationRejectsMismatchedRetainedSeed" "${modernization_tests}"; then
    echo "error: retained mnemonic entropy and seed are not cross-verified and zeroized"
    exit 1
fi

if ! /usr/bin/grep -Fq "walletNetworkSynchronizer" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "walletMigrationRecoveryRequired = true" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "commitInternalValue(" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "func performInsertAndSelect(" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "WalletAccountCommitJournalStore" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "private static let maximumJournalFiles = 16" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let maximumJournalBytes = 64 * 1_024" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let maximumPointerBytes = 4 * 1_024" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let maximumSnapshotBytes = 4 * 1_024 * 1_024" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func testWalletNetworkStoreRejectsOversizedActivePointerBeforeDecoding" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "func testWalletNetworkStoreRejectsSnapshotWithoutActivePointer" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "func testWalletAccountCommitJournalRejectsOversizedFileBeforeDecoding" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalRejectsUnboundedFileSet" "${modernization_tests}"; then
    echo "error: selected-account lifecycle is not synchronized with the wallet-network store"
    exit 1
fi

if ! /usr/bin/grep -Fq "final class WalletLifecycleCoordinator" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "final class WalletLifecycleLease" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func tryAcquire() -> WalletLifecycleLease?" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func acquireAsync() async -> WalletLifecycleLease" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func makeAcquireOperation(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func enqueueOwnedAcquireOperation(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func withBorrow" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "withExclusiveAccess(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "lifecycleLease: WalletLifecycleLease? = nil" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${account_options}" ||
   ! /usr/bin/grep -Fq "suppliedLifecycleLease" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "lifecycleLease: lifecycleLease" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "func performUpdateName(" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "func performUpdateAssetSettings(" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "isSelected: existing.isSelected" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "accountSettings?.performUpdateAssetSettings(" "${asset_manager}" ||
   /usr/bin/grep -Fq "accountRepository.saveOperation" "${asset_manager}" ||
   ! /usr/bin/grep -Fq "SelectedWalletSettings.shared.performUpdateName(" "${account_options}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${account_confirm}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${account_import_commit}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${add_account_confirm}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${add_account_import}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${account_create}" ||
   ! /usr/bin/grep -Fq "makeAcquireOperation()" "${create_account_service}" ||
   ! /usr/bin/grep -Fq "performInsertAndSelect(" "${account_confirm}" ||
   ! /usr/bin/grep -Fq "performInsertAndSelect(" "${account_import_commit}" ||
   ! /usr/bin/grep -Fq "performInsertAndSelect(" "${add_account_confirm}" ||
   ! /usr/bin/grep -Fq "performInsertAndSelect(" "${add_account_import}" ||
   ! /usr/bin/grep -Fq "performInsertAndSelect(" "${account_create}" ||
   ! /usr/bin/grep -Fq "performInsertAndSelect(" "${create_account_service}" ||
   ! /usr/bin/grep -Fq "settingsManager.performSave(" "${change_account}" ||
   ! /usr/bin/grep -Fq "testWalletLifecycleCoordinatorRequiresOneActiveLease" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletLifecycleReleaseWaitsForBorrowedCriticalSection" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testCancelledLifecycleAcquireOperationDoesNotLeakLease" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testLifecycleAcquisitionQueueDoesNotStarveSingleWorker" "${modernization_tests}"; then
    echo "error: wallet import, switching, metadata updates, migration, removal, and Keychain cleanup do not share one lifecycle coordinator"
    exit 1
fi

if [ ! -f "${recovery_gate_tests}" ] ||
   ! /usr/bin/grep -Fq "final class WalletRecoveryCapabilityGate" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "enum WalletRecoveryMigrationJournalProbe" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "enum WalletMigrationSafetyNamespaceAdmission" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "expectedActivatedAttemptRootNames" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "return Darwin.lstat(path, &metadata)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq ".isExactActivatedAttemptRoot(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "excludedRecoveryEvidence.isEmpty" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq '$0.hasPrefix(".durable-")' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq ".isExactActivatedAttemptRoot(" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq ".isRegularFileNoFollow(at: entry)" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq 'Set(entries.map(\.lastPathComponent)) == expectedNames' "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "private static let maximumRetainedDatabaseFileBytes" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let maximumRetainedNamespaceBytes" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let maximumJournalNamespaceBytes" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "private static let maximumNamespaceBytes" "${wallet_network_model}" ||
   /usr/bin/grep -Fq "maximumBytes: nil" "${wallet_network_model}" ||
   /usr/bin/grep -Fq "skipsHiddenFiles" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "options: []" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func tryAcquireForMutableWalletAccess()" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "func acquireForMutableWalletAccessAsync()" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "latchRecoveryAfterAmbiguousWalletCommit()" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "verifyMonotonicActivation(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "requireAuthorizedLifecycleContinuation()" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "tryAcquireForMutableWalletAccess()" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "tryAcquireForMutableWalletAccess()" "${iroha_signing_decorator}" ||
   ! /usr/bin/grep -Fq "requireAuthorizedLifecycleContinuation()" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "tryAcquireForMutableWalletAccess()" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "requireAuthorizedLifecycleContinuation()" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "tryAcquireForMutableWalletAccess()" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "async let submittedReceipt = submissionClient.submit(" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "acquireForMutableWalletAccessAsync()" "${nexus_service}" ||
   [ "$(/usr/bin/grep -Fc 'acquireForMutableWalletAccessAsync()' "${polkamarkt_runtime}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "private func submitClaimAdmitted(" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'PolkamarktClaimValidator.requireFreshAuthorization(' "${polkamarkt_runtime}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'requireAuthorizedLifecycleContinuation()' "${selected_wallet_settings}")" -lt 7 ] ||
   [ "$(/usr/bin/grep -Fc 'requireAuthorizedLifecycleContinuation()' "${account_options}")" -lt 9 ] ||
   ! /usr/bin/grep -Fq "WalletRecoveryCapabilityGateTests.swift in Sources" "${project}" ||
   ! /usr/bin/grep -Fq "testUnresolvedCommitBlocksNewAccessButNotAuthorizedContinuation" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testConcurrentFreshAccessReturnsBusyWithoutProbingInflightJournal" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testInterruptedMigrationJournalProbeFailsClosed" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testVerifiedActivatedMigrationAttemptAllowsMutableAccessProbe" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq ".durable-capability-root-residue.anchor" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq ".durable-capability-legacy-residue.withdrawn" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testTamperedActivatedMigrationArtifactFailsClosed" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testUnexpectedHiddenMigrationNamespaceEntryFailsClosed" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreRejectsAndWillNotActivateOverNamespaceEvidence" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreRejectsUnexpectedEntryBesideActiveSnapshot" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreRejectsMalformedRetainedSnapshotBesideActive" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreRejectsUnprunedCanonicalSnapshotSet" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletNetworkStoreGenericActivationCannotRemoveOrRewriteIdentity" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalRejectsUnexpectedNamespaceEntries" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalWillNotAdvanceBesideUnexpectedEvidence" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalRejectsStaleAdvanceHandle" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalPrunesBeforeTerminalActivation" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalNormalizesMalformedCanonicalEntry" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "requireAuthorizedLifecycleContinuation()" "${pin_setup}" ||
   ! /usr/bin/grep -Fq "secretManager.saveSecret(" "${pin_setup}" ||
   ! /usr/bin/grep -Fq "requireAuthorizedLifecycleContinuation()" "${local_auth}" ||
   ! /usr/bin/grep -Fq "secretManager.saveSecret(" "${local_auth}" ||
   ! /usr/bin/grep -Fq "options: []" "${storage_migrator}" ||
   /usr/bin/grep -Fq "skipsHiddenFiles" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq ".durable-migrator-root-residue.safety-anchor" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".durable-migrator-legacy-residue.withdrawn" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testUnexpectedMigrationSafetyEntriesFailClosed" "${modernization_tests}"; then
    echo "error: app-wide wallet recovery capability gate is missing, unbounded, or bypassable"
    exit 1
fi

if [ ! -f "${recovery_exporter}" ] ||
   [ ! -f "${recovery_export_tests}" ] ||
   ! /usr/bin/grep -Fq "newestVerifiedLegacyStoreBackup(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "Never conceal a tampered newest verified backup" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "case verifiedMigrationLegacyStore" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "case liveStoreFallback" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "static let recoverableSettingsKeys" "${recovery_exporter}" ||
   /usr/bin/grep -Fq "SettingsKey.streamToken" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq '.sorted { $0.key < $1.key }' "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "format: .xml" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "afterInitialSourceVerification" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "revalidateSources(" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "verifyPrivateStagingRoot(" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "\"SORA-Wallet-Recovery\"" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq ".wallet-recovery-\\(exportID.uuidString).staging" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq ".wallet-recovery-\\(exportID.uuidString).archive-staging" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "NSFileCoordinator(filePresenter: nil)" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "options: .forUploading" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "private static let maximumArchiveBytes" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "typealias ProtectionClassProvider" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "self.protectionClassProvider = protectionClassProvider ??" "${recovery_exporter}" ||
   [ "$(/usr/bin/grep -Fc 'FileProtectionMetadata.protectionClass(' "${recovery_exporter}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "let reviewedArchiveProtection = try requireProtectionClass(" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "expected: reviewedArchiveProtection" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "if archiveWasPublished" "${recovery_exporter}" ||
   /usr/bin/grep -Fq "removeItem(finalURL)" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "case publicationWithdrawalFailed" "${recovery_exporter}" ||
   [ "$(/usr/bin/grep -Fc 'withdrawPublishedArchive(' "${recovery_exporter}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'removeWithdrawnArchiveIfExact(' "${recovery_exporter}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'restoreRejectedArchiveWithdrawal(' "${recovery_exporter}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'UInt32(RENAME_EXCL)' "${recovery_exporter}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'synchronizeRegularFileAndContainingDirectory(' "${recovery_exporter}")" -lt 2 ] ||
   ! /usr/bin/awk '
       /private func withdrawPublishedArchive\(/ && !in_withdraw { in_withdraw = 1 }
       in_withdraw && /UInt32\(RENAME_EXCL\)/ && stage == 0 { stage = 1 }
       in_withdraw && /withdrawnIdentity == expectedIdentity/ && stage == 1 { stage = 2 }
       in_withdraw && /FileProtectionMetadata\.setProtectionClass\(/ && stage == 2 { stage = 3 }
       in_withdraw && /^[[:space:]]+\.complete,/ && stage == 3 { stage = 4 }
       in_withdraw && /synchronizeRegularFileAndContainingDirectory\(/ && stage == 4 { stage = 5 }
       in_withdraw && /try removeWithdrawnArchiveIfExact\(/ && stage == 5 { stage = 6 }
       in_withdraw && /^    }$/ { in_withdraw = 0 }
       END { exit(stage == 6 ? 0 : 1) }
   ' "${recovery_exporter}" ||
   ! /usr/bin/awk '
       /private func removeWithdrawnArchiveIfExact\(/ && !in_remove { in_remove = 1 }
       in_remove && /regularArchiveIdentity\(at: hiddenURL\) == expectedIdentity/ && stage == 0 { stage = 1 }
       in_remove && /try removeItem\(hiddenURL\)/ && stage == 1 { stage = 2 }
       in_remove && /archiveEntryIdentity\(at: hiddenURL\) == nil/ && stage == 2 { stage = 3 }
       in_remove && /try synchronizeArchiveDirectory\(/ && stage == 3 { stage = 4 }
       in_remove && /archiveEntryIdentity\(at: hiddenURL\) == nil/ && stage == 4 { stage = 5 }
       in_remove && /^    }$/ { in_remove = 0 }
       END { exit(stage == 5 ? 0 : 1) }
   ' "${recovery_exporter}" ||
   ! /usr/bin/awk '
       /func createRecoveryPackage\(\) throws/ && !in_export { in_export = 1 }
       in_export && /try protect\(archiveStagingURL\)/ && stage == 0 { stage = 1 }
       in_export && /let reviewedArchiveProtection = try requireProtectionClass\(/ && stage == 1 { stage = 2 }
       in_export && /try removeItem\(stagingURL\)/ && stage == 2 { stage = 3 }
       in_export && /reviewedArchiveIdentity/ && stage == 3 { stage = 4 }
       in_export && /expected: reviewedArchiveProtection/ && stage == 4 { stage = 5 }
       in_export && /try verifyArchive\(at: archiveStagingURL\)/ && stage == 5 { stage = 6 }
       in_export && /reviewedArchiveIdentity/ && stage == 6 { stage = 7 }
       in_export && /expected: reviewedArchiveProtection/ && stage == 7 { stage = 8 }
       in_export && /UInt32\(RENAME_EXCL\)/ && stage == 8 { stage = 9 }
       in_export && /expected: reviewedArchiveProtection/ && stage == 9 { stage = 10 }
       in_export && /try verifyArchive\(at: finalURL\)/ && stage == 10 { stage = 11 }
       in_export && /synchronizeRegularFileAndContainingDirectory\(/ && stage == 11 { stage = 12 }
       in_export && /expected: reviewedArchiveProtection/ && stage == 12 { stage = 13 }
       in_export && /try verifyArchive\(at: finalURL\)/ && stage == 13 { stage = 14 }
       in_export && /reviewedArchiveIdentity/ && stage == 14 { stage = 15 }
       in_export && /expected: reviewedArchiveProtection/ && stage == 15 { stage = 16 }
       in_export && /try withdrawPublishedArchive\(/ && stage == 16 { stage = 17 }
       in_export && /try\? removeItem\(archiveStagingURL\)/ && stage == 17 { stage = 18 }
       in_export && /^    }$/ { in_export = 0 }
       END { exit(stage == 18 ? 0 : 1) }
   ' "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq ".sorarecovery.zip" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq ".completeFileProtection" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "Keychain secrets remain only on this device" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "try removeItem(stagingURL)" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "try? removeItem(archiveStagingURL)" "${recovery_exporter}" ||
   ! /usr/bin/grep -Fq "Create protected recovery export" "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "WalletRecoveryExporter()" "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "Keychain secrets stay only on this device" "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "WalletRecoveryExporter.swift in Sources" "${project}" ||
   ! /usr/bin/grep -Fq "WalletRecoveryExporterTests.swift in Sources" "${project}" ||
   ! /usr/bin/grep -Fq "testNewestVerifiedBackupIsExportedAndSettingsAreAllowlisted" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testLiveStoreFallbackCapturesStableSQLiteSidecarsAndSettings" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "SettingsKey.migratedAccountsV1.rawValue" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testUnverifiedStagingStoreIsIgnoredForLiveFallback" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testVerifiedFailedMigrationBackupIsPreferredOverLiveFallback" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testTamperedActivatedBackupFailsClosedWithoutLiveFallback" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testUnexpectedVerifiedLegacyStoreEntryFailsClosed" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testSymlinkedLiveStoreFailsClosed" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testOversizedLiveStoreFailsBeforeCopy" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testLiveSourceChurnFailsClosedAndLeavesNoPublishedPackage" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testSuccessfulExportDoesNotMutateLiveSources" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testArchiveCoordinationFailureLeavesNoPublishedArtifact" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "didRejectMissingPublishedProtection" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "didRejectMismatchedPublishedProtection" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "didExerciseRealOnDiskProtectionMismatch" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "FileProtectionMetadata.setProtectionClass(" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "publicationWithdrawalFailed" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "at: retainedArchiveURL," "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "let publishedProtection = try FileProtectionMetadata.protectionClass(" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "FileProtectionType.complete" "${recovery_export_tests}" ||
   ! /usr/bin/grep -Fq "testCleanupFailureLeavesOnlyHiddenUnpublishedStaging" "${recovery_export_tests}"; then
    echo "error: protected wallet recovery export is missing, unsafe, or not release-wired"
    exit 1
fi

if ! /usr/bin/grep -Fq "protocol LifecycleSigningWrapperProtocol" "${signing_protocol}" ||
   ! /usr/bin/grep -Fq "lifecycleLease: WalletLifecycleLease" "${signing_protocol}" ||
   ! /usr/bin/grep -Fq "validateSelectedSora2Identity()" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "Sora2SignatureVerifier.verify(" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "WalletNetworkStore().load()" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "defer { wipeSensitive(&directSecret) }" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "defer { wipeSensitive(&sourceSeed) }" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "phrase.removeAll(keepingCapacity: false)" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "secret = nil" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "entropy = nil" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "rawSeed = nil" "${signing_wrapper}" ||
   ! /usr/bin/grep -Fq "final class PreparedExtrinsicSubmission" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "final class CancellableCallRelay" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "final class MutableSignedTransportPayload" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "final class PreparedExtrinsicRPCOperation" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "enum PreparedExtrinsicTransportError" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "struct Sora2SubmissionUnknownContext: Error" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "case submissionUnknown(Error)" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "var submissionUnknownLocalHash: String?" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "enum Sora2LegacySubmissionProjection" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "journal write failure must retain that success" "${extrinsic_service}" ||
	   [ "$(/usr/bin/grep -Fc '.submissionUnknown(' "${extrinsic_service}")" -lt 6 ] ||
	   /usr/bin/grep -Fq "watch ? submitOperation.parameters?.first" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "staged?.pending.extrinsicHash" "${extrinsic_service}" ||
	   [ "$(/usr/bin/grep -Fc 'let submitOperation = PreparedExtrinsicRPCOperation(' "${extrinsic_service}")" -lt 1 ] ||
   ! /usr/bin/grep -Fq "try preTransportValidation()" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "transportDidHandoff()" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq ") -> CancellableCall" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "func removeBeforeSubmission(" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "case stagedBeforeTransport" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "case submittedRetained" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "enum Sora2PendingSubmissionPurpose" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "case legacyMigration" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "retainingTransportWitness: retainingTransportWitness" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "state: .submitting" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "func acknowledgeRetainedSubmission(" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "func acknowledgeAuthoritativelyFinalizedSubmissions(" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "case .duplicatePreparedSubmission = serviceError" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "case let .failedBeforeTransport(error)" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "final class Sora2PendingSubmissionStore" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "let stageOperation = ClosureOperation<StagedExtrinsicInfo>" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "try self.validateSora2SigningRuntime(factory)" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "case unsupportedRuntimeMetadata" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "PolkamarktRuntimeContract.signingMetadataSHA256(" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "static func signingMetadataSHA256(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static func matchesReviewedSigningIdentity(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static func matchesReviewedGenesisHash(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static func rawMetadataSHA256(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static func wireMetadataSHA256(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "func reviewedGenesisHash() async throws -> String" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "_ = try await rpc.reviewedGenesisHash()" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "private func createLiveGenesisOperation()" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "let connectedGenesisHash = try genesisOperation" "${extrinsic_service}" ||
   [ "$(/usr/bin/grep -Fc 'let genesisOperation = createLiveGenesisOperation()' "${extrinsic_service}")" -ne 4 ] ||
   [ "$(/usr/bin/grep -Fc 'addDependency(genesisOperation)' "${extrinsic_service}")" -ne 7 ] ||
   ! /usr/bin/grep -Fq "final class Sora2BoundedHTTPJSONRPCEngine" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "final class Sora2OneShotURLSessionDelegate" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "needNewBodyStream completionHandler" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "static let maximumRequestBytes = 2 * 1024 * 1024" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "static let maximumResponseBytes = 8 * 1024 * 1024" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "let (bytes, response) = try await session.bytes(for: request)" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "if method == RPCMethod.submitExtrinsic" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "static func isCanonicalSignedExtrinsic(" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "completedBeforePublication" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "method: RPCMethod.submitExtrinsic" "${extrinsic_service}" ||
   /usr/bin/grep -Fq "subscriptionEngine" "${extrinsic_service}" ||
   /usr/bin/grep -Fq "RPCMethod.submitExtrinsicAndWatch" "${extrinsic_service}" ||
   /usr/bin/grep -Fq "watch: Bool" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'engine: statusEngine,' "${polkamarkt_runtime}")" -ne 2 ] ||
   ! /usr/bin/grep -Fq "enum ReviewedSoraRuntimeSnapshotAdmission" "${runtime_snapshot_factory}" ||
   ! /usr/bin/grep -Fq "let normalizedItemChain =" "${runtime_snapshot_factory}" ||
   ! /usr/bin/grep -Fq "normalizedItemChain == normalizedRequestedChain" "${runtime_snapshot_factory}" ||
   ! /usr/bin/grep -Fq "static let maximumTypeRegistryBytes = 512 * 1024" "${runtime_snapshot_factory}" ||
   ! /usr/bin/grep -Fq '"2bd6d5a58ceaecb5a1ac05f089e1269288d884ae8b768527d58ae217434bf580"' "${runtime_snapshot_factory}" ||
   ! /usr/bin/grep -Fq '"9ced79bb14808bd5e56145e834807e54cc5c623023b768bb415773035388ae92"' "${runtime_snapshot_factory}" ||
   [ "$(sha256_file "${runtime_default_types}")" != "2bd6d5a58ceaecb5a1ac05f089e1269288d884ae8b768527d58ae217434bf580" ] ||
   [ "$(sha256_file "${runtime_sora_types}")" != "9ced79bb14808bd5e56145e834807e54cc5c623023b768bb415773035388ae92" ] ||
   [ "$(/usr/bin/wc -c < "${runtime_default_types}" | /usr/bin/tr -d '[:space:]')" != "122551" ] ||
   [ "$(/usr/bin/wc -c < "${runtime_sora_types}" | /usr/bin/tr -d '[:space:]')" != "136939" ] ||
   [ "$(/usr/bin/grep -Fc 'ReviewedSoraRuntimeSnapshotAdmission.validate(' "${runtime_snapshot_factory}")" -ne 3 ] ||
   [ "$(/usr/bin/grep -Fc 'ReviewedSoraRuntimeSnapshotAdmission.validate(' "${runtime_hot_snapshot_factory}")" -ne 3 ] ||
   [ "$(/usr/bin/grep -Fc '.validateTypeRegistryUsage(' "${runtime_snapshot_factory}")" -ne 3 ] ||
   [ "$(/usr/bin/grep -Fc '.validateTypeRegistryUsage(' "${runtime_hot_snapshot_factory}")" -ne 3 ] ||
   [ "$(/usr/bin/grep -Fc 'validateChainTypes(' "${runtime_snapshot_factory}")" -lt 3 ] ||
   [ "$(/usr/bin/grep -Fc 'validateChainTypes(' "${runtime_hot_snapshot_factory}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'ReviewedSoraRuntimeSnapshotAdmission.validate(' "${runtime_sync_service}")" -ne 2 ] ||
   ! /usr/bin/grep -Fq "loadReviewedChainTypes()" "${runtime_sync_service}" ||
   ! /usr/bin/grep -Fq "usesReviewedSoraBundle: true" "${chain_registry_factory}" ||
   ! /usr/bin/grep -Fq "loadReviewedCommonTypes()" "${common_types_sync_service}" ||
   ! /usr/bin/grep -Fq "? .onlyOwn" "${runtime_provider}" ||
   ! /usr/bin/grep -Fq "Sora2BoundedHTTPJSONRPCEngine.wrapping(connection)" "${runtime_sync_service}" ||
   ! /usr/bin/grep -Fq "ReviewedSoraRuntimeSnapshotAdmission.isReviewedSoraChain(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq '"not-a-chain-hash"' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "RPCMethod.submitExtrinsicAndWatch" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "RPCMethod.needsMigration" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "XCTAssertNil(legacyEntry.purpose)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq '"0x28AF"' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "profile=unsafe" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "reviewedGenesis.uppercased()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "tamperedChainTypes[0] ^= 0x01" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testSora2SigningIdentityRejectsVersionOrMetadataSubstitution" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "preparedSubmissionAlreadyConsumed" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "testPreparedExtrinsicSubmissionIsOneShot" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testCancellableCallRelayClosesPublicationRaceExactlyOnce" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusHistoryRejectsOversizedExactAmountAndMantissa" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testSora2DefinitivePreTransportFailureRemovesReservation" "${recovery_gate_tests}" ||
   ! /usr/bin/grep -Fq "testSora2ProducedSignatureIsVerifiedAgainstStoredPublicKey" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testEd25519SignerMatchesPinnedSora2Rfc8032Vector" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "enum Sora2Ed25519SeedSigner" "${signing_protocol}" ||
	   ! /usr/bin/grep -Fq "EDSeedSigner(seed: seed).sign(originalData)" "${signing_protocol}" ||
	   ! /usr/bin/grep -Fq "unsigned char expandedPrivateKey[64]" "${ed25519_seed_signer}" ||
	   ! /usr/bin/grep -Fq "ed25519_sha2_create_keypair(" "${ed25519_seed_signer}" ||
	   ! /usr/bin/grep -Fq "EDSeedSignerWipe(expandedPrivateKey" "${ed25519_seed_signer}" ||
	   ! /usr/bin/grep -Fq "EDSeedSignerWipe(_seed.mutableBytes" "${ed25519_seed_signer}" ||
	   ! /usr/bin/grep -Fq '#import "EDSeedSigner.h"' "${ed25519_umbrella}" ||
	   ! /usr/bin/grep -Fq "Legacy EDSigner is unavailable" "${ed25519_legacy_signer}" ||
	   /usr/bin/grep -Fq "ed25519_sha2_sign(" "${ed25519_legacy_signer}" ||
	   ! /usr/bin/grep -Fq "EDSeedSigner(seed: secretKey.miniSeed)" "${ssf_transaction_signer}" ||
	   ! /usr/bin/grep -Fq "XCTAssertEqual(secondSignature, firstSignature)" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testEd25519SeedSignerRejectsShortSeedBeforeExpansion" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingSubmissionStoreNeverRegressesTerminalState" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingSubmissionStoreRetainsExactAmbiguousHash" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2ConfirmedTransportSuccessSurvivesJournalFailure" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2SubmissionUnknownCarriesAndProjectsExactStagedHash" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PostTransportCancellationAndHashMismatchUseStagedHash" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingProjectionRejectsEveryNonAmbiguousFailure" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingProjectionRejectsMalformedAmbiguityHash" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingProjectionKeepsConfirmedHashPendingForReconciliation" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "Sora2LegacySubmissionProjection" "${polkaswap_network_factory}" ||
	   [ "$(/usr/bin/grep -Fc 'Sora2LegacySubmissionProjection' "${polkaswap_wallet_facade_protocol}")" -lt 2 ] ||
	   ! /usr/bin/grep -Fq "Sora2ConfirmSendingResultProjection" "${confirm_sending}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingSubmissionStorePreservesDuplicateHashForReconciliation" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testSora2PendingJournalRejectsSymbolicLink" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "struct Sora2SubmissionRecoveryContext: Codable, Equatable" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "static let currentSchemaVersion = 1" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "eraDeathBlockExclusive" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "Reject a custom/cross-network identity before the signing closure" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "recoveryContext: info.recoveryContext" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "guard let recoveryContext = prepared.recoveryContext" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "func resolveAuthoritatively(" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "var isPrunable: Bool" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "recoveryContext == nil || terminalResolution != nil" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "case mortalEraAbsence(" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "final class Sora2PendingSubmissionReconciler" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "func reconcileStatusOnly() async throws" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "maximumWitnessesPerPass = 16" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "ordered.prefix(Self.maximumWitnessesPerPass)" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "canonicalExtrinsicHashes(" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "authoritativeExecutionResult(" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "A pre-expiry absence is not terminal" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "private static let requestTimeoutSeconds = 30" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "PolkamarktRPCOperationRelay" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "JSONRPCOperation<Parameters, Response>" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "operation.completionBlock = { [weak operation] in" "${polkamarkt_runtime}" ||
	   [ "$(/usr/bin/grep -Fc 'let relay = PolkamarktRPCOperationRelay()' "${polkamarkt_runtime}")" -lt 2 ] ||
	   ! /usr/bin/grep -Fq "targetOperation.completionBlock = {" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "[weak targetOperation] in" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "relay.set(wrapper)" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "final class Sora2PendingSubmissionRecoveryRuntime" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "walletStorageReady, chainReady" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "Sora2PendingSubmissionRecoveryRuntime.shared" "${app_delegate}" ||
	   ! /usr/bin/grep -Fq "Sora2PendingSubmissionRecoveryRuntime.shared" "${splash_interactor}" ||
	   ! /usr/bin/grep -Fq "updateSora2PendingRecoveryReadiness()" "${service_coordinator}" ||
	   ! /usr/bin/grep -Fq '!$0.isPrunable' "${account_options}" ||
	   ! /usr/bin/grep -Fq "return witness.isPrunable" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "finalizedHeight: 191" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq ".finalizedFailure" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq ".finalizedSuccess" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq ".expiredNotIncluded" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "schemaVersion: 2" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "corruptContextStore.all()" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "DurableFileWriter.write(" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "PendingTransactionJournalNamespace.validate(" "${extrinsic_service}"; then
	    echo "error: SORA2 signing or status-only ambiguous-submission recovery is incomplete"
    exit 1
fi

if /usr/bin/grep -Fq "watch: true" "${legacy_migration_service}" ||
   /usr/bin/grep -Fq "JSONRPCSubscription" "${legacy_migration_service}" ||
   /usr/bin/grep -Fq "resendOnReconnect" "${legacy_migration_service}" ||
   /usr/bin/grep -Fq "lazy var irohaKeyPair" "${legacy_migration_service}" ||
   /usr/bin/grep -Fq "self.did" "${legacy_migration_service}" ||
   /usr/bin/grep -Fq "_ = try? statusEngine.callMethod(" "${legacy_migration_service}" ||
   /usr/bin/grep -Fq "MigrationAccountCompletionStore.contains(" "${legacy_migration_service}" ||
   [ "$(/usr/bin/grep -Fc 'settings.hasMigrated' "${legacy_migration_service}")" -ne 1 ] ||
   ! /usr/bin/grep -Fq "settings.hasMigrated = true" "${legacy_migration_service}" ||
   [ "$(/usr/bin/grep -Fc 'RPCMethod.needsMigration' "${legacy_migration_service}")" -ne 2 ] ||
   ! /usr/bin/grep -Fq "purpose: .legacyMigration" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "Migration recovery witness is incomplete" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq 'completion?(.success(""))' "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "preSigningValidation: {" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "Sora2PendingSubmissionReconciler(" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "terminalResolution?.kind == .finalizedSuccess" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "final class MigrationFinalityRecoveryHandle" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "final class MigrationEligibilityCheckGate" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "eligibilityGate.authorizeForSigning(" "${legacy_migration_service}" ||
   [ "$(/usr/bin/grep -Fc 'eligibilityGate.validateSigningAuthorization(' "${legacy_migration_service}")" -ne 2 ] ||
   [ "$(/usr/bin/grep -Fc 'consumeAwaitingEligibility(' "${legacy_migration_service}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "enum MigrationAccountCompletionStore" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "private static let maximumPayloadBytes = 300 * 1_024" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "SettingsKey.migratedAccountsV1.rawValue" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "private func submitMigration(" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "private func createIrohaDid(for accountAddress: String)" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "migrationSuccess(accountAddress:" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "createIrohaKeyPair(" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "for: account.address" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "completion: completion" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "Migration requires the existing master phrase" "${legacy_migration_service}" ||
   ! /usr/bin/grep -Fq "MigrationFinalityRecoveryHandle(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "MigrationEligibilityCheckGate()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "MigrationAccountCompletionStore.record(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "The legacy global flag is not account-level authority" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "migrationService.checkMigration()" "${service_coordinator}"; then
    echo "error: legacy migration can reconnect/resubmit, reuse stale identity, or strand durable finality recovery"
    exit 1
fi

legacy_ed_signer_constructor='EDSigner''(privateKey:'
legacy_ed_signer_callers="$({
    /usr/bin/find \
        "${root}/SoraPassport" \
        "${root}/SoraPassportTests" \
        "${root}/VendorPackages/shared-features-spm/Sources" \
        -type f -name '*.swift' \
        -exec /usr/bin/grep -lF \
            "${legacy_ed_signer_constructor}" {} \;
} || true)"
if [ -n "${legacy_ed_signer_callers}" ]; then
    echo "error: unsafe legacy EDSigner remains reachable from Swift source"
    exit 1
fi

if /usr/bin/grep -Fq "walletMigrationRecoveryRequired = false" "${storage_migrator}" ||
   /usr/bin/grep -Fq "walletMigrationRecoveryReason = nil" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "testSuccessfulCurrentSchemaSafetySnapshotDoesNotClearConcurrentRecoveryMarker" "${modernization_tests}"; then
    echo "error: a successful migration path can clear a concurrent sticky recovery latch"
    exit 1
fi

if ! /usr/bin/grep -Fq "private let recoveryGate: WalletRecoveryCapabilityGate" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "private func fetchEntropyForAddress(_ address: String)" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "recoveryGate: recoveryGate ??" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "makeIsolatedRecoveryGate(settings: settings)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "injectedBlockedSettings.walletMigrationRecoveryRequired = true" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "recoveryGate: blockedMigrationGate" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "blockedMigrator.performMigration()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "recoveryMarkerReadCount" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "blockedStoreBytes" "${modernization_tests}" ||
   ! /usr/bin/python3 -I -S - \
        "${wallet_network_model}" \
        "${keystore_extensions}" \
        "${storage_migrator}" <<'PY'
import re
import sys
from pathlib import Path

wallet_model, keystore, storage = [Path(value).read_text() for value in sys.argv[1:]]
validator_marker = "enum LegacySoraIdentityValidator {"
if validator_marker not in wallet_model:
    raise SystemExit(1)
validator_source = wallet_model.split(validator_marker, 1)[1]
signature = re.search(
    r"static func validate\((?P<body>.*?)\n\s*\) throws \{",
    validator_source,
    re.DOTALL,
)
if signature is None or "recoveryGate: WalletRecoveryCapabilityGate" not in signature.group("body"):
    raise SystemExit(1)
if "recoveryGate: WalletRecoveryCapabilityGate = .shared" in signature.group("body"):
    raise SystemExit(1)

def has_injected_validator_call(source: str) -> bool:
    return re.search(
        r"LegacySoraIdentityValidator\.validate\(.*?"
        r"recoveryGate:\s*recoveryGate\s*\n\s*\)",
        source,
        re.DOTALL,
    ) is not None

if not has_injected_validator_call(keystore):
    raise SystemExit(1)
if not has_injected_validator_call(storage):
    raise SystemExit(1)
PY
then
    echo "error: retained entropy validation does not preserve the caller's recovery capability"
    exit 1
fi

if /usr/bin/grep -Fq "Set(NetworkId.allCases)" "${root_interactor}" ||
   /usr/bin/grep -Fq "Set(NetworkId.allCases)" "${modernization_tests}" ||
   /usr/bin/grep -Fq "[.sora2, .minamoto, .taira]" "${wallet_network_model}" ||
   /usr/bin/grep -Fq "[.minamoto, .taira]" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "struct NexusDerivationProfile" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "struct NexusNetworkAdmissionPolicy" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "persistedMnemonicNetworkIdsAreValid" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "verifyTopologyAdmission(" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "admissionPolicy.admittedDerivationProfiles" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "static var admittedWalletNetworkIds" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq ".admittedWalletNetworkIds" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "NexusNetworkConfiguration.admittedWalletNetworkIds" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "NexusNetworkConfiguration.admittedWalletNetworkIds" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusAdmissionPolicyHasIndependentExactTopologySets" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusTopologyAdmissionAppendsAndRetainsTairaRecovery" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "tairaAdmitted: Bool" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq ".current.isTairaAdmitted" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "portfolioSubtitle(tairaAdmitted:" "${more_menu_presenter}" ||
   ! /usr/bin/grep -Fq ".current.isTairaAdmitted" "${more_menu_presenter}" ||
   ! /usr/bin/grep -Fq "exposesTairaSettings(" "${app_settings_presenter}" ||
   ! /usr/bin/grep -Fq ".current.isTairaAdmitted" "${app_settings_presenter}" ||
   ! /usr/bin/grep -Fq '"SORA2 · Minamoto"' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq '"SORA2 · Minamoto · Taira Testnet"' "${modernization_tests}"; then
    echo "error: retained-wallet migration and verification disagree on bundle-admitted Nexus networks"
    exit 1
fi

if /usr/bin/grep -Fq "newAccountOperation" "${account_factory}" ||
   ! /usr/bin/grep -Fq "final class PreparedAccount" "${account_factory}" ||
   ! /usr/bin/grep -Fq "LegacySoraIdentityValidator.validate(" "${account_factory}" ||
   ! /usr/bin/grep -Fq "func persistPreparedAccount(" "${account_factory}" ||
   ! /usr/bin/grep -Fq "try !keystore.checkKey" "${account_factory}" ||
   ! /usr/bin/grep -Fq "testPreparedSeedImportValidationDoesNotWriteKeychain" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPreparedAccountRejectsMismatchedPrivateAndPublicMaterial" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testWalletAccountCommitJournalRequiresOrderedActivation" "${modernization_tests}"; then
    echo "error: account import validation is not pure or new-wallet activation is not journaled"
    exit 1
fi

if ! /usr/bin/grep -Fq "co.jp.soramitsu.sora.storage-migration" "${splash_interactor}" ||
   ! /usr/bin/grep -Fq "WalletAccountCommitJournalStore().unresolved()" "${splash_interactor}" ||
   ! /usr/bin/grep -Fq "WalletLifecycleCoordinator.shared.withExclusiveAccess" "${splash_interactor}"; then
    echo "error: startup migration is not background, single-flight, journal-aware, and lifecycle coordinated"
    exit 1
fi

if /usr/bin/grep -Fq "stopped before changing anything" "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "It did not delete, replace, log out, or recreate any account." "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "Backup and export help" "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "Do not delete or reinstall SORA." "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "Never send anyone your phrase, seed, private key, or PIN." "${root_wireframe}"; then
    echo "error: wallet recovery route lacks accurate preservation and protected backup/export assistance"
    exit 1
fi

if ! /usr/bin/grep -Fq "randomMnemonic(.entropy256)" "${account_create}" ||
   ! /usr/bin/grep -Fq "static let userImportWordCounts: Set<Int> = [12, 24]" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "static let retainedSoraWordCounts: Set<Int> = [12, 15, 24]" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "case legacyMnemonicEntropy" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "source == .mnemonicEntropy" "${wallet_network_model}" ||
   [ "$(/usr/bin/grep -Fc "allowedMnemonicWordCounts.contains(mnemonic.allWords().count)" "${account_import}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "WalletMnemonicWordPolicy.userImportWordCounts" "${account_import}" ||
   [ "$(/usr/bin/grep -Fc ".retainedSoraWordCounts" "${account_import_factory}")" -ne 1 ] ||
   ! /usr/bin/grep -Fq "WalletMnemonicWordPolicy.retainedSoraWordCounts" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "WalletMnemonicWordPolicy.userImportWordCounts" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".legacyMnemonicEntropy" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testExplicitWatchOnlyMigrationNeverSynthesizesNexusChildren" "${modernization_tests}" ||
   ! /usr/bin/awk '
       /private func migrateLocked\(/ { in_migrate = 1 }
       in_migrate && /let isExplicitWatchOnly =/ && stage == 0 { stage = 1 }
       in_migrate && /legacySecret == nil,/ && stage == 1 { stage = 2 }
       in_migrate && /!isExplicitWatchOnly/ && stage == 2 { stage = 3 }
       in_migrate && /KeystoreTag\.legacyEntropy\.rawValue/ && stage == 3 { stage = 4 }
       in_migrate && /private static func wipeSensitive\(/ { in_migrate = 0 }
       END { exit(stage == 4 ? 0 : 1) }
   ' "${wallet_network_model}"; then
    echo "error: new-wallet 24-word policy, public 12/24 import, or retained 15-word SORA2-only compatibility is not enforced"
    exit 1
fi

if ! /usr/bin/grep -Fq "private static let maximumTransactions = 500" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "private static let maximumAddressBytes = 512" "${iroha_address_codec}" ||
   ! /usr/bin/grep -Fq "static let maximumScale = 255" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "testI105RejectsUnboundedInputBeforeBaseConversion" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusAmountScaleMatchesNoritoUnsignedByteContract" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "try transactions.forEach(validate)" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "Set(transactionHashes).count == transactionHashes.count" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "oldestTerminalIndex" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "try receipt.validate(expectedHash: expectedHash)" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "finalizedBlockHeight >= committedBlockHeight" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "prepared.reserveSubmission()" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "preservesDurableProgress(" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "try Task.checkCancellation()" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "testNexusPreparedTransferCanBeSubmittedOnlyOnce" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusStagedSendCanFailDefinitivelyBeforeTransport" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusPendingJournalRejectsStateAndTimestampContradictions" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testNexusPendingJournalPreservesTerminalReconciliation" "${modernization_tests}"; then
    echo "error: Nexus pending, receipt, or finalized-history reconciliation is incomplete"
    exit 1
fi

if ! /usr/bin/grep -Fq "static let maximumWireBytes = 4_096" "${pi_client}" ||
	   ! /usr/bin/grep -Fq 'URL(string: "https://pi.soramitsu.io/graphql")!' "${application_configs}" ||
	   ! /usr/bin/grep -Fq "var subqueryURL: URL { polkaswapIndexerURL }" "${config_service}" ||
	   ! /usr/bin/grep -Fq "ApplicationConfig.shared.polkaswapIndexerURL.absoluteString" "${config_service}" ||
	   ! /usr/bin/grep -Fq "static let maximumHealthIntegerBytes = 4_096" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "private static let healthIntegerFieldNames: Set<String>" "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "latestIndexedBlock",' "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "latestIndexedAt",' "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "workerLatestFinalizedBlock",' "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "workerLatestIndexedBlock",' "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "workerLag",' "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "workerLastSuccessfulIndexTimestamp",' "${pi_client}" ||
	   ! /usr/bin/grep -Fqx '        "workerLastErrorTimestamp",' "${pi_client}" ||
	   ! /usr/bin/grep -Fq 'objectName == "_health" || objectName == "health"' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "private struct PICanonicalHealthInteger: Decodable" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "extension PIHealth: Codable" "${pi_client}" ||
	   /usr/bin/grep -Fq "struct PIHealth: Codable" "${pi_client}" ||
	   [ "$(/usr/bin/grep -Fc 'try Self.decodeInteger(' "${pi_client}")" -ne 7 ] ||
	   ! /usr/bin/grep -Fq "rawValue.utf8.count <= Self.maximumWireBytes" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "decimalMatch == (rawValue.startIndex ..< rawValue.endIndex)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "finiteDoubleForRendering" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "unitIntervalDoubleForRendering" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "percentageFractionForRendering" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "isPercentage" "${pi_client}" ||
	   /usr/bin/grep -Fq "doubleValueForRendering" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "enum PIMarketCapLiquidityValidator" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq 'of: #"^(?:0|[1-9][0-9]*)$"#' "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "try PIMarketCapLiquidityValidator" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "enum PIMarketCapCatalogValidator" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "static let maximumRequestedAssetCount = 2_000" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "static let maximumAssetIDBytes = 256" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "requested.count == requestedAssetIDs.count" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "!CharacterSet.controlCharacters.contains(\$0)" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq ".validatedRequestedAssetIDs(assetIds)" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "requireExactRequestedCoverage(" "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "PIIndexerClient(endpoint: baseUrl)" "${market_cap_operation}" ||
	   ! /usr/bin/awk '
	       /override public func execute\(\) async throws/ { in_execute = 1 }
	       in_execute && /\.validatedRequestedAssetIDs\(assetIds\)/ {
	           admitted = 1
	       }
	       in_execute && /client\.allAssets\(\)/ {
	           saw_network = 1
	           if (!admitted) { exit 1 }
	       }
	       END { exit(admitted && saw_network ? 0 : 1) }
	   ' "${market_cap_operation}" ||
	   /usr/bin/grep -Fq 'asset.liquidity?.rawValue ?? "0"' "${market_cap_operation}" ||
	   ! /usr/bin/grep -Fq "let result = response.compactMap" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "let bigIntLiquidity = BigUInt(info.liquidity)" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "let liquidity = Decimal.fromSubstrateAmount(" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "liquidity: liquidity" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "guard result.count == response.count else" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq ".validatedRequestedAssetIDs(assetIds)) != nil" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "marketCapInfos.update(with: newValue)" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "let cacheExpired = expiredDate < Date()" "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "let findAssetIds = cacheExpired" "${market_cap_service}" ||
	   /usr/bin/grep -Fq "BigUInt(info.liquidity) ??" "${market_cap_service}" ||
	   ! /usr/bin/awk '
	       /let liquidity = Decimal\.fromSubstrateAmount\(/ {
	           in_conversion = 1
	           saw_conversion = 1
	       }
	       in_conversion && /\?\?/ { unsafe_default = 1 }
	       in_conversion && /^[[:space:]]*\)[[:space:]]*$/ {
	           in_conversion = 0
	       }
	       END { exit(saw_conversion && !unsafe_default ? 0 : 1) }
	   ' "${market_cap_service}" ||
	   ! /usr/bin/grep -Fq "struct PIExactFiatData" "${fiat_service}" ||
	   ! /usr/bin/grep -Fq "actor FiatService: FiatServiceProtocol" "${fiat_service}" ||
	   ! /usr/bin/grep -Fq "try await client.allAssets()" "${fiat_service}" ||
	   /usr/bin/grep -Fq "withCheckedContinuation" "${fiat_service}" ||
	   ! /usr/bin/grep -Fq "priceUsd: asset.priceUSD" "${fiat_operation}" ||
	   ! /usr/bin/grep -Fq "PIIndexerClient(endpoint: baseUrl)" "${fiat_operation}" ||
	   /usr/bin/grep -Fq "KotlinDouble" "${fiat_operation}" ||
	   ! /usr/bin/grep -Fq "actor APYService" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "private var catalogRefresh: CatalogRefresh?" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "if let flight = requestFlights[key]" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "try await client.allPoolXYKs()" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "return hasValidatedSnapshot ? apy : nil" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "withTaskCancellationHandler(" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "gate.resume(returning: nil)" "${apy_service}" ||
	   /usr/bin/grep -Fq "SubqueryApyInfoOperation" "${apy_service}" ||
	   ! /usr/bin/grep -Fq "struct PIExactApyInfo" "${apy_operation}" ||
	   ! /usr/bin/grep -Fq "sbApy: pool.strategicBonusApy" "${apy_operation}" ||
	   ! /usr/bin/grep -Fq "PIIndexerClient(endpoint: baseUrl)" "${apy_operation}" ||
	   /usr/bin/grep -Fq "KotlinDouble" "${apy_operation}" ||
	   ! /usr/bin/grep -Fq "testPIFiatAndApyAdaptersPreserveExactWireValues" "${modernization_tests}" ||
   [ "$(/usr/bin/grep -Fc 'PIQuantity.maximumWireBytes' "${nexus_service}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "PIAsyncOperation<ResultType>" "${pi_history_operation}" ||
   /usr/bin/grep -Fq "private enum State" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "func allHistory(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "func qualifiedAllHistory(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "func allAccountPositions(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "func allAccountTrades(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "struct PIReadQualification" "${pi_client}" ||
   ! /usr/bin/grep -Fq "let health: PIHealth?" "${pi_client}" ||
   ! /usr/bin/grep -Fq "var cacheIdentity = Data(endpoint.absoluteString.utf8)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "health(requireLive: true)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateStableResponseCheckpoint(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "let postflightHealth = try await health(requireLive: true)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateResponseHeights(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateConnectionPage(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateMobileConfig(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validatePolkamarktSignals(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "market.closeBlock.map(isRuntimeUInt32)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "closeBlockOverflow" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "let marketIds: [Int]?" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "values.count <= PolkamarktRuntimeContract.maximumBatchClaims" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "values.first == primary" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "XCTAssertEqual(trade.marketIds, [7, 8])" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "func includesMarket(_ marketId: UInt32) -> Bool" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "XCTAssertTrue(trade.includesMarket(8))" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "XCTAssertNil(legacyCachedTrade.marketIds)" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '.includesMarket(marketId)' "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "trade.marketIds, marketIds.count > 1" "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "accuracySummary { accuracyPercent }" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateAssets(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "let priceChangeDay: Double?" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "let volumeDayUSD: PIQuantity?" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validatePools(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateReferrerRewards(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "func allReferrerRewards(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq '$0.amount != nil' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "client.allReferrerRewards(" "${pi_referral_operation}" ||
	   /usr/bin/grep -Fq "while rewards.count < limit" "${pi_referral_operation}" ||
	   /usr/bin/grep -Fq 'amount: reward.amount?.rawValue ?? "0"' "${pi_referral_operation}" ||
	   ! /usr/bin/grep -Fq "specific identity and checkpoint bounds" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "try validateResponse(payload, qualification)" "${pi_client}" ||
	   [ "$(/usr/bin/grep -Fc 'validateResponse: validateResponse' "${pi_client}")" -lt 2 ] ||
	   [ "$(/usr/bin/grep -Fc 'await cache.remove(key: cacheKey)' "${pi_client}")" -lt 2 ] ||
	   ! /usr/bin/grep -Fq "validatedPendingTransactionHashes(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "func qualifiedHistoryByTransactionHashes(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateAccountHistory(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq '"or": [' "${pi_client}" ||
	   ! /usr/bin/grep -Fq '["address": ["equalTo": address]]' "${pi_client}" ||
	   ! /usr/bin/grep -Fq '["dataFrom": ["equalTo": address]]' "${pi_client}" ||
	   ! /usr/bin/grep -Fq '["dataTo": ["equalTo": address]]' "${pi_client}" ||
	   ! /usr/bin/awk '
	       /query MobileHistory\(/ { in_history = 1 }
	       in_history && /orderBy: \[TIMESTAMP_DESC, ID_DESC\]/ {
	           deterministic_order = 1
	       }
	       in_history && /^[[:space:]]*""",?$/ { exit }
	       END { exit(deterministic_order ? 0 : 1) }
	   ' "${pi_client}" ||
	   ! /usr/bin/awk '
	       /query MobileReferrerRewards\(/ { in_rewards = 1 }
	       in_rewards && /orderBy: \[TIMESTAMP_DESC, ID_DESC\]/ {
	           deterministic_order = 1
	       }
	       in_rewards && /^[[:space:]]*""",?$/ { exit }
	       END { exit(deterministic_order ? 0 : 1) }
	   ' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "PIHistoryCheckpointValidator.normalizedBlockHash" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateMarketSnapshots(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "isCanonicalAscendingSnapshotOrder" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "orderBy: [TIMESTAMP_ASC, ID_ASC]" "${pi_client}" ||
	   ! /usr/bin/grep -Fq '"type": ["equalTo": "DEFAULT"]' "${pi_client}" ||
	   /usr/bin/grep -Fq '"type": ["equalTo": "BLOCK"]' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "qualifiedAllMarketSnapshots(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "testPIMarketSnapshotsRequireCoordinatesAndCanonicalOrdering" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "orderBy: [UPDATED_AT_DESC, ID_DESC]" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "orderBy: [TIMESTAMP_DESC, ID_DESC]" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateMarkets(" "${pi_client}" ||
	   [ "$(/usr/bin/grep -Fc 'validateUniqueRuntimeMarketIds(' "${pi_client}")" -lt 3 ] ||
	   ! /usr/bin/grep -Fq "fully collected catalog" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "UInt32(exactly: value) != nil" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "testPIMarketIdentifiersCoverExactRuntimeUInt32Domain" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "status: PolkamarktMarketStatus?" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateAccountPositions(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "validateAccountTrades(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "isBoundedRequiredLabel(market.status)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq '$0.blockHash.flatMap(' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "qualification: PIReadQualification(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "guard let health = entry.health" "${pi_client}" ||
   ! /usr/bin/grep -Fq "if let expectedQualification" "${pi_client}" ||
   ! /usr/bin/grep -Fq "PIHistoryCheckpointValidator.validate(" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "PIHistoryPageValidator.validate(" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "client.qualifiedHistoryPage(" "${pi_history_operation}" ||
	   /usr/bin/grep -Fq "offset: offset" "${pi_history_operation}" ||
	   /usr/bin/grep -Fq '$offset' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "for currentPage in 1 ... page" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var seenCursors = Set<String>()" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var seenItemIdentities = Set<String>()" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var expectedTotalCount: Int?" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var expectedQualification: PIReadQualification?" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "actor PIValidatedHistoryCache" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "let digest: String" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "Self.digest(entryData) == envelope.digest" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "qualification.source == .live" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "PIValidatedHistoryCache.shared.save(" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "PIValidatedHistoryCache.shared.load(" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "Raw GraphQL cache" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "raw GraphQL page here would lose that proof" "${pi_client}" ||
   ! /usr/bin/grep -Fq "normalizedTransactionHash" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "indexedCheckpointHash: health.latestIndexedBlockHash" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "element.dataFrom == expectedAddress" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "element.dataTo == expectedAddress" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "executionSucceeded(element.execution) != nil" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "isNonNegativeIntegerQuantity(element.networkFee)" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "let timestamp = element.timestamp" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "PIHistoryCheckpointValidator.isNonNegativeIntegerQuantity(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq '($0.timestamp ?? -1) >= 0' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "try Self.validatedFee(item.networkFee)" "${history_transaction_mapper}" ||
	   ! /usr/bin/grep -Fq "static func validatedFee" "${history_transaction_mapper}" ||
	   ! /usr/bin/grep -Fq "canonicalDecimal(roundTrip) == canonicalDecimal(rawValue)" "${history_transaction_mapper}" ||
	   /usr/bin/grep -Fq "?? Amount(value: 0)" "${history_transaction_mapper}" ||
	   /usr/bin/grep -Fq "Decimal(string:" "${sora_history_wallet_mapper}" ||
	   ! /usr/bin/grep -Fq "testPIHistoryAmountMappingRejectsMalformedOrNegativeValues" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "History without a timestamp was accepted" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "isValidHistoryIdentifier" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "canonicalHistoryIdentifier" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "CharacterSet.controlCharacters.contains" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "historyIdentifiers.insert(canonicalIdentifier).inserted" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "Set(identifiers).count == values.count" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "RPCMethod.getBlockHash" "${pi_history_operation}" ||
	   ! /usr/bin/grep -Fq "testPIHistoryBindsAccountCheckpointAndCanonicalBlockHash" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIReturnedHistoryRowsAreBoundToRequestedAccountAndHash" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "syntheticBridgeEvent" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "canonicalDuplicate" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "controlledSyntheticIdentifier" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIMarketCatalogBindsTypedStatusAndQuantitySemantics" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"id":"different-row-id","marketId":7' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "duplicateRuntimeMarket" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIPolkamarktRowsRejectNegativeAccountAndSnapshotQuantities" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIPolkamarktAccountRowsRequireCheckpointCoordinatesBeforeUse" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIHistoryRequiresCanonicalChainCoordinatesBeforeUse" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIConnectionPageIsValidatedBeforeCacheEligibility" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIMobileConfigRejectsConflictingMutationFlagsBeforeCacheEligibility" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIPolkamarktSignalsRejectNegativeCountsAndDuplicateLabels" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIAssetPoolAndRewardRowsRejectInvalidSemantics" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "PIMarketCapLiquidityValidator.validatedWireValue(nil)" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'try PIQuantity("1.5")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'try PIQuantity("-1")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"xor\nval"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "PIMarketCapCatalogValidator.requireExactRequestedCoverage(" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'returnedAssetIDs: ["xor", "xor"]' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'requestedAssetIDs: ["xor", "xor"]' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "PIMarketCapCatalogValidator.maximumRequestedAssetCount" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "PIMarketCapCatalogValidator.maximumAssetIDBytes + 1" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIChartConversionRequiresFiniteBoundedDerivedValues" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "Malformed PI transaction identity was accepted" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "Non-canonical PI indexed checkpoint hash was accepted" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIHistoryRejectsIncoherentPageMetadataAndDuplicateIDs" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIPaginationRejectsMixedCacheSourceOrCheckpoint" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIPaginationRejectsOverlappingItemIdentities" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIResponseRequiresStablePreflightAndPostflightCheckpoint" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIResponseRowsCannotExceedAttributedCheckpoint" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIReturnedPolkamarktRowsAreBoundToRequestedIdentity" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIPendingLookupRequiresBoundedUniqueCanonicalHashes" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIHistorySchemaFixturePreservesExactIntegerMetadata" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIHealthAcceptsNumericAndCanonicalQuotedIntegerWireForms" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testPIHealthIntegerWireRejectsNoncanonicalOverflowAndTypedValues" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "piHealthAdmissionEnvelope(unboundedData)" "${modernization_tests}" ||
	   /usr/bin/grep -Fq "case invalidQuantity(String)" "${pi_client}" ||
	   /usr/bin/grep -Fq "case repeatedCursor(String)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "testPIProtocolErrorsNeverRetainRawQuantityOrCursorText" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testValidatedPIHistoryCacheSurvivesRestartAndExpires" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "testValidatedPIHistoryCacheRejectsSymbolicLinkEntry" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq ".isSymbolicLinkKey" "${pi_client}" ||
	   ! /usr/bin/grep -Fq ".isSymbolicLinkKey" "${pi_history_operation}" ||
   ! /usr/bin/grep -Fq "liveError.allowsOfflineFallback" "${pi_client}" ||
   ! /usr/bin/grep -Fq "Self.allowsOfflineTransportFallback(liveError)" "${pi_client}" ||
   ! /usr/bin/grep -Fq "testPICacheFallbackAllowsOnlyTransientTransportErrors" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "values.count <= pageSize" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "(1 ... 100).contains(maximumPages)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "seenItemIdentities.insert" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "throw PIIndexerError.repeatedPage" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var typedAccountBalancesAvailable: Bool { false }" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "func requireTypedAccountBalancesCapability(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "throw PIIndexerError.typedAccountBalancesUnavailable" "${pi_client}"; then
    echo "error: PI numeric, live-health, bounded-cache, or pagination safety is incomplete"
    exit 1
fi

if ! /usr/bin/grep -Fq "enum Sora2TransferFeeQualification" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "reviewedFee == signedBytesFee" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "requiredByAsset[WalletAssetId.xor.rawValue, default: .zero] += exactFee" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "final class PreparedSora2TransferSubmission" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "func estimateTransferFee(for info: TransferInfo) async throws -> Decimal" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "func prepareTransferSubmission(" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "func submitPreparedTransfer(" "${wallet_network_factory_protocol}" ||
   [ "$(/usr/bin/grep -Fc 'let closure = try exactTransferBuilderClosure(for: info)' "${polkaswap_network_factory}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "expectedRawFee: submission.rawFee" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "func submitPreparedTransfer(" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "TransactionHistoryItem.createFromTransferInfo(" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "func prepareTransferSubmission(" "${wallet_service_protocol}" ||
   ! /usr/bin/grep -Fq "func submitPreparedTransfer(" "${wallet_service}" ||
   ! /usr/bin/grep -Fq "func prepareTransferSubmission(" "${wallet_network_factory_mock}" ||
   ! /usr/bin/grep -Fq "expectedRawFee: String" "${extrinsic_service}" ||
   /usr/bin/grep -Fq "expectedRawFee: String?" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "try signedPayload.hexForFeeQualification()" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "enum Sora2SignedFeeRevalidation" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "actual == expected" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "dependencies: [feeOperation]" "${extrinsic_service}" ||
	   ! /usr/bin/grep -Fq "enum Sora2LegacyTransferAdmission" "${wallet_network_factory_protocol}" ||
	   [ "$(/usr/bin/grep -Fc 'Sora2LegacyTransferAdmission.requirePreparedPath(for: info.type)' "${polkaswap_network_factory}")" -ne 1 ] ||
	   [ "$(/usr/bin/grep -Fc 'Sora2LegacyTransferAdmission.requirePreparedPath(for: info.type)' "${polkaswap_wallet_facade_protocol}")" -ne 1 ] ||
	   /usr/bin/grep -Fq "case .outgoing, .incoming" "${polkaswap_network_factory}" ||
	   ! /usr/bin/grep -Fq "let reviewedAssetId = self.firstAssetId" "${input_asset_amount}" ||
	   ! /usr/bin/grep -Fq "self.inputedFirstAmount == reviewedAmount" "${input_asset_amount}" ||
	   ! /usr/bin/grep -Fq "currentAccount.publicKeyData ==" "${input_asset_amount}" ||
	   ! /usr/bin/grep -Fq "firstAssetAmount: reviewedAmount" "${input_asset_amount}" ||
	   ! /usr/bin/grep -Fq "let reviewedRecipient = result.firstName" "${generate_qr}" ||
	   ! /usr/bin/grep -Fq "currentAccount.publicKeyData ==" "${generate_qr}" ||
	   ! /usr/bin/grep -Fq "firstAssetAmount: reviewedAmount.decimalValue" "${generate_qr}" ||
	   ! /usr/bin/grep -Fq "Sora2SignedFeeRevalidation.requireExact(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "walletService.prepareTransferSubmission(" "${confirm_sending}" ||
   ! /usr/bin/grep -Fq "walletService.submitPreparedTransfer(" "${confirm_sending}" ||
   [ "$(/usr/bin/grep -Fc 'fetchLiveTransferBalances()' "${confirm_sending}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "Sora2TransferFeeQualification.requireExact(" "${confirm_sending}" ||
   ! /usr/bin/grep -Fq "Sora2TransferSigningAuthorization" "${confirm_sending}" ||
   ! /usr/bin/grep -Fq "networkFacade.estimateTransferFee(" "${input_asset_amount}" ||
   ! /usr/bin/grep -Fq ".estimateTransferFee(for: info)" "${generate_qr}" ||
   /usr/bin/grep -Fq "feeProvider.getFee(for: .outgoing)" "${input_asset_amount}" ||
   /usr/bin/grep -Fq "feeProvider.getFee(for: .outgoing)" "${generate_qr}" ||
   ! /usr/bin/grep -Fq "Sora2TransferFeeQualification.requireSufficientBalances(" "${modernization_tests}"; then
    echo "error: ordinary SORA2 transfers are not bound to an exact signed-byte fee and fresh balances"
    exit 1
fi

if ! /usr/bin/grep -Fq \
    "893783ba6a19c33043eb5dabe42d949c14d0f257" \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq \
    'static let webContractCommitTree =' \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq \
    '"e391982c0921dea5278e919a7558b7a6a2afc0d4"' \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq \
    'static let webContractSourceTree =' \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq \
    '"57f0fe7623f2b93b34faecfc66d6c5da96d54e1b"' \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq \
    "static let webContractSourceFileCount = 22" \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'static let webContractBranch = "ui-updates"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static let maximumBatchClaims = 24" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static let maximumMarketId = UInt32.max" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static let maximumCloseBlock = UInt32.max" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "static let quoteDebounceNanoseconds: UInt64 = 250_000_000" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq '"Active",' "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq '"Finalized",' "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktRuntimeContract.categories.map" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "mineOnly.toggle()" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "dpmPricingCurve()" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktExternalLinkPolicy.validated" "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "Offline PI snapshot" "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "unitIntervalDoubleForRendering" "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "percentageFractionForRendering" "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "qualifiedAllMarketSnapshots(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "state?.finalizedStatus?.rawValue.uppercased()" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktTaskPolicy.isCancellation" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "testPolkamarktExternalLinksRequireCredentialFreeHTTPS" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "func authoritativeClaimables(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "PolkamarktClaimValidator.reviewedClaims(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "struct PolkamarktClaimAuthorization: Equatable" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "enum PolkamarktClaimAuthorizationSource: Equatable" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "let source: PolkamarktClaimAuthorizationSource" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "PolkamarktClaimValidator.reviewedTraderAuthorization(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktClaimValidator.reviewedCreatorAuthorization(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "source: .reviewedPositions" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "source: .selectedDetail" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktRuntimeContract.ClaimConfirmation.body" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktRuntimeContract.ClaimConfirmation.feeNotice" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "coordinator.reconcilePending(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "mutationAdmissionAvailable" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "runtimeReviewFinalizedBlockHash" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "coordinator.authoritativeClaimables(" "${polkamarkt_ui}" ||
   /usr/bin/grep -Fq "claimablePayoutUsd" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "coordinator.submitTraderClaim(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "coordinator.submitBatchClaim(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "coordinator.submitCreatorFeeClaim(" "${polkamarkt_ui}" ||
   /usr/bin/grep -Fq "/Users/" "${polkamarkt_runtime}"; then
    echo "error: canonical Polkamarkt board, filters, quote, or batch-claim behavior is incomplete"
    exit 1
fi

polkamarkt_locale_count=0
for polkamarkt_strings in \
    "${root}/SoraPassport/SoraLocalizable/"*.lproj/Localizable.strings
do
    if [ ! -f "${polkamarkt_strings}" ] || [ -L "${polkamarkt_strings}" ]; then
        echo "error: Polkamarkt localization table is missing or symbolic"
        exit 1
    fi
    for polkamarkt_key in \
        pageTitle.Polkamarkt \
        polkamarkt.outcomes.yes \
        polkamarkt.outcomes.no \
        polkamarkt.actions.buy \
        polkamarkt.actions.sell \
        polkamarkt.actions.claimTraderPayout \
        polkamarkt.actions.claimCreatorFees \
        polkamarkt.ticket.sharesOut \
        polkamarkt.ticket.collateralOut \
        polkamarkt.ticket.slippage \
        polkamarkt.ticket.takerFee \
        networkFeeText
    do
        if [ "$(/usr/bin/grep -Fc "\"${polkamarkt_key}\" = \"" "${polkamarkt_strings}")" != "1" ]; then
            echo "error: ${polkamarkt_key} is not defined exactly once in ${polkamarkt_strings}"
            exit 1
        fi
    done
    polkamarkt_locale_count=$((polkamarkt_locale_count + 1))
done

if [ "${polkamarkt_locale_count}" != "31" ] ||
   ! /usr/bin/grep -Fq "private enum PolkamarktL10n" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "R.string.localizable.pageTitlePolkamarkt(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "R.string.localizable.polkamarktActionsClaimTraderPayout(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "controller.localizationManager = localizationManager" "${polkamarkt_ui}"; then
    echo "error: canonical Polkamarkt localization contract is incomplete"
    exit 1
fi

if ! /usr/bin/grep -Fq "struct PolkaswapSlippage: Equatable, Sendable" "${polkaswap_slippage}" ||
   ! /usr/bin/grep -Fq "let basisPoints: UInt16" "${polkaswap_slippage}" ||
   ! /usr/bin/grep -Fq "init?(contextValue: String)" "${polkaswap_slippage}" ||
   ! /usr/bin/grep -Fq "func minimumAmount(for amount: Decimal)" "${polkaswap_slippage}" ||
   ! /usr/bin/grep -Fq "func maximumAmount(for amount: Decimal)" "${polkaswap_slippage}" ||
   ! /usr/bin/grep -Fq "let value: Decimal" "${polkaswap_accessory}" ||
   ! /usr/bin/grep -Fq "let maximumSpend = swapVariant == .desiredOutput" "${polkaswap_swap}" ||
   ! /usr/bin/grep -Fq "let substrateAmount = amountValue.toSubstrateAmount" "${polkaswap_swap}" ||
   ! /usr/bin/grep -Fq "private func hasCurrentExactQuote()" "${polkaswap_confirm_swap}" ||
   ! /usr/bin/grep -Fq "guard isEnoughtBalance, hasCurrentExactQuote()" "${polkaswap_confirm_swap}" ||
   [ "$(/usr/bin/grep -Fc 'slippage: PolkaswapSlippage' "${polkaswap_pool_detail}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "slippage.maximumAmount(for: quote.toAmount)" "${polkaswap_pool_detail}" ||
   ! /usr/bin/grep -Fq "slipValue = minMaxAmount.decimalValue.toSubstrateAmountRoundingUp" "${polkaswap_transfer_info}" ||
   ! /usr/bin/grep -Fq "PolkaswapSlippage(contextValue: rawSlippage)" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "WalletNetworkOperationFactoryError.invalidContext" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "private func exactLiquidityBuilderClosure(for info: TransferInfo)" "${polkaswap_network_factory}" ||
   [ "$(/usr/bin/grep -Fc 'let closure = try exactLiquidityBuilderClosure(for: info)' "${polkaswap_network_factory}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq '$0.identifier == WalletAssetId.xor.rawValue && $0.isFeeAsset' "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "feeAssets.count == 1" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal" "${wallet_network_factory_mock}" ||
   ! /usr/bin/grep -Fq "func prepareAndEstimateFee(" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "preSigningValidation: preSigningValidation" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "call: info.object.call" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "func prepareLiquiditySubmission(" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "func submitPreparedLiquidity(" "${polkaswap_network_factory}" ||
   ! /usr/bin/grep -Fq "func prepareLiquiditySubmission(" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "func submitPreparedLiquidity(" "${wallet_network_factory_protocol}" ||
   ! /usr/bin/grep -Fq "func prepareLiquiditySubmission(" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "func submitPreparedLiquidity(" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "createFromPreparedLiquidity(" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "performLocalHistorySave(" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "func prepareLiquiditySubmission(" "${wallet_network_factory_mock}" ||
   ! /usr/bin/grep -Fq "func submitPreparedLiquidity(" "${wallet_network_factory_mock}" ||
   ! /usr/bin/grep -Fq "LiquidityFeeQualification.accepts" "${polkaswap_liquidity_wireframe}" ||
   ! /usr/bin/grep -Fq "freshFee <= reviewedFee" "${polkaswap_liquidity_wireframe}" ||
   ! /usr/bin/grep -Fq "final class LiquiditySigningAuthorization" "${polkaswap_liquidity_wireframe}" ||
   ! /usr/bin/grep -Fq "estimateLiquidityFee(for: transferInfo)" "${polkaswap_supply}" ||
   ! /usr/bin/grep -Fq "estimateLiquidityFee(for: transferInfo)" "${polkaswap_remove}" ||
   ! /usr/bin/grep -Fq ".prepareLiquiditySubmission(" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq ".prepareLiquiditySubmission(" "${polkaswap_confirm_remove}" ||
   ! /usr/bin/grep -Fq ".submitPreparedLiquidity(" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq ".submitPreparedLiquidity(" "${polkaswap_confirm_remove}" ||
   [ "$(/usr/bin/grep -Fc 'cancellable.set(call)' "${polkaswap_network_factory}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "@MainActor" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq "@MainActor" "${polkaswap_confirm_remove}" ||
   ! /usr/bin/grep -Fq "preflightTask?.cancel()" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq "preflightTask?.cancel()" "${polkaswap_confirm_remove}" ||
   ! /usr/bin/grep -Fq "viewModel.viewWillDisappear()" "${confirm_view_controller}" ||
   ! /usr/bin/grep -Fq "feeReviewInvalidated" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq "feeReviewInvalidated" "${polkaswap_confirm_remove}" ||
   ! /usr/bin/grep -Fq "requiredByAsset[WalletAssetId.xor.rawValue, default: .zero] += freshFee" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq "xorBalance >= freshFee" "${polkaswap_confirm_remove}" ||
   ! /usr/bin/grep -Fq "testLiquidityExactFeeMustRemainWithinReviewedBound" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "private static func decodeHexQuantity" "${runtime_dispatch_info}" ||
   /usr/bin/grep -Fq "?? BigUInt.zero" "${runtime_dispatch_info}" ||
   ! /usr/bin/grep -Fq "testRuntimeFeeDetailsRejectsMalformedHexComponents" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".adding(call: initializeCall)" "${polkaswap_fee_provider}" ||
   ! /usr/bin/grep -Fq "static func createFromPreparedLiquidity(" "${polkaswap_history}" ||
   ! /usr/bin/grep -Fq "let runtimeCall = try exactCall.map(to: RuntimeCall<JSON>.self)" "${polkaswap_history}" ||
   ! /usr/bin/grep -Fq "Liquidity history must come from the exact prepared call above" "${polkaswap_history}" ||
   ! /usr/bin/grep -Fq "guard item.status != .pending" "${history_merge_manager}" ||
   ! /usr/bin/grep -Fq "static func pendingJournalOverlay(" "${history_merge_manager}" ||
   ! /usr/bin/grep -Fq "Indexer age alone never suppresses a journal witness" "${history_merge_manager}" ||
   ! /usr/bin/grep -Fq "Sora2PendingSubmissionStore().all()" "${polkaswap_wallet_facade_protocol}" ||
   ! /usr/bin/grep -Fq "pendingOperation: BaseOperation<[Sora2PendingSubmission]>?" "${wallet_history_facade}" ||
   ! /usr/bin/grep -Fq "pendingSubmissions: pendingSubmissions" "${wallet_history_facade}" ||
   ! /usr/bin/grep -Fq "testPendingHistoryRequiresExactRemoteHashBeforeRemoval" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "pendingJournalOverlay(" "${modernization_tests}" ||
   /usr/bin/grep -Fq "freshFee * pow(10, 18)" "${polkaswap_confirm_supply}" ||
   /usr/bin/grep -Fq "freshFee * pow(10, 18)" "${polkaswap_confirm_remove}" ||
   /usr/bin/grep -Fq "Extrinsic encoded:" "${extrinsic_builder}" ||
   ! /usr/bin/grep -Fq "var isUtilityBatch: Bool" "${polkaswap_call_path}" ||
   ! /usr/bin/grep -Fq "RuntimeCall<BatchArgs>.self" "${polkaswap_history_mapper}" ||
   ! /usr/bin/grep -Fq "func loadUserFarmInfos(" "${demeter_farming_service}" ||
   ! /usr/bin/grep -Fq "accountId: Data" "${demeter_farming_service}" ||
   ! /usr/bin/grep -Fq "let farms = try filtredUserFarms.map" "${demeter_farming_service}" ||
   ! /usr/bin/grep -Fq "throw DemeterFarmingServiceError.unavailable" "${demeter_farming_service}" ||
   ! /usr/bin/grep -Fq "extractResultData(" "${polkaswap_pool_facade}" ||
   ! /usr/bin/grep -Fq "throwing: DemeterFarmingServiceError.unavailable" "${polkaswap_pool_facade}" ||
   ! /usr/bin/grep -Fq "private let boundAccount: AccountItem?" "${polkaswap_fee_provider}" ||
   ! /usr/bin/grep -Fq "init(account: AccountItem? = SelectedWalletSettings.shared.currentAccount)" "${polkaswap_fee_provider}" ||
   /usr/bin/grep -Fq "feeStore" "${polkaswap_fee_provider}" ||
   /usr/bin/grep -Fq "SelectedWalletSettings" "${polkaswap_balance_storage}" ||
   ! /usr/bin/grep -Fq "fromAddress: address" "${polkaswap_balance_storage}" ||
   ! /usr/bin/grep -Fq "type: networkType" "${polkaswap_balance_storage}" ||
   ! /usr/bin/grep -Fq "senderAddress: self.address" "${polkaswap_wallet_facade_protocol}" ||
   /usr/bin/grep -Fq "SelectedWalletSettings" "${polkaswap_history}" ||
   /usr/bin/grep -Fq ".kensetsuCase" "${polkaswap_supply}" ||
   /usr/bin/grep -Fq ".kensetsuCase" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq "let accountSigner: SigningWrapperProtocol" "${wallet_network_factory_impl}" ||
   ! /usr/bin/grep -Fq "accountSigner: SigningWrapperProtocol" "${wallet_network_factory_impl}" ||
   [ "$(/usr/bin/grep -Fc 'return AwaitOperation<String>' "${wallet_network_factory_impl}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'try Task.checkCancellation()' "${wallet_network_factory_impl}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'withCheckedThrowingContinuation' "${wallet_network_factory_impl}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'continuation.resume(with: result)' "${wallet_network_factory_impl}")" -lt 2 ] ||
   /usr/bin/grep -Fq "DispatchSemaphore" "${wallet_network_factory_impl}" ||
   /usr/bin/grep -Fq "as! SigningWrapperProtocol" "${wallet_network_factory_impl}" ||
   /usr/bin/grep -Eq 'toSubstrateAmount[^;]*\?\? 0|currentAccount!' "${polkaswap_history}" ||
   ! /usr/bin/grep -Fq "testPolkaswapSlippageUsesExactBasisPointVectors" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkaswapDesiredOutputSignsExactMaximumInput" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkaswapDesiredInputSignsExactMinimumOutput" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testLiquidityBatchHistoryPreservesSignedCallOrdering" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testLocalHistoryUsesFacadeBoundSenderAddress" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testLiquidityPairStateResolvesCanonicalMutationMatrix" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "var liquidityAction: LiquidityPairAction" "${account_pools_service}" ||
   ! /usr/bin/grep -Fq "case registerInitializeAndDeposit" "${account_pools_service}" ||
   ! /usr/bin/grep -Fq "pairStateTask = Task" "${polkaswap_supply}" ||
   ! /usr/bin/grep -Fq "private var pairStateRequestId: UUID?" "${polkaswap_supply}" ||
   [ "$(/usr/bin/grep -Fc 'self.pairStateRequestId == requestId' "${polkaswap_supply}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "try Task.checkCancellation()" "${polkaswap_supply}" ||
   ! /usr/bin/grep -Fq "guard !Task.isCancelled" "${polkaswap_supply}" ||
   ! /usr/bin/grep -Fq "guard isPairStateValid" "${polkaswap_supply}" ||
   ! /usr/bin/grep -Fq "pairStateTask = Task" "${polkaswap_remove}" ||
   ! /usr/bin/grep -Fq "private var pairStateRequestId: UUID?" "${polkaswap_remove}" ||
   [ "$(/usr/bin/grep -Fc 'self.pairStateRequestId == requestId' "${polkaswap_remove}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "try Task.checkCancellation()" "${polkaswap_remove}" ||
   ! /usr/bin/grep -Fq "guard !Task.isCancelled" "${polkaswap_remove}" ||
   ! /usr/bin/grep -Fq "guard isPairStateValid" "${polkaswap_remove}" ||
   ! /usr/bin/grep -Fq "isEnoughtFeeAssetLiquidity" "${polkaswap_remove}" ||
   ! /usr/bin/grep -Fq "private var isConfirmationActive: Bool" "${polkaswap_confirm_supply}" ||
   ! /usr/bin/grep -Fq "private var isConfirmationActive: Bool" "${polkaswap_confirm_remove}" ||
   ! /usr/bin/grep -Fq "struct FarmShareSelection: Equatable, Hashable, Sendable" "${edit_farm_service}" ||
   ! /usr/bin/grep -Fq "var fraction: Decimal" "${edit_farm_service}" ||
   ! /usr/bin/grep -Fq "AnyPublisher<FarmShareSelection, Never>" "${edit_farm_service}" ||
   ! /usr/bin/grep -Fq "accountPoolBalance * selection.fraction" "${edit_farm_service}" ||
   ! /usr/bin/grep -Fq "PassthroughSubject<FarmShareSelection, Never>" "${edit_farm_cell}" ||
   [ "$(/usr/bin/grep -Fc 'validatedDemeterContext(info)' "${polkaswap_network_factory}")" -lt 3 ] ||
   [ "$(/usr/bin/grep -Fc 'validatedDemeterContext(info)' "${polkaswap_history}")" -lt 3 ] ||
   /usr/bin/grep -Fq 'amount: amount.toSubstrateAmount(precision: 18) ?? 0' "${polkaswap_history}" ||
   ! /usr/bin/grep -Fq "testDemeterFarmSliderQuantizesBeforeTransactionMath" "${modernization_tests}" ||
   /usr/bin/grep -Eq 'AnyPublisher<Float|Decimal\(Double\(|\.toDecimal\(\)' "${edit_farm_service}" ||
   /usr/bin/grep -Eq \
       'slippageTolerance: Float|Decimal\(Double\([^)]*slippage|String\(slippageTolerance\)|didSelect\(variant: Float\)' \
       "${polkaswap_swap}" \
       "${polkaswap_confirm_swap}" \
       "${polkaswap_liquidity_wireframe}" \
       "${polkaswap_confirm_supply}" \
       "${polkaswap_confirm_remove}" \
       "${polkaswap_transfer_info}" \
       "${polkaswap_network_factory}"; then
    echo "error: legacy Polkaswap slippage or percentage inputs are not exact and fail-closed"
    exit 1
fi

if ! /usr/bin/grep -Fq \
    "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf" \
    "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "private static let maximumMutations = 500" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "Set(extrinsicHashes).count == extrinsicHashes.count" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "[.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'try DurableFileWriter.write(' "${polkamarkt_runtime}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "let latest = try all()" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "PolkamarktPendingReconciliationPolicy.applying(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "if existing.state.isTerminal" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "oldestTerminalIndex" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "private func terminalMutationCanBePruned(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "return witness.state == .submitted" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "safelyPrunableTerminalIndices" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "journalMutationLimit: 2" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "protectedCrashWindowMutation" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "A protected companion witness was pruned at journal capacity" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "Capacity admission discarded protected recovery proof" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "canonicalExtrinsicHashes(" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "validateSigningFactory(" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "static func validateOutcome(" "${polkamarkt_runtime}" ||
	   [ "$(/usr/bin/grep -Fc 'try PolkamarktQuoteValidator.validateOutcome(' "${polkamarkt_runtime}")" -ne 6 ] ||
	   /usr/bin/grep -Fq "quote.outcome.caseInsensitiveCompare" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq 'case marketId = "market_id"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'case collateralIn = "collateral_in"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'case minSharesOut = "min_shares_out"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'case sharesIn = "shares_in"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'case minCollateralOut = "min_collateral_out"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'case marketIds = "market_ids"' "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq 'XCTAssertEqual(Set(arguments.keys)' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "acquireForMutableWalletAccessAsync()" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "try Task.checkCancellation()" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "lifecycleLease: lifecycleLease" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'Reject a wallet switch that completed while quote RPCs were in flight.' "${polkamarkt_runtime}")" -lt 2 ] ||
	   ! /usr/bin/grep -Fq "preTransportValidation: { [weak self] in" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "let cancellable = CancellableCallRelay()" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "withTaskCancellationHandler(" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "cancellable.set(call)" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq ".qualifiedHistoryByTransactionHashes(" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "activeHashes.count <= 100" "${polkamarkt_runtime}" ||
	   ! /usr/bin/grep -Fq "Set(returnedHashes).count == returnedHashes.count" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "interrupted_before_signed_hash" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "case signedBeforeTransport" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "enum PolkamarktPreTransportRecoveryPolicy" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "interrupted_before_transport_staging" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "retainingTransportWitness: true" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'acknowledgeDurableCanonicalTerminalWitnesses(' "${polkamarkt_runtime}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "private func acknowledgeCanonicalTerminalWitnesses(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "try persistValidated(merged)" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "acknowledgeAuthoritativelyFinalizedSubmissions(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "terminalSnapshot = try await store.all()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "try await store.acknowledgeDurableCanonicalTerminalWitnesses(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'errorClass: "interrupted_before_transport_admission"' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "var legacySubmitting = signedBeforeTransport" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "PolkamarktClaimValidator.requireTraderPayouts" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "actor PolkamarktMutationAdmissionGate" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "private var activeAdmission: (account: String, token: UUID)?" "${polkamarkt_runtime}" ||
   /usr/bin/grep -Fq "accountTokens" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "func requireMutationAdmission(account: String) throws" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "try await pendingStore.requireMutationAdmission(account: account)" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'withMutationAdmission(account:' "${polkamarkt_runtime}")" -lt 5 ] ||
   ! /usr/bin/grep -Fq "private func quoteAdmitted(" "${polkamarkt_runtime}" ||
   [ "$(/usr/bin/grep -Fc 'PolkamarktClaimValidator.requireFreshAuthorization(' "${polkamarkt_runtime}")" -lt 2 ] ||
	   ! /usr/bin/grep -Fq "testPolkamarktClaimsBindEveryAccountAndMarketBeforeSigning" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "Wrong-case runtime outcome projection was accepted" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkamarktPendingJournalUsesCrashDurableProtectedPublication" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "store.requireMutationAdmission(account: pending.account)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let admissionGate = PolkamarktMutationAdmissionGate()" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "A second account bypassed the app-wide journal gate" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "PolkamarktClaimValidator.reviewedTraderAuthorization(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "PolkamarktClaimValidator.requireFreshAuthorization(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "XCTAssertEqual(traderAuthorization.source, .reviewedPositions)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "XCTAssertEqual(creatorAuthorization.source, .selectedDetail)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkamarktPendingJournalRejectsSymbolicLink" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkamarktReconciliationMergesIntoLatestJournalWithoutRegression" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkamarktPendingJournalKeepsTerminalStateAgainstLateCallback" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPolkamarktPendingJournalRejectsStateRegression" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "EventCodingPath.extrinsicSuccess.eventName" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "EventCodingPath.extrinsicFailed.eventName" "${polkamarkt_runtime}"; then
    echo "error: Polkamarkt metadata, journal, canonical inclusion, or execution-event safety is incomplete"
    exit 1
fi

pi_last_reprobed_at="$(json_raw piIndexer.lastReprobedAtUtc "${release_probe}")"
pi_last_reprobed_epoch="$(
    /bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "${pi_last_reprobed_at}" '+%s' 2>/dev/null ||
        /usr/bin/true
)"
pi_probe_now_epoch="$(/bin/date -u '+%s')"
pi_probe_minimum_epoch="$((pi_probe_now_epoch - 86400))"
pi_probe_maximum_epoch="$((pi_probe_now_epoch + 300))"
if ! is_unsigned_integer "${pi_last_reprobed_epoch}" ||
   [ "${pi_last_reprobed_epoch:-0}" -lt "${pi_probe_minimum_epoch}" ] ||
   [ "${pi_last_reprobed_epoch:-0}" -gt "${pi_probe_maximum_epoch}" ]; then
    echo "error: PI production probe evidence is stale, future-dated, or invalid"
    exit 1
fi

pi_finalized_checkpoint="$(json_raw piIndexer.validatedContracts.0.observed.workerLatestFinalizedBlock "${release_probe}")"
pi_indexed_checkpoint="$(json_raw piIndexer.validatedContracts.0.observed.workerLatestIndexedBlock "${release_probe}")"
if [ ! -f "${release_probe}" ] ||
   [ -L "${release_probe}" ] ||
   [ "$(json_raw schemaVersion "${release_probe}")" != "1" ] ||
   [ "$(json_raw privacy.accountIdentifiersIncluded "${release_probe}")" != "false" ] ||
   [ "$(json_raw privacy.secretsIncluded "${release_probe}")" != "false" ] ||
   [ "$(json_raw privacy.signedPayloadsIncluded "${release_probe}")" != "false" ] ||
   [ "$(json_raw privacy.transactionsSubmitted "${release_probe}")" != "false" ] ||
   [ "$(json_raw piIndexer.endpoint "${release_probe}")" != "https://pi.soramitsu.io/graphql" ] ||
   [ "$(json_raw piIndexer.status "${release_probe}")" != "qualified" ] ||
   [ "$(json_raw piIndexer.readContractStatus "${release_probe}")" != "qualified" ] ||
   [ "$(json_raw piIndexer.historyCheckpointContractStatus "${release_probe}")" != "qualified" ] ||
   [ "$(json_raw piIndexer.mutationCapabilitiesStatus "${release_probe}")" != "qualified" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.operation "${release_probe}")" != "health" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.observed.serviceId "${release_probe}")" != "pi.soramitsu.io" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.observed.ecosystem "${release_probe}")" != "sora2" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.observed.chainId "${release_probe}")" != "sora:mainnet" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.observed.network "${release_probe}")" != "mainnet" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.observed.readOnly "${release_probe}")" != "true" ] ||
   [ "$(json_raw piIndexer.validatedContracts.0.observed.workerReady "${release_probe}")" != "true" ] ||
   ! is_unsigned_integer "${pi_finalized_checkpoint}" ||
   ! is_unsigned_integer "${pi_indexed_checkpoint}" ||
   [ "${pi_indexed_checkpoint}" -gt "${pi_finalized_checkpoint}" ] ||
   # This retained convenience-route observation is explicitly non-authoritative.
   # It must never select either UUID or satisfy the signed deployment boundary.
   [ "$(json_raw torii.taira.endpoint "${release_probe}")" != "https://taira.sora.org/v1/mcp" ] ||
   [ "$(json_raw torii.taira.httpStatus "${release_probe}")" != "200" ] ||
   [ -n "$(json_raw torii.taira.observedChainId "${release_probe}")" ] ||
   [ -n "$(json_raw torii.taira.observedI105Discriminant "${release_probe}")" ] ||
   [ "$(json_raw torii.taira.rolloutValidation.configuredEndpointClass "${release_probe}")" != "convenience" ] ||
   [ "$(json_raw torii.taira.rolloutValidation.canonicalPublicNodeEndpointProvided "${release_probe}")" != "false" ] ||
   [ "$(json_raw torii.taira.sumeragiTelemetry.chainIdentityDecoded "${release_probe}")" != "false" ] ||
   ! /usr/bin/grep -Fq '"qualification": "blocked until operators provide and qualify the explicit public-node /v1/mcp endpoint"' "${release_probe}" ||
   [ "$(json_raw torii.minamoto.endpoint "${release_probe}")" != "https://minamoto.sora.org/health" ] ||
   [ "$(json_raw torii.minamoto.httpStatus "${release_probe}")" != "200" ] ||
   [ "$(json_raw torii.minamoto.observedChainId "${release_probe}")" != "00000000-0000-0000-0000-000000000753" ] ||
   [ "$(json_raw torii.minamoto.observedI105Discriminant "${release_probe}")" != "753" ] ||
   [ "$(json_raw torii.minamoto.qualification "${release_probe}")" != "qualified" ]; then
    echo "error: PI chain identity or Nexus Torii qualification evidence is incomplete"
    exit 1
fi

for history_qualification in \
    blockHeightFieldDeployed \
    exactAccountBindingQualified \
    canonicalTransactionHashQualified \
    nonzeroBlockHashQualified \
    soraRpcCheckpointBindingQualified \
    boundedRpcVerificationQualified \
    partialGraphQLErrorRejectionQualified \
    pendingOverlayFallbackQualified
do
    if [ "$(json_raw "piIndexer.historyQualification.${history_qualification}" "${release_probe}")" != "true" ]; then
        echo "error: PI history release evidence remains incomplete: ${history_qualification}"
        exit 1
    fi
done

for mobile_config_qualification in \
    allRequiredFieldsDeployed \
    strictBooleanTypesQualified \
    healthBoundFetchQualified \
    capabilityChangeFailClosedQualified
do
    if [ "$(json_raw "piIndexer.mobileConfigQualification.${mobile_config_qualification}" "${release_probe}")" != "true" ]; then
        echo "error: PI mobileConfig release evidence remains incomplete: ${mobile_config_qualification}"
        exit 1
    fi
done

for account_balance_qualification in \
    typedContractDeployed \
    exactAccountBindingQualified \
    exactAssetBindingQualified \
    finalizedCheckpointBindingQualified \
    arbitraryPrecisionQualified
do
    if [ "$(json_raw "piIndexer.accountBalancesQualification.${account_balance_qualification}" "${release_probe}")" != "true" ]; then
        echo "error: PI typed account-balance qualification remains incomplete: ${account_balance_qualification}"
        exit 1
    fi
done

polkamarkt_review_key_sha256="${POLKAMARKT_EXTRINSIC_REVIEW_KEY_SHA256:-}"
if ! is_lower_hex_length "${polkamarkt_review_key_sha256}" 64 ||
   [ "${polkamarkt_review_key_sha256}" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "error: protected Polkamarkt full-extrinsic review key SHA-256 is missing or invalid"
    exit 1
fi

polkamarkt_qualified_fixture_sha256="${POLKAMARKT_EXTRINSIC_QUALIFIED_FIXTURE_SHA256:-}"
if ! is_lower_hex_length "${polkamarkt_qualified_fixture_sha256}" 64 ||
   [ "${polkamarkt_qualified_fixture_sha256}" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "error: protected qualified Polkamarkt fixture SHA-256 is missing or invalid"
    exit 1
fi

polkamarkt_node_binary="${POLKAMARKT_NODE_BINARY:-}"
polkamarkt_node_binary_sha256="${POLKAMARKT_NODE_BINARY_SHA256:-}"
case "${polkamarkt_node_binary}" in
    /*) ;;
    *)
        echo "error: reviewed Node binary for Polkamarkt replay validation is missing or non-canonical"
        exit 1
        ;;
esac
if [ ! -f "${polkamarkt_node_binary}" ] ||
   [ -L "${polkamarkt_node_binary}" ] ||
   [ ! -x "${polkamarkt_node_binary}" ] ||
   [ "$(CDPATH= cd "$(/usr/bin/dirname "${polkamarkt_node_binary}")" 2>/dev/null && /bin/pwd -P)/$(/usr/bin/basename "${polkamarkt_node_binary}")" != "${polkamarkt_node_binary}" ] ||
   ! is_lower_hex_length "${polkamarkt_node_binary_sha256}" 64 ||
   [ "${polkamarkt_node_binary_sha256}" = "0000000000000000000000000000000000000000000000000000000000000000" ] ||
   [ "$(sha256_file "${polkamarkt_node_binary}")" != "${polkamarkt_node_binary_sha256}" ]; then
    echo "error: reviewed Node binary for Polkamarkt replay validation is unverified"
    exit 1
fi

polkamarkt_android_source_root="${POLKAMARKT_ANDROID_SOURCE_ROOT:-}"
polkamarkt_android_source_revision="${POLKAMARKT_ANDROID_SOURCE_REVISION:-}"
polkamarkt_android_fixture="${POLKAMARKT_ANDROID_FIXTURE_PATH:-}"
case "${polkamarkt_android_source_root}" in
    /*) ;;
    *)
        echo "error: reviewed Android parity source root is missing or non-canonical"
        exit 1
        ;;
esac
if ! is_lower_hex_length "${polkamarkt_android_source_revision}" 40 ||
   [ "${polkamarkt_android_source_revision}" = "0000000000000000000000000000000000000000" ] ||
   [ ! -d "${polkamarkt_android_source_root}" ] ||
   [ -L "${polkamarkt_android_source_root}" ] ||
   [ "$(CDPATH= cd "${polkamarkt_android_source_root}" 2>/dev/null && /bin/pwd -P)" != "${polkamarkt_android_source_root}" ] ||
   [ "${polkamarkt_android_fixture}" != "${polkamarkt_android_source_root}/feature_polkaswap_impl/src/test/resources/polkamarkt_web_contract.json" ] ||
   [ ! -f "${polkamarkt_android_fixture}" ] ||
   [ -L "${polkamarkt_android_fixture}" ] ||
   [ "$(CDPATH= cd "$(/usr/bin/dirname "${polkamarkt_android_fixture}")" 2>/dev/null && /bin/pwd -P)/$(/usr/bin/basename "${polkamarkt_android_fixture}")" != "${polkamarkt_android_fixture}" ]; then
    echo "error: reviewed Android parity source is missing, symbolic, or non-canonical"
    exit 1
fi
polkamarkt_android_observed_revision="$(
    /usr/bin/git -C "${polkamarkt_android_source_root}" rev-parse --verify HEAD 2>/dev/null || /usr/bin/true
)"
if [ "${polkamarkt_android_observed_revision}" != "${polkamarkt_android_source_revision}" ]; then
    echo "error: reviewed Android parity source revision changed"
    exit 1
fi
polkamarkt_android_snapshot="${verification_tmp}/polkamarkt-android-runtime-v130.json"
if ! /bin/cp "${polkamarkt_android_fixture}" "${polkamarkt_android_snapshot}" ||
   ! /bin/chmod 400 "${polkamarkt_android_snapshot}" ||
   [ ! -f "${polkamarkt_android_snapshot}" ] ||
   [ -L "${polkamarkt_android_snapshot}" ] ||
   [ "$(/usr/bin/wc -c < "${polkamarkt_android_snapshot}" | /usr/bin/tr -d ' ')" -gt 16777216 ] ||
   [ "$(sha256_file "${polkamarkt_android_snapshot}")" != "${polkamarkt_qualified_fixture_sha256}" ]; then
    echo "error: reviewed Android parity fixture does not match the protected qualification"
    exit 1
fi

polkamarkt_contract_source="${polkamarkt_contract}"
polkamarkt_contract_snapshot="${verification_tmp}/polkamarkt-runtime-v130.json"
if [ ! -f "${polkamarkt_contract_source}" ] ||
   [ -L "${polkamarkt_contract_source}" ] ||
   ! /bin/cp "${polkamarkt_contract_source}" "${polkamarkt_contract_snapshot}" ||
   ! /bin/chmod 400 "${polkamarkt_contract_snapshot}" ||
   [ ! -f "${polkamarkt_contract_snapshot}" ] ||
   [ -L "${polkamarkt_contract_snapshot}" ] ||
   [ "$(/usr/bin/wc -c < "${polkamarkt_contract_snapshot}" | /usr/bin/tr -d ' ')" -gt 16777216 ] ||
   [ "$(sha256_file "${polkamarkt_contract_snapshot}")" != "${polkamarkt_qualified_fixture_sha256}" ]; then
    echo "error: qualified Polkamarkt fixture does not match its stable protected snapshot"
    exit 1
fi
polkamarkt_contract="${polkamarkt_contract_snapshot}"
if ! /usr/bin/cmp -s "${polkamarkt_android_snapshot}" "${polkamarkt_contract}"; then
    echo "error: Android and iOS Polkamarkt fixtures diverged"
    exit 1
fi

polkamarkt_qualifier="${polkamarkt_android_source_root}/scripts/qualify-polkamarkt-extrinsic-receipts.mjs"
if [ ! -f "${polkamarkt_qualifier}" ] ||
   [ -L "${polkamarkt_qualifier}" ] ||
   [ "$(CDPATH= cd "$(/usr/bin/dirname "${polkamarkt_qualifier}")" 2>/dev/null && /bin/pwd -P)/$(/usr/bin/basename "${polkamarkt_qualifier}")" != "${polkamarkt_qualifier}" ]; then
    echo "error: reviewed Android Polkamarkt replay validator is missing, symbolic, or non-canonical"
    exit 1
fi
polkamarkt_replay_stdout="${verification_tmp}/polkamarkt-qualified-replay.stdout"
polkamarkt_replay_stderr="${verification_tmp}/polkamarkt-qualified-replay.stderr"
polkamarkt_replay_expected="${verification_tmp}/polkamarkt-qualified-replay.expected"
/usr/bin/printf 'POLKAMARKT_QUALIFIED_FIXTURE_VALID\n' > "${polkamarkt_replay_expected}"
if ! "${polkamarkt_node_binary}" "${polkamarkt_qualifier}" \
    --validate-qualified "${polkamarkt_contract}" \
    > "${polkamarkt_replay_stdout}" \
    2> "${polkamarkt_replay_stderr}"; then
    echo "error: installed qualified Polkamarkt evidence failed full replay validation"
    exit 1
fi
if [ -s "${polkamarkt_replay_stderr}" ] ||
   ! /usr/bin/cmp -s "${polkamarkt_replay_expected}" "${polkamarkt_replay_stdout}"; then
    echo "error: installed qualified Polkamarkt replay produced a non-canonical result"
    exit 1
fi

polkamarkt_android_proof_revision="$(
    json_raw canonicalVectors.fullExtrinsicQualification.generationContract.platformSourceManifests.android.revision "${polkamarkt_contract}"
)"
polkamarkt_ios_proof_revision="$(
    json_raw canonicalVectors.fullExtrinsicQualification.generationContract.platformSourceManifests.ios.revision "${polkamarkt_contract}"
)"
polkamarkt_ios_observed_revision="$(
    /usr/bin/git -C "${root}" rev-parse --verify HEAD 2>/dev/null || /usr/bin/true
)"
if ! is_lower_hex_length "${polkamarkt_android_proof_revision}" 40 ||
   [ "${polkamarkt_android_proof_revision}" = "0000000000000000000000000000000000000000" ] ||
   ! is_lower_hex_length "${polkamarkt_ios_proof_revision}" 40 ||
   [ "${polkamarkt_ios_proof_revision}" = "0000000000000000000000000000000000000000" ] ||
   ! is_lower_hex_length "${polkamarkt_ios_observed_revision}" 40 ||
   [ "${polkamarkt_ios_observed_revision}" = "0000000000000000000000000000000000000000" ] ||
   ! /usr/bin/git -C "${polkamarkt_android_source_root}" cat-file -e "${polkamarkt_android_proof_revision}^{commit}" 2>/dev/null ||
   ! /usr/bin/git -C "${root}" cat-file -e "${polkamarkt_ios_proof_revision}^{commit}" 2>/dev/null; then
    echo "error: reviewed Polkamarkt producer revision is missing from a protected checkout"
    exit 1
fi
if ! /usr/bin/git -C "${polkamarkt_android_source_root}" diff --quiet \
    "${polkamarkt_android_proof_revision}" \
    "${polkamarkt_android_observed_revision}" -- \
    ':(glob)**/src/main/**' \
    ':(glob)**/src/production/**' \
    ':(glob)**/src/release/**' \
    ':(glob)**/*.gradle' \
    ':(glob)**/*.gradle.kts' \
    'buildSrc/**' \
    'gradle/**' \
    'gradle.properties' \
    'settings.gradle' \
    'settings.gradle.kts'; then
    echo "error: Android production implementation drifted from the reviewed Polkamarkt proof"
    exit 1
fi
if ! /usr/bin/git -C "${root}" diff --quiet \
    "${polkamarkt_ios_proof_revision}" \
    "${polkamarkt_ios_observed_revision}" -- \
    ':(glob)SoraPassport/**/*.swift' \
    ':(glob)SoraPassport/**/*.[chm]' \
    ':(glob)SoraPassport/**/*.[ch]pp' \
    ':(glob)SoraPassport/**/*.mm' \
    ':(glob)VendorPackages/**/Sources/**' \
    'Vendor/IrohaSwift/**' \
    'Vendor/NoritoBridge.xcframework/**' \
    'SoraPassport.xcodeproj/project.pbxproj' \
    'SoraPassport.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved' \
    'SoraPassport/Configs/**'; then
    echo "error: iOS production implementation drifted from the reviewed Polkamarkt proof"
    exit 1
fi

if [ "$(json_raw format "${polkamarkt_contract}")" != "sora-mobile-polkamarkt-contract-v2" ] ||
   [ "$(json_raw webReference.branch "${polkamarkt_contract}")" != "ui-updates" ] ||
   [ "$(json_raw webReference.inspectedRevision "${polkamarkt_contract}")" != "893783ba6a19c33043eb5dabe42d949c14d0f257" ] ||
   [ "$(json_raw webReference.commitTreeObject "${polkamarkt_contract}")" != "e391982c0921dea5278e919a7558b7a6a2afc0d4" ] ||
   [ "$(json_raw webReference.polkamarktTreeObject "${polkamarkt_contract}")" != "57f0fe7623f2b93b34faecfc66d6c5da96d54e1b" ] ||
   [ "$(json_raw webReference.commitSignatureStatus "${polkamarkt_contract}")" != "verified" ] ||
   [ "$(json_raw webReference.sourceFiles "${polkamarkt_contract}")" != "22" ] ||
   [ "$(/usr/bin/plutil -extract webReference.sourceBlobObjects raw "${polkamarkt_contract}" 2>/dev/null | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')" != "22" ] ||
   [ "$(json_raw webReference.polkamarktContractPresentAtInspectedRevision "${polkamarkt_contract}")" != "true" ] ||
   [ "$(json_raw runtime.marketIdScaleType "${polkamarkt_contract}")" != "u32" ] ||
   [ "$(json_raw runtime.marketIdMaximum "${polkamarkt_contract}")" != "4294967295" ] ||
   [ "$(json_raw runtime.closeBlockScaleType "${polkamarkt_contract}")" != "u32" ] ||
   [ "$(json_raw runtime.closeBlockMaximum "${polkamarkt_contract}")" != "4294967295" ] ||
   [ "$(json_raw canonicalBehavior.defaultSlippageBps "${polkamarkt_contract}")" != "50" ] ||
   [ "$(json_raw canonicalBehavior.maxBatchClaims "${polkamarkt_contract}")" != "24" ] ||
   [ "$(json_raw canonicalVectors.derivationSources.minimumOutput "${polkamarkt_contract}")" != "lib/amounts.ts" ] ||
   [ "$(json_raw canonicalVectors.derivationSources.runtimeCalls "${polkamarkt_contract}")" != "services/runtimeMarkets.ts" ] ||
   [ "$(json_raw canonicalVectors.derivationSources.scaleArguments "${polkamarkt_contract}")" != "../sora2-network/pallets/polkamarkt/src/lib.rs" ] ||
   [ "$(json_raw canonicalVectors.derivationSources.runtimeRevision "${polkamarkt_contract}")" != "411dcdb70c5c00b21482a44d02334840d5f338c6" ] ||
   [ "$(json_raw canonicalVectors.minimumOutput "${polkamarkt_contract}")" != "4" ] ||
   [ "$(json_raw canonicalVectors.runtimeCalls "${polkamarkt_contract}")" != "5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.receiptSchema "${polkamarkt_contract}")" != "sora-mobile-polkamarkt-full-extrinsic-receipt-v1" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredMetadataSha256 "${polkamarkt_contract}")" != "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredGenesisHash "${polkamarkt_contract}")" != "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredSpecVersion "${polkamarkt_contract}")" != "130" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredTransactionVersion "${polkamarkt_contract}")" != "130" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.metadataIndicesMustBeResolvedDynamically "${polkamarkt_contract}")" != "true" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredVectorOrder "${polkamarkt_contract}")" != "5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredVectorOrder.0 "${polkamarkt_contract}")" != "buy" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredVectorOrder.1 "${polkamarkt_contract}")" != "sell" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredVectorOrder.2 "${polkamarkt_contract}")" != "claim_market" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredVectorOrder.3 "${polkamarkt_contract}")" != "claim_markets" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.requiredVectorOrder.4 "${polkamarkt_contract}")" != "claim_creator_fees" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.candidateReceiptSchema "${polkamarkt_contract}")" != "sora-mobile-polkamarkt-platform-extrinsic-receipt-v1" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.independentReviewSchema "${polkamarkt_contract}")" != "sora-mobile-polkamarkt-extrinsic-review-v1" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.merger "${polkamarkt_contract}")" != "scripts/qualify-polkamarkt-extrinsic-receipts.mjs" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.runtimeMetadata.sha256 "${polkamarkt_contract}")" != "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.runtimeMetadata.palletAndCallIndices "${polkamarkt_contract}")" != "resolve-from-this-metadata-never-hardcode" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.cryptoType "${polkamarkt_contract}")" != "sr25519" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.accountIdSource "${polkamarkt_contract}")" != "reviewed-receipt" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.nonceSource "${polkamarkt_contract}")" != "reviewed-receipt" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.mortalEraSource "${polkamarkt_contract}")" != "reviewed-receipt" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.finalizedBlockHashSource "${polkamarkt_contract}")" != "reviewed-receipt" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.tipSource "${polkamarkt_contract}")" != "reviewed-receipt" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.signaturePayloadHashingThresholdBytes "${polkamarkt_contract}")" != "256" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.signaturePayloadHashingRule "${polkamarkt_contract}")" != "blake2b-256-only-when-raw-payload-length-is-greater-than-256" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.privateSigningMaterialPermittedInFixture "${polkamarkt_contract}")" != "false" ] ||
   ! is_lower_hex_length "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.qualificationAccountIdHex "${polkamarkt_contract}")" 64 ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.signingContext.qualificationAccountIdHex "${polkamarkt_contract}")" = "0000000000000000000000000000000000000000000000000000000000000000" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.generationContract.cryptographicProofSchema "${polkamarkt_contract}")" != "sora-mobile-polkamarkt-native-cryptographic-proof-v1" ] ||
   ! json_array_equals canonicalVectors.fullExtrinsicQualification.generationContract.requiredCryptographicProofFields "${polkamarkt_contract}" \
       format platform candidateBindingSha256 sourceRevision sourceTreeSha256 generatorSha256 verifierRevision verifierBinarySha256 metadataSha256 runtimeRevision genesisHash specVersion transactionVersion signingContextSha256 vectorsSha256 claims verifiedAtEpochSeconds publicKeySpkiDerHex signatureHex ||
   ! json_array_equals canonicalVectors.fullExtrinsicQualification.generationContract.requiredCryptographicProofClaims "${polkamarkt_contract}" \
       candidate-identity-bound \
       sr25519-signatures-verified-over-reconstructed-signing-prehashes \
       signed-extrinsics-decoded-through-pinned-live-metadata \
       decoded-projections-match-canonical-runtime-call-vectors \
       signed-extrinsic-hashes-recomputed \
       non-production-qualification-account-used \
       private-signing-material-absent-from-receipts ||
   ! json_array_equals canonicalVectors.fullExtrinsicQualification.generationContract.requiredSharedVectorFields "${polkamarkt_contract}" \
       id call arguments metadataPalletIndex metadataCallIndex scaleArgumentsHex fullCallHex rawSigningPayloadHex signingPrehashHex signingPrehashRule decodedProjection decodedProjectionSha256 ||
   ! json_array_equals canonicalVectors.fullExtrinsicQualification.generationContract.requiredPlatformVectorFields "${polkamarkt_contract}" \
       id signerPublicKeyHex signatureHex signedExtrinsicHex extrinsicHashHex signingPrehashHex decodedProjection decodedProjectionSha256 ||
   ! json_array_equals canonicalVectors.fullExtrinsicQualification.generationContract.parityRules "${polkamarkt_contract}" \
       reference-android-ios-full-call-bytes-equal \
       reference-android-ios-signing-prehash-equal \
       reference-android-ios-decoded-projection-sha256-equal \
       each-platform-reviewed-cryptographic-proof-signature-verifies \
       each-proof-binds-source-metadata-context-vectors-and-signed-extrinsics \
       each-proof-attests-sr25519-verification-and-live-metadata-round-trip \
       sr25519-signature-bytes-may-differ-but-must-verify ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedWebAndRuntimeReceiptQualified "${polkamarkt_contract}")" != "true" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.format "${polkamarkt_contract}")" != "sora-mobile-polkamarkt-full-extrinsic-receipt-v1" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.metadataSha256 "${polkamarkt_contract}")" != "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.genesisHash "${polkamarkt_contract}")" != "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.sharedVectors "${polkamarkt_contract}")" != "5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.platforms.reference.vectors "${polkamarkt_contract}")" != "5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.platforms.android.vectors "${polkamarkt_contract}")" != "5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.platforms.ios.vectors "${polkamarkt_contract}")" != "5" ] ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.review.publicKeySha256 "${polkamarkt_contract}")" != "${polkamarkt_review_key_sha256}" ] ||
   ! is_lower_hex_length "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.review.receiptSha256 "${polkamarkt_contract}")" 64 ||
   ! is_lower_hex_length "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.review.signatureReceiptSha256 "${polkamarkt_contract}")" 64 ||
   ! is_lower_hex_length "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.platforms.reference.candidateReceiptSha256 "${polkamarkt_contract}")" 64 ||
   ! is_lower_hex_length "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.platforms.android.candidateReceiptSha256 "${polkamarkt_contract}")" 64 ||
   ! is_lower_hex_length "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.platforms.ios.candidateReceiptSha256 "${polkamarkt_contract}")" 64 ||
   [ "$(json_raw canonicalVectors.fullExtrinsicQualification.reviewedReceipt.parityQualified "${polkamarkt_contract}")" != "true" ] ||
   [ -n "$(json_raw canonicalVectors.fullExtrinsicQualification.blocker "${polkamarkt_contract}")" ] ||
   [ "$(json_raw mobileClaimConfirmation.requiresExplicitConfirmation "${polkamarkt_contract}")" != "true" ] ||
   ! /usr/bin/grep -Fq "static let requiresExplicitConfirmation = true" "${polkamarkt_runtime}" ||
   [ "$(json_raw mobileClaimConfirmation.requiredReviewedFields.0 "${polkamarkt_contract}")" != "accountId" ] ||
   [ "$(json_raw mobileClaimConfirmation.requiredReviewedFields.1 "${polkamarkt_contract}")" != "source" ] ||
   [ "$(json_raw mobileClaimConfirmation.requiredReviewedFields.2 "${polkamarkt_contract}")" != "marketIds" ] ||
   [ "$(json_raw mobileClaimConfirmation.requiredReviewedFields.3 "${polkamarkt_contract}")" != "finalizedBlockHash" ] ||
   [ "$(json_raw mobileClaimConfirmation.requiredReviewedFields.4 "${polkamarkt_contract}")" != "claims" ] ||
   [ "$(json_raw mobileClaimConfirmation.freshChecksBeforeSigning.0 "${polkamarkt_contract}")" != "account" ] ||
   [ "$(json_raw mobileClaimConfirmation.freshChecksBeforeSigning.1 "${polkamarkt_contract}")" != "featureFlags" ] ||
   [ "$(json_raw mobileClaimConfirmation.freshChecksBeforeSigning.2 "${polkamarkt_contract}")" != "runtimeMetadata" ] ||
   [ "$(json_raw mobileClaimConfirmation.freshChecksBeforeSigning.3 "${polkamarkt_contract}")" != "claimValues" ] ||
   [ "$(json_raw mobileClaimConfirmation.freshChecksBeforeSigning.4 "${polkamarkt_contract}")" != "xorFee" ] ||
   [ "$(json_raw mobileClaimConfirmation.freshChecksBeforeSigning.5 "${polkamarkt_contract}")" != "xorBalance" ] ||
   [ "$(json_raw mobileClaimConfirmation.copy.title "${polkamarkt_contract}")" != "Confirm claim" ] ||
   [ "$(json_raw mobileClaimConfirmation.copy.batchTitle "${polkamarkt_contract}")" != "Confirm %1\$d trader payouts" ] ||
   [ "$(json_raw mobileClaimConfirmation.copy.body "${polkamarkt_contract}")" != "Verify these finalized runtime values before signing." ] ||
   [ "$(json_raw mobileClaimConfirmation.copy.feeNotice "${polkamarkt_contract}")" != "The exact XOR network fee and balance will be rechecked before signing." ] ||
   ! /usr/bin/grep -Fq "fixture[\"mobileClaimConfirmation\"]" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq '"boardOpensBeforeDetail": true' "${polkamarkt_contract}" ||
   ! /usr/bin/grep -Fq '"excludedMobileModes"' "${polkamarkt_contract}"; then
    echo "error: canonical Polkamarkt web behavior or reviewed runtime/extrinsic parity is incomplete"
    exit 1
fi

migration_post_export_admission_deferred=false
if [ "${migration_candidate_archive_active}" = "true" ]; then
    migration_post_export_admission_deferred=true
    migration_qualification_contract_hash="$(
        qualification_contract_sha256
    )"
    modernization_test_count="$(
        /usr/bin/grep -Ec '^[[:space:]]+func test' "${modernization_tests}"
    )"
    recovery_gate_test_count="$(
        /usr/bin/grep -Ec '^[[:space:]]+func test' "${recovery_gate_tests}"
    )"
    recovery_export_test_count="$(
        /usr/bin/grep -Ec '^[[:space:]]+func test' "${recovery_export_tests}"
    )"
    retained_device_evidence_test_count="$(
        /usr/bin/grep -Ec '^[[:space:]]+func test' "${migration_evidence_tests}"
    )"
    if [ "${modernization_test_count}" != "200" ] ||
       [ "${recovery_gate_test_count}" != "11" ] ||
       [ "${recovery_export_test_count}" != "12" ] ||
       [ "${retained_device_evidence_test_count}" != "3" ] ||
       [ "$((modernization_test_count + recovery_gate_test_count + recovery_export_test_count + retained_device_evidence_test_count))" -ne 226 ] ||
       ! verify_qualification_contract_unchanged; then
        echo "error: observed-only candidate archive migration source contract is incomplete or unstable"
        exit 1
    fi
    /usr/bin/printf '%s\n' \
        'warning: migration and IPA-bound post-export admission are deferred for this observed-only candidate archive; dependency, signing, runtime, and source gates remain active' >&2
else
if [ ! -f "${migration_qualification}" ] ||
   [ -L "${migration_qualification}" ] ||
   [ ! -f "${migration_qualification_validator}" ] ||
   [ -L "${migration_qualification_validator}" ] ||
   [ ! -f "${migration_qualification_json_validator}" ] ||
   [ -L "${migration_qualification_json_validator}" ]; then
    echo "error: retained iOS wallet migration matrix is not qualified"
    exit 1
fi

migration_qualification_original="${migration_qualification}"
migration_authentication="$(
    /bin/sh "${migration_qualification_validator}" --verify-qualified 2>/dev/null
)" || {
    echo "error: retained iOS wallet migration evidence is not independently authenticated"
    exit 1
}
case "${migration_authentication}" in
    receiptSha256=*)
        migration_authenticated_sha256="${migration_authentication#receiptSha256=}"
        ;;
    *)
        echo "error: retained iOS wallet migration authenticator returned an invalid result"
        exit 1
        ;;
esac
if ! is_lower_hex_length "${migration_authenticated_sha256}" 64 ||
   [ "$(/usr/bin/printf '%s\n' "${migration_authentication}" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" != "1" ]; then
    echo "error: retained iOS wallet migration authenticator result is malformed"
    exit 1
fi
migration_qualification_snapshot="${verification_tmp}/ios-migration-qualification.json"
/bin/cp -p "${migration_qualification_original}" "${migration_qualification_snapshot}"
if [ ! -f "${migration_qualification_snapshot}" ] ||
   [ -L "${migration_qualification_snapshot}" ] ||
   [ ! -f "${migration_qualification_original}" ] ||
   [ -L "${migration_qualification_original}" ] ||
   [ "$(sha256_file "${migration_qualification_snapshot}")" != "${migration_authenticated_sha256}" ] ||
   [ "$(sha256_file "${migration_qualification_original}")" != "${migration_authenticated_sha256}" ]; then
    echo "error: retained iOS wallet migration receipt changed after authentication"
    exit 1
fi
migration_qualification="${migration_qualification_snapshot}"

require_exact_json_root_keys \
    "retained iOS wallet migration receipt" \
    "${migration_qualification}" \
    schemaVersion \
    contractId \
    platform \
    status \
    runId \
    runChallengeSha256 \
    rawInputSetSha256 \
    qualificationSequenceNumber \
    sourceRevision \
    qualifiedAtEpochSeconds \
    reviewedAtEpochSeconds \
    trustRootSha256 \
    evidenceManifestSha256 \
    collectionReceiptSha256 \
    deviceEvidenceProducerKeyId \
    independentReviewerKeyId \
    identity \
    privacy \
    sourceModelVersions \
    targetModelVersion \
    retainedCoreDataModelCount \
    retainedCoreDataCohortCount \
    singleAccountCohortCount \
    multiAccountCohortCount \
    successfulSecretSourceCohortCount \
    secretFailureCohortCount \
    currentSchemaSafetySnapshotCohortCount \
    interruptionPointCohortCount \
    retainedReleaseSnapshotCount \
    retainedReleaseSnapshotManifestSha256 \
    executedWalletModernizationTestCount \
    executedRecoveryCapabilityGateTestCount \
    executedRecoveryExporterTestCount \
    executedRetainedDeviceEvidenceTestCount \
    testFailureCount \
    testUnexpectedFailureCount \
    testSkippedCount \
    testExpectedFailureCount \
    testResultBundleSha256 \
    keychainEvidenceSha256 \
    deviceExecutionEvidenceSha256 \
    zeroLostAccounts \
    accountCountParity \
    selectedWalletParity \
    preferencesParity \
    keychainIdentityUnchanged \
    keychainAccessibilityUnchanged \
    legacyStoresRetainedForDualRead \
    sora2SigningParity \
    coreDataModelSha256 \
    qualificationContractSha256 \
    qualificationChecks \
    blockingReasons
require_exact_json_object_keys \
    "retained iOS wallet migration release identity" \
    identity \
    "${migration_qualification}" \
    productionIpaSha256 \
    installedAppRawTreeSha256 \
    installedAppRawTreeRecordByteCount \
    installedExecutableSha256 \
    installedExecutableByteCount \
    productionCanonicalProjectionSha256 \
    installedCanonicalProjectionSha256 \
    canonicalProjectionReceiptSha256 \
    canonicalProjectorSourceSha256 \
    deviceClasses \
    operatingSystemBuilds
require_exact_json_object_keys \
    "retained iOS wallet migration privacy contract" \
    privacy \
    "${migration_qualification}" \
    aggregateOnly \
    accountIdentifiersIncluded \
    addressesIncluded \
    deviceIdentifiersIncluded \
    secretsIncluded \
    phrasesOrSeedsIncluded \
    privateKeysIncluded \
    publicKeysIncluded \
    rawKeychainValuesIncluded \
    signedPayloadsIncluded \
    rawSignedPayloadsIncluded \
    perWalletRecordsIncluded
require_exact_json_object_keys \
    "retained iOS Core Data model identities" \
    coreDataModelSha256 \
    "${migration_qualification}" \
    version1 \
    version2
require_exact_json_object_keys \
    "retained iOS wallet migration checks" \
    qualificationChecks \
    "${migration_qualification}" \
    allRetainedCoreDataSnapshotsQualified \
    backupManifestIntegrityQualified \
    currentSchemaSafetySnapshotQualified \
    dualReadQualified \
    explicitRemovalQualified \
    interruptedMigrationQualified \
    keychainAccessibilityQualified \
    legacyContinuationQualified \
    legacyEmptySuffixQualified \
    legacySecretQualified \
    lifecycleConcurrencyQualified \
    lowStorageQualified \
    missingOrCorruptSecretQualified \
    multiAccountQualified \
    newWalletCommitJournalQualified \
    pendingMutationDeletionPreflightQualified \
    rawSeedQualified \
    retainedFifteenWordMnemonicQualified \
    recoveryArchiveExportQualified \
    reinstallUpgradeQualified \
    rollbackQualified \
    selectedWalletLegacyMetadataQualified \
    selectionGraphAtomicityQualified \
    singleAccountQualified \
    twelveWordMnemonicQualified \
    twentyFourWordMnemonicQualified \
    walSidecarQualified \
    watchOnlyQualified

migration_qualification_contract_hash="$(
    qualification_contract_sha256
)"
modernization_test_count="$(
    /usr/bin/grep -Ec '^[[:space:]]+func test' "${modernization_tests}"
)"
recovery_gate_test_count="$(
    /usr/bin/grep -Ec '^[[:space:]]+func test' "${recovery_gate_tests}"
)"
recovery_export_test_count="$(
    /usr/bin/grep -Ec '^[[:space:]]+func test' "${recovery_export_tests}"
)"
retained_device_evidence_test_count="$(
    /usr/bin/grep -Ec '^[[:space:]]+func test' "${migration_evidence_tests}"
)"
if [ "${modernization_test_count}" != "200" ]; then
    echo "error: WalletModernizationTests source must contain exactly 200 test methods"
    exit 1
fi
if [ "${recovery_gate_test_count}" != "11" ] ||
   [ "${recovery_export_test_count}" != "12" ] ||
   [ "${retained_device_evidence_test_count}" != "3" ] ||
   [ "$((modernization_test_count + recovery_gate_test_count + recovery_export_test_count + retained_device_evidence_test_count))" -ne 226 ]; then
    echo "error: retained iOS migration evidence source must contain the exact 226-test inventory"
    exit 1
fi
qualified_at_epoch_seconds="$(
    json_raw qualifiedAtEpochSeconds "${migration_qualification}"
)"
retained_release_snapshot_count="$(
    json_raw retainedReleaseSnapshotCount "${migration_qualification}"
)"

if ! is_unsigned_integer "${qualified_at_epoch_seconds}" ||
   [ "${qualified_at_epoch_seconds}" -le 0 ] ||
   [ "${qualified_at_epoch_seconds}" -gt "$(/bin/date +%s)" ] ||
   ! is_unsigned_integer "${retained_release_snapshot_count}" ||
   [ "${retained_release_snapshot_count}" -le 0 ] ||
   [ "$(json_raw schemaVersion "${migration_qualification}")" != "8" ] ||
   [ "$(json_raw contractId "${migration_qualification}")" != "sora-ios-wallet-migration-qualification-v8" ] ||
   [ "$(json_raw platform "${migration_qualification}")" != "ios" ] ||
   [ "$(json_raw status "${migration_qualification}")" != "qualified" ] ||
   [ "$(json_raw blockingReasons "${migration_qualification}")" != "0" ] ||
   [ "$(json_raw privacy.aggregateOnly "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw privacy.accountIdentifiersIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.addressesIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.deviceIdentifiersIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.secretsIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.phrasesOrSeedsIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.privateKeysIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.publicKeysIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.rawKeychainValuesIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.signedPayloadsIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.rawSignedPayloadsIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(json_raw privacy.perWalletRecordsIncluded "${migration_qualification}")" != "false" ] ||
   [ "$(/usr/bin/plutil -extract sourceModelVersions raw "${migration_qualification}" 2>/dev/null || /usr/bin/true)" != "2" ] ||
   [ "$(json_raw sourceModelVersions.0 "${migration_qualification}")" != "UserDataModel" ] ||
   [ "$(json_raw sourceModelVersions.1 "${migration_qualification}")" != "UserDataModel 2" ] ||
   [ "$(json_raw targetModelVersion "${migration_qualification}")" != "UserDataModel 2" ] ||
   [ "$(json_raw retainedCoreDataModelCount "${migration_qualification}")" != "2" ] ||
   [ "$(json_raw retainedCoreDataCohortCount "${migration_qualification}")" != "4" ] ||
   [ "$(json_raw singleAccountCohortCount "${migration_qualification}")" != "2" ] ||
   [ "$(json_raw multiAccountCohortCount "${migration_qualification}")" != "2" ] ||
   [ "$(json_raw successfulSecretSourceCohortCount "${migration_qualification}")" != "6" ] ||
   [ "$(json_raw secretFailureCohortCount "${migration_qualification}")" != "2" ] ||
   [ "$(json_raw currentSchemaSafetySnapshotCohortCount "${migration_qualification}")" != "2" ] ||
   [ "$(json_raw interruptionPointCohortCount "${migration_qualification}")" != "5" ] ||
   [ "$(json_raw executedWalletModernizationTestCount "${migration_qualification}")" != "${modernization_test_count}" ] ||
   [ "$(json_raw executedRecoveryCapabilityGateTestCount "${migration_qualification}")" != "${recovery_gate_test_count}" ] ||
   [ "$(json_raw executedRecoveryExporterTestCount "${migration_qualification}")" != "${recovery_export_test_count}" ] ||
   [ "$(json_raw executedRetainedDeviceEvidenceTestCount "${migration_qualification}")" != "${retained_device_evidence_test_count}" ] ||
   [ "$(json_raw testFailureCount "${migration_qualification}")" != "0" ] ||
   [ "$(json_raw testUnexpectedFailureCount "${migration_qualification}")" != "0" ] ||
   [ "$(json_raw testSkippedCount "${migration_qualification}")" != "0" ] ||
   [ "$(json_raw testExpectedFailureCount "${migration_qualification}")" != "0" ] ||
   [ "$(json_raw zeroLostAccounts "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw accountCountParity "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw selectedWalletParity "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw preferencesParity "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw keychainIdentityUnchanged "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw keychainAccessibilityUnchanged "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw legacyStoresRetainedForDualRead "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw sora2SigningParity "${migration_qualification}")" != "true" ] ||
   [ "$(json_raw coreDataModelSha256.version1 "${migration_qualification}")" != "$(sha256_file "${user_data_model_v1}")" ] ||
   [ "$(json_raw coreDataModelSha256.version2 "${migration_qualification}")" != "$(sha256_file "${user_data_model_v2}")" ] ||
   ! is_lower_hex_length "$(json_raw retainedReleaseSnapshotManifestSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw testResultBundleSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw keychainEvidenceSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw deviceExecutionEvidenceSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw collectionReceiptSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw rawInputSetSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw runChallengeSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw identity.productionIpaSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw identity.installedAppRawTreeSha256 "${migration_qualification}")" 64 ||
   ! is_unsigned_integer "$(json_raw identity.installedAppRawTreeRecordByteCount "${migration_qualification}")" ||
   [ "$(json_raw identity.installedAppRawTreeRecordByteCount "${migration_qualification}")" -le 0 ] ||
   ! is_lower_hex_length "$(json_raw identity.installedExecutableSha256 "${migration_qualification}")" 64 ||
   ! is_unsigned_integer "$(json_raw identity.installedExecutableByteCount "${migration_qualification}")" ||
   [ "$(json_raw identity.installedExecutableByteCount "${migration_qualification}")" -le 0 ] ||
   ! is_lower_hex_length "$(json_raw identity.productionCanonicalProjectionSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw identity.installedCanonicalProjectionSha256 "${migration_qualification}")" 64 ||
   [ "$(json_raw identity.productionCanonicalProjectionSha256 "${migration_qualification}")" != "$(json_raw identity.installedCanonicalProjectionSha256 "${migration_qualification}")" ] ||
   ! is_lower_hex_length "$(json_raw identity.canonicalProjectionReceiptSha256 "${migration_qualification}")" 64 ||
   ! is_lower_hex_length "$(json_raw identity.canonicalProjectorSourceSha256 "${migration_qualification}")" 64 ||
   [ "$(json_raw qualificationContractSha256 "${migration_qualification}")" != "${migration_qualification_contract_hash}" ]; then
    echo "error: retained iOS wallet migration matrix is incomplete, stale, or not source-bound"
    exit 1
fi

for forbidden_receipt_field in \
    accounts \
    addresses \
    notes \
    perWalletRecords \
    phrases \
    privateKeys \
    rawSignedPayloads \
    seeds \
    signatures \
    signedPayloads \
    wallets
do
    if [ -n "$(json_raw "${forbidden_receipt_field}" "${migration_qualification}")" ]; then
        echo "error: retained iOS wallet migration receipt contains forbidden non-aggregate field: ${forbidden_receipt_field}"
        exit 1
    fi
done

for migration_check in \
    allRetainedCoreDataSnapshotsQualified \
    backupManifestIntegrityQualified \
    currentSchemaSafetySnapshotQualified \
    dualReadQualified \
    explicitRemovalQualified \
    interruptedMigrationQualified \
    keychainAccessibilityQualified \
    legacyContinuationQualified \
    legacyEmptySuffixQualified \
    legacySecretQualified \
    lifecycleConcurrencyQualified \
    lowStorageQualified \
    missingOrCorruptSecretQualified \
    multiAccountQualified \
    newWalletCommitJournalQualified \
    pendingMutationDeletionPreflightQualified \
    rawSeedQualified \
    retainedFifteenWordMnemonicQualified \
    recoveryArchiveExportQualified \
    reinstallUpgradeQualified \
    rollbackQualified \
    selectedWalletLegacyMetadataQualified \
    selectionGraphAtomicityQualified \
    singleAccountQualified \
    twelveWordMnemonicQualified \
    twentyFourWordMnemonicQualified \
    walSidecarQualified \
    watchOnlyQualified
do
    if [ "$(json_raw "qualificationChecks.${migration_check}" "${migration_qualification}")" != "true" ]; then
        echo "error: retained iOS wallet migration matrix remains incomplete: ${migration_check}"
        exit 1
    fi
done

if ! verify_qualification_contract_unchanged ||
   [ ! -f "${migration_qualification_original}" ] ||
   [ -L "${migration_qualification_original}" ] ||
   [ "$(sha256_file "${migration_qualification}")" != "${migration_authenticated_sha256}" ] ||
   [ "$(sha256_file "${migration_qualification_original}")" != "${migration_authenticated_sha256}" ]; then
    echo "error: retained iOS wallet migration receipt or source contract changed during aggregate verification"
    exit 1
fi
fi

if [ "${migration_post_export_admission_deferred}" = "true" ]; then
    /usr/bin/printf '%s\n' \
        'warning: funded-canary and rollout receipt admission require the exported IPA and remain deferred until post-export qualification' >&2
else
for funded_canary_source in \
    "${taira_canary}" \
    "${minamoto_canary}" \
    "${funded_canary_trust}" \
    "${funded_canary_documentation}" \
    "${funded_canary_validator}" \
    "${funded_canary_json_validator}"
do
    if [ ! -f "${funded_canary_source}" ] || [ -L "${funded_canary_source}" ]; then
        echo "error: funded Nexus canary contract input is missing or symbolic: ${funded_canary_source}"
        exit 1
    fi
done
/bin/sh "${funded_canary_validator}" --lint-templates >/dev/null || {
    echo "error: funded Nexus canary templates or trust-root contract are not exact and fail-closed"
    exit 1
}
if [ "${FUNDED_NEXUS_CANARY_POST_EXPORT_ADMISSION_REQUIRED:-}" != "true" ] ||
   [ "${FUNDED_NEXUS_CANARY_ADMISSION_STATUS:-}" != "blocked" ] ||
   [ "${FUNDED_NEXUS_CANARY_TRUST_STATUS:-}" != "blocked" ] ||
   [ "${FUNDED_NEXUS_CANARY_TRUST_ROOT_SHA256:-}" != "REQUIRED_AFTER_INDEPENDENT_REVIEW" ] ||
   [ "${FUNDED_NEXUS_CANARY_ADMISSION_RECEIPT_SHA256:-}" != "REQUIRED_AFTER_INDEPENDENT_REVIEW" ] ||
   [ "${FUNDED_TAIRA_CANARY_RECEIPT_SHA256:-}" != "REQUIRED_AFTER_INDEPENDENT_REVIEW" ] ||
   [ "${FUNDED_MINAMOTO_CANARY_RECEIPT_SHA256:-}" != "REQUIRED_AFTER_INDEPENDENT_REVIEW" ]; then
    echo "error: funded Nexus post-export admission configuration is absent or silently promoted"
    exit 1
fi
if ! /usr/bin/grep -Fq "one-use append-only" "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq "actual regular non-symlink signed IPA" "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq "independent reviewer" "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq "not an opaque hash assertion" "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq "trusted first height must not exceed" "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq 'sora-pi-production-capability-probe-v3' "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq 'PI v2 receipts are wire-incompatible with v3 and are rejected' "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq 'mobileConfigHealthBound' "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq 'historyBlockHeightContractDeployed' "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq 'protected producer compatibility remains a hard release blocker' "${funded_canary_documentation}" ||
   ! /usr/bin/grep -Fq "never contains an account, address, transaction hash" "${funded_canary_documentation}"; then
    echo "error: funded Nexus canary operational contract is incomplete"
    exit 1
fi
for funded_canary_contract_marker in \
    '"committedBlockHeight"' \
    '"attestationChallengeSha256"' \
    '"attestationChallengeBindingSha256"' \
    '"attestationEvidenceSha256"' \
    '"bundleEvidenceSha256"' \
    '"reviewedVerifierArtifactSha256"' \
    '"finalityTrustManifestReceiptSha256"' \
    '"networkTrustContextReceiptSha256"' \
    '"sora-ios-nexus-finality-native-canary-v1"' \
    '"observedExportInventorySha256"' \
    '"attestationNoritoRoundTripKatSha256"' \
    '"finalizedProjectionQualified"' \
    '"liveBoundedSequentialStatefulSuccessorChainVerified"'
do
    if ! /usr/bin/grep -Fq "${funded_canary_contract_marker}" "${funded_canary_json_validator}"; then
        echo "error: funded Nexus canonical finality binding is absent: ${funded_canary_contract_marker}"
        exit 1
    fi
done
for funded_canary_cross_stage_marker in \
    'attested finality height does not cover the transaction' \
    'trusted first finality height exceeds the attested finalized checkpoint' \
    'sora-ios-funded-nexus-finality-challenge-binding-v1' \
    'funded canary admission was recorded before one of its bound network receipts' \
    'finality trust evidence was reviewed after funded execution began' \
    'low-value policy was reviewed after the dual-controlled approval' \
    'Taira and Minamoto receipts must use distinct receipt, candidate, finality, run, approval, and challenge evidence'
do
    if ! /usr/bin/grep -Fq "${funded_canary_cross_stage_marker}" "${funded_canary_json_validator}"; then
        echo "error: funded Nexus cross-evidence admission invariant is absent: ${funded_canary_cross_stage_marker}"
        exit 1
    fi
done
for funded_canary_full_path_marker in \
    'verify_network taira "${taira_snapshot}" "${taira_template_snapshot}"' \
    'verify_network minamoto "${minamoto_snapshot}" "${minamoto_template_snapshot}"'
do
    if ! /usr/bin/grep -Fq "${funded_canary_full_path_marker}" "${funded_canary_validator}"; then
        echo "error: funded Nexus rollout admission bypasses full network qualification"
        exit 1
    fi
done
for funded_canary_harness_marker in \
    'def build_funded_evidence(' \
    'missing-full-funded-evidence' \
    'preclaimed-funded-readiness' \
    'funded-finality-below-commit' \
    'funded-trusted-first-height-above-finality' \
    'funded-missing-live-successor-proof' \
    'funded-invalid-challenge-binding' \
    'funded-invalid-finality-native-abi' \
    'funded-retroactive-finality-trust' \
    'funded-retroactive-policy-review' \
    'funded-reused-cross-network-run'
do
    if ! /usr/bin/grep -Fq "${funded_canary_harness_marker}" "${rollout_regression_harness}"; then
        echo "error: funded Nexus hermetic full-path regression is absent: ${funded_canary_harness_marker}"
        exit 1
    fi
done
fi

for nexus_chain_admission_marker in \
    "func requireCurrentChainMutationAdmission() throws" \
    "transactions.allSatisfy(Self.hasCurrentChainIdentity)" \
    "pendingStore.requireCurrentChainMutationAdmission()"
do
    if ! /usr/bin/grep -Fq "${nexus_chain_admission_marker}" "${nexus_service}"; then
        echo "error: Nexus current-chain mutation admission marker is absent: ${nexus_chain_admission_marker}"
        exit 1
    fi
done
[ "$(/usr/bin/grep -Fc "pendingStore.requireCurrentChainMutationAdmission()" "${nexus_service}")" -ge 4 ] || {
    echo "error: Nexus prepare/send/pre-sign/pre-transport chain admission is incomplete"
    exit 1
}
if ! /usr/bin/grep -Fq "!containsAssetRecovery" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "containsAssetRecovery: pendingRows.contains(where:" "${nexus_ui}"; then
    echo "error: Nexus UI mutation admission ignores retained recovery evidence"
    exit 1
fi
for nexus_chain_test_marker in \
    "Legacy-unbound evidence admitted a new Nexus mutation" \
    "A new current-chain send bypassed retired-chain evidence" \
    "Mixed current/retired evidence admitted a mutation"
do
    if ! /usr/bin/grep -Fq "${nexus_chain_test_marker}" "${modernization_tests}"; then
        echo "error: Nexus retained-chain mutation regression is absent: ${nexus_chain_test_marker}"
        exit 1
    fi
done
if ! /usr/bin/grep -Fq "checksummed Norito hash" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "lowercase, prefix-free 64-hex representation" "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'finalizedBlockHash: "0x" +' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'finalizedBlockHash: "hash:" +' "${modernization_tests}"; then
    echo "error: Nexus finality checkpoint native-projection or raw Norito-literal rejection is absent"
    exit 1
fi

if /usr/bin/grep -Fq "signer: NexusTransactionSigning = UnavailableNexusTransactionSigner()" "${nexus_service}"; then
    echo "error: Nexus mutation signer remains fail-closed"
    exit 1
fi

if /usr/bin/grep -Fq "finalityReader: NexusFinalityReading = UnavailableNexusFinalityReader()" "${nexus_service}"; then
    echo "error: Nexus finalized-head reader remains fail-closed"
    exit 1
fi

if ! /usr/bin/grep -Eq '^[[:space:]]*static let nexusSends = true[[:space:]]*$' "${settings_extension}" ||
   ! /usr/bin/grep -Eq '^[[:space:]]*static let polkamarktMutations = true[[:space:]]*$' "${settings_extension}"; then
    echo "error: local production mutation qualification remains fail-closed"
    exit 1
fi

if /usr/bin/grep -Fq "Estimated fee XOR" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "quoteTransfer" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "freshQuote.quoteIdentity == prepared.quote.quoteIdentity" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "finalQuote.quoteIdentity == freshQuote.quoteIdentity" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "finalAvailableAmount >= amount + fee" "${nexus_service}"; then
    echo "error: Nexus send does not use an authoritative reviewed fee quote"
    exit 1
fi

if ! /usr/bin/grep -Fq "openSora2Experience()" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "tabBarController.selectedIndex = 0" "${more_menu_wireframe}"; then
    echo "error: unified portfolio does not retain the qualified SORA2 asset experience"
    exit 1
fi

for selection_emitter in \
    "${change_account}" \
    "${account_create}" \
    "${account_import_commit}" \
    "${add_account_import}" \
    "${add_account_confirm}" \
    "${create_account_service}" \
    "${account_options}"
do
    if ! /usr/bin/grep -Eq '^[[:space:]]*let selectionEventCenter = eventCenter[[:space:]]*$' "${selection_emitter}" ||
       ! /usr/bin/grep -Eq '^[[:space:]]*selectionEventCenter\.notify\([[:space:]]*$' "${selection_emitter}" ||
       ! /usr/bin/grep -Eq '^[[:space:]]*completionOnMain:' "${selection_emitter}"; then
        echo "error: account-selection delivery is not lifetime-safe: ${selection_emitter}"
        exit 1
    fi
done

if ! /usr/bin/grep -Fq "override func viewWillAppear" "${more_menu_view}" ||
   ! /usr/bin/grep -Fq "createMoreMenuController(" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "MainTabBarAccountRebindPolicy" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "requiresRecoveryAfterRebuildFailure" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "let replacementViewControllers = [" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "replacementViewControllers.count ==" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "SelectedWalletSettings.shared.currentAccount?.address ==" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "self.walletContext = walletContext" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "walletContextWalletId = selectedAccount.address" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "!accountSwitchRecoveryActive," "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "walletContextMatchesSelectedWallet" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "canPresentAccountBoundRoute" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "routeWalletId: selectedAccount.address" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "let replacementBindingId = UUID()" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "accountBindingId == replacementBindingId" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "accountBindingId = replacementBindingId" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "middleButtonHadler = { [weak self, weak view]" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "completion: { [weak self, weak view]" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "tabBarController.viewControllers = replacementViewControllers" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "tabBarController.viewControllers = [recoveryController]" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "WalletRecoveryViewController(" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "deliveryGroup.notify(" "${event_center}" ||
   ! /usr/bin/grep -Fq "completionOnMain: @escaping () -> Void" "${event_protocols}" ||
   [ "$(/usr/bin/grep -Fc 'completionOnMain: @escaping () -> Void' "${module_mocks}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "with: SelectedAccountChanged()," "${change_account}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${change_account}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${account_create}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${account_import_commit}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${add_account_import}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${add_account_confirm}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${create_account_service}" ||
   ! /usr/bin/grep -Fq "completionOnMain:" "${account_options}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${change_account}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${account_create}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${account_import_commit}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${add_account_import}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${add_account_confirm}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${create_account_service}" ||
   ! /usr/bin/grep -Fq "let selectionEventCenter = eventCenter" "${account_options}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${change_account}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${account_create}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${account_import_commit}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${add_account_import}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${add_account_confirm}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${create_account_service}" ||
   ! /usr/bin/grep -Fq "selectionEventCenter.notify(" "${account_options}" ||
   ! /usr/bin/grep -Fq "navigationController.viewControllers.first === controller" "${account_options_wireframe}" ||
   ! /usr/bin/grep -Fq "navigationController.parent ?? navigationController" "${account_options_wireframe}" ||
   ! /usr/bin/grep -Fq "func dismissAfterDeletion" "${account_options_wireframe}" ||
   ! /usr/bin/grep -Fq "AccountOptionsDeletionPresentationPolicy" "${account_options_wireframe}" ||
   ! /usr/bin/grep -Fq ".dismissalContainer(for: controller)" "${account_options_wireframe}" ||
   ! /usr/bin/grep -Fq "wireframe.dismissAfterDeletion(from: view)" "${account_options_presenter}" ||
   ! /usr/bin/grep -Fq ".dismiss(animated: true)" "${account_options_wireframe}" ||
   /usr/bin/grep -Fq "viewcontrollers.remove(at:" "${main_tab_wireframe}" ||
   ! /usr/bin/grep -Fq "NexusPortfolioPresentationPolicy.detailMatchesSelectedWallet" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "NexusPortfolioPresentationPolicy.rowsMatchSelectedWallet" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq 'walletIds: rows.map(\.account.walletId)' "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "Account selection is a privacy boundary" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "let rowsRemainAvailable = rows.allSatisfy" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "NexusPortfolioPresentationPolicy.networkDetailIsAvailable" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "static func networkDetailAccess(" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "readsAvailable && mutationCoordinatorAvailable" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "private let readClient: NexusToriiReading" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "readClient: NexusToriiReading = NexusToriiReadClient()" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "private func readCurrentNexusXorBalance(" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "let definition = try await readClient.xorAssetDefinition(" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "let response = try await readClient.accountAssets(" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "limit: 100" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "let quantity = try NexusBalanceValidator.xorBalance(" "${nexus_ui}" ||
	   /usr/bin/grep -Fq "NexusToriiClient(" "${nexus_ui}" ||
	   /usr/bin/grep -Fq "pendingStore" "${nexus_ui}" ||
	   /usr/bin/grep -Fq "guard let coordinator, let pendingStore else" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "if access.mutationSurfaceAvailable" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "static func mutationIsReady(" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "sendButton.isEnabled = false" "${nexus_ui}" ||
	   ! /usr/bin/grep -Fq "private var mutationReady = false" "${nexus_ui}" ||
	   [ "$(/usr/bin/grep -Fc 'setMutationReady(false)' "${nexus_ui}")" -lt 3 ] ||
	   ! /usr/bin/grep -Fq "guard mutationReady, coordinator != nil else" "${nexus_ui}" ||
	   [ "$(/usr/bin/grep -Fc 'guard mutationReady, let coordinator else' "${nexus_ui}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "static func pendingRows(" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "let isCurrentChain = configuration.map" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq 'transaction.chainId == $0.chainId' "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "let isCurrentXor = isCurrentChain && assetMatches" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "currentXorAssetDefinitionID: currentXorAssetDefinitionID" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "currentXorAssetDefinitionID = value.assetDefinitionID" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "assetDefinitionID: currentXorAssetDefinitionID" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "if let currentXorAssetDefinitionID" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "currentXorAssetDefinitionID != nil" "${nexus_ui}" ||
   /usr/bin/grep -Fq "async let historyResult = client.committedXorTransfers" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "Pending asset recovery" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "func currentXorBalance(" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "message: [account.address, notice]" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "self.portfolioContextIsCurrent(" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "private func networkActionContextIsCurrent()" "${nexus_ui}" ||
   [ "$(/usr/bin/grep -Fc 'guard networkActionContextIsCurrent()' "${nexus_ui}")" -lt 9 ] ||
   ! /usr/bin/grep -Fq "loadTask?.cancel()" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktPresentationPolicy.canCommitCatalogAccountState" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktPresentationPolicy.canPresentAccountDetail" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "loadTask?.cancel()" "${polkamarkt_ui}" ||
	   ! /usr/bin/grep -Fq "testRetainedNetworkDetailsRejectAChangedSelectedWallet" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "let journalRecoveryAccess =" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "XCTAssertTrue(journalRecoveryAccess.readsAvailable)" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "XCTAssertFalse(journalRecoveryAccess.mutationSurfaceAvailable)" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "XCTAssertTrue(qualifiedMutationAccess.mutationSurfaceAvailable)" "${modernization_tests}" ||
	   [ "$(/usr/bin/grep -Fc 'NexusPortfolioPresentationPolicy.mutationIsReady(' "${modernization_tests}")" -lt 6 ] ||
   ! /usr/bin/grep -Fq "currentXorAssetDefinitionID: nil" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let unboundChainPending = try pending(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let retiredChainPending = try pending(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".assetRecovery" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testEventCenterCompletionRunsAfterQueuedObserverThroughProtocol" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testAccountDeletionTargetsContainingModalFromRootAndPushedRoutes" "${modernization_tests}" ||
   ! /usr/bin/grep -Eq '^[[:space:]]*func testRetainedNetworkDetailsRejectAChangedSelectedWallet\(\)([[:space:]]+throws)?[[:space:]]*\{' "${modernization_tests}" ||
   ! /usr/bin/grep -Eq '^[[:space:]]*func testEventCenterCompletionRunsAfterQueuedObserverThroughProtocol\(\)' "${modernization_tests}" ||
   ! /usr/bin/grep -Eq '^[[:space:]]*func testAccountDeletionTargetsContainingModalFromRootAndPushedRoutes\(\)' "${modernization_tests}"; then
    echo "error: retained iOS navigation can expose stale wallet-scoped modernization state"
    exit 1
fi

if ! /usr/bin/grep -Fq "SORA2 · MAINNET" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "MINAMOTO · MAINNET" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "TAIRA · TESTNET" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "configuration.validate(address: receiver)" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq '$0.walletId == self.account.walletId' "${nexus_ui}" ||
   ! /usr/bin/grep -Fq '$0.networkId == self.account.networkId' "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "UIImageView(image: qrImage(account.address))" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "UIPasteboard.general.string = account.address" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "UIApplication.shared.open(configuration.explorerURL)" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "unknown submission result is never retried" "${nexus_ui}" ||
   ! /usr/bin/grep -Fq "testI105RejectsCrossNetworkAddress" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIMobileFlagsCannotEnableUnqualifiedMutationsOrOverrideTairaChoice" "${modernization_tests}"; then
    echo "error: unified iOS portfolio actions are not visibly and durably network-scoped"
    exit 1
fi

if ! /usr/bin/grep -Fq "enum NexusSendAvailabilityPolicy" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "networkId != .taira || tairaEnabled" "${nexus_service}" ||
   [ "$(/usr/bin/grep -Fc 'validateLiveFeatureFlags(for: request.networkId)' "${nexus_service}")" -lt 5 ] ||
   [ "$(/usr/bin/grep -Fc 'sendAvailabilityAllows(request.networkId)' "${nexus_service}")" -lt 4 ] ||
   ! /usr/bin/grep -Fq "testTairaSendAvailabilityRequiresVisibleTestNetworks" "${modernization_tests}"; then
    echo "error: Taira sends are not bound to the explicit test-network visibility choice"
    exit 1
fi

if ! /usr/bin/grep -Fq "enum PolkamarktPendingObservationPolicy" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "static func delayNanoseconds(afterAttempt attempt: Int) -> UInt64" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "static func requiresObservation(" "${polkamarkt_ui}" ||
   [ "$(/usr/bin/grep -Fc 'private func beginPendingReconciliation' "${polkamarkt_ui}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "Pending SORA2 transaction — reconciling finalized status" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "case positions" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "Your indexed positions" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "private var displayedPositions: [PIAccountPosition]" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PI supplies account-wide position discovery" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "static func matchesOwnerFilter(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "return creator == selectedAccount" "${polkamarkt_ui}" ||
   /usr/bin/grep -Fq "market.creator?.caseInsensitiveCompare(" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "private var quoteTask: Task<Void, Never>?" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "private var quoteRequestID: UUID?" "${polkamarkt_ui}" ||
   [ "$(/usr/bin/grep -Fc 'quoteTask?.cancel()' "${polkamarkt_ui}")" -lt 4 ] ||
   [ "$(/usr/bin/grep -Fc 'quoteRequestID == requestID' "${polkamarkt_ui}")" -lt 3 ] ||
   ! /usr/bin/grep -Fq "private func canPresentAccountScopedResult() -> Bool" "${polkamarkt_ui}" ||
   [ "$(/usr/bin/grep -Fc 'canPresentAccountScopedResult()' "${polkamarkt_ui}")" -lt 11 ] ||
   ! /usr/bin/grep -Fq "private func canPresentCatalogMutationResult(account: String) -> Bool" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "request.account == account" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktPresentationPolicy.canPresentAccountDetail(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "PolkamarktPresentationPolicy.canCommitCatalogAccountState(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "let durableValues = try await pendingStore.all()" "${polkamarkt_ui}" ||
   [ "$(/usr/bin/grep -Fc 'applyPendingOverlay(' "${polkamarkt_ui}")" -lt 4 ] ||
   ! /usr/bin/grep -Fq '$0.account == account && $0.marketIds.contains(marketId)' "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "if let pendingLoadError, pending.isEmpty" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "let durableStatusDetails = [" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "cell.detailTextLabel?.text = durableStatusDetails" "${polkamarkt_ui}" ||
   ! /usr/bin/grep -Fq "PolkamarktPendingObservationPolicy.requiresObservation(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "afterAttempt: .max" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'creator: "5exactCaseSensitiveOwner"' "${modernization_tests}"; then
    echo "error: iOS Polkamarkt positions or continuous pending reconciliation regressed"
    exit 1
fi

if ! /usr/bin/grep -Fq "committedPendingReconciliation" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "committedXorTransfers" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "enum NexusCommittedHistoryReconciliation" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "transfersForSignedHash.count == 1" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "NexusCommittedHistoryReconciliation.matchesExactlyOne(" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "committedBlockHeight > 0" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "transaction.terminalBlockHeight.map({ \$0 > 0 }) == true" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "transaction.assetDefinitionID != nil" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "let promotesLegacyZeroHeight =" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "let wasLegacyUnreconciledCommit =" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "if !wasLegacyUnreconciledCommit" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "legacyUnreconciled.requiresCommittedHistoryReconciliation" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "history: page.items + page.items" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "A conflicting XOR instruction under the signed hash was ignored" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "A new pending commit accepted a zero block height" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "A reconciled commit omitted its exact asset identity" "${modernization_tests}"; then
    echo "error: Nexus finality lacks exact committed-history reconciliation"
    exit 1
fi

if ! /usr/bin/grep -Fq 'final class NexusTransactionRuntime' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'func resumePendingAfterProcessStart()' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'walletStorageReady' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'func prepareForWalletStorageMigration()' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'try Task.checkCancellation()' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'activeSubmissionIds.contains(transaction.id)' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'let lifecycleLease = await WalletLifecycleCoordinator.shared' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'let chainId: UUID?' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'chainId: configuration.chainId' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'lhs.chainId == rhs.chainId' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'allowsReadOnlyHistoricalChain: true' "${nexus_service}" ||
   [ "$(/usr/bin/grep -Fc 'allowsReadOnlyHistoricalChain: false' "${nexus_service}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq 'private static func transactionHashIdentity(' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'private static func transactionHashScope(' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'transaction.chainId?.uuidString.lowercased()' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'unboundHashScopes.allSatisfy' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'let isCurrentChain = retainedConfiguration.map' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'return isCurrentChain &&' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'transaction.chainId == journalConfiguration.chainId' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'transaction.chainId == configuration.chainId' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'struct NexusFinalityCheckpoint: Equatable {' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'networkId == configuration.networkId' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'chainId == configuration.chainId' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'finalizedBlockHeight > 0' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'let finalizedBlockHash: String' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'NexusTransactionHash.normalized(finalizedBlockHash)' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'protocol NexusFinalityReading' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'challenge-bound BridgeFinalityAttestationV1' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'bounded sequential BridgeFinalityBundle catch-up' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'Scalar status height' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'func finalizedCheckpoint(' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'private let finalityReader: NexusFinalityReading' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'let finalizedCheckpoint = try await finalityReader' "${nexus_service}" ||
   ! /usr/bin/grep -Fq '.finalizedCheckpoint(for: configuration)' "${nexus_service}" ||
   ! /usr/bin/grep -Fq '.requireHeight(for: configuration)' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'finalityReader.isQualified(for: configuration)' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'quote.validUntilBlock.map({ $0 > 0 }) ?? true' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'fee.unscaled > 0' "${nexus_service}" ||
   /usr/bin/grep -Fq 'signer.finalizedBlockHeight(' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'prepareForWalletStorageMigration()' "${splash_interactor}" ||
   ! /usr/bin/grep -Fq 'markWalletStorageReadyAndResume()' "${splash_interactor}" ||
   ! /usr/bin/grep -Fq 'NexusTransactionRuntime.shared' "${nexus_ui}" ||
   ! /usr/bin/grep -Fq 'resumePendingNexusTransactions()' "${app_delegate}" ||
   ! /usr/bin/grep -Fq 'func applicationWillEnterForeground' "${app_delegate}" ||
   ! /usr/bin/grep -Fq 'URLQueryItem(name: "scope", value: "global")' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'status.hasAuthoritativeGlobalResolution' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'for page in 1 ... maximumPages' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'private static func parseBatchTransfer' "${nexus_service}" ||
   ! /usr/bin/grep -Fq '"asset_definition", "assetDefinition"' "${nexus_service}" ||
   ! /usr/bin/grep -Fq '!candidate.isEmpty, !candidate.contains("#")' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'canonicalExplicitSource != canonicalEmbeddedSource' "${nexus_service}" ||
	   /usr/bin/grep -Fq 'container.decode(Decimal.self)' "${nexus_service}" ||
	   /usr/bin/grep -Fq 'container.decode(Decimal.self)' "${pi_client}" ||
	   /usr/bin/grep -Fq 'container.decode(Double.self)' "${pi_client}" ||
	   ! /usr/bin/grep -Fq 'container.decode(Int64.self)' "${pi_client}" ||
	   ! /usr/bin/grep -Fq 'container.decode(UInt64.self)' "${pi_client}" ||
   ! /usr/bin/grep -Fq 'testNexusCommittedHistoryRejectsMalformedOrConflictingSourceIdentity' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'testNexusBatchHistoryRequiresExactXorDefinitionPerLeg' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testNexusPipelineStatusRequiresGlobalAuthoritativeResolution' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testNexusAppliedStatusRequiresStateAndPositiveBlock' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testNexusTerminalFailureRequiresStateResolution' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testNexusRecoveryNeverInterruptsALiveSubmission' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'for: Self.admittedTairaConfiguration()' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'finalizedBlockHeight: 0' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'finalizedBlockHash: String(repeating: "AB", count: 32)' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'finalizedBlockHash: String(repeating: "0", count: 64)' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '809574f5-fee7-5e69-bfcf-52451e42d50f' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'legacyRows[0].removeValue(forKey: "chainId")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'let retiredChainEvidence = try await store.all()' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'Retired-chain evidence was accepted for mutation' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'let crossChainEvidence = try await store.all()' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'Unbound and current-chain duplicate hashes were accepted' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'Retired-chain evidence was silently evicted' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'var pending = try await pendingStore.put(originalPending)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'no orphan row is' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'case entrypointHash = "entrypoint_hash"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'NexusTransactionHash.normalized(payload.entrypointHash)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'payload.submittedAtMs > 0' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'willPerformHTTPRedirection response: HTTPURLResponse' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'completionHandler(nil)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let requestURL = request.url' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'response.url == requestURL' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let (bytes, response) = try await session.bytes(for: request)' "${nexus_service}" ||
	   /usr/bin/grep -Fq 'session.data(for: request)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func validateResponseLength(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func appendResponseByte(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'try Self.validateResponseLength(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'for try await byte in bytes' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'try Self.appendResponseByte(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'XCTAssertEqual(boundedResponse, Data([0x01, 0x02]))' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'static func responseAcceptHeader(for url: URL) -> String' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'url.path.hasSuffix("/health") ? "text/plain" : "application/json"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func requestContentType(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'return "application/x-norito"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let expectedRequestContentType = try Self.requestContentType(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'requestHasBody == (expectedRequestContentType != nil)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func isExpectedResponseContentType(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'enum NexusToriiMediaTypeContract' "${nexus_service}" ||
	   [ "$(/usr/bin/grep -Fc 'NexusToriiMediaTypeContract.matches(' "${nexus_service}")" -lt 2 ] ||
	   ! /usr/bin/grep -Fq 'expected: "application/json"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'response.value(forHTTPHeaderField: "Content-Type")' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq '!value.contains(",")' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'contentType: .string("application/json; profile=unexpected")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'contentType: .string("application/json;")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'static func validateHealthPayload(_ data: Data) throws' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'data == Data("Healthy".utf8)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'try Self.validateHealthPayload(payload)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'requiresFanout: Bool = false' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private static let maximumFanoutRoutes = 1_024' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private static let routedByHeader = "x-iroha-routed-by"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'routedBy.map({ ["local", "proxy"].contains($0) }) ?? true' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'of: #"^(?:0|[1-9][0-9]{0,3})$"#' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'count <= maximumFanoutRoutes' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'guard firstFailure == nil, !requiresFanout else' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'firstFailure == nil' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'rawCounts.allSatisfy({ $0 != nil })' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'counts[1] == counts[0]' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'counts[0] > 0' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'counts.dropFirst(2).allSatisfy({ $0 == 0 })' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private static let routeLaneIDHeader = "x-iroha-route-lane-id"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private static let routeDataspaceIDHeader = "x-iroha-route-dataspace-id"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'isCanonicalRouteID($0, maximum: UInt64(UInt32.max))' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'isCanonicalRouteID($0, maximum: UInt64.max)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'requiresFanout: requiresFanout' "${nexus_service}" ||
	   [ "$(/usr/bin/grep -Fc 'requiresFanout: true' "${nexus_service}")" -lt 4 ] ||
	   ! /usr/bin/grep -Fq 'Self.responseAcceptHeader(for: url)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'struct NexusAssetDefinition: Decodable, Equatable' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'case aliasBinding = "alias_binding"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func hasCanonicalWireShape(_ value: String) -> Bool' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func exactAssetBalance(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'asset = try container.decode(String.self, forKey: .asset)' "${nexus_service}" ||
	   /usr/bin/grep -Fq 'asset = try container.decodeIfPresent(String.self, forKey: .asset)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let missingAuthoritativeAssetEnvelope: [String: Any]' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'hasMore = try container.decode(Bool.self, forKey: .hasMore)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'countMode = try container.decode(String.self, forKey: .countMode)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'total = try container.decode(Int64.self, forKey: .total)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let total: Int64' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'response.countMode == "exact"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'expectedAssetName: NexusAssetDefinitionIdentity.xorName' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'expectedAssetAlias: NexusAssetDefinitionIdentity.xorAlias' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'requiresCurrentXorIdentity: Bool = true' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'requiresCurrentXorIdentity: false' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'expectedAssetName: nil' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'expectedAssetAlias: nil' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq '["permanent", "leased_active"].contains' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func xorAssetDefinitionURL(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'func xorAssetDefinition(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'func hasAuthoritativeCommittedTransaction(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'from: await data(request: mcpRequest)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'enum NexusMCPResultContract {' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'enum NexusMCPEnvelopeContract {' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'responseID: response.id' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'expectedID: payload.id' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let structuredResult = try NexusMCPResultContract' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq '.validateEmbeddedRoute(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'result: structuredResult' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'direct["body"] == nil' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'structured["body"]?.objectValue != nil' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'structured["items"] == nil' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'embeddedMCPResult(body: .null)' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'embeddedMCPResult(includesStructuredShadowItems: true)' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'caller consuming global instruction history opts into the stricter' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'static func accountTransactionsURL(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'URLQueryItem(name: "asset_id", value: assetDefinitionID)' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'struct NexusAccountTransactionProof {' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'case hasMore = "has_more"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'case countMode = "count_mode"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'page.countMode == "exact"' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'page.hasMore == (' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private(set) var nextOffset = 0' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'expectedTotal.map({ $0 == page.total }) ?? true' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'pageFingerprints.insert(fingerprint).inserted' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'seenHashes.insert(normalized).inserted' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'pagesAccepted < maximumPages' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'switch try proof.accept(page)' "${nexus_service}" ||
   ! /usr/bin/grep -Fq 'protocol NexusToriiReading' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'protocol NexusToriiSubmitting' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'final class NexusToriiReadClient: NexusToriiReading' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'final class NexusToriiSubmissionClient: NexusToriiSubmitting' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'readClient: NexusToriiReading = NexusToriiReadClient()' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'NexusToriiSubmissionClient(),' "${nexus_service}" ||
	   /usr/bin/grep -Fq 'extension NexusToriiClient: NexusToriiReading' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private let readClient: NexusToriiReading' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'private let submissionClient: NexusToriiSubmitting' "${nexus_service}" ||
	   /usr/bin/grep -Fq 'private let client: NexusToriiClient' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'readClient' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'recoverySource.contains("submissionClient")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'recoveryClient is NexusToriiSubmitting' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'submissionClient is NexusToriiReading' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'readClient' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq '.hasAuthoritativeCommittedTransaction(' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'assetDefinitionID: xorDefinition.id' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'assetDefinitionID: finalDefinition.id' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let assetDefinitionID: String?' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'lhs.assetDefinitionID == rhs.assetDefinitionID' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'let assetDefinitionID = transaction.assetDefinitionID' "${nexus_service}" ||
	   ! /usr/bin/grep -Fq 'testNexusToriiHealthNegotiatesPlainTextWhileAPIRoutesRemainJSON' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'NexusToriiClient.requestContentType(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"application/x-norito"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'NexusToriiClient.isExpectedResponseContentType(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"application/json, text/plain"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'https://public-01.taira.example.org/v1/assets/definitions/xor%23universal' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'https://taira.sora.org/v1/mcp' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testNexusToriiRejectsPartialFanoutSuccess' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"x-iroha-route-lane-id": "1"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"x-iroha-route-dataspace-id": "2"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"x-iroha-route-lane-id": "4294967295"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"x-iroha-route-dataspace-id": "18446744073709551615"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"x-iroha-route-lane-id": "4294967296"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"x-iroha-route-dataspace-id": "18446744073709551616"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'headerFields: ["x-iroha-routed-by": "proxy"]' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'headerFields: ["x-iroha-routed-by": "local"]' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'headerFields: ["x-iroha-routed-by": "Proxy"]' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'requiresFanout: true' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'malformedHeaders["x-iroha-fanout-routes-attempted"] = "04"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'embeddedMCPResult(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'NexusMCPResultContract.validateEmbeddedRoute(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'includesShadowBody: true' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'NexusMCPEnvelopeContract.validate(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'NexusToriiClient.accountTransactionsURL(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"asset_id": Self.nexusXorAssetDefinitionID' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'var drift = try proof()' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'countMode: "bounded"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'hasMore: true' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'var repeated = try proof()' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'var duplicate = try proof(pageSize: 2)' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'var exhausted = try proof(maximumPages: 1)' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '"asset_name": "renamed-after-submission"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'NexusBalanceValidator.exactAssetBalance(' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'missingExactMetadataEnvelope.removeValue(forKey: "count_mode")' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'mixedCaseExactMetadataEnvelope["count_mode"] = "Exact"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq '61CtjvNd9T3THAR65GsMVHr82Bjc' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'status: "leased_grace"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'legacyRows[0].removeValue(forKey: "assetDefinitionID")' "${modernization_tests}" ||
	   /usr/bin/grep -Fq 'assetDefinitionID: "xor#universal"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testNexusSubmissionReceiptBindsEveryHashAndPosition' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'testGenericWireJSONRejectsLossyNumericTokens' "${modernization_tests}"; then
    echo "error: Nexus restart recovery, routing provenance, history identity, or exact numeric parsing is incomplete"
    exit 1
fi

nexus_recovery_forbidden_calls="$(
    /usr/bin/awk '
        /func resumePending\(\) async throws/ { in_recovery = 1 }
        in_recovery && /final class NexusTransactionRuntime/ {
            in_recovery = 0
        }
        in_recovery && /(signer\.|submissionClient|NexusToriiSubmitting|\.submit\(|quoteTransfer\(|signTransfer\()/ {
            print
        }
    ' "${nexus_service}"
)"
if [ -n "${nexus_recovery_forbidden_calls}" ]; then
    echo "error: Nexus restart recovery can reach signing or submission capability"
    exit 1
fi

nexus_pre_sign_journal_line="$(
    /usr/bin/grep -Fn 'var pending = try await pendingStore.put(originalPending)' "${nexus_service}" |
        /usr/bin/head -n 1 |
        /usr/bin/cut -d: -f1
)"
nexus_sign_line="$(
    /usr/bin/grep -Fn 'var signed = try await signer.signTransfer(' "${nexus_service}" |
        /usr/bin/head -n 1 |
        /usr/bin/cut -d: -f1
)"
if [ -z "${nexus_pre_sign_journal_line}" ] ||
   [ -z "${nexus_sign_line}" ] ||
   [ "${nexus_pre_sign_journal_line}" -ge "${nexus_sign_line}" ]; then
    echo "error: Nexus pre-sign journal must publish under the lifecycle lease before secret use"
    exit 1
fi

for capability in \
    nexusAvailable \
    nexusSendsAvailable \
    polkamarktVisible \
    polkamarktMutationsAvailable \
    tairaDefaultVisible
do
    if ! /usr/bin/grep -Fq "${capability}" "${pi_client}"; then
        echo "error: PI mobileConfig emergency capability is missing: ${capability}"
        exit 1
    fi
done

if ! /usr/bin/grep -Fq "func qualifiedMobileConfig(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "let result: PIQualifiedRead<Payload> = try await executeQualified(" "${pi_client}" ||
   ! /usr/bin/grep -Fq "client.qualifiedMobileConfig(" "${pi_config_operation}" ||
   ! /usr/bin/grep -Fq "qualification.source == .live" "${pi_config_operation}" ||
   ! /usr/bin/grep -Fq "checkedHealth = qualification.health" "${pi_config_operation}" ||
   /usr/bin/grep -Fq "async let health = client.health" "${pi_config_operation}" ||
   /usr/bin/grep -Fq "client.health()" "${pi_config_operation}" ||
   ! /usr/bin/grep -Fq "applyPIMobileConfig" "${pi_config_operation}" ||
   ! /usr/bin/grep -Fq "capabilitySession.beginLiveRefresh()" "${pi_config_operation}" ||
   ! /usr/bin/grep -Fq "capabilitySession.invalidate(refreshToken)" "${pi_config_operation}" ||
   ! /usr/bin/grep -Fq "ProductionRemoteCapabilitySession.shared.permitsMutation" "${settings_extension}" ||
   ! /usr/bin/grep -Fq "capabilitySession.publishFreshConfig" "${settings_extension}" ||
   ! /usr/bin/grep -Fq "snapshot?.nexusSends" "${settings_extension}" ||
   ! /usr/bin/grep -Fq "generation == token.generation" "${settings_extension}" ||
   ! /usr/bin/grep -Fq "tairaPreferenceWasSet" "${settings_extension}" ||
   ! /usr/bin/grep -Fq "tairaExplicitPreference" "${settings_extension}" ||
   ! /usr/bin/grep -Fq "tairaRemoteDefault" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq 'newValue ? "enabled" : "disabled"' "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "atomicTairaExplicitPreference" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "anyValue(for: key.rawValue)" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "CFGetTypeID(number) == CFBooleanGetTypeID()" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "case .disabled, .malformed:" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "switch (legacyMarker, legacyValue)" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "case (.absent, .absent):" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "Any partial pair" "${settings_extension}" ||
	   ! /usr/bin/grep -Fq "SettingsKey.tairaExplicitPreference.rawValue" "${recovery_exporter}" ||
	   ! /usr/bin/grep -Fq 'SettingsKey.tairaExplicitPreference.rawValue: "enabled"' "${recovery_export_tests}" ||
	   ! /usr/bin/grep -Fq '"disabled"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq 'value: "malformed"' "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "wrongTypedAtomicChoice" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "incompleteLegacyChoice" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "partialLegacyValue" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "falseLegacyMarker" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "wrongTypedLegacyMarker" "${modernization_tests}" ||
	   ! /usr/bin/grep -Fq "wrongTypedRemoteDefault" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq 'This is deliberately not `isTairaEnabled = ...`' "${settings_extension}" ||
   ! /usr/bin/grep -Fq "testProductionMutationSessionRequiresFreshLiveConfigInCurrentProcess" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIMobileFlagsCannotEnableUnqualifiedMutationsOrOverrideTairaChoice" "${modernization_tests}"; then
    echo "error: PI mobileConfig emergency capabilities are not applied"
    exit 1
fi

if ! /usr/bin/grep -Fq "final class PIRedirectRejectingDelegate" "${pi_client}" ||
   ! /usr/bin/grep -Fq "delegate: PIRedirectRejectingDelegate.shared" "${pi_client}" ||
   ! /usr/bin/grep -Fq "static func validateProductionEndpoint(_ candidate: URL) throws" "${pi_client}" ||
   ! /usr/bin/grep -Fq "candidate.absoluteString == endpoint.absoluteString" "${pi_client}" ||
   ! /usr/bin/grep -Fq "try Self.validateProductionEndpoint(endpoint)" "${pi_client}" ||
   ! /usr/bin/grep -Fq "health.publicBaseUrl?.absoluteString == endpoint.absoluteString" "${pi_client}" ||
   ! /usr/bin/grep -Fq "try Self.validateRequestBody(body)" "${pi_client}" ||
   ! /usr/bin/grep -Fq "static let maximumResponseBytes = 4 * 1024 * 1024" "${pi_client}" ||
   ! /usr/bin/grep -Fq "try Self.validateExpectedResponseLength(" "${pi_client}" ||
   ! /usr/bin/grep -Fq 'request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")' "${pi_client}" ||
   ! /usr/bin/grep -Fq "configuration.urlCache = nil" "${pi_client}" ||
   [ "$(/usr/bin/grep -Fc 'requestCachePolicy = .reloadIgnoringLocalCacheData' "${pi_client}")" -lt 1 ] ||
   ! /usr/bin/grep -Fq "request.cachePolicy = .reloadIgnoringLocalCacheData" "${pi_client}" ||
   ! /usr/bin/grep -Fq '"no-store, no-cache, max-age=0"' "${pi_client}" ||
   ! /usr/bin/grep -Fq "session.bytes(for: request)" "${pi_client}" ||
   ! /usr/bin/grep -Fq "data.count < Self.maximumResponseBytes" "${pi_client}" ||
   ! /usr/bin/grep -Fq "http.url == endpoint" "${pi_client}" ||
   ! /usr/bin/grep -Fq "http.url?.absoluteString == endpoint.absoluteString" "${pi_client}" ||
   ! /usr/bin/grep -Fq "guard http.statusCode == 200 else" "${pi_client}" ||
   ! /usr/bin/grep -Fq 'http.mimeType?.lowercased() == "application/json"' "${pi_client}" ||
   ! /usr/bin/grep -Fq 'forHTTPHeaderField: "Content-Encoding"' "${pi_client}" ||
   ! /usr/bin/grep -Fq 'contentEncoding.lowercased() == "identity"' "${pi_client}" ||
   ! /usr/bin/grep -Fq '"Content-Encoding": "gzip"' "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "enum PIStrictJSONAdmission" "${pi_client}" ||
   ! /usr/bin/grep -Fq "guard names.insert(name).inserted" "${pi_client}" ||
   ! /usr/bin/grep -Fq "try PIStrictJSONAdmission.validate(data)" "${pi_client}" ||
   ! /usr/bin/grep -Fq "enum PIResponseCacheAdmission" "${pi_client}" ||
   [ "$(/usr/bin/grep -Fc 'PIResponseCacheAdmission.validatePayload' "${pi_client}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'PIResponseCacheAdmission.validateEnvelope' "${pi_client}")" -lt 2 ] ||
   [ "$(/usr/bin/grep -Fc 'PIResponseCacheAdmission.validatePayload' "${modernization_tests}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "PIResponseCacheAdmission.validateEnvelope" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "static let maximumCursorBytes = 4_096" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "static let maximumHistoryPages = 20" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "static func validateHistoryPagination(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "static func validateHistoryPage(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "func qualifiedHistoryPage(" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var seenItemIdentities = Set<String>()" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "var consumedCount = 0" "${pi_client}" ||
	   /usr/bin/grep -Fq '$offset: Int' "${pi_client}" ||
	   /usr/bin/grep -Fq 'offset: $offset' "${pi_client}" ||
	   ! /usr/bin/grep -Fq "Self.isBoundedCursor(page.pageInfo.endCursor)" "${pi_client}" ||
	   ! /usr/bin/grep -Fq "PIIndexerClient.validateCursor(" "${modernization_tests}" ||
	   [ "$(/usr/bin/grep -Fc 'PIIndexerClient.validateHistoryPage(' "${modernization_tests}")" -lt 2 ] ||
   ! /usr/bin/grep -Fq "testPIHTTPResponseRejectsRedirectedOrNonJSONEndpoints" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIExecutionEndpointIsPinnedToConsolidatedProductionOrigin" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIRequestBodyIsBoundedBeforeTransport" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIStrictJSONAdmissionRejectsDuplicateDecodedObjectNames" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIStrictJSONAdmissionRejectsMalformedAndTrailingDocuments" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testPIStrictJSONAdmissionBoundsBytesDepthAndTokenWork" "${modernization_tests}"; then
    echo "error: PI transport is not pinned or does not reject redirects, ambiguous JSON, non-JSON responses, or oversized streams"
    exit 1
fi

if ! /usr/bin/grep -Fq "capabilitySession.beginLiveRefresh()" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "capabilitySession.invalidate(refreshToken)" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "capabilitySession.beginLiveRefresh()" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "capabilitySession.invalidate(refreshToken)" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "actual signer boundary" "${nexus_service}" ||
   ! /usr/bin/grep -Fq "prepare/sign" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "preSigningValidation: {" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "preSigningValidation: preSigningValidation" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "PolkamarktExactFeeValidator.validate(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "maximumNetworkFee: request.maximumNetworkFee" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "testPolkamarktExactSignedFeeMustRemainWithinConfirmedBound" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "PolkamarktSigningHeadValidator.validate(" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "finalizedHeadValidation: finalizedHeadValidation" "${extrinsic_service}" ||
   ! /usr/bin/grep -Fq "testPolkamarktSigningHeadMustMatchTheRevalidatedQuoteHead" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "factory.metadata.encode(scaleEncoder: metadataEncoder)" "${polkamarkt_runtime}" ||
   ! /usr/bin/grep -Fq "facade.networkType == Chain.sora.addressType()" "${polkamarkt_runtime}" ||
   /usr/bin/grep -Fq "guard settings.nexusEnabled, settings.nexusSendsEnabled else" "${nexus_service}" ||
   [ "$(/usr/bin/grep -Fc 'try await validateLiveMutationFlags()' "${polkamarkt_runtime}")" -lt 9 ] ||
   [ "$(/usr/bin/grep -Fc 'try validateMutationFlags()' "${polkamarkt_runtime}")" -ne 3 ] ||
   [ "$(/usr/bin/grep -Fc 'try self.validateMutationFlags()' "${polkamarkt_runtime}")" -ne 2 ]; then
    echo "error: live mutation capability refresh does not invalidate stale session authority"
    exit 1
fi

if ! /usr/bin/grep -Fq "LegacySoraIdentityValidator.validate" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "backup-manifest.json" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "hasVerifiedSafetyBackup(destinationVersion: targetVersion)" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "Most installed production wallets already use the current Core" "${storage_migrator}" ||
   [ "$(/usr/bin/grep -Fc 'try verifySafetyAttempt(' "${storage_migrator}")" -lt 3 ] ||
   ! /usr/bin/awk '
       /^[[:space:]]*func migrate\(/ {
           in_public_migrate = 1
           public_migrate_definitions++
       }
       in_public_migrate && /try lifecycleCoordinator\.withExclusiveAccess\(/ {
           saw_exclusive_access = 1
       }
       in_public_migrate && /try migrateLocked\(/ {
           public_locked_calls++
           if (!saw_exclusive_access) { invalid = 1 }
       }
       /^[[:space:]]*private func migrateLocked\(/ {
           in_public_migrate = 0
           in_locked_migrate = 1
           locked_migrate_definitions++
       }
       in_locked_migrate && /let snapshot = WalletNetworkSnapshot\(/ {
           saw_expected_snapshot = 1
       }
       in_locked_migrate && /try verifyLegacyAccounts\(accounts, in: snapshot\)/ {
           saw_expected_snapshot_verification = 1
       }
       in_locked_migrate && saw_expected_snapshot &&
           saw_expected_snapshot_verification &&
           /^[[:space:]]*if let current \{$/ {
           current_unwraps++
           current_unwrap_line = NR
       }
       in_locked_migrate && /try verifyExistingNexusChildren\(/ {
           reconciliation_calls++
           if (current_unwrap_line != NR - 1 ||
               settings_version_writes != 0 || stage_calls != 0) {
               invalid = 1
           }
           in_reconciliation_call = 1
       }
       in_locked_migrate && in_reconciliation_call && /against: snapshot/ {
           reconciliation_targets_snapshot = 1
           in_reconciliation_call = 0
       }
       in_locked_migrate && /^[[:space:]]*if let current,$/ {
           equality_fast_path = 1
           if (reconciliation_calls != 1) { invalid = 1 }
       }
       in_locked_migrate && /settings\.walletNetworkStoreVersion =/ {
           settings_version_writes++
           if (reconciliation_calls != 1 || !equality_fast_path) {
               invalid = 1
           }
       }
       in_locked_migrate && /try store\.stageAndActivate\(snapshot\)/ {
           stage_calls++
           if (reconciliation_calls != 1 ||
               settings_version_writes != 1) {
               invalid = 1
           }
       }
       in_locked_migrate && /^[[:space:]]*private static func wipeSensitive\(/ {
           in_locked_migrate = 0
       }
       /private func verifyExistingNexusChildren\(/ {
           in_reconciliation = 1
           reconciliation_definitions++
       }
       in_reconciliation &&
           index($0, "currentWallets.values.allSatisfy({ $0.count == 1 })") {
           current_wallet_cardinality = 1
       }
       in_reconciliation &&
           index($0, "currentAccounts.values.allSatisfy({ $0.count == 1 })") {
           current_account_cardinality = 1
       }
       in_reconciliation &&
           index($0, "expectedWallets.values.allSatisfy({ $0.count == 1 })") {
           expected_wallet_cardinality = 1
       }
       in_reconciliation &&
           index($0, "expectedAccounts.values.allSatisfy({ $0.count == 1 })") {
           expected_account_cardinality = 1
       }
       in_reconciliation &&
           index($0, "let expectedWallet = expectedWallets[wallet.id]?.first") {
           expected_wallet_lookup = 1
       }
       in_reconciliation && /expectedWallet\.secretSource == wallet\.secretSource/ {
           source_continuity = 1
           if (!current_wallet_cardinality ||
               !current_account_cardinality ||
               !expected_wallet_cardinality ||
               !expected_account_cardinality ||
               !expected_wallet_lookup) {
               invalid = 1
           }
       }
       in_reconciliation && /let storedChildren = current\.accounts\.filter/ {
           saw_child_reconciliation = 1
           if (!source_continuity) { invalid = 1 }
       }
       in_reconciliation && /private func validateLegacyIdentity\(/ {
           in_reconciliation = 0
       }
       END {
           valid = public_migrate_definitions == 1 &&
               public_locked_calls == 1 &&
               locked_migrate_definitions == 1 &&
               saw_expected_snapshot &&
               saw_expected_snapshot_verification &&
               current_unwraps == 1 &&
               reconciliation_calls == 1 &&
               reconciliation_targets_snapshot &&
               equality_fast_path &&
               settings_version_writes == 2 &&
               stage_calls == 1 &&
               reconciliation_definitions == 1 &&
               source_continuity &&
               saw_child_reconciliation
           exit(valid && !invalid ? 0 : 1)
       }
   ' "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "beforeSafetyActivationVerification" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "expectedState: .inventoryVerified" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "expectedState: .stagingVerified" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "journal.safetyArtifacts == expectedArtifacts" "${storage_migrator}" ||
   ! /usr/bin/grep -Fq "retainedSourceContinuityCases" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "watchOnlyToSigningSettings" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "walletNetworkBytes(at" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testRetainedMultiAccountMigrationPreservesOrderAndSelection" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testRetainedVersionTwoCoreDataGetsVerifiedSafetySnapshotWithoutWalletRewrite" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testRetainedVersionTwoMultiAccountSafetySnapshotPreservesInventoryAndSelection" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testTamperedCurrentSchemaSafetySnapshotFailsClosedWithoutTouchingLiveWallet" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testCurrentSchemaSafetyArtifactTamperBeforeActivationFailsClosed" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "testMappedSchemaSafetyArtifactTamperBeforeActivationRestoresLegacyStore" "${modernization_tests}"; then
    echo "error: pre-activation wallet identity or verified backup gate is missing"
    exit 1
fi

if /usr/bin/grep -Fq "createSilentImportInteractor" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "didDecideLegacyWalletUpgrade" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "performLegacyWalletUpgrade" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "shouldDeferStorageMigration" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "LegacyWalletUpgradePolicy.shouldDeferStorageMigration" "${splash_interactor}" ||
   ! /usr/bin/grep -Fq "Set(try keychain.allKeyIdentifiers())" "${splash_interactor}" ||
   ! /usr/bin/grep -Fq 'keyIdentifiers.contains("privateKey")' "${root_interactor}" ||
   ! /usr/bin/grep -Fq "expectedEntropyDigest" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "LegacyWalletUpgradeDisplayNameResolver" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "expectedDisplayName" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "LegacyWalletUpgradeSecretRetention" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "activeSnapshot: current" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "entropy = try keystore.loadIfKeyExists(scopedEntropyTag)" "${wallet_network_model}" ||
   ! /usr/bin/grep -Fq "prepared.discard()" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "scopedTags.allSatisfy" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "let expectedNetworks: Set<NetworkId>" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "legacyUpgradeSnapshotLoader" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "legacyUpgradeUnresolvedCommitLoader" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "legacyUpgradeInteractorFactory" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "if legacyUpgradeSelectedAccount() == nil" "${root_interactor}" ||
   /usr/bin/grep -Fq "if !settings.hasSelectedAccount" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "preparedAccountPersistence" "${account_import}" ||
   ! /usr/bin/grep -Fq "lifecycleCoordinator: WalletLifecycleCoordinator = .shared" "${account_import_commit}" ||
   ! /usr/bin/grep -Fq "consumeWithoutPersisting(" "${account_import_factory}" ||
   ! /usr/bin/grep -Fq "walletAccountCommitJournalStoreFactory" "${selected_wallet_settings}" ||
   ! /usr/bin/grep -Fq "WalletAccountCommitJournalStore()" "${root_interactor}" ||
   ! /usr/bin/grep -Fq "testLegacyWalletUpgradeRequiresExplicitUnambiguousLegacyOnlyState" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "exerciseFullLegacyWalletUpgrade(" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "mapper: AnyCoreDataMapper(AccountItemMapper())" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "(wordCount: 12, entropyBytes: 16)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "(wordCount: 15, entropyBytes: 20)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "(wordCount: 24, entropyBytes: 32)" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "corruptCommitJournal: true" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "terminalJournal.stage, .activated" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".coreDataCommitted" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "rawSeedSnapshot" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "watchOnlySnapshot" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "originalValues" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "originalIdentifiers" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "expectedKeypair" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "preMigrationIdentifiers" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "migratedSnapshot.accounts.map" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "secretOnlySnapshot" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq ".legacySecret" "${modernization_tests}" ||
   ! /usr/bin/grep -Fq "Continue protected upgrade" "${root_wireframe}" ||
   ! /usr/bin/grep -Fq "original Keychain entry will not be deleted or replaced" "${root_wireframe}"; then
    echo "error: legacy wallet upgrade is not explicit, journaled, and lossless"
    exit 1
fi

echo "Verified reviewed IrohaSwift and NoritoBridge identities."
