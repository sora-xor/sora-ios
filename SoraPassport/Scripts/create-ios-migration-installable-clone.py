#!/usr/bin/env python3
"""Create an observed-only installable clone of the exact production IPA app.

The clone is never a rebuilt application.  This controller extracts the exact
App Store candidate, replaces only its provisioning/signature material, signs
it for one registered retained device, and then requires the separately bound
canonical projector to prove equality of every non-signature byte and every
non-signing entitlement before publishing a non-authorizing receipt.
"""

from __future__ import annotations

import datetime
import hashlib
import importlib.util
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTROLLER_PATH = ROOT / "SoraPassport/Scripts/run-ios-migration-exact-ipa-evidence.py"
PROJECTOR_PATH = ROOT / "SoraPassport/Scripts/derive-ios-migration-test-host.py"
CONTRACT_ID = "sora-ios-wallet-migration-installable-clone-v1"
NONAUTHORIZING_BLOCKER = (
    "Observed installable clone only: no rebuilt app is accepted; this controller cannot "
    "authorize, review, qualify, "
    "sequence, promote, upload, or enable a release."
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
SAFE_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
    "TMPDIR": "/private/tmp",
}
MAX_PROFILE_BYTES = 16 * 1024 * 1024
TEAM_IDENTIFIER = "YLWWUD25VZ"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"


class CloneError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise CloneError(message)


def load_controller() -> Any:
    metadata = os.lstat(CONTROLLER_PATH)
    if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        fail("exact-IPA controller source is absent or symbolic")
    spec = importlib.util.spec_from_file_location("sora_exact_ipa_controller", CONTROLLER_PATH)
    if spec is None or spec.loader is None:
        fail("exact-IPA controller source cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    final = os.lstat(CONTROLLER_PATH)
    if module.stable_identity(metadata) != module.stable_identity(final):
        fail("exact-IPA controller source changed while being loaded")
    return module


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def decode_profile(raw: bytes, output: Path) -> dict[str, Any]:
    temporary = output / ".profile-input.mobileprovision"
    descriptor = os.open(
        temporary,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
    )
    try:
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                fail("provisioning profile could not be staged")
            view = view[written:]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    result = subprocess.run(
        ["/usr/bin/security", "cms", "-D", "-i", str(temporary)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_ENV,
        timeout=30,
    )
    if result.returncode != 0 or not result.stdout or len(result.stdout) > MAX_PROFILE_BYTES:
        fail("registered-device provisioning profile cannot be decoded")
    try:
        profile = plistlib.loads(result.stdout)
    except plistlib.InvalidFileException as error:
        fail(f"registered-device provisioning profile is invalid: {error}")
    if type(profile) is not dict:
        fail("registered-device provisioning profile is not a dictionary")
    return profile


def entitlement_group_array(
    entitlements: dict[str, Any], key: str, label: str, *, required: bool = False
) -> list[str]:
    if key not in entitlements:
        if required:
            fail(f"{label} lacks {key}")
        return []
    value = entitlements.get(key)
    if (
        type(value) is not list
        or not value
        or len(value) > 256
        or any(
            type(group) is not str
            or not group
            or len(group.encode("utf-8")) > 512
            for group in value
        )
        or len(set(value)) != len(value)
    ):
        fail(f"{label} {key} is not one ordered, bounded string array")
    return list(value)


def effective_keychain_access_groups(
    entitlements: dict[str, Any], label: str
) -> list[str]:
    application_id = entitlements.get("application-identifier")
    if type(application_id) is not str or not application_id:
        fail(f"{label} lacks one application identifier")
    candidates = (
        entitlement_group_array(entitlements, "keychain-access-groups", label)
        + [application_id]
        + entitlement_group_array(
            entitlements, "com.apple.security.application-groups", label
        )
    )
    effective: list[str] = []
    seen: set[str] = set()
    for group in candidates:
        if group not in seen:
            seen.add(group)
            effective.append(group)
    return effective


def profile_authorizes_group(group: str, profile_groups: list[str]) -> bool:
    team_wildcard = f"{TEAM_IDENTIFIER}.*"
    return any(
        candidate == group
        or (
            candidate == team_wildcard
            and group.startswith(f"{TEAM_IDENTIFIER}.")
        )
        for candidate in profile_groups
    )


def validate_profile(
    profile: dict[str, Any],
    signing_identity: str,
    registered_device_udid: str,
    production_entitlements: dict[str, Any],
) -> dict[str, Any]:
    profile_entitlements = profile.get("Entitlements")
    certificates = profile.get("DeveloperCertificates")
    devices = profile.get("ProvisionedDevices")
    expiration = profile.get("ExpirationDate")
    team_ids = profile.get("TeamIdentifier")
    application_id = f"{TEAM_IDENTIFIER}.{BUNDLE_IDENTIFIER}"
    if (
        type(profile_entitlements) is not dict
        or type(production_entitlements) is not dict
        or type(certificates) is not list
        or not certificates
        or any(type(item) is not bytes for item in certificates)
        or type(devices) is not list
        or any(type(item) is not str for item in devices)
        or registered_device_udid not in devices
        or profile.get("ProvisionsAllDevices") is True
        or type(expiration) is not datetime.datetime
        or expiration.replace(tzinfo=datetime.timezone.utc)
        <= datetime.datetime.now(datetime.timezone.utc)
        or type(team_ids) is not list
        or TEAM_IDENTIFIER not in team_ids
        or profile_entitlements.get("application-identifier")
        not in (application_id, f"{TEAM_IDENTIFIER}.*")
        or profile_entitlements.get("com.apple.developer.team-identifier")
        != TEAM_IDENTIFIER
        or (
            "get-task-allow" in profile_entitlements
            and type(profile_entitlements["get-task-allow"]) is not bool
        )
        or production_entitlements.get("application-identifier") != application_id
        or production_entitlements.get("com.apple.developer.team-identifier")
        != TEAM_IDENTIFIER
        or any(
            key in production_entitlements
            for key in ("aps-environment", "beta-reports-active", "get-task-allow")
        )
    ):
        fail("provisioning profile is not one reviewed registered-device profile")
    certificate_hashes = {hashlib.sha1(value).hexdigest() for value in certificates}
    if signing_identity not in certificate_hashes:
        fail("signing identity is not authorized by the registered-device profile")
    effective_groups = effective_keychain_access_groups(
        production_entitlements, "production-derived clone entitlements"
    )
    profile_groups = entitlement_group_array(
        profile_entitlements,
        "keychain-access-groups",
        "registered-device provisioning profile",
        required=True,
    ) + entitlement_group_array(
        profile_entitlements,
        "com.apple.security.application-groups",
        "registered-device provisioning profile",
    )
    if any(
        not profile_authorizes_group(group, profile_groups)
        for group in effective_groups
    ):
        fail("registered-device profile does not authorize every effective access group")
    for key, value in production_entitlements.items():
        if key in {
            "application-identifier",
            "com.apple.developer.team-identifier",
            "keychain-access-groups",
            "com.apple.security.application-groups",
        }:
            continue
        if profile_entitlements.get(key) != value:
            fail("registered-device profile does not authorize a preserved entitlement")
    # Return only the production-signed projection.  Profile-only TEAM.* and
    # com.apple.token authorization values must never become clone entitlements.
    return dict(production_entitlements)


def replace_profile(app: Path, raw: bytes) -> None:
    destination = app / "embedded.mobileprovision"
    replacement = app / ".embedded.mobileprovision.replacement"
    descriptor = os.open(
        replacement,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o644,
    )
    try:
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                fail("registered-device profile replacement could not be written")
            view = view[written:]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    before = os.lstat(destination)
    if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
        fail("production embedded provisioning profile is not replaceable")
    os.replace(replacement, destination)
    directory = os.open(app, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def signing_targets(app: Path) -> list[Path]:
    targets: list[Path] = []
    for directory, directory_names, file_names in os.walk(app, topdown=True, followlinks=False):
        base = Path(directory)
        directory_names.sort(key=lambda value: value.encode("utf-8"))
        file_names.sort(key=lambda value: value.encode("utf-8"))
        for name in directory_names:
            path = base / name
            metadata = os.lstat(path)
            if not stat.S_ISDIR(metadata.st_mode):
                fail("installable clone contains a linked or special directory")
            if name.endswith((".framework", ".appex", ".xpc")):
                targets.append(path)
        for name in file_names:
            path = base / name
            metadata = os.lstat(path)
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
                fail("installable clone contains a linked or special file")
            if name.endswith(".dylib"):
                targets.append(path)
    return sorted(set(targets), key=lambda path: (len(path.parts), path.as_posix()), reverse=True)


def codesign(
    app: Path,
    signing_identity: str,
    entitlements: dict[str, Any],
    output: Path,
) -> None:
    for index, target in enumerate(signing_targets(app)):
        result = subprocess.run(
            [
                "/usr/bin/codesign",
                "--force",
                "--sign",
                signing_identity,
                "--timestamp=none",
                "--preserve-metadata=identifier,entitlements,requirements,flags,runtime",
                str(target),
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_ENV,
            timeout=120,
        )
        if result.returncode != 0 or len(result.stderr) > 4 * 1024 * 1024:
            fail(f"nested installable-clone signature failed at target {index}")
    entitlement_path = output / ".registered-device-entitlements.plist"
    entitlement_raw = plistlib.dumps(entitlements, fmt=plistlib.FMT_XML, sort_keys=True)
    descriptor = os.open(
        entitlement_path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
    )
    try:
        view = memoryview(entitlement_raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                fail("registered-device entitlement projection could not be written")
            view = view[written:]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    result = subprocess.run(
        [
            "/usr/bin/codesign",
            "--force",
            "--sign",
            signing_identity,
            "--timestamp=none",
            "--generate-entitlement-der",
            "--entitlements",
            str(entitlement_path),
            str(app),
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_ENV,
        timeout=180,
    )
    if result.returncode != 0 or len(result.stderr) > 4 * 1024 * 1024:
        fail("main installable-clone signature failed")
    verification = subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_ENV,
        timeout=120,
    )
    if verification.returncode != 0:
        fail("installable clone does not pass codesign --deep --strict")


def load_canonical_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{label} is invalid JSON: {error}")
    if type(value) is not dict or canonical_json(value) != raw:
        fail(f"{label} is not exact canonical JSON")
    return value, raw


def create(
    *,
    ipa_raw: str,
    profile_raw: str,
    signing_identity: str,
    registered_device_udid: str,
    output_raw: str,
    qualification_contract_sha: str,
) -> dict[str, str]:
    controller = load_controller()
    controller.require_sha256(qualification_contract_sha, "qualification contract")
    if SHA1_RE.fullmatch(signing_identity) is None:
        fail("registered-device signing identity must be one lowercase SHA-1 certificate ID")
    controller.safe_device_id(registered_device_udid)
    output = controller.create_private_output_root(output_raw, "installable clone output")
    source_hashes = {
        path: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (CONTROLLER_PATH, PROJECTOR_PATH, Path(__file__).resolve())
    }
    profile_bytes, profile_sha, _ = controller.read_regular(
        profile_raw, MAX_PROFILE_BYTES, "registered-device provisioning profile"
    )
    profile = decode_profile(profile_bytes, output)
    identity = controller.inspect_and_extract_ipa(ipa_raw, output / "installable-app")
    entitlements = validate_profile(
        profile,
        signing_identity,
        registered_device_udid,
        identity["cloneSigningEntitlements"],
    )
    app = Path(identity["appPath"])
    replace_profile(app, profile_bytes)
    codesign(app, signing_identity, entitlements, output)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    signed_identity = controller.inspect_production_signature_identity(app, info)
    installed_tree_sha, installed_tree_bytes, installed_file_count = (
        controller.complete_tree_record(
            app, controller.RAW_APP_TREE_PREFIX, "installable application tree"
        )
    )
    executable = app / info["CFBundleExecutable"]
    installed_executable_sha, installed_executable_bytes = (
        controller.hash_extracted_regular(
            executable, controller.MAX_FILE_BYTES, "installable application executable"
        )
    )
    projection_receipt = output / "canonical-projection-receipt-v2.json"
    result = subprocess.run(
        [
            "/usr/bin/python3",
            "-I",
            "-S",
            str(PROJECTOR_PATH),
            "--repository-root",
            str(ROOT),
            "--derive",
            "--ipa",
            ipa_raw,
            "--test-host",
            str(app),
            "--output",
            str(projection_receipt),
            "--qualification-contract-sha",
            qualification_contract_sha,
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=SAFE_ENV,
        timeout=600,
    )
    if result.returncode != 0 or len(result.stdout) > 64 * 1024 or len(result.stderr) > 4 * 1024 * 1024:
        fail("installable clone does not satisfy canonical production projection")
    projection, projection_raw = load_canonical_json(
        projection_receipt, "canonical projection receipt"
    )
    production_projection = projection["productionIpa"]["canonicalProjection"]
    installed_projection = projection["releaseTestHost"]["canonicalProjection"]
    production_projection_sha = production_projection["recordSha256"]
    installed_projection_sha = installed_projection["recordSha256"]
    if (
        production_projection_sha != installed_projection_sha
        or projection["productionIpa"]["sha256"] != identity["ipaSha256"]
        or projection["releaseTestHost"]["rawTree"]["recordSha256"]
        != installed_tree_sha
        or projection["releaseTestHost"]["rawExecutableSha256"]
        != installed_executable_sha
        or signed_identity["applicationIdentifier"]
        != f"{TEAM_IDENTIFIER}.{BUNDLE_IDENTIFIER}"
    ):
        fail("canonical projection receipt differs from the exact clone bytes")
    final_sources = {
        path: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in source_hashes
    }
    if final_sources != source_hashes:
        fail("installable-clone source changed during derivation")
    projector_source_sha = source_hashes[PROJECTOR_PATH]
    receipt = {
        "schemaVersion": 1,
        "contractId": CONTRACT_ID,
        "platform": "ios",
        "status": "observed",
        "releaseAuthorized": False,
        "qualificationContractSha256": qualification_contract_sha,
        "productionIpaSha256": identity["ipaSha256"],
        "productionCanonicalProjectionSha256": production_projection_sha,
        "installedAppRawTreeSha256": installed_tree_sha,
        "installedAppRawTreeRecordByteCount": installed_tree_bytes,
        "installedAppFileCount": installed_file_count,
        "installedCanonicalProjectionSha256": installed_projection_sha,
        "installedExecutableSha256": installed_executable_sha,
        "installedExecutableByteCount": installed_executable_bytes,
        "canonicalProjectionReceiptSha256": hashlib.sha256(projection_raw).hexdigest(),
        "canonicalProjectorSourceSha256": projector_source_sha,
        "registeredDeviceProvisioningProfileSha256": profile_sha,
        "registeredDeviceSigningCertificateSha1": signing_identity,
        "registeredDeviceUdidSha256": hashlib.sha256(
            registered_device_udid.encode("utf-8")
        ).hexdigest(),
        "checks": {
            "exactProductionIpaExtracted": True,
            "registeredDeviceProfileVerified": True,
            "productionIdentityPreserved": True,
            "canonicalProjectionEqual": True,
            "installedCloneCodeSignatureDeepStrictVerified": True,
            "rebuiltApplicationAccepted": False,
            "qualificationCreated": False,
        },
        "blockingReasons": [NONAUTHORIZING_BLOCKER],
    }
    receipt_raw = canonical_json(receipt)
    controller.validate_installable_clone_receipt(receipt_raw)
    receipt_sha = controller.write_new_file(
        output / "installable-clone-receipt-v1.json", receipt_raw
    )
    controller.write_new_file(
        output / ".complete",
        canonical_json(
            {
                "schemaVersion": 1,
                "contractId": "sora-ios-wallet-migration-installable-clone-complete-v1",
                "installableCloneReceiptSha256": receipt_sha,
                "releaseAuthorized": False,
            }
        ),
    )
    return {
        "installableCloneReceiptSha256": receipt_sha,
        "qualificationContractSha256": qualification_contract_sha,
        "productionIpaSha256": identity["ipaSha256"],
        "installedAppRawTreeSha256": installed_tree_sha,
        "installedExecutableSha256": installed_executable_sha,
        "productionCanonicalProjectionSha256": production_projection_sha,
        "installedCanonicalProjectionSha256": installed_projection_sha,
        "canonicalProjectionReceiptSha256": hashlib.sha256(projection_raw).hexdigest(),
        "canonicalProjectorSourceSha256": projector_source_sha,
        "registeredDeviceUdidSha256": hashlib.sha256(
            registered_device_udid.encode("utf-8")
        ).hexdigest(),
    }


def lint_contract() -> None:
    controller = load_controller()
    if (
        ROOT.name != "sora-ios"
        or not CONTROLLER_PATH.is_file()
        or not PROJECTOR_PATH.is_file()
        or CONTRACT_ID != "sora-ios-wallet-migration-installable-clone-v1"
        or controller.INSTALLABLE_CLONE_CONTRACT_ID != CONTRACT_ID
        or len(controller.REQUEST_KEYS) != 26
        or len(controller.INSTALLABLE_CLONE_RECEIPT_KEYS) != 21
        or controller.CLONE_OMITTED_SIGNING_ENTITLEMENTS
        != frozenset(
            {"aps-environment", "beta-reports-active", "get-task-allow"}
        )
        or not controller.CLONE_BOUND_AUTHORIZATION_KEYS.issubset(
            controller.REQUEST_KEYS
        )
        or controller.INSTALLABLE_CLONE_NONAUTHORIZING_BLOCKER
        != NONAUTHORIZING_BLOCKER
        or "rebuilt" not in NONAUTHORIZING_BLOCKER.lower()
        or "qualify" not in NONAUTHORIZING_BLOCKER.lower()
    ):
        fail("installable-clone controller contract is incomplete")


def main(argv: list[str]) -> int:
    try:
        if argv == ["--lint-contract"]:
            lint_contract()
            print("iOS migration installable-clone controller contract: OK")
            return 0
        if (
            len(argv) == 13
            and argv[0] == "--create"
            and argv[1] == "--ipa"
            and argv[3] == "--provisioning-profile"
            and argv[5] == "--signing-identity-sha1"
            and argv[7] == "--registered-device-udid"
            and argv[9] == "--output-root"
            and argv[11] == "--qualification-contract-sha"
        ):
            lint_contract()
            result = create(
                ipa_raw=argv[2],
                profile_raw=argv[4],
                signing_identity=argv[6],
                registered_device_udid=argv[8],
                output_raw=argv[10],
                qualification_contract_sha=argv[12],
            )
            print(" ".join(f"{key}={value}" for key, value in result.items()))
            return 0
        fail(
            "usage: create-ios-migration-installable-clone.py --lint-contract | "
            "--create --ipa /private/Sora.ipa --provisioning-profile /private/profile.mobileprovision "
            "--signing-identity-sha1 40hex --registered-device-udid UDID "
            "--output-root /private/fresh-clone --qualification-contract-sha SHA256"
        )
    except (CloneError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
