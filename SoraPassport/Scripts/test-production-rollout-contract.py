#!/usr/bin/env python3
"""Hermetic success and mutation coverage for the iOS production rollout gate.

The real rollout trust root intentionally remains blocked. This test copies the
validator into an isolated temporary release tree, generates an ephemeral P-256
controller, creates a tiny validator-valid IPA, signs strict synthetic evidence,
and exercises the complete 1 -> 5 -> 25 -> 100 contract without network access.
"""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


SOURCE_ROOT = Path(__file__).resolve().parents[2]
ROLLOUT_SHELL = SOURCE_ROOT / "SoraPassport/Scripts/verify-production-rollout.sh"
ROLLOUT_JSON = SOURCE_ROOT / "SoraPassport/Scripts/verify-production-rollout-json.py"
FUNDED_CANARY_SHELL = SOURCE_ROOT / "SoraPassport/Scripts/verify-funded-nexus-canary.sh"
FUNDED_CANARY_JSON = SOURCE_ROOT / "SoraPassport/Scripts/verify-funded-nexus-canary-json.py"
CANDIDATE_TEMPLATE = SOURCE_ROOT / "Fixtures/Modernization/production-rollout-candidate.blocked.json"
ADVANCEMENT_TEMPLATE = SOURCE_ROOT / "Fixtures/Modernization/production-rollout-advancement.blocked.json"
TAIRA_CANARY_TEMPLATE = SOURCE_ROOT / "Fixtures/Modernization/taira-funded-canary.json"
MINAMOTO_CANARY_TEMPLATE = SOURCE_ROOT / "Fixtures/Modernization/minamoto-funded-canary.json"
FUNDED_CANARY_TRUST = SOURCE_ROOT / "Fixtures/Modernization/funded-nexus-canary-trust.json"
IROHA_READINESS = SOURCE_ROOT / "Fixtures/Modernization/iroha-production-send-readiness.json"
TAIRA_DEPLOYMENT_VALIDATOR = SOURCE_ROOT / "SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
TAIRA_DEPLOYMENT_BLOCKED = SOURCE_ROOT / "Fixtures/Modernization/ios-taira-deployment-manifest.blocked.json"

MIGRATION_ADMISSION_REGRESSION_STUB = """#!/bin/sh
set -eu
if [ "$#" -eq 1 ] && [ "$1" = "--lint-contract" ]; then
    /usr/bin/printf 'synthetic migration admission contract: OK\\n'
    exit 0
fi
if [ "$#" -ne 2 ] || [ "$1" != "--verify-qualified-ipa" ]; then
    /usr/bin/printf 'error: invalid synthetic migration admission arguments\\n' >&2
    exit 1
fi
candidate="$2"
expected_receipt="${SORA_ROLLOUT_REGRESSION_MIGRATION_RECEIPT_SHA256:?missing synthetic migration receipt}"
expected_ipa="${SORA_ROLLOUT_REGRESSION_MIGRATION_IPA_SHA256:?missing synthetic migration IPA identity}"
test -f "${candidate}"
test ! -L "${candidate}"
actual_ipa="$(/usr/bin/shasum -a 256 "${candidate}" | /usr/bin/awk '{print $1}')"
test "${actual_ipa}" = "${expected_ipa}"
/usr/bin/printf 'receiptSha256=%s ipaSha256=%s\\n' "${expected_receipt}" "${actual_ipa}"
"""

OPENSSL = Path("/usr/bin/openssl")
SHELL = Path("/bin/sh")
SAFE_TOOL_ENV = {
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
}
PRIVATE_TMP = Path("/private/tmp")

CONTROLLER_ID = "synthetic-ios-rollout-controller"
SOURCE_REVISION = "1234567890abcdef1234567890abcdef12345678"
SORA2_REVISION = "411dcdb70c5c00b21482a44d02334840d5f338c6"
RUNTIME_METADATA_SHA256 = "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf"
SOURCE_ENTITLEMENTS_SHA256 = "97704a8960b4facceef54397a08fb5d0a456247c3627359215aa2a27df22656c"
SORA2_GENESIS_HASH = "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
BUNDLE_IDENTIFIER = "co.jp.soramitsu.sora"
DEVELOPMENT_TEAM = "YLWWUD25VZ"
APPLICATION_IDENTIFIER = f"{DEVELOPMENT_TEAM}.{BUNDLE_IDENTIFIER}"
APP_VERSION = "9.9.9-regression"
BUILD_NUMBER = "999999"
APP_STORE_BUILD_IDENTIFIER = "synthetic-app-store-build-999999"
CONFIG_REVISION = "synthetic-mobile-config-v1"
LEGACY_PI_V2_CONTRACT_ID_NEGATIVE_TEST_ONLY = "sora-pi-production-capability-probe-v2"
MINAMOTO_CHAIN_ID = "00000000-0000-0000-0000-000000000753"
TAIRA_CHAIN_ID = "fc56984b-2be7-431d-840e-21514d1883f0"
TAIRA_RETIRED_CHAIN_ID = "809574f5-fee7-5e69-bfcf-52451e42d50f"
TAIRA_DEPLOYMENT: dict[str, Any] | None = None
TAIRA_DEPLOYMENT_ENVIRONMENT: dict[str, str] = {}
MINIMUM_DWELL_SECONDS = 172_800
GATE_SPACING_SECONDS = MINIMUM_DWELL_SECONDS + 3
HARNESS_TIMEOUT_SECONDS = 1200
TARGETS = (1, 5, 25, 100)
TRANSITIONS = {1: (1, 0), 5: (2, 1), 25: (3, 5), 100: (4, 25)}
FUNDED_STAGE_ASSERTIONS: dict[str, dict[str, bool | str]] = {
    "receive": {
        "networkScopedAddressValidated": True,
        "discriminantValidated": True,
        "fundedXorObserved": True,
    },
    "sendValidation": {
        "recipientNetworkValidated": True,
        "amountPrecisionValidated": True,
        "xorBalanceValidated": True,
        "xorFeeBalanceValidated": True,
    },
    "fee": {
        "positiveFeeObserved": True,
        "feeBoundToCanonicalPayload": True,
        "feeRevalidatedBeforeSigning": True,
    },
    "signing": {
        "candidateSignerBindingMatched": True,
        "oneUseReservationMatched": True,
        "osSecuredSigningObserved": True,
        "privateKeyExportObserved": False,
        "selectedWalletRevalidated": True,
        "selectedNetworkRevalidated": True,
        "selectedAccountRevalidated": True,
        "walletDeletionInactive": True,
        "liveFeatureFlagsRevalidated": True,
        "quoteIdentityRevalidated": True,
    },
    "submission": {
        "singleHandoffObserved": True,
        "oneUseReservationMatched": True,
        "localHashMatchedToriiReceipt": True,
        "durablePendingJournalObserved": True,
        "selectedNetworkRevalidated": True,
        "selectedAccountRevalidated": True,
        "walletDeletionInactive": True,
        "liveFeatureFlagsRevalidated": True,
        "exactSignedPayloadHandoffObserved": True,
        "failureClassification": "none",
    },
    "terminalStatusReadback": {
        "exactHashStatusQueried": True,
        "committedTerminalStatusObserved": True,
        "globalStateResolutionObserved": True,
        "positiveCommittedBlockHeightObserved": True,
    },
    "finalityReadback": {
        "freshChallengeBoundAttestationVerified": True,
        "canonicalNoritoRoundTripVerified": True,
        "attestationRouteMatched": True,
        "bundleRouteMatched": True,
        "reviewedVerifierBindingMatched": True,
        "trustedContextReceiptMatched": True,
        "genesisAndTipProofsVerified": True,
        "nodeAndAggregateSignaturesVerified": True,
        "singleStateViewVerified": True,
        "liveBoundedSequentialStatefulSuccessorChainVerified": True,
        "receiptBlockReadBack": True,
    },
    "balanceReadback": {
        "senderDeltaReconciled": True,
        "receiverDeltaReconciled": True,
        "feeDeltaReconciled": True,
    },
    "explorerReconciliation": {
        "networkScopedExplorerUsed": True,
        "committedTransactionObserved": True,
    },
    "historyReconciliation": {
        "completeFanoutObserved": True,
        "exactTransactionObservedOnce": True,
        "networkAssetAmountDirectionMatched": True,
    },
    "restartRecovery": {
        "coldRestartPerformed": True,
        "statusOnlyRecoveryObserved": True,
        "readOnlyCapabilityBoundaryObserved": True,
        "signingDuringRecoveryObserved": False,
        "resubmissionDuringRecoveryObserved": False,
    },
}

_deadline: float | None = None


class HarnessFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class SignedEvidence:
    payload: Path
    signature: Path


@dataclass
class GateEvidence:
    target: int
    evaluated_at: int
    authorized_at: int
    pi: SignedEvidence
    rollout: SignedEvidence
    telemetry: SignedEvidence | None
    distribution: SignedEvidence | None


@dataclass
class CommonEvidence:
    ipa: Path
    qualification: SignedEvidence
    artifact: SignedEvidence
    candidate_sha256: str
    qualification_sha256: str
    artifact_sha256: str
    candidate_manifest_sha256: str
    keychain_groups_sha256: str
    candidate_binding_sha256: str
    funded_admission: SignedEvidence
    funded_taira: SignedEvidence
    funded_minamoto: SignedEvidence
    funded_trust_sha256: str
    funded_environment: dict[str, str]


@dataclass
class FundedEvidenceBundle:
    admission: SignedEvidence
    taira: SignedEvidence
    minamoto: SignedEvidence
    environment: dict[str, str]


@dataclass
class Mutation:
    stale_current_pi: bool = False
    false_mobile_config_health_bound_target: int | None = None
    false_history_block_height_contract_deployed_target: int | None = None
    legacy_pi_v2_target: int | None = None
    historical_pi_worker_lag_target: int | None = None
    rewritten_evaluation_binding_target: int | None = None
    delayed_authorization_target: int | None = None
    rewritten_cohort_candidate_target: int | None = None
    broken_link_target: int | None = None
    short_dwell_target: int | None = None
    backdated_dwell_target: int | None = None
    hard_stop_target: int | None = None
    wrong_app_store_target: int | None = None
    legacy_v2_target: int | None = None


@dataclass
class ChainEvidence:
    directory: Path
    target: int
    gates: dict[int, GateEvidence]
    common: CommonEvidence


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def synthetic_sha256(label: str) -> str:
    digest = sha256_bytes(f"sora-ios-rollout-regression:{label}".encode("utf-8"))
    if digest == "0" * 64:
        raise HarnessFailure("synthetic digest unexpectedly used the all-zero placeholder")
    return digest


def write_json(path: Path, value: dict[str, Any]) -> None:
    encoded = (json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True) + "\n").encode(
        "utf-8"
    )
    path.write_bytes(encoded)


def load_validator(path: Path, label: str) -> Any:
    module_name = f"sora_{label.replace('-', '_')}_{synthetic_sha256(str(path))[:12]}"
    specification = importlib.util.spec_from_file_location(module_name, path)
    if specification is None or specification.loader is None:
        raise HarnessFailure(f"cannot load {label} validator")
    module = importlib.util.module_from_spec(specification)
    sys.modules[module_name] = module
    specification.loader.exec_module(module)
    return module


def require_taira_epoch_order_rejection(
    *,
    validator: Path,
    admission: dict[str, Any],
    output: Path,
    current_epoch: int,
    label: str,
) -> None:
    mutated = copy.deepcopy(admission)
    mutated["current"]["deploymentEpoch"] = current_epoch
    write_json(output, mutated)
    os.chmod(output, 0o600)
    module = load_validator(validator, label)
    try:
        module.configure_authenticated_taira(str(output))
    except Exception as error:
        if "current Taira deployment epoch is not newer than retired" not in str(error):
            raise HarnessFailure(
                f"{label} rejected regressed Taira epochs for the wrong reason: {error}"
            ) from error
    else:
        raise HarnessFailure(f"{label} admitted a non-newer current Taira epoch")


def bounded_timeout(maximum_seconds: int) -> float:
    if _deadline is None:
        return float(maximum_seconds)
    remaining = _deadline - time.monotonic()
    if remaining <= 0:
        raise HarnessFailure(
            f"rollout regression exceeded its {HARNESS_TIMEOUT_SECONDS}-second aggregate timeout"
        )
    return min(float(maximum_seconds), remaining)


def run_tool(arguments: list[str], *, timeout: int = 45) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            arguments,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=bounded_timeout(timeout),
            env=SAFE_TOOL_ENV,
        )
    except subprocess.TimeoutExpired as error:
        raise HarnessFailure(f"timed out running {' '.join(arguments)}") from error


def require_tool_success(arguments: list[str]) -> None:
    result = run_tool(arguments)
    if result.returncode != 0:
        detail = (result.stdout + result.stderr).strip()
        raise HarnessFailure(f"tool failed ({' '.join(arguments)}): {detail}")


def sign_file(payload: Path, signature: Path, private_key: Path) -> None:
    require_tool_success(
        [
            str(OPENSSL),
            "dgst",
            "-sha256",
            "-sign",
            str(private_key),
            "-out",
            str(signature),
            str(payload),
        ]
    )


def write_signed_json(directory: Path, name: str, value: dict[str, Any], private_key: Path) -> SignedEvidence:
    payload = directory / f"{name}.json"
    signature = directory / f"{name}.sig"
    write_json(payload, value)
    sign_file(payload, signature, private_key)
    return SignedEvidence(payload=payload, signature=signature)


def privacy_contract() -> dict[str, Any]:
    return {
        "aggregateOnly": True,
        "accountIdentifiersIncluded": False,
        "addressesIncluded": False,
        "transactionIdentifiersIncluded": False,
        "phrasesOrSeedsIncluded": False,
        "privateKeysIncluded": False,
        "publicKeysIncluded": False,
        "rawSignedPayloadsIncluded": False,
        "perWalletRecordsIncluded": False,
        "deviceIdentifiersIncluded": False,
        "ipAddressesIncluded": False,
        "rawResponsesIncluded": False,
        "rawErrorsIncluded": False,
    }


def funded_privacy_contract() -> dict[str, Any]:
    return {
        "redactedAggregateEvidenceOnly": True,
        "accountIdentifiersIncluded": False,
        "addressesIncluded": False,
        "transactionIdentifiersIncluded": False,
        "phrasesOrSeedsIncluded": False,
        "privateKeysIncluded": False,
        "rawSignedPayloadsIncluded": False,
        "rawNetworkResponsesIncluded": False,
        "deviceIdentifiersIncluded": False,
        "operatorNamesIncluded": False,
    }


def canonical_scalar(value: bool | int | str) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    return str(value)


def canonical_digest(lines: list[str]) -> str:
    return sha256_bytes("\n".join(lines).encode("utf-8"))


def admitted_taira() -> dict[str, Any]:
    if TAIRA_DEPLOYMENT is None:
        raise HarnessFailure("synthetic Taira deployment was not admitted")
    return TAIRA_DEPLOYMENT


def build_tiny_ipa(path: Path) -> dict[str, Any]:
    taira = admitted_taira()
    info_plist = plistlib.dumps(
        {
            "CFBundleExecutable": "SoraRegression",
            "CFBundleIdentifier": BUNDLE_IDENTIFIER,
            "CFBundleName": "Sora Rollout Regression",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": APP_VERSION,
            "CFBundleVersion": BUILD_NUMBER,
            "MinimumOSVersion": "16.0",
            "SoraTairaDeploymentManifestSha256": taira["manifestSha256"],
            "SoraTairaDeploymentAdmissionSha256": taira["admissionSha256"],
            "SoraTairaCurrentChainId": taira["currentChainId"],
            "SoraTairaCurrentGenesisHash": taira["currentGenesisHash"],
            "SoraTairaCanonicalToriiBaseUrl": taira["canonicalToriiBaseUrl"],
            "SoraTairaPublicMcpEndpoint": taira["publicMcpEndpoint"],
        },
        fmt=plistlib.FMT_XML,
        sort_keys=True,
    )
    executable = b"\xcf\xfa\xed\xfeSORA-ROLLOUT-REGRESSION\n"
    provisioning = b"SYNTHETIC MOBILEPROVISION; NEVER A RELEASE CREDENTIAL\n"
    members = (
        ("Payload/SoraRegression.app/Info.plist", info_plist, 0o100644),
        ("Payload/SoraRegression.app/SoraRegression", executable, 0o100755),
        ("Payload/SoraRegression.app/embedded.mobileprovision", provisioning, 0o100644),
    )
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for name, payload, mode in members:
            info = zipfile.ZipInfo(name, date_time=(2026, 8, 8, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = mode << 16
            archive.writestr(info, payload)
    return {
        "sha256": sha256_file(path),
        "bytes": path.stat().st_size,
        "zipEntryCount": len(members),
        "uncompressedBytes": sum(len(payload) for _, payload, _ in members),
        "zipStructureQualified": True,
        "singleApplicationBundleQualified": True,
        "infoPlistSha256": sha256_bytes(info_plist),
        "executableSha256": sha256_bytes(executable),
        "embeddedProvisioningProfileSha256": sha256_bytes(provisioning),
    }


def build_common_evidence(
    directory: Path,
    private_key: Path,
    earliest_gate_epoch: int,
    *,
    funded_private_keys: dict[str, Path],
    funded_public_keys: dict[str, Path],
    funded_key_ids: dict[str, str],
    funded_trust_sha256: str,
    readiness_path: Path,
    funded_mutation: str | None = None,
) -> CommonEvidence:
    directory.mkdir(parents=True)
    ipa = directory / "candidate.ipa"
    ipa_identity = build_tiny_ipa(ipa)
    candidate_manifest_sha256 = synthetic_sha256("candidate-build-manifest")
    keychain_groups_sha256 = synthetic_sha256(f"keychain-groups:{APPLICATION_IDENTIFIER}")
    qualification_value = {
        "schemaVersion": 2,
        "contractId": "sora-ios-production-qualification-v2",
        "status": "qualified",
        "controllerId": CONTROLLER_ID,
        "recordedAtEpochSeconds": earliest_gate_epoch - 120,
        "sourceRevision": SOURCE_REVISION,
        "candidateBuildManifestSha256": candidate_manifest_sha256,
        "qualificationEvidenceManifestSha256": synthetic_sha256("qualification-evidence-manifest"),
        "releaseConfiguration": "Release",
        "hardGates": {
            "walletMigrationQualified": True,
            "sora2Runtime130Qualified": True,
            "minamotoSendQualified": True,
            "tairaSendQualified": True,
            "piIndexerQualified": True,
            "polkamarktQualified": True,
            "dependencyProvenanceQualified": True,
            "productionSignerQualified": True,
            "nativeCanaryQualified": True,
            "productionSigningQualified": True,
            "privacyTelemetryQualified": True,
        },
        "privacy": privacy_contract(),
    }
    qualification = write_signed_json(directory, "qualification", qualification_value, private_key)
    qualification_sha256 = sha256_file(qualification.payload)
    artifact_value = {
        "schemaVersion": 2,
        "contractId": "sora-ios-production-artifact-identity-v2",
        "status": "qualified",
        "controllerId": CONTROLLER_ID,
        "recordedAtEpochSeconds": earliest_gate_epoch - 60,
        "sourceRevision": SOURCE_REVISION,
        "candidateBuildManifestSha256": candidate_manifest_sha256,
        "productionQualificationReceiptSha256": qualification_sha256,
        "ipa": ipa_identity,
        "application": {
            "bundleIdentifier": BUNDLE_IDENTIFIER,
            "developmentTeam": DEVELOPMENT_TEAM,
            "applicationIdentifier": APPLICATION_IDENTIFIER,
            "appVersion": APP_VERSION,
            "buildNumber": BUILD_NUMBER,
            "appStoreBuildIdentifier": APP_STORE_BUILD_IDENTIFIER,
        },
        "signing": {
            "codesignVerified": True,
            "nestedCodeVerified": True,
            "provisioningProfileVerified": True,
            "distributionCertificateSha256": synthetic_sha256("distribution-certificate"),
            "provisioningProfileUuid": "12345678-1234-4abc-8def-1234567890ab",
            "provisioningProfileName": "Synthetic SORA Regression Profile",
            "inspectionToolSha256": synthetic_sha256("inspection-tool"),
            "codesignEvidenceSha256": synthetic_sha256("codesign-evidence"),
            "provisioningEvidenceSha256": synthetic_sha256("provisioning-evidence"),
            "sourceEntitlementsSha256": SOURCE_ENTITLEMENTS_SHA256,
            "signedEntitlementsSha256": synthetic_sha256("signed-entitlements"),
            "keychainAccessGroupsSha256": keychain_groups_sha256,
            "applicationIdentifierContinuityReviewed": True,
            "archivedEntitlementsMatched": True,
            "keychainAccessGroupsUnchanged": True,
            "appStoreSigningContinuityReviewed": True,
        },
        "runtime": {
            "sora2NetworkRevision": SORA2_REVISION,
            "runtimeSpecVersion": 130,
            "runtimeTransactionVersion": 130,
            "runtimeMetadataSha256": RUNTIME_METADATA_SHA256,
            "embeddedRuntimeContractSha256": synthetic_sha256("embedded-runtime-contract"),
        },
        "tairaDeployment": {
            key: admitted_taira()[key]
            for key in (
                "manifestSha256",
                "admissionSha256",
                "currentChainId",
                "currentGenesisHash",
                "canonicalToriiBaseUrl",
                "publicMcpEndpoint",
            )
        },
        "privacy": privacy_contract(),
    }
    artifact = write_signed_json(directory, "artifact", artifact_value, private_key)
    artifact_sha256 = sha256_file(artifact.payload)
    candidate_sha256 = ipa_identity["sha256"]
    funded = build_funded_evidence(
        directory=directory,
        controller_private_key=private_key,
        funded_private_keys=funded_private_keys,
        funded_public_keys=funded_public_keys,
        funded_key_ids=funded_key_ids,
        funded_trust_sha256=funded_trust_sha256,
        earliest_gate_epoch=earliest_gate_epoch,
        ipa_identity=ipa_identity,
        artifact_sha256=artifact_sha256,
        readiness_path=readiness_path,
        funded_mutation=funded_mutation,
    )
    funded_admission = funded.admission
    funded_taira = funded.taira
    funded_minamoto = funded.minamoto
    funded_admission_sha256 = sha256_file(funded_admission.payload)
    funded_taira_sha256 = sha256_file(funded_taira.payload)
    funded_minamoto_sha256 = sha256_file(funded_minamoto.payload)
    candidate_binding_sha256 = canonical_digest(
        [
            "platform=ios",
            f"candidateArtifactSha256={candidate_sha256}",
            f"artifactIdentityReceiptSha256={artifact_sha256}",
            f"productionQualificationReceiptSha256={qualification_sha256}",
            f"fundedNexusCanaryAdmissionReceiptSha256={funded_admission_sha256}",
            f"fundedTairaCanaryReceiptSha256={funded_taira_sha256}",
            f"fundedMinamotoCanaryReceiptSha256={funded_minamoto_sha256}",
            f"tairaDeploymentManifestSha256={admitted_taira()['manifestSha256']}",
            f"tairaDeploymentAdmissionSha256={admitted_taira()['admissionSha256']}",
            f"tairaCurrentChainId={admitted_taira()['currentChainId']}",
            f"tairaCurrentGenesisHash={admitted_taira()['currentGenesisHash']}",
            f"sourceRevision={SOURCE_REVISION}",
            f"candidateBuildManifestSha256={candidate_manifest_sha256}",
            f"bundleIdentifier={BUNDLE_IDENTIFIER}",
            f"developmentTeam={DEVELOPMENT_TEAM}",
            f"appVersion={APP_VERSION}",
            f"buildNumber={BUILD_NUMBER}",
            f"appStoreBuildIdentifier={APP_STORE_BUILD_IDENTIFIER}",
            f"sora2NetworkRevision={SORA2_REVISION}",
            "runtimeSpecVersion=130",
            "runtimeTransactionVersion=130",
            f"runtimeMetadataSha256={RUNTIME_METADATA_SHA256}",
        ]
    )
    return CommonEvidence(
        ipa=ipa,
        qualification=qualification,
        artifact=artifact,
        candidate_sha256=candidate_sha256,
        qualification_sha256=qualification_sha256,
        artifact_sha256=artifact_sha256,
        candidate_manifest_sha256=candidate_manifest_sha256,
        keychain_groups_sha256=keychain_groups_sha256,
        candidate_binding_sha256=candidate_binding_sha256,
        funded_admission=funded_admission,
        funded_taira=funded_taira,
        funded_minamoto=funded_minamoto,
        funded_trust_sha256=funded_trust_sha256,
        funded_environment=funded.environment,
    )


def pi_value(*, captured_at: int, worker_last_success: int, ordinal: int) -> dict[str, Any]:
    taira = admitted_taira()
    sora2_height = 10_000 + ordinal
    minamoto_height = 20_000 + ordinal
    taira_height = 30_000 + ordinal
    sora2_hash = synthetic_sha256(f"sora2-finalized-{sora2_height}")
    return {
        "schemaVersion": 3,
        "contractId": "sora-pi-production-capability-probe-v3",
        "status": "qualified",
        "controllerId": CONTROLLER_ID,
        "capturedAtEpochSeconds": captured_at,
        "endpoint": "https://pi.soramitsu.io/graphql",
        "privacy": privacy_contract(),
        "health": {
            "serviceId": "pi.soramitsu.io",
            "ecosystem": "sora2",
            "chainId": "sora:mainnet",
            "network": "mainnet",
            "readOnly": True,
            "workerReady": True,
            "genesisHash": SORA2_GENESIS_HASH,
            "runtimeSpecVersion": 130,
            "runtimeTransactionVersion": 130,
            "runtimeMetadataSha256": RUNTIME_METADATA_SHA256,
            "workerLatestFinalizedBlock": sora2_height,
            "workerLatestFinalizedBlockHash": sora2_hash,
            "canonicalRpcFinalizedBlockHash": sora2_hash,
            "workerLatestIndexedBlock": sora2_height,
            "workerLatestIndexedBlockHash": sora2_hash,
            "workerLag": 0,
            "workerLastSuccessfulIndexTimestamp": worker_last_success,
            "canonicalRpcCheckpointMatched": True,
        },
        "capabilities": {
            "configRevision": CONFIG_REVISION,
            "capturedAtEpochSeconds": captured_at,
            "mobileConfigHealthBound": True,
            "historyBlockHeightContractDeployed": True,
            "nexusAvailable": True,
            "nexusSendsAvailable": True,
            "polkamarktVisible": True,
            "polkamarktMutationsAvailable": True,
            "tairaDefaultVisible": True,
        },
        "networkCheckpoints": {
            "minamoto": {
                "networkId": "minamoto",
                "chainId": MINAMOTO_CHAIN_ID,
                "toriiEndpoint": "https://minamoto.sora.org",
                "i105Discriminant": 753,
                "genesisHash": synthetic_sha256("minamoto-genesis"),
                "finalizedHeight": minamoto_height,
                "finalizedBlockHash": synthetic_sha256(f"minamoto-finalized-{minamoto_height}"),
                "canonicalToriiMatched": True,
            },
            "taira": {
                "networkId": "taira",
                "chainId": taira["currentChainId"],
                "toriiEndpoint": taira["canonicalToriiBaseUrl"],
                "i105Discriminant": 369,
                "genesisHash": taira["currentGenesisHash"],
                "finalizedHeight": taira_height,
                "finalizedBlockHash": synthetic_sha256(f"taira-finalized-{taira_height}"),
                "canonicalToriiMatched": True,
            },
        },
    }


def build_funded_evidence(
    *,
    directory: Path,
    controller_private_key: Path,
    funded_private_keys: dict[str, Path],
    funded_public_keys: dict[str, Path],
    funded_key_ids: dict[str, str],
    funded_trust_sha256: str,
    earliest_gate_epoch: int,
    ipa_identity: dict[str, Any],
    artifact_sha256: str,
    readiness_path: Path,
    funded_mutation: str | None,
) -> FundedEvidenceBundle:
    """Build synthetic full-path evidence; none of it is production qualification."""

    taira = admitted_taira()
    reviewer_private = funded_private_keys["independentReviewer"]
    admission_evaluated_at = earliest_gate_epoch - 20
    started_at = admission_evaluated_at - 30
    completed_at = started_at + 15
    receipt_recorded_at = completed_at + 3
    reviewed_at = completed_at + 2
    finality_manifest_reviewed_at = (
        started_at + 1
        if funded_mutation == "retroactive-finality-trust"
        else started_at - 100
    )

    native_canary = write_signed_json(
        directory,
        "funded-native-signer-canary",
        {
            "contractId": "synthetic-reviewed-native-signer-canary-v1",
            "status": "qualified",
            "platform": "ios",
            "requiredNativeAbi": 21,
            "artifactClass": "synthetic-regression-only",
        },
        reviewer_private,
    )
    native_canary_sha256 = sha256_file(native_canary.payload)

    verifier_source_revision = "abcdef0123456789abcdef0123456789abcdef01"
    verifier_artifact_sha256 = synthetic_sha256("funded-finality-verifier-artifact")
    server_source_revision = "fedcba9876543210fedcba9876543210fedcba98"
    server_openapi_sha256 = synthetic_sha256("funded-finality-openapi")
    server_route_sha256 = synthetic_sha256("funded-finality-route-source")
    signer_adapter_source_sha256 = synthetic_sha256("funded-signer-adapter-source")
    signer_provider_source_sha256 = synthetic_sha256("funded-signer-provider-source")
    reviewed_native_artifact_sha256 = synthetic_sha256("funded-reviewed-native-artifact")
    finality_adapter_source_sha256 = synthetic_sha256("funded-finality-adapter-source")
    finality_provider_source_sha256 = synthetic_sha256("funded-finality-provider-source")

    network_trust: dict[str, SignedEvidence] = {}
    for network_id, chain_id in (
        ("taira", taira["currentChainId"]),
        ("minamoto", MINAMOTO_CHAIN_ID),
    ):
        trust_value = {
            "schemaVersion": 1,
            "contractId": "sora-ios-nexus-finality-trust-context-v1",
            "status": "qualified",
            "platform": "ios",
            "networkId": network_id,
            "chainId": chain_id,
            "reviewedAtEpochSeconds": finality_manifest_reviewed_at,
            "expectedNodeKeySha256": synthetic_sha256(f"{network_id}:node-key"),
            "expectedNodeBuildFingerprint": synthetic_sha256(f"{network_id}:node-build"),
            "expectedProtocolVersion": "iroha.v2",
            "expectedConsensusMode": "sumeragi.v2",
            "validatorRosterSha256": synthetic_sha256(f"{network_id}:validator-roster"),
            "quorumNumerator": 2,
            "quorumDenominator": 3,
            "canonicalSignedGenesisSha256": (
                taira["currentGenesisHash"]
                if network_id == "taira"
                else synthetic_sha256(f"{network_id}:signed-genesis")
            ),
            "genesisPublicKeySha256": synthetic_sha256(f"{network_id}:genesis-key"),
            "trustedFirstHeight": (
                100_000
                if funded_mutation == "trusted-first-height-above-finalized"
                and network_id == "taira"
                else 1
            ),
            "trustedFirstHeightContextId": synthetic_sha256(f"{network_id}:first-height-context"),
            "verifierSourceRevision": verifier_source_revision,
            "verifierArtifactSha256": verifier_artifact_sha256,
            "serverContractSourceRevision": server_source_revision,
            "serverOpenApiSha256": server_openapi_sha256,
            "serverRouteSourceSha256": server_route_sha256,
            "reviewerRole": "independent-reviewer",
            "reviewerKeyId": funded_key_ids["independentReviewer"],
            "privacy": funded_privacy_contract(),
        }
        network_trust[network_id] = write_signed_json(
            directory,
            f"funded-{network_id}-finality-trust",
            trust_value,
            reviewer_private,
        )

    taira_trust_sha256 = sha256_file(network_trust["taira"].payload)
    minamoto_trust_sha256 = sha256_file(network_trust["minamoto"].payload)
    finality_manifest = write_signed_json(
        directory,
        "funded-finality-trust-manifest",
        {
            "schemaVersion": 1,
            "contractId": "sora-ios-nexus-finality-trust-manifest-v1",
            "status": "qualified",
            "platform": "ios",
            "reviewedAtEpochSeconds": finality_manifest_reviewed_at,
            "verifierSourceRevision": verifier_source_revision,
            "verifierArtifactSha256": verifier_artifact_sha256,
            "serverContractSourceRevision": server_source_revision,
            "serverOpenApiSha256": server_openapi_sha256,
            "serverRouteSourceSha256": server_route_sha256,
            "attestationRoute": "/v1/bridge/finality/attestation/{height}",
            "bundleRoute": "/v1/bridge/finality/bundle/{height}",
            "minamotoTrustContextReceiptSha256": minamoto_trust_sha256,
            "tairaTrustContextReceiptSha256": taira_trust_sha256,
            "reviewerRole": "independent-reviewer",
            "reviewerKeyId": funded_key_ids["independentReviewer"],
            "privacy": funded_privacy_contract(),
        },
        reviewer_private,
    )
    finality_manifest_sha256 = sha256_file(finality_manifest.payload)
    finality_kat_fields = {
        "attestationNoritoRoundTripKatSha256": "attestation-norito-round-trip",
        "bundleNoritoRoundTripKatSha256": "bundle-norito-round-trip",
        "challengeBindingKatSha256": "challenge-binding",
        "genesisProofKatSha256": "genesis-proof",
        "tipProofKatSha256": "tip-proof",
        "nodeSignatureKatSha256": "node-signature",
        "aggregateSignatureKatSha256": "aggregate-signature",
        "statefulSuccessorKatSha256": "stateful-successor",
        "finalizedProjectionKatSha256": "finalized-projection",
    }
    finality_native = write_signed_json(
        directory,
        "funded-finality-native-canary",
        {
            "schemaVersion": 1,
            "contractId": "sora-ios-nexus-finality-native-canary-v1",
            "status": "qualified",
            "platform": "ios",
            "artifactClass": "reviewed-platform-release",
            "sourceTreeClean": True,
            "requiredNativeAbi": 21,
            "observedNativeAbi": (
                20 if funded_mutation == "invalid-finality-native-abi" else 21
            ),
            "verifierSourceRevision": verifier_source_revision,
            "verifierArtifactSha256": verifier_artifact_sha256,
            "finalityTrustManifestReceiptSha256": finality_manifest_sha256,
            "attestationRoute": "/v1/bridge/finality/attestation/{height}",
            "attestationResponseType": "BridgeFinalityAttestationV1",
            "bundleRoute": "/v1/bridge/finality/bundle/{height}",
            "bundleResponseType": "BridgeFinalityBundle",
            "requiredExportInventorySha256": synthetic_sha256(
                "funded-finality-required-export-inventory"
            ),
            "observedExportInventorySha256": synthetic_sha256(
                "funded-finality-required-export-inventory"
            ),
            **{
                field: synthetic_sha256(f"funded-finality-kat:{name}")
                for field, name in finality_kat_fields.items()
            },
            "requiredExportInventoryQualified": True,
            "attestationNoritoRoundTripQualified": True,
            "bundleNoritoRoundTripQualified": True,
            "challengeBindingQualified": True,
            "genesisProofQualified": True,
            "tipProofQualified": True,
            "nodeSignatureQualified": True,
            "aggregateSignatureQualified": True,
            "statefulSuccessorQualified": True,
            "finalizedProjectionQualified": True,
            "privacy": funded_privacy_contract(),
        },
        reviewer_private,
    )
    finality_native_sha256 = sha256_file(finality_native.payload)

    readiness = json.loads(readiness_path.read_text(encoding="utf-8"))
    readiness["status"] = "qualified"
    readiness["releaseEnabled"] = True
    readiness["defaultSigner"] = "ReviewedNexusTransactionSigner"
    readiness["defaultFinalityReader"] = "ReviewedNexusFinalityReader"
    readiness["productionSignerBinding"].update(
        {
            "status": "qualified",
            "adapterType": "ReviewedNexusTransactionSigner",
            "adapterSourceSha256": signer_adapter_source_sha256,
            "providerSourceSha256": signer_provider_source_sha256,
            "reviewedNativeArtifactSha256": reviewed_native_artifact_sha256,
            "nativeCanaryReceiptSha256": native_canary_sha256,
        }
    )
    readiness["productionFinalityBinding"].update(
        {
            "status": "qualified",
            "adapterType": "ReviewedNexusFinalityReader",
            "adapterSourceSha256": finality_adapter_source_sha256,
            "providerSourceSha256": finality_provider_source_sha256,
            "reviewedVerifierArtifactSha256": verifier_artifact_sha256,
            "reviewedVerifierSourceRevision": verifier_source_revision,
            "trustedContextReceiptSha256": finality_manifest_sha256,
            "nativeCanaryReceiptSha256": finality_native_sha256,
        }
    )
    readiness["finalityTrustContract"].update(
        {
            "serverContractSourceRevision": server_source_revision,
            "serverOpenApiSha256": server_openapi_sha256,
            "serverRouteSourceSha256": server_route_sha256,
            "minamotoTrustedContextReceiptSha256": minamoto_trust_sha256,
            "tairaTrustedContextReceiptSha256": taira_trust_sha256,
        }
    )
    readiness["nativeCanaryContract"].update(
        {
            "referenceOnly": False,
            "qualificationEvidence": {
                "status": "qualified",
                "receiptPath": "synthetic-regression-only",
                "receiptSha256": native_canary_sha256,
            },
            "reviewedPlatformArtifactPresent": True,
            "requiredExportInventoryQualified": True,
            "transactionBytesParityQualified": True,
            "signingPrehashParityQualified": True,
            "signedEnvelopeParityQualified": True,
            "decodeProjectionParityQualified": True,
        }
    )
    for criterion in readiness["releaseCriteria"]:
        readiness["releaseCriteria"][criterion] = (
            True
            if funded_mutation == "preclaimed-readiness"
            else criterion not in {"fundedTairaCanaryQualified", "fundedMinamotoCanaryQualified"}
        )
    write_json(readiness_path, readiness)
    readiness_sha256 = sha256_file(readiness_path)

    pi_receipts: dict[str, SignedEvidence] = {}
    for ordinal, network_id in enumerate(("taira", "minamoto"), start=900):
        pi_receipts[network_id] = write_signed_json(
            directory,
            f"funded-{network_id}-pi",
            pi_value(captured_at=started_at - 20, worker_last_success=started_at - 21, ordinal=ordinal),
            controller_private_key,
        )

    network_receipts: dict[str, SignedEvidence] = {}
    network_environment: dict[str, str] = {}
    for ordinal, (network_id, chain_id, template_path) in enumerate(
        (
            ("taira", taira["currentChainId"], TAIRA_CANARY_TEMPLATE),
            ("minamoto", MINAMOTO_CHAIN_ID, MINAMOTO_CANARY_TEMPLATE),
        ),
        start=1,
    ):
        receipt = json.loads(template_path.read_text(encoding="utf-8"))
        receipt["status"] = "qualified"
        receipt["receiptRecordedAtEpochSeconds"] = receipt_recorded_at
        receipt["blockingReasons"] = []
        if network_id == "taira":
            receipt["network"]["chainId"] = taira["currentChainId"]
            receipt["network"]["toriiBaseUrl"] = taira["canonicalToriiBaseUrl"]
        pi_sha256 = sha256_file(pi_receipts[network_id].payload)
        receipt["featureFlags"] = {
            "snapshotObservedAtEpochSeconds": started_at - 20,
            "snapshotReceiptSha256": pi_sha256,
            "configRevision": CONFIG_REVISION,
            "nexusAvailable": True,
            "nexusSendsAvailable": True,
            "polkamarktVisible": True,
            "polkamarktMutationsAvailable": True,
            "tairaDefaultVisible": True,
            "tairaPreferenceIsExplicit": True,
            "tairaEffectiveVisible": True,
            "localNexusSendsQualified": True,
        }
        receipt["signer"] = {
            "status": "qualified",
            "readinessReceiptSha256": readiness_sha256,
            "adapterType": "ReviewedNexusTransactionSigner",
            "adapterSourcePath": readiness["productionSignerBinding"]["adapterSourcePath"],
            "adapterSourceSha256": signer_adapter_source_sha256,
            "reviewedNativeArtifactSha256": reviewed_native_artifact_sha256,
            "nativeCanaryReceiptSha256": native_canary_sha256,
            "requiredNativeAbi": 21,
            "observedNativeAbi": 21,
            "artifactClass": "reviewed-platform-release",
            "sourceTreeClean": True,
            "dirtyLocalDebugArtifactAccepted": False,
            "osSecurityBoundary": "iOSDataProtectionKeychain",
            "bindingSha256": "",
        }
        signer = receipt["signer"]
        signer["bindingSha256"] = canonical_digest(
            [
                f"status={signer['status']}",
                f"readinessReceiptSha256={signer['readinessReceiptSha256']}",
                f"adapterType={signer['adapterType']}",
                f"adapterSourcePath={signer['adapterSourcePath']}",
                f"adapterSourceSha256={signer['adapterSourceSha256']}",
                f"reviewedNativeArtifactSha256={signer['reviewedNativeArtifactSha256']}",
                f"nativeCanaryReceiptSha256={signer['nativeCanaryReceiptSha256']}",
                f"requiredNativeAbi={signer['requiredNativeAbi']}",
                f"observedNativeAbi={signer['observedNativeAbi']}",
                f"artifactClass={signer['artifactClass']}",
                f"sourceTreeClean={canonical_scalar(signer['sourceTreeClean'])}",
                f"dirtyLocalDebugArtifactAccepted={canonical_scalar(signer['dirtyLocalDebugArtifactAccepted'])}",
                f"osSecurityBoundary={signer['osSecurityBoundary']}",
            ]
        )
        network_trust_sha256 = sha256_file(network_trust[network_id].payload)
        receipt["finality"] = {
            "status": "qualified",
            "readinessReceiptSha256": readiness_sha256,
            "adapterType": "ReviewedNexusFinalityReader",
            "adapterSourcePath": readiness["productionFinalityBinding"]["adapterSourcePath"],
            "adapterSourceSha256": finality_adapter_source_sha256,
            "verifierSourceRevision": verifier_source_revision,
            "verifierArtifactSha256": verifier_artifact_sha256,
            "finalityNativeCanaryReceiptSha256": finality_native_sha256,
            "finalityTrustManifestReceiptSha256": finality_manifest_sha256,
            "networkTrustContextReceiptSha256": network_trust_sha256,
            "serverContractSourceRevision": server_source_revision,
            "serverOpenApiSha256": server_openapi_sha256,
            "serverRouteSourceSha256": server_route_sha256,
            "attestationRoute": "/v1/bridge/finality/attestation/{height}",
            "bundleRoute": "/v1/bridge/finality/bundle/{height}",
            "bindingSha256": "",
        }
        finality = receipt["finality"]
        finality["bindingSha256"] = canonical_digest(
            [f"{key}={finality[key]}" for key in (
                "status",
                "readinessReceiptSha256",
                "adapterType",
                "adapterSourcePath",
                "adapterSourceSha256",
                "verifierSourceRevision",
                "verifierArtifactSha256",
                "finalityNativeCanaryReceiptSha256",
                "finalityTrustManifestReceiptSha256",
                "networkTrustContextReceiptSha256",
                "serverContractSourceRevision",
                "serverOpenApiSha256",
                "serverRouteSourceSha256",
                "attestationRoute",
                "bundleRoute",
            )]
        )
        receipt["candidate"] = {
            "bundleIdentifier": BUNDLE_IDENTIFIER,
            "developmentTeam": DEVELOPMENT_TEAM,
            "appVersion": APP_VERSION,
            "buildNumber": BUILD_NUMBER,
            "appStoreBuildIdentifier": APP_STORE_BUILD_IDENTIFIER,
            "sourceRevision": SOURCE_REVISION,
            "ipaSha256": ipa_identity["sha256"],
            "ipaBytes": ipa_identity["bytes"],
            "artifactIdentityReceiptSha256": artifact_sha256,
            "tairaDeploymentManifestSha256": taira["manifestSha256"],
            "tairaDeploymentAdmissionSha256": taira["admissionSha256"],
            "tairaCurrentChainId": taira["currentChainId"],
            "tairaCurrentGenesisHash": taira["currentGenesisHash"],
            "candidateBindingSha256": "",
        }
        candidate = receipt["candidate"]
        runtime = receipt["sora2Runtime"]
        flags = receipt["featureFlags"]
        candidate["candidateBindingSha256"] = canonical_digest(
            [
                "contractId=sora-ios-funded-nexus-canary-v1",
                "platform=ios",
                f"bundleIdentifier={BUNDLE_IDENTIFIER}",
                f"developmentTeam={DEVELOPMENT_TEAM}",
                f"appVersion={APP_VERSION}",
                f"buildNumber={BUILD_NUMBER}",
                f"appStoreBuildIdentifier={APP_STORE_BUILD_IDENTIFIER}",
                f"sourceRevision={SOURCE_REVISION}",
                f"ipaSha256={ipa_identity['sha256']}",
                f"ipaBytes={ipa_identity['bytes']}",
                f"artifactIdentityReceiptSha256={artifact_sha256}",
                f"tairaDeploymentManifestSha256={taira['manifestSha256']}",
                f"tairaDeploymentAdmissionSha256={taira['admissionSha256']}",
                f"tairaCurrentChainId={taira['currentChainId']}",
                f"tairaCurrentGenesisHash={taira['currentGenesisHash']}",
                f"sora2SourceRevision={runtime['sourceRevision']}",
                f"runtimeSpecVersion={runtime['specVersion']}",
                f"runtimeTransactionVersion={runtime['transactionVersion']}",
                f"runtimeGenesisHash={runtime['genesisHash']}",
                f"runtimeMetadataSha256={runtime['metadataSha256']}",
                f"runtimeTypesSha256={runtime['typesSha256']}",
                f"featureSnapshotObservedAtEpochSeconds={flags['snapshotObservedAtEpochSeconds']}",
                f"featureSnapshotReceiptSha256={flags['snapshotReceiptSha256']}",
                f"featureConfigRevision={flags['configRevision']}",
                f"nexusAvailable={canonical_scalar(flags['nexusAvailable'])}",
                f"nexusSendsAvailable={canonical_scalar(flags['nexusSendsAvailable'])}",
                f"polkamarktVisible={canonical_scalar(flags['polkamarktVisible'])}",
                f"polkamarktMutationsAvailable={canonical_scalar(flags['polkamarktMutationsAvailable'])}",
                f"tairaDefaultVisible={canonical_scalar(flags['tairaDefaultVisible'])}",
                f"tairaPreferenceIsExplicit={canonical_scalar(flags['tairaPreferenceIsExplicit'])}",
                f"tairaEffectiveVisible={canonical_scalar(flags['tairaEffectiveVisible'])}",
                f"localNexusSendsQualified={canonical_scalar(flags['localNexusSendsQualified'])}",
                f"signerBindingSha256={signer['bindingSha256']}",
                f"finalityBindingSha256={finality['bindingSha256']}",
                f"networkId={network_id}",
                f"chainId={chain_id}",
            ]
        )

        policy_value = {
            "schemaVersion": 1,
            "contractId": "sora-ios-funded-nexus-low-value-policy-v1",
            "platform": "ios",
            "networkId": network_id,
            "assetAlias": "xor#universal",
            "maximumAmountCanonical": "0.1",
            "maximumFeeCanonical": "0.1",
            "maximumExecutions": 1,
            "validFromEpochSeconds": started_at - 200,
            "validUntilEpochSeconds": completed_at + 200,
            "reviewedAtEpochSeconds": (
                started_at - 10
                if funded_mutation == "retroactive-policy-review"
                else started_at - 100
            ),
            "privacy": funded_privacy_contract(),
        }
        policy_path = directory / f"funded-{network_id}-policy.json"
        write_json(policy_path, policy_value)
        policy_sha256 = sha256_file(policy_path)
        approval_value = {
            "schemaVersion": 1,
            "contractId": "sora-ios-funded-nexus-canary-approval-v1",
            "platform": "ios",
            "networkId": network_id,
            "candidateBindingSha256": candidate["candidateBindingSha256"],
            "lowValuePolicySha256": policy_sha256,
            "approvalNonce": synthetic_sha256(f"funded-{network_id}:approval-nonce"),
            "approvedAtEpochSeconds": started_at - 20,
            "expiresAtEpochSeconds": completed_at + 30,
            "operatorRole": "release-operator",
            "operatorKeyId": funded_key_ids["releaseOperator"],
            "independentApproverRole": "independent-approver",
            "independentApproverKeyId": funded_key_ids["independentApprover"],
            "privacy": funded_privacy_contract(),
        }
        approval_path = directory / f"funded-{network_id}-approval.json"
        approval_operator_signature = directory / f"funded-{network_id}-approval-operator.sig"
        approval_independent_signature = directory / f"funded-{network_id}-approval-independent.sig"
        write_json(approval_path, approval_value)
        sign_file(approval_path, approval_operator_signature, funded_private_keys["releaseOperator"])
        sign_file(approval_path, approval_independent_signature, funded_private_keys["independentApprover"])
        approval_sha256 = sha256_file(approval_path)
        receipt["operatorApproval"] = {
            "scopeNetworkId": network_id,
            "approvalNonce": approval_value["approvalNonce"],
            "approvalReceiptSha256": approval_sha256,
            "lowValuePolicySha256": policy_sha256,
            "approvedAtEpochSeconds": approval_value["approvedAtEpochSeconds"],
            "expiresAtEpochSeconds": approval_value["expiresAtEpochSeconds"],
            "operatorRole": "release-operator",
            "independentApproverRole": "independent-approver",
        }

        canary_run_id = synthetic_sha256(
            "funded-shared-cross-network-canary-run"
            if funded_mutation == "reused-cross-network-run"
            else f"funded-{network_id}:canary-run"
        )
        committed_height = 40_000 + ordinal * 10
        finalized_height = (
            committed_height - 1
            if funded_mutation == "finalized-below-committed" and network_id == "taira"
            else committed_height + 1
        )
        stages: dict[str, dict[str, Any]] = {}
        for stage_index, (stage_name, assertions) in enumerate(FUNDED_STAGE_ASSERTIONS.items(), start=1):
            stage: dict[str, Any] = {
                "status": "qualified",
                "observedAtEpochSeconds": started_at + stage_index,
                "evidenceSha256": "",
                **assertions,
            }
            if (
                funded_mutation == "missing-live-successor-proof"
                and network_id == "taira"
                and stage_name == "finalityReadback"
            ):
                stage["liveBoundedSequentialStatefulSuccessorChainVerified"] = False
            projection = [
                "contractId=sora-ios-funded-nexus-canary-stage-v1",
                f"canaryRunId={canary_run_id}",
                f"candidateBindingSha256={candidate['candidateBindingSha256']}",
                f"networkId={network_id}",
                f"stageName={stage_name}",
                f"observedAtEpochSeconds={stage['observedAtEpochSeconds']}",
                "status=qualified",
            ]
            if stage_name == "terminalStatusReadback":
                stage["committedBlockHeight"] = committed_height
                projection.append(f"assertion.committedBlockHeight={committed_height}")
            elif stage_name == "finalityReadback":
                attestation_sha256 = synthetic_sha256(f"funded-{network_id}:attestation-evidence")
                challenge_sha256 = synthetic_sha256(f"funded-{network_id}:attestation-challenge")
                finalized_block_hash = synthetic_sha256(
                    f"funded-{network_id}:finalized-block"
                )
                bundle_sha256 = synthetic_sha256(
                    f"funded-{network_id}:bundle-evidence"
                )
                stage.update(
                    {
                        "networkId": network_id,
                        "chainId": chain_id,
                        "finalizedBlockHeight": finalized_height,
                        "finalizedBlockHash": finalized_block_hash,
                        "attestationChallengeSha256": challenge_sha256,
                        "attestationChallengeBindingSha256": (
                            synthetic_sha256("funded-invalid-challenge-binding")
                            if funded_mutation == "invalid-challenge-binding" and network_id == "taira"
                            else canonical_digest(
                                [
                                    "contractId=sora-ios-funded-nexus-finality-challenge-binding-v1",
                                    f"canaryRunId={canary_run_id}",
                                    f"candidateBindingSha256={candidate['candidateBindingSha256']}",
                                    f"networkId={network_id}",
                                    f"chainId={chain_id}",
                                    f"finalizedBlockHeight={finalized_height}",
                                    f"finalizedBlockHash={finalized_block_hash}",
                                    f"attestationChallengeSha256={challenge_sha256}",
                                    f"attestationEvidenceSha256={attestation_sha256}",
                                    f"bundleEvidenceSha256={bundle_sha256}",
                                    f"finalityBindingSha256={finality['bindingSha256']}",
                                ]
                            )
                        ),
                        "attestationEvidenceSha256": attestation_sha256,
                        "bundleEvidenceSha256": bundle_sha256,
                        "reviewedVerifierSourceRevision": verifier_source_revision,
                        "reviewedVerifierArtifactSha256": verifier_artifact_sha256,
                        "finalityNativeCanaryReceiptSha256": finality_native_sha256,
                        "finalityTrustManifestReceiptSha256": finality_manifest_sha256,
                        "networkTrustContextReceiptSha256": network_trust_sha256,
                        "finalityBindingSha256": finality["bindingSha256"],
                    }
                )
                for key in (
                    "networkId",
                    "chainId",
                    "finalizedBlockHeight",
                    "finalizedBlockHash",
                    "attestationChallengeSha256",
                    "attestationChallengeBindingSha256",
                    "attestationEvidenceSha256",
                    "bundleEvidenceSha256",
                    "reviewedVerifierSourceRevision",
                    "reviewedVerifierArtifactSha256",
                    "finalityNativeCanaryReceiptSha256",
                    "finalityTrustManifestReceiptSha256",
                    "networkTrustContextReceiptSha256",
                    "finalityBindingSha256",
                ):
                    projection.append(f"assertion.{key}={canonical_scalar(stage[key])}")
            projection.extend(f"assertion.{key}={canonical_scalar(stage[key])}" for key in assertions)
            stage["evidenceSha256"] = canonical_digest(projection)
            stages[stage_name] = stage

        consumption_value = {
            "schemaVersion": 1,
            "contractId": "sora-ios-funded-nexus-approval-consumption-v1",
            "status": "completed",
            "platform": "ios",
            "ledgerStoreId": "synthetic-append-only-ledger",
            "networkId": network_id,
            "candidateBindingSha256": candidate["candidateBindingSha256"],
            "approvalNonce": approval_value["approvalNonce"],
            "approvalReceiptSha256": approval_sha256,
            "canaryRunId": canary_run_id,
            "reservedAtEpochSeconds": stages["fee"]["observedAtEpochSeconds"],
            "finalizedAtEpochSeconds": completed_at + 1,
            "reservationStoreVersion": 1,
            "finalizationStoreVersion": 2,
            "previousLedgerHeadSha256": synthetic_sha256(f"funded-{network_id}:ledger-previous"),
            "reservationLedgerHeadSha256": synthetic_sha256(f"funded-{network_id}:ledger-reservation"),
            "finalizationLedgerHeadSha256": synthetic_sha256(f"funded-{network_id}:ledger-finalization"),
            "priorReservationCount": 0,
            "submissionHandoffCount": 1,
            "ambiguousAttemptCount": 0,
            "ledgerAuthorityRole": "approval-consumption-ledger",
            "ledgerAuthorityKeyId": funded_key_ids["consumptionLedger"],
            "privacy": funded_privacy_contract(),
        }
        consumption = write_signed_json(
            directory,
            f"funded-{network_id}-consumption",
            consumption_value,
            funded_private_keys["consumptionLedger"],
        )
        consumption_sha256 = sha256_file(consumption.payload)
        receipt["execution"] = {
            "startedAtEpochSeconds": started_at,
            "completedAtEpochSeconds": completed_at,
            "canaryRunId": canary_run_id,
            "evidenceBundleSha256": "",
            "consumptionReceiptSha256": consumption_sha256,
            "sendAmountCanonical": "0.1",
            "feeAmountCanonical": "0.1",
            "submissionAttemptCount": 1,
            "automaticRetryAttempted": False,
            "ambiguousSubmissionObserved": False,
            "terminalStatus": "committed",
            **stages,
        }
        evidence_value = {
            "schemaVersion": 1,
            "contractId": "sora-ios-funded-nexus-canary-evidence-v1",
            "platform": "ios",
            "networkId": network_id,
            "canaryRunId": canary_run_id,
            "candidateBindingSha256": candidate["candidateBindingSha256"],
            "artifactIdentityReceiptSha256": artifact_sha256,
            "approvalReceiptSha256": approval_sha256,
            "lowValuePolicySha256": policy_sha256,
            "approvalNonce": approval_value["approvalNonce"],
            "consumptionReceiptSha256": consumption_sha256,
            "startedAtEpochSeconds": started_at,
            "completedAtEpochSeconds": completed_at,
            "sendAmountCanonical": "0.1",
            "feeAmountCanonical": "0.1",
            "submissionAttemptCount": 1,
            "automaticRetryAttempted": False,
            "ambiguousSubmissionObserved": False,
            "terminalStatus": "committed",
            "attestationEvidenceSha256": stages["finalityReadback"]["attestationEvidenceSha256"],
            "bundleEvidenceSha256": stages["finalityReadback"]["bundleEvidenceSha256"],
            "stages": copy.deepcopy(stages),
            "independentReviewerRole": "independent-reviewer",
            "independentReviewerKeyId": funded_key_ids["independentReviewer"],
            "independentReviewedAtEpochSeconds": reviewed_at,
            "privacy": funded_privacy_contract(),
        }
        evidence = write_signed_json(
            directory,
            f"funded-{network_id}-evidence",
            evidence_value,
            reviewer_private,
        )
        receipt["execution"]["evidenceBundleSha256"] = sha256_file(evidence.payload)
        network_receipts[network_id] = write_signed_json(
            directory,
            f"funded-{network_id}",
            receipt,
            reviewer_private,
        )
        prefix = network_id.upper()
        network_environment.update(
            {
                f"{prefix}_FUNDED_CANARY_RECEIPT_PATH": str(network_receipts[network_id].payload),
                f"{prefix}_FUNDED_CANARY_RECEIPT_SIGNATURE_PATH": str(network_receipts[network_id].signature),
                f"{prefix}_FUNDED_CANARY_APPROVAL_RECEIPT_PATH": str(approval_path),
                f"{prefix}_FUNDED_CANARY_APPROVAL_OPERATOR_SIGNATURE_PATH": str(approval_operator_signature),
                f"{prefix}_FUNDED_CANARY_APPROVAL_INDEPENDENT_SIGNATURE_PATH": str(approval_independent_signature),
                f"{prefix}_FUNDED_CANARY_LOW_VALUE_POLICY_PATH": str(policy_path),
                f"{prefix}_FUNDED_CANARY_CONSUMPTION_RECEIPT_PATH": str(consumption.payload),
                f"{prefix}_FUNDED_CANARY_CONSUMPTION_SIGNATURE_PATH": str(consumption.signature),
                f"{prefix}_FUNDED_CANARY_EVIDENCE_BUNDLE_PATH": str(evidence.payload),
                f"{prefix}_FUNDED_CANARY_EVIDENCE_SIGNATURE_PATH": str(evidence.signature),
                f"{prefix}_FUNDED_CANARY_FINALITY_TRUST_CONTEXT_PATH": str(network_trust[network_id].payload),
                f"{prefix}_FUNDED_CANARY_FINALITY_TRUST_CONTEXT_SIGNATURE_PATH": str(network_trust[network_id].signature),
                f"{prefix}_FUNDED_CANARY_PI_RECEIPT_PATH": str(pi_receipts[network_id].payload),
                f"{prefix}_FUNDED_CANARY_PI_SIGNATURE_PATH": str(pi_receipts[network_id].signature),
            }
        )

    admission_value = {
        "schemaVersion": 1,
        "contractId": "sora-ios-funded-nexus-canary-admission-v1",
        "status": "qualified",
        "platform": "ios",
        "recordedAtEpochSeconds": admission_evaluated_at + 1,
        "evaluatedAtEpochSeconds": admission_evaluated_at,
        "candidate": {
            "bundleIdentifier": BUNDLE_IDENTIFIER,
            "developmentTeam": DEVELOPMENT_TEAM,
            "appVersion": APP_VERSION,
            "buildNumber": BUILD_NUMBER,
            "appStoreBuildIdentifier": APP_STORE_BUILD_IDENTIFIER,
            "sourceRevision": SOURCE_REVISION,
            "ipaSha256": ipa_identity["sha256"],
            "ipaBytes": ipa_identity["bytes"],
            "artifactIdentityReceiptSha256": artifact_sha256,
            "tairaDeploymentManifestSha256": taira["manifestSha256"],
            "tairaDeploymentAdmissionSha256": taira["admissionSha256"],
            "tairaCurrentChainId": taira["currentChainId"],
            "tairaCurrentGenesisHash": taira["currentGenesisHash"],
        },
        "readinessReceiptSha256": readiness_sha256,
        "finalityTrustManifestReceiptSha256": finality_manifest_sha256,
        "taira": {
            "networkId": "taira",
            "chainId": taira["currentChainId"],
            "receiptSha256": sha256_file(network_receipts["taira"].payload),
            "candidateBindingSha256": json.loads(network_receipts["taira"].payload.read_text())["candidate"]["candidateBindingSha256"],
            "finalityBindingSha256": json.loads(network_receipts["taira"].payload.read_text())["finality"]["bindingSha256"],
        },
        "minamoto": {
            "networkId": "minamoto",
            "chainId": MINAMOTO_CHAIN_ID,
            "receiptSha256": sha256_file(network_receipts["minamoto"].payload),
            "candidateBindingSha256": json.loads(network_receipts["minamoto"].payload.read_text())["candidate"]["candidateBindingSha256"],
            "finalityBindingSha256": json.loads(network_receipts["minamoto"].payload.read_text())["finality"]["bindingSha256"],
        },
        "independentReviewerRole": "independent-reviewer",
        "independentReviewerKeyId": funded_key_ids["independentReviewer"],
        "privacy": funded_privacy_contract(),
        "blockingReasons": [],
    }
    admission = write_signed_json(
        directory,
        "funded-admission",
        admission_value,
        reviewer_private,
    )
    environment = {
        "FUNDED_NEXUS_CANARY_TRUST_ROOT_SHA256": funded_trust_sha256,
        "FUNDED_NEXUS_CANARY_RELEASE_OPERATOR_PUBLIC_KEY_PATH": str(funded_public_keys["releaseOperator"]),
        "FUNDED_NEXUS_CANARY_INDEPENDENT_APPROVER_PUBLIC_KEY_PATH": str(funded_public_keys["independentApprover"]),
        "FUNDED_NEXUS_CANARY_INDEPENDENT_REVIEWER_PUBLIC_KEY_PATH": str(funded_public_keys["independentReviewer"]),
        "FUNDED_NEXUS_CANARY_CONSUMPTION_LEDGER_PUBLIC_KEY_PATH": str(funded_public_keys["consumptionLedger"]),
        "FUNDED_NEXUS_CANARY_ADMISSION_RECEIPT_PATH": str(admission.payload),
        "FUNDED_NEXUS_CANARY_ADMISSION_SIGNATURE_PATH": str(admission.signature),
        "PRODUCTION_FINALITY_TRUST_MANIFEST_RECEIPT_PATH": str(finality_manifest.payload),
        "PRODUCTION_FINALITY_TRUST_MANIFEST_SIGNATURE_PATH": str(finality_manifest.signature),
        "IROHA_REVIEWED_NATIVE_CANARY_RECEIPT_PATH": str(native_canary.payload),
        "IROHA_REVIEWED_NATIVE_CANARY_SIGNATURE_PATH": str(native_canary.signature),
        "IROHA_REVIEWED_FINALITY_NATIVE_CANARY_RECEIPT_PATH": str(finality_native.payload),
        "IROHA_REVIEWED_FINALITY_NATIVE_CANARY_SIGNATURE_PATH": str(finality_native.signature),
        **network_environment,
    }
    return FundedEvidenceBundle(
        admission=admission,
        taira=network_receipts["taira"],
        minamoto=network_receipts["minamoto"],
        environment=environment,
    )


def capability_binding(value: dict[str, Any]) -> str:
    return canonical_digest(
        [
            "schemaVersion=3",
            f"configRevision={value['capabilities']['configRevision']}",
            "endpoint=https://pi.soramitsu.io/graphql",
            "serviceId=pi.soramitsu.io",
            "ecosystem=sora2",
            "chainId=sora:mainnet",
            "network=mainnet",
            "readOnly=true",
            "workerReady=true",
            "mobileConfigHealthBound=true",
            "historyBlockHeightContractDeployed=true",
            "nexusAvailable=true",
            "nexusSendsAvailable=true",
            "polkamarktVisible=true",
            "polkamarktMutationsAvailable=true",
            "tairaDefaultVisible=true",
        ]
    )


def legacy_pi_v2_capability_binding_negative_test_only(value: dict[str, Any]) -> str:
    capabilities = value["capabilities"]
    expected_capability_keys = {
        "configRevision",
        "capturedAtEpochSeconds",
        "nexusAvailable",
        "nexusSendsAvailable",
        "polkamarktVisible",
        "polkamarktMutationsAvailable",
        "tairaDefaultVisible",
    }
    if (
        value["schemaVersion"] != 2
        or value["contractId"] != LEGACY_PI_V2_CONTRACT_ID_NEGATIVE_TEST_ONLY
        or set(capabilities) != expected_capability_keys
    ):
        raise HarnessFailure("legacy PI v2 negative-test envelope is not exact")
    return canonical_digest(
        [
            "schemaVersion=2",
            f"configRevision={capabilities['configRevision']}",
            "endpoint=https://pi.soramitsu.io/graphql",
            "serviceId=pi.soramitsu.io",
            "ecosystem=sora2",
            "chainId=sora:mainnet",
            "network=mainnet",
            "readOnly=true",
            "workerReady=true",
            "nexusAvailable=true",
            "nexusSendsAvailable=true",
            "polkamarktVisible=true",
            "polkamarktMutationsAvailable=true",
            "tairaDefaultVisible=true",
        ]
    )


def checkpoint_binding(value: dict[str, Any], pi_sha256: str) -> str:
    health = value["health"]
    minamoto = value["networkCheckpoints"]["minamoto"]
    taira = value["networkCheckpoints"]["taira"]
    return canonical_digest(
        [
            f"piProbeReceiptSha256={pi_sha256}",
            f"sora2GenesisHash={health['genesisHash']}",
            f"sora2FinalizedHeight={health['workerLatestFinalizedBlock']}",
            f"sora2FinalizedBlockHash={health['workerLatestFinalizedBlockHash']}",
            f"minamotoChainId={MINAMOTO_CHAIN_ID}",
            f"minamotoGenesisHash={minamoto['genesisHash']}",
            f"minamotoFinalizedHeight={minamoto['finalizedHeight']}",
            f"minamotoFinalizedBlockHash={minamoto['finalizedBlockHash']}",
            f"tairaChainId={admitted_taira()['currentChainId']}",
            f"tairaGenesisHash={taira['genesisHash']}",
            f"tairaFinalizedHeight={taira['finalizedHeight']}",
            f"tairaFinalizedBlockHash={taira['finalizedBlockHash']}",
        ]
    )


def telemetry_payload(label: str, *, hard_stop: bool) -> dict[str, Any]:
    return {
        "datasetSha256": synthetic_sha256(f"telemetry-dataset:{label}"),
        "telemetryCompletenessQualified": True,
        "outcomesMutuallyExclusiveQualified": True,
        "eligibleDevices": 10,
        "reportingDevices": 10,
        "upgradedWalletsObserved": 5,
        "accountsObserved": 5,
        "confirmedMissingWalletEvents": 1 if hard_stop else 0,
        "confirmedMissingAccountEvents": 0,
        "addressMismatchEvents": 0,
        "signatureMismatchEvents": 0,
        "crossNetworkRoutingEvents": 0,
        "terminalTransactionsObserved": 100,
        "terminalSuccessEvents": 100,
        "excludedUserCancellationEvents": 0,
        "excludedInsufficientFundsEvents": 0,
        "eligibleTerminalTransactionsObserved": 100,
        "eligibleTerminalFailureEvents": 0,
    }


def build_chain(
    directory: Path,
    *,
    target: int,
    common: CommonEvidence,
    private_key: Path,
    current_evaluated_at: int,
    mutation: Mutation | None = None,
) -> ChainEvidence:
    mutation = mutation or Mutation()
    directory.mkdir(parents=True)
    target_index = TARGETS.index(target)
    included_targets = TARGETS[: target_index + 1]
    evaluations = {
        gate_target: current_evaluated_at - GATE_SPACING_SECONDS * (target_index - index)
        for index, gate_target in enumerate(included_targets)
    }
    gates: dict[int, GateEvidence] = {}
    prior_receipt_sha256: str | None = None

    for ordinal, gate_target in enumerate(included_targets, start=1):
        evaluated_at = evaluations[gate_target]
        authorized_at = evaluated_at + 1
        if mutation.delayed_authorization_target == gate_target:
            authorized_at = evaluated_at + 31
        captured_at = evaluated_at - 5
        if mutation.stale_current_pi and gate_target == target:
            captured_at = evaluated_at - 301
        worker_last_success = captured_at - 1
        if mutation.historical_pi_worker_lag_target == gate_target:
            worker_last_success = captured_at - 301
        current_pi_value = pi_value(
            captured_at=captured_at,
            worker_last_success=worker_last_success,
            ordinal=ordinal,
        )
        if mutation.legacy_pi_v2_target == gate_target:
            current_pi_value["schemaVersion"] = 2
            current_pi_value["contractId"] = LEGACY_PI_V2_CONTRACT_ID_NEGATIVE_TEST_ONLY
            current_pi_value["capabilities"].pop("mobileConfigHealthBound")
            current_pi_value["capabilities"].pop("historyBlockHeightContractDeployed")
        if mutation.false_mobile_config_health_bound_target == gate_target:
            current_pi_value["capabilities"]["mobileConfigHealthBound"] = False
        if mutation.false_history_block_height_contract_deployed_target == gate_target:
            current_pi_value["capabilities"]["historyBlockHeightContractDeployed"] = False
        pi = write_signed_json(directory, f"gate-{gate_target}-pi", current_pi_value, private_key)
        pi_sha256 = sha256_file(pi.payload)
        capability_sha256 = (
            legacy_pi_v2_capability_binding_negative_test_only(current_pi_value)
            if mutation.legacy_pi_v2_target == gate_target
            else capability_binding(current_pi_value)
        )
        checkpoint_sha256 = checkpoint_binding(current_pi_value, pi_sha256)
        sequence_number, from_percent = TRANSITIONS[gate_target]
        evaluation_sha256 = canonical_digest(
            [
                f"candidateBindingSha256={common.candidate_binding_sha256}",
                f"piProbeReceiptSha256={pi_sha256}",
                f"piCapturedAtEpochSeconds={captured_at}",
                f"capabilitySnapshotSha256={capability_sha256}",
                f"finalizedCheckpointBindingSha256={checkpoint_sha256}",
                f"sequenceNumber={sequence_number}",
                f"fromCohortPercent={from_percent}",
                f"targetCohortPercent={gate_target}",
                f"evaluatedAtEpochSeconds={evaluated_at}",
                f"authorizedAtEpochSeconds={authorized_at}",
            ]
        )
        if mutation.rewritten_evaluation_binding_target == gate_target:
            evaluation_sha256 = synthetic_sha256(f"rewritten-evaluation-binding:{gate_target}")

        telemetry: SignedEvidence | None = None
        distribution: SignedEvidence | None = None
        completed_cohort: dict[str, Any] | None = None
        if from_percent != 0:
            prior = gates[from_percent]
            started_at = prior.authorized_at + 1
            if mutation.backdated_dwell_target == gate_target:
                started_at = prior.authorized_at
            dwell = MINIMUM_DWELL_SECONDS
            if mutation.short_dwell_target == gate_target:
                dwell -= 1
            ended_at = started_at + dwell
            telemetry_value = {
                "schemaVersion": 1,
                "contractId": "sora-ios-rollout-telemetry-attestation-v1",
                "status": "qualified",
                "controllerId": CONTROLLER_ID,
                "candidateBindingSha256": common.candidate_binding_sha256,
                "cohortPercent": from_percent,
                "capturedAtEpochSeconds": ended_at,
                "telemetry": telemetry_payload(
                    f"gate-{gate_target}",
                    hard_stop=mutation.hard_stop_target == gate_target,
                ),
                "privacy": privacy_contract(),
            }
            distribution_value = {
                "schemaVersion": 1,
                "contractId": "sora-ios-distribution-cohort-attestation-v1",
                "status": "qualified",
                "controllerId": CONTROLLER_ID,
                "candidateBindingSha256": common.candidate_binding_sha256,
                "cohortPercent": from_percent,
                "startedAtEpochSeconds": started_at,
                "endedAtEpochSeconds": ended_at,
                "appStoreBuildIdentifier": (
                    "wrong-synthetic-app-store-build"
                    if mutation.wrong_app_store_target == gate_target
                    else APP_STORE_BUILD_IDENTIFIER
                ),
                "cohortAssignmentQualified": True,
                "privacy": privacy_contract(),
            }
            telemetry = write_signed_json(
                directory,
                f"gate-{gate_target}-telemetry",
                telemetry_value,
                private_key,
            )
            distribution = write_signed_json(
                directory,
                f"gate-{gate_target}-distribution",
                distribution_value,
                private_key,
            )
            completed_cohort = {
                "cohortPercent": from_percent,
                "startedAtEpochSeconds": started_at,
                "endedAtEpochSeconds": ended_at,
                "candidateBindingSha256": (
                    synthetic_sha256(f"rewritten-cohort-candidate:{gate_target}")
                    if mutation.rewritten_cohort_candidate_target == gate_target
                    else common.candidate_binding_sha256
                ),
                "distributionPlatformAttestationSha256": sha256_file(distribution.payload),
                "telemetryAttestationSha256": sha256_file(telemetry.payload),
                "telemetry": copy.deepcopy(telemetry_value["telemetry"]),
            }

        health = current_pi_value["health"]
        minamoto = current_pi_value["networkCheckpoints"]["minamoto"]
        taira = current_pi_value["networkCheckpoints"]["taira"]
        identity = {
            "candidateBindingSha256": common.candidate_binding_sha256,
            "evaluationBindingSha256": evaluation_sha256,
            "candidateArtifactSha256": common.candidate_sha256,
            "artifactIdentityReceiptSha256": common.artifact_sha256,
            "productionQualificationReceiptSha256": common.qualification_sha256,
            "fundedNexusCanaryAdmissionReceiptSha256": sha256_file(common.funded_admission.payload),
            "fundedTairaCanaryReceiptSha256": sha256_file(common.funded_taira.payload),
            "fundedMinamotoCanaryReceiptSha256": sha256_file(common.funded_minamoto.payload),
            "tairaDeploymentManifestSha256": admitted_taira()["manifestSha256"],
            "tairaDeploymentAdmissionSha256": admitted_taira()["admissionSha256"],
            "tairaCurrentChainId": admitted_taira()["currentChainId"],
            "tairaCurrentGenesisHash": admitted_taira()["currentGenesisHash"],
            "piProbeReceiptSha256": pi_sha256,
            "piCapturedAtEpochSeconds": captured_at,
            "sourceRevision": SOURCE_REVISION,
            "bundleIdentifier": BUNDLE_IDENTIFIER,
            "developmentTeam": DEVELOPMENT_TEAM,
            "appVersion": APP_VERSION,
            "buildNumber": BUILD_NUMBER,
            "appStoreBuildIdentifier": APP_STORE_BUILD_IDENTIFIER,
            "sora2NetworkRevision": SORA2_REVISION,
            "runtimeSpecVersion": 130,
            "runtimeTransactionVersion": 130,
            "runtimeMetadataSha256": RUNTIME_METADATA_SHA256,
            "capabilitySnapshotSha256": capability_sha256,
            "finalizedCheckpointBindingSha256": checkpoint_sha256,
            "sora2GenesisHash": health["genesisHash"],
            "sora2FinalizedHeight": health["workerLatestFinalizedBlock"],
            "sora2FinalizedBlockHash": health["workerLatestFinalizedBlockHash"],
            "minamotoGenesisHash": minamoto["genesisHash"],
            "minamotoFinalizedHeight": minamoto["finalizedHeight"],
            "minamotoFinalizedBlockHash": minamoto["finalizedBlockHash"],
            "tairaGenesisHash": taira["genesisHash"],
            "tairaFinalizedHeight": taira["finalizedHeight"],
            "tairaFinalizedBlockHash": taira["finalizedBlockHash"],
        }
        linked_prior_sha256 = prior_receipt_sha256
        if mutation.broken_link_target == gate_target:
            linked_prior_sha256 = synthetic_sha256(f"broken-prior-link:{gate_target}")
        rollout_value = {
            "schemaVersion": 2 if mutation.legacy_v2_target == gate_target else 3,
            "contractId": (
                "sora-mobile-production-rollout-v2"
                if mutation.legacy_v2_target == gate_target
                else "sora-mobile-production-rollout-v3"
            ),
            "status": "qualified",
            "platform": "ios",
            "controllerId": CONTROLLER_ID,
            "sequenceNumber": sequence_number,
            "fromCohortPercent": from_percent,
            "targetCohortPercent": gate_target,
            "evaluatedAtEpochSeconds": evaluated_at,
            "authorizedAtEpochSeconds": authorized_at,
            "identity": identity,
            "privacy": privacy_contract(),
            "priorReceiptSha256": linked_prior_sha256,
            "completedCohort": completed_cohort,
            "blockingReasons": [],
        }
        rollout = write_signed_json(directory, f"gate-{gate_target}-rollout", rollout_value, private_key)
        prior_receipt_sha256 = sha256_file(rollout.payload)
        gates[gate_target] = GateEvidence(
            target=gate_target,
            evaluated_at=evaluated_at,
            authorized_at=authorized_at,
            pi=pi,
            rollout=rollout,
            telemetry=telemetry,
            distribution=distribution,
        )

    return ChainEvidence(directory=directory, target=target, gates=gates, common=common)


def clean_environment() -> dict[str, str]:
    forbidden_prefixes = (
        "PRODUCTION_ROLLOUT_",
        "PRODUCTION_QUALIFICATION_",
        "PRODUCTION_CANDIDATE_",
        "PRODUCTION_KEYCHAIN_",
        "PI_PRODUCTION_",
        "PRODUCTION_FINALITY_",
        "IROHA_REVIEWED_",
        "FUNDED_NEXUS_",
        "TAIRA_FUNDED_",
        "MINAMOTO_FUNDED_",
        "IOS_TAIRA_DEPLOYMENT_",
    )
    environment = {
        key: value
        for key, value in os.environ.items()
        if not any(key.startswith(prefix) for prefix in forbidden_prefixes)
    }
    environment["LC_ALL"] = "C"
    return environment


def environment_for(
    chain: ChainEvidence,
    *,
    shell_path: Path,
    trust_path: Path,
    trust_sha256: str,
    public_key: Path,
    regression_current_epoch: int,
) -> dict[str, str]:
    environment = clean_environment()
    current = chain.gates[chain.target]
    environment.update(
        {
            "PRODUCTION_ROLLOUT_TARGET_PERCENT": str(chain.target),
            "PRODUCTION_ROLLOUT_IPA_PATH": str(chain.common.ipa),
            "PRODUCTION_CANDIDATE_SOURCE_REVISION": SOURCE_REVISION,
            "PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256": trust_sha256,
            "PRODUCTION_KEYCHAIN_ACCESS_GROUPS_SHA256": chain.common.keychain_groups_sha256,
            "PRODUCTION_ROLLOUT_CONTROLLER_PUBLIC_KEY_PATH": str(public_key),
            "SORA_ROLLOUT_REGRESSION_CURRENT_EPOCH_SECONDS": str(
                regression_current_epoch
            ),
            "PRODUCTION_QUALIFICATION_RECEIPT_PATH": str(chain.common.qualification.payload),
            "PRODUCTION_QUALIFICATION_RECEIPT_SIGNATURE_PATH": str(chain.common.qualification.signature),
            "PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH": str(chain.common.artifact.payload),
            "PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH": str(chain.common.artifact.signature),
            "PI_PRODUCTION_PROBE_RECEIPT_PATH": str(current.pi.payload),
            "PI_PRODUCTION_PROBE_SIGNATURE_PATH": str(current.pi.signature),
            "PRODUCTION_ROLLOUT_RECEIPT_PATH": str(current.rollout.payload),
            "PRODUCTION_ROLLOUT_RECEIPT_SIGNATURE_PATH": str(current.rollout.signature),
            "SORA_ROLLOUT_REGRESSION_MIGRATION_RECEIPT_SHA256": synthetic_sha256(
                "migration-qualification-receipt"
            ),
            "SORA_ROLLOUT_REGRESSION_MIGRATION_IPA_SHA256": chain.common.candidate_sha256,
            **TAIRA_DEPLOYMENT_ENVIRONMENT,
            **chain.common.funded_environment,
        }
    )
    for prior_target in TARGETS[: TARGETS.index(chain.target)]:
        prior = chain.gates[prior_target]
        environment[f"PRODUCTION_ROLLOUT_RECEIPT_{prior_target}_PATH"] = str(prior.rollout.payload)
        environment[f"PRODUCTION_ROLLOUT_RECEIPT_{prior_target}_SIGNATURE_PATH"] = str(
            prior.rollout.signature
        )
        environment[f"PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_{prior_target}_PATH"] = str(
            prior.pi.payload
        )
        environment[f"PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_{prior_target}_SIGNATURE_PATH"] = str(
            prior.pi.signature
        )
        if prior_target != 1:
            if prior.telemetry is None or prior.distribution is None:
                raise HarnessFailure(f"gate {prior_target}% lacks historical cohort evidence")
            environment[f"PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_{prior_target}_PATH"] = str(
                prior.telemetry.payload
            )
            environment[
                f"PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_{prior_target}_SIGNATURE_PATH"
            ] = str(prior.telemetry.signature)
            environment[f"PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_{prior_target}_PATH"] = str(
                prior.distribution.payload
            )
            environment[
                f"PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_{prior_target}_SIGNATURE_PATH"
            ] = str(prior.distribution.signature)
    if chain.target != 1:
        if current.telemetry is None or current.distribution is None:
            raise HarnessFailure(f"gate {chain.target}% lacks current cohort evidence")
        environment["PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_PATH"] = str(current.telemetry.payload)
        environment["PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_SIGNATURE_PATH"] = str(
            current.telemetry.signature
        )
        environment["PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_PATH"] = str(
            current.distribution.payload
        )
        environment["PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_SIGNATURE_PATH"] = str(
            current.distribution.signature
        )
    environment["SORA_ROLLOUT_REGRESSION_SHELL"] = str(shell_path)
    environment["SORA_ROLLOUT_REGRESSION_TRUST"] = str(trust_path)
    return environment


def run_gate(
    *,
    name: str,
    shell_path: Path,
    environment: dict[str, str],
    should_succeed: bool,
    expected_fragment: str,
) -> None:
    try:
        result = subprocess.run(
            [str(SHELL), str(shell_path)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=environment,
            # The 100% chain authenticates all four retained rollout stages and
            # can exceed 45 seconds on a cold Apple-Python process. Keep the
            # per-case bound finite while leaving the aggregate 1,200-second
            # harness deadline authoritative.
            timeout=bounded_timeout(180),
        )
    except subprocess.TimeoutExpired as error:
        raise HarnessFailure(f"{name}: rollout validator timed out") from error
    combined = result.stdout + result.stderr
    if should_succeed:
        if result.returncode != 0 or expected_fragment not in combined:
            raise HarnessFailure(
                f"{name}: expected success, exit={result.returncode}, output={combined.strip()}"
            )
    elif result.returncode == 0 or expected_fragment not in combined:
        raise HarnessFailure(
            f"{name}: expected failure containing {expected_fragment!r}, "
            f"exit={result.returncode}, output={combined.strip()}"
        )


def copy_release_tree(root: Path) -> tuple[Path, Path, Path, Path]:
    scripts = root / "SoraPassport/Scripts"
    fixtures = root / "Fixtures/Modernization"
    scripts.mkdir(parents=True)
    fixtures.mkdir(parents=True)
    copied_shell = scripts / ROLLOUT_SHELL.name
    copied_json = scripts / ROLLOUT_JSON.name
    copied_funded_shell = scripts / FUNDED_CANARY_SHELL.name
    copied_funded_json = scripts / FUNDED_CANARY_JSON.name
    copied_taira_validator = scripts / TAIRA_DEPLOYMENT_VALIDATOR.name
    copied_migration_admission = scripts / "verify-ios-migration-promotion-ipa.sh"
    shutil.copy2(ROLLOUT_SHELL, copied_shell)
    shutil.copy2(ROLLOUT_JSON, copied_json)
    shutil.copy2(FUNDED_CANARY_SHELL, copied_funded_shell)
    shutil.copy2(FUNDED_CANARY_JSON, copied_funded_json)
    shutil.copy2(TAIRA_DEPLOYMENT_VALIDATOR, copied_taira_validator)
    copied_migration_admission.write_text(
        MIGRATION_ADMISSION_REGRESSION_STUB,
        encoding="utf-8",
    )
    copied_shell_source = copied_shell.read_text(encoding="utf-8")
    production_clock = 'current_epoch="$(/bin/date +%s)"'
    regression_clock = (
        'current_epoch="${SORA_ROLLOUT_REGRESSION_CURRENT_EPOCH_SECONDS:'
        '?missing regression current epoch}"'
    )
    if copied_shell_source.count(production_clock) != 1:
        raise HarnessFailure("production rollout clock source shape drifted")
    copied_shell.write_text(
        copied_shell_source.replace(production_clock, regression_clock),
        encoding="utf-8",
    )
    shutil.copy2(CANDIDATE_TEMPLATE, fixtures / CANDIDATE_TEMPLATE.name)
    shutil.copy2(ADVANCEMENT_TEMPLATE, fixtures / ADVANCEMENT_TEMPLATE.name)
    shutil.copy2(TAIRA_CANARY_TEMPLATE, fixtures / TAIRA_CANARY_TEMPLATE.name)
    shutil.copy2(MINAMOTO_CANARY_TEMPLATE, fixtures / MINAMOTO_CANARY_TEMPLATE.name)
    shutil.copy2(IROHA_READINESS, fixtures / IROHA_READINESS.name)
    shutil.copy2(TAIRA_DEPLOYMENT_BLOCKED, fixtures / TAIRA_DEPLOYMENT_BLOCKED.name)
    return (
        copied_shell,
        fixtures / "production-rollout-controller-trust.json",
        fixtures / FUNDED_CANARY_TRUST.name,
        fixtures / IROHA_READINESS.name,
    )


def generate_controller(root: Path, trust_path: Path) -> tuple[Path, Path, str]:
    private_key = root / "synthetic-controller-private.pem"
    public_key = root / "synthetic-controller-public.pem"
    require_tool_success(
        [str(OPENSSL), "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(private_key)]
    )
    require_tool_success(
        [str(OPENSSL), "ec", "-in", str(private_key), "-pubout", "-out", str(public_key)]
    )
    trust = {
        "schemaVersion": 1,
        "contractId": "sora-ios-production-rollout-controller-trust-v1",
        "status": "qualified",
        "releaseEnabled": True,
        "controllerId": CONTROLLER_ID,
        "signatureAlgorithm": "ecdsa-p256-sha256",
        "publicKeySha256": sha256_file(public_key),
        "blockingReasons": [],
    }
    write_json(trust_path, trust)
    return private_key, public_key, sha256_file(trust_path)


def generate_taira_deployment(
    root: Path,
    *,
    validator: Path,
    evaluated_at: int,
    current_chain_id: str = TAIRA_CHAIN_ID,
) -> tuple[dict[str, Any], dict[str, str]]:
    """Create synthetic dual-signed input for hermetic validation only."""

    operator_private = root / "synthetic-taira-operator-private.pem"
    operator_public = root / "synthetic-taira-operator-public.pem"
    reviewer_private = root / "synthetic-taira-reviewer-private.pem"
    reviewer_public = root / "synthetic-taira-reviewer-public.pem"
    for private_key, public_key in (
        (operator_private, operator_public),
        (reviewer_private, reviewer_public),
    ):
        require_tool_success(
            [
                str(OPENSSL), "ecparam", "-name", "prime256v1", "-genkey",
                "-noout", "-out", str(private_key),
            ]
        )
        require_tool_success(
            [str(OPENSSL), "ec", "-in", str(private_key), "-pubout", "-out", str(public_key)]
        )
        os.chmod(private_key, 0o600)
        os.chmod(public_key, 0o600)

    manifest = root / "synthetic-taira-deployment-manifest.json"
    operator_signature = root / "synthetic-taira-deployment-operator.sig"
    reviewer_signature = root / "synthetic-taira-deployment-reviewer.sig"
    if current_chain_id not in (TAIRA_CHAIN_ID, TAIRA_RETIRED_CHAIN_ID):
        raise HarnessFailure("synthetic current Taira UUID is unknown")
    retired_chain_id = (
        TAIRA_RETIRED_CHAIN_ID
        if current_chain_id == TAIRA_CHAIN_ID
        else TAIRA_CHAIN_ID
    )
    current_genesis = synthetic_sha256(
        f"taira-current-admitted-genesis:{current_chain_id}"
    )
    retired_genesis = synthetic_sha256(
        f"taira-retired-genesis:{retired_chain_id}"
    )
    current_base = "https://taira-public.synthetic.invalid"
    write_json(
        manifest,
        {
            "schemaVersion": 1,
            "contractId": "sora-taira-deployment-manifest-v1",
            "manifestId": "synthetic-ios-rollout-regression",
            "issuedAtEpochSeconds": evaluated_at - 60,
            "expiresAtEpochSeconds": evaluated_at + 3600,
            "authorities": {
                "operatorKeyId": "synthetic-taira-operator",
                "reviewerKeyId": "synthetic-taira-independent-reviewer",
            },
            "pendingRowPolicy": {
                "schemaVersion": 77,
                "preserveExactChainUuid": True,
                "mismatchedCurrentDisposition": "quarantine-recovery-only",
                "reinterpretationAllowed": False,
            },
            "epochs": [
                {
                    "chainId": current_chain_id,
                    "role": "current",
                    "deploymentEpoch": 2026081002,
                    "genesisHash": current_genesis,
                    "canonicalToriiBaseUrl": current_base,
                    "publicMcpEndpoint": f"{current_base}/v1/mcp",
                },
                {
                    "chainId": retired_chain_id,
                    "role": "retired",
                    "deploymentEpoch": 2026081001,
                    "genesisHash": retired_genesis,
                    "canonicalToriiBaseUrl": None,
                    "publicMcpEndpoint": None,
                },
            ],
        },
    )
    os.chmod(manifest, 0o600)
    sign_file(manifest, operator_signature, operator_private)
    sign_file(manifest, reviewer_signature, reviewer_private)
    os.chmod(operator_signature, 0o600)
    os.chmod(reviewer_signature, 0o600)
    admission = root / "synthetic-taira-deployment-admission.json"
    environment = {
        "IOS_TAIRA_DEPLOYMENT_MANIFEST_PATH": str(manifest),
        "IOS_TAIRA_DEPLOYMENT_OPERATOR_SIGNATURE_PATH": str(operator_signature),
        "IOS_TAIRA_DEPLOYMENT_REVIEWER_SIGNATURE_PATH": str(reviewer_signature),
        "IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_PATH": str(operator_public),
        "IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_PATH": str(reviewer_public),
        "IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256": sha256_file(operator_public),
        "IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256": sha256_file(reviewer_public),
        "IOS_TAIRA_DEPLOYMENT_EVALUATED_AT_EPOCH_SECONDS": str(evaluated_at),
    }
    command = [
        sys.executable,
        "-B",
        "-I",
        "-S",
        str(validator),
        "--verify-protected",
        "--manifest",
        str(manifest),
        "--operator-signature",
        str(operator_signature),
        "--reviewer-signature",
        str(reviewer_signature),
        "--operator-public-key",
        str(operator_public),
        "--reviewer-public-key",
        str(reviewer_public),
        "--operator-key-sha256",
        environment["IOS_TAIRA_DEPLOYMENT_OPERATOR_PUBLIC_KEY_SHA256"],
        "--reviewer-key-sha256",
        environment["IOS_TAIRA_DEPLOYMENT_REVIEWER_PUBLIC_KEY_SHA256"],
        "--evaluated-at-epoch-seconds",
        str(evaluated_at),
        "--output",
        str(admission),
    ]
    require_tool_success(command)
    admitted = json.loads(admission.read_text(encoding="utf-8"))
    current = admitted["current"]
    projection = {
        "manifestSha256": admitted["manifestSha256"],
        "admissionSha256": sha256_file(admission),
        "currentChainId": current["chainId"],
        "currentGenesisHash": current["genesisHash"],
        "canonicalToriiBaseUrl": current["canonicalToriiBaseUrl"],
        "publicMcpEndpoint": current["publicMcpEndpoint"],
    }
    return projection, environment


def generate_funded_canary_trust(
    root: Path,
    trust_path: Path,
) -> tuple[dict[str, Path], dict[str, Path], dict[str, str], str]:
    authorities: dict[str, dict[str, Any]] = {}
    private_keys: dict[str, Path] = {}
    public_keys: dict[str, Path] = {}
    roles = {
        "releaseOperator": ("release-operator", "synthetic-release-operator"),
        "independentApprover": ("independent-approver", "synthetic-independent-approver"),
        "independentReviewer": ("independent-reviewer", "synthetic-independent-reviewer"),
        "consumptionLedger": ("approval-consumption-ledger", "synthetic-consumption-ledger"),
    }
    for name, (role, key_id) in roles.items():
        private_key = root / f"synthetic-{name}-private.pem"
        public_key = root / f"synthetic-{name}-public.pem"
        require_tool_success(
            [str(OPENSSL), "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(private_key)]
        )
        require_tool_success(
            [str(OPENSSL), "ec", "-in", str(private_key), "-pubout", "-out", str(public_key)]
        )
        authorities[name] = {
            "role": role,
            "keyId": key_id,
            "publicKeyPemSha256": sha256_file(public_key),
            "enabled": True,
        }
        private_keys[name] = private_key
        public_keys[name] = public_key
    trust = {
        "schemaVersion": 1,
        "contractId": "sora-ios-funded-nexus-canary-trust-v1",
        "platform": "ios",
        "assessedAt": "2026-08-08",
        "status": "qualified",
        "signatureAlgorithm": "ecdsa-p256-sha256",
        "ledgerStoreId": "synthetic-append-only-ledger",
        "authorities": authorities,
        "blockingReasons": [],
    }
    write_json(trust_path, trust)
    return private_keys, public_keys, {name: key_id for name, (_, key_id) in roles.items()}, sha256_file(trust_path)


def make_environment_factory(
    *,
    shell_path: Path,
    trust_path: Path,
    trust_sha256: str,
    public_key: Path,
    regression_current_epoch: int,
) -> Callable[[ChainEvidence], dict[str, str]]:
    return lambda chain: environment_for(
        chain,
        shell_path=shell_path,
        trust_path=trust_path,
        trust_sha256=trust_sha256,
        public_key=public_key,
        regression_current_epoch=regression_current_epoch,
    )


def main() -> int:
    global _deadline, TAIRA_DEPLOYMENT, TAIRA_DEPLOYMENT_ENVIRONMENT
    _deadline = time.monotonic() + HARNESS_TIMEOUT_SECONDS

    for required in (
        OPENSSL,
        SHELL,
        ROLLOUT_SHELL,
        ROLLOUT_JSON,
        FUNDED_CANARY_SHELL,
        FUNDED_CANARY_JSON,
        TAIRA_DEPLOYMENT_VALIDATOR,
        TAIRA_DEPLOYMENT_BLOCKED,
        CANDIDATE_TEMPLATE,
        ADVANCEMENT_TEMPLATE,
        TAIRA_CANARY_TEMPLATE,
        MINAMOTO_CANARY_TEMPLATE,
        FUNDED_CANARY_TRUST,
        IROHA_READINESS,
    ):
        if not required.is_file() or required.is_symlink():
            raise HarnessFailure(f"required rollout regression input is missing or symbolic: {required}")
    if not PRIVATE_TMP.is_dir():
        raise HarnessFailure("/private/tmp is required by the iOS rollout contract")

    with tempfile.TemporaryDirectory(prefix="sora-ios-rollout-regression-", dir=PRIVATE_TMP) as temporary:
        temporary_root = Path(temporary)
        release_root = temporary_root / "release-tree"
        shell_path, trust_path, funded_trust_path, readiness_path = copy_release_tree(release_root)
        private_key, public_key, trust_sha256 = generate_controller(temporary_root, trust_path)
        (
            funded_private_keys,
            funded_public_keys,
            funded_key_ids,
            funded_trust_sha256,
        ) = generate_funded_canary_trust(temporary_root, funded_trust_path)
        now = int(time.time())
        TAIRA_DEPLOYMENT, TAIRA_DEPLOYMENT_ENVIRONMENT = generate_taira_deployment(
            temporary_root,
            validator=release_root / "SoraPassport/Scripts" / TAIRA_DEPLOYMENT_VALIDATOR.name,
            evaluated_at=now,
        )
        taira_admission_path = (
            temporary_root / "synthetic-taira-deployment-admission.json"
        )
        taira_admission = json.loads(
            taira_admission_path.read_text(encoding="utf-8")
        )
        retired_epoch = taira_admission["retired"]["deploymentEpoch"]
        require_taira_epoch_order_rejection(
            validator=release_root / "SoraPassport/Scripts" / FUNDED_CANARY_JSON.name,
            admission=taira_admission,
            output=temporary_root / "equal-epoch-canary-admission.json",
            current_epoch=retired_epoch,
            label="funded-canary",
        )
        require_taira_epoch_order_rejection(
            validator=release_root / "SoraPassport/Scripts" / ROLLOUT_JSON.name,
            admission=taira_admission,
            output=temporary_root / "reversed-epoch-rollout-admission.json",
            current_epoch=retired_epoch - 1,
            label="production-rollout",
        )
        current_evaluated_at = now - 10
        earliest_gate_epoch = current_evaluated_at - GATE_SPACING_SECONDS * 3
        common = build_common_evidence(
            temporary_root / "common",
            private_key,
            earliest_gate_epoch,
            funded_private_keys=funded_private_keys,
            funded_public_keys=funded_public_keys,
            funded_key_ids=funded_key_ids,
            funded_trust_sha256=funded_trust_sha256,
            readiness_path=readiness_path,
        )
        make_environment = make_environment_factory(
            shell_path=shell_path,
            trust_path=trust_path,
            trust_sha256=trust_sha256,
            public_key=public_key,
            regression_current_epoch=now,
        )

        success_chains: dict[int, ChainEvidence] = {}
        for target in TARGETS:
            chain = build_chain(
                temporary_root / f"success-{target}",
                target=target,
                common=common,
                private_key=private_key,
                current_evaluated_at=current_evaluated_at,
            )
            success_chains[target] = chain
            run_gate(
                name=f"success-{target}",
                shell_path=shell_path,
                environment=make_environment(chain),
                should_succeed=True,
                expected_fragment=f"production rollout v3 gate to {target}% qualified",
            )

        wrong_migration_ipa = make_environment(success_chains[1])
        wrong_migration_ipa["SORA_ROLLOUT_REGRESSION_MIGRATION_IPA_SHA256"] = synthetic_sha256(
            "different-post-archive-ipa"
        )
        run_gate(
            name="migration-admission-ipa-mismatch",
            shell_path=shell_path,
            environment=wrong_migration_ipa,
            should_succeed=False,
            expected_fragment="completed IPA lacks authenticated retained-device migration admission",
        )

        missing_full_evidence = make_environment(success_chains[1])
        missing_full_evidence.pop("TAIRA_FUNDED_CANARY_APPROVAL_RECEIPT_PATH")
        run_gate(
            name="missing-full-funded-evidence",
            shell_path=shell_path,
            environment=missing_full_evidence,
            should_succeed=False,
            expected_fragment="taira approval receipt path is missing",
        )

        baseline_readiness = readiness_path.read_bytes()

        def run_funded_semantic_mutation(name: str, mutation: str, expected_fragment: str) -> None:
            mutation_common = build_common_evidence(
                temporary_root / f"common-{name}",
                private_key,
                earliest_gate_epoch,
                funded_private_keys=funded_private_keys,
                funded_public_keys=funded_public_keys,
                funded_key_ids=funded_key_ids,
                funded_trust_sha256=funded_trust_sha256,
                readiness_path=readiness_path,
                funded_mutation=mutation,
            )
            mutation_chain = build_chain(
                temporary_root / name,
                target=1,
                common=mutation_common,
                private_key=private_key,
                current_evaluated_at=current_evaluated_at,
            )
            run_gate(
                name=name,
                shell_path=shell_path,
                environment=make_environment(mutation_chain),
                should_succeed=False,
                expected_fragment=expected_fragment,
            )
            readiness_path.write_bytes(baseline_readiness)

        run_funded_semantic_mutation(
            "preclaimed-funded-readiness",
            "preclaimed-readiness",
            "readiness.releaseCriteria.fundedTairaCanaryQualified must be false",
        )
        run_funded_semantic_mutation(
            "funded-finality-below-commit",
            "finalized-below-committed",
            "attested finality height does not cover the transaction's committed block height",
        )
        run_funded_semantic_mutation(
            "funded-trusted-first-height-above-finality",
            "trusted-first-height-above-finalized",
            "trusted first finality height exceeds the attested finalized checkpoint",
        )
        run_funded_semantic_mutation(
            "funded-missing-live-successor-proof",
            "missing-live-successor-proof",
            "execution.finalityReadback.liveBoundedSequentialStatefulSuccessorChainVerified must be true",
        )
        run_funded_semantic_mutation(
            "funded-invalid-challenge-binding",
            "invalid-challenge-binding",
            "execution.finalityReadback.attestationChallengeBindingSha256 must equal",
        )
        run_funded_semantic_mutation(
            "funded-invalid-finality-native-abi",
            "invalid-finality-native-abi",
            "finalityNative.observedNativeAbi must be an integer in [21, 21]",
        )
        run_funded_semantic_mutation(
            "funded-retroactive-finality-trust",
            "retroactive-finality-trust",
            "finality trust evidence was reviewed after funded execution began",
        )
        run_funded_semantic_mutation(
            "funded-retroactive-policy-review",
            "retroactive-policy-review",
            "low-value policy was reviewed after the dual-controlled approval",
        )
        run_funded_semantic_mutation(
            "funded-reused-cross-network-run",
            "reused-cross-network-run",
            "Taira and Minamoto receipts must use distinct receipt, candidate, finality, run, approval, and challenge evidence",
        )

        legacy_v2_replay = build_chain(
            temporary_root / "legacy-rollout-v2-replay",
            target=1,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(legacy_v2_target=1),
        )
        run_gate(
            name="legacy-rollout-v2-replay",
            shell_path=shell_path,
            environment=make_environment(legacy_v2_replay),
            should_succeed=False,
            expected_fragment="schemaVersion must be an integer in [3, 3]",
        )

        legacy_pi_v2_replay = build_chain(
            temporary_root / "legacy-pi-v2-replay",
            target=1,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(legacy_pi_v2_target=1),
        )
        run_gate(
            name="legacy-pi-v2-replay",
            shell_path=shell_path,
            environment=make_environment(legacy_pi_v2_replay),
            should_succeed=False,
            expected_fragment="schemaVersion must be an integer in [3, 3]",
        )

        missing_funded_admission = make_environment(success_chains[1])
        missing_funded_admission.pop("FUNDED_NEXUS_CANARY_ADMISSION_RECEIPT_PATH")
        run_gate(
            name="missing-funded-canary-admission",
            shell_path=shell_path,
            environment=missing_funded_admission,
            should_succeed=False,
            expected_fragment="funded canary admission receipt path is missing",
        )

        missing_ancestor = make_environment(success_chains[100])
        missing_ancestor.pop("PRODUCTION_ROLLOUT_RECEIPT_1_PATH")
        run_gate(
            name="missing-ancestor",
            shell_path=shell_path,
            environment=missing_ancestor,
            should_succeed=False,
            expected_fragment="rollout 1% receipt path is missing",
        )

        extra_ancestor = make_environment(success_chains[25])
        extra_ancestor["PRODUCTION_ROLLOUT_RECEIPT_25_PATH"] = str(
            success_chains[25].gates[25].rollout.payload
        )
        extra_ancestor["PRODUCTION_ROLLOUT_RECEIPT_25_SIGNATURE_PATH"] = str(
            success_chains[25].gates[25].rollout.signature
        )
        run_gate(
            name="extra-ancestor",
            shell_path=shell_path,
            environment=extra_ancestor,
            should_succeed=False,
            expected_fragment="rollout 25% receipt inputs are not part of the requested chain",
        )

        missing_historical_pi = make_environment(success_chains[100])
        missing_historical_pi.pop("PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_PATH")
        run_gate(
            name="missing-historical-pi",
            shell_path=shell_path,
            environment=missing_historical_pi,
            should_succeed=False,
            expected_fragment="rollout 5% PI receipt path is missing",
        )

        extra_historical_pi = make_environment(success_chains[5])
        extra_historical_pi[
            "PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_PATH"
        ] = str(success_chains[5].gates[5].pi.payload)
        extra_historical_pi[
            "PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_5_SIGNATURE_PATH"
        ] = str(success_chains[5].gates[5].pi.signature)
        run_gate(
            name="extra-historical-pi",
            shell_path=shell_path,
            environment=extra_historical_pi,
            should_succeed=False,
            expected_fragment="rollout 5% PI receipt inputs are not part of the requested chain",
        )

        missing_historical_evidence = make_environment(success_chains[100])
        missing_historical_evidence.pop("PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_PATH")
        run_gate(
            name="missing-historical-evidence",
            shell_path=shell_path,
            environment=missing_historical_evidence,
            should_succeed=False,
            expected_fragment="rollout 5% telemetry attestation path is missing",
        )

        extra_historical_evidence = make_environment(success_chains[5])
        gate5 = success_chains[5].gates[5]
        if gate5.telemetry is None or gate5.distribution is None:
            raise HarnessFailure("success 5% fixture lacks cohort attestations")
        extra_historical_evidence.update(
            {
                "PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_PATH": str(gate5.telemetry.payload),
                "PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_SIGNATURE_PATH": str(gate5.telemetry.signature),
                "PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_PATH": str(gate5.distribution.payload),
                "PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_SIGNATURE_PATH": str(
                    gate5.distribution.signature
                ),
            }
        )
        run_gate(
            name="extra-historical-evidence",
            shell_path=shell_path,
            environment=extra_historical_evidence,
            should_succeed=False,
            expected_fragment="rollout 5% historical cohort attestations are not part of the requested chain",
        )

        broken_link = build_chain(
            temporary_root / "broken-link",
            target=25,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(broken_link_target=25),
        )
        run_gate(
            name="broken-link",
            shell_path=shell_path,
            environment=make_environment(broken_link),
            should_succeed=False,
            expected_fragment="does not append the exact 5% gate",
        )

        broken_signature_environment = make_environment(success_chains[5])
        broken_signature = temporary_root / "broken-prior-signature.sig"
        broken_signature.write_bytes(b"not-an-ecdsa-signature")
        broken_signature_environment["PRODUCTION_ROLLOUT_RECEIPT_1_SIGNATURE_PATH"] = str(
            broken_signature
        )
        run_gate(
            name="broken-signature",
            shell_path=shell_path,
            environment=broken_signature_environment,
            should_succeed=False,
            expected_fragment="detached ECDSA signature is invalid",
        )

        rewritten_binding = build_chain(
            temporary_root / "rewritten-binding",
            target=25,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(rewritten_evaluation_binding_target=5),
        )
        run_gate(
            name="rewritten-binding",
            shell_path=shell_path,
            environment=make_environment(rewritten_binding),
            should_succeed=False,
            expected_fragment="stored rollout 5% identity or evaluation binding is inconsistent",
        )

        delayed_authorization = build_chain(
            temporary_root / "delayed-authorization",
            target=1,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(delayed_authorization_target=1),
        )
        run_gate(
            name="delayed-authorization",
            shell_path=shell_path,
            environment=make_environment(delayed_authorization),
            should_succeed=False,
            expected_fragment="rollout authorization must follow evaluation by no more than 30 seconds",
        )

        rewritten_candidate = build_chain(
            temporary_root / "rewritten-cohort-candidate",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(rewritten_cohort_candidate_target=5),
        )
        run_gate(
            name="rewritten-cohort-candidate",
            shell_path=shell_path,
            environment=make_environment(rewritten_candidate),
            should_succeed=False,
            expected_fragment="completed cohort is bound to a different candidate",
        )

        false_mobile_config_health_bound = build_chain(
            temporary_root / "false-mobile-config-health-bound",
            target=1,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(false_mobile_config_health_bound_target=1),
        )
        run_gate(
            name="false-mobile-config-health-bound",
            shell_path=shell_path,
            environment=make_environment(false_mobile_config_health_bound),
            should_succeed=False,
            expected_fragment="capabilities.mobileConfigHealthBound must be true",
        )

        false_history_block_height_contract = build_chain(
            temporary_root / "false-history-block-height-contract-deployed",
            target=1,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(false_history_block_height_contract_deployed_target=1),
        )
        run_gate(
            name="false-history-block-height-contract-deployed",
            shell_path=shell_path,
            environment=make_environment(false_history_block_height_contract),
            should_succeed=False,
            expected_fragment="capabilities.historyBlockHeightContractDeployed must be true",
        )

        stale_pi = build_chain(
            temporary_root / "stale-current-pi",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(stale_current_pi=True),
        )
        run_gate(
            name="stale-current-pi",
            shell_path=shell_path,
            environment=make_environment(stale_pi),
            should_succeed=False,
            expected_fragment="PI probe capture and last successful indexing must both be no more than five minutes old",
        )

        historical_pi = build_chain(
            temporary_root / "historical-pi-chronology",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(historical_pi_worker_lag_target=1),
        )
        run_gate(
            name="historical-pi-chronology",
            shell_path=shell_path,
            environment=make_environment(historical_pi),
            should_succeed=False,
            expected_fragment="stored rollout 1% identity or evaluation binding is inconsistent",
        )

        short_dwell = build_chain(
            temporary_root / "short-dwell",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(short_dwell_target=5),
        )
        run_gate(
            name="short-dwell",
            shell_path=shell_path,
            environment=make_environment(short_dwell),
            should_succeed=False,
            expected_fragment="cohort is not strictly sequenced after 1% with a full 48-hour dwell",
        )

        backdated_dwell = build_chain(
            temporary_root / "backdated-dwell",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(backdated_dwell_target=5),
        )
        run_gate(
            name="backdated-dwell",
            shell_path=shell_path,
            environment=make_environment(backdated_dwell),
            should_succeed=False,
            expected_fragment="cohort is not strictly sequenced after 1% with a full 48-hour dwell",
        )

        hard_stop = build_chain(
            temporary_root / "hard-stop-telemetry",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(hard_stop_target=5),
        )
        run_gate(
            name="hard-stop-telemetry",
            shell_path=shell_path,
            environment=make_environment(hard_stop),
            should_succeed=False,
            expected_fragment="rollout hard-stop counter is nonzero: confirmedMissingWalletEvents",
        )

        wrong_app_store = build_chain(
            temporary_root / "wrong-app-store",
            target=5,
            common=common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
            mutation=Mutation(wrong_app_store_target=5),
        )
        run_gate(
            name="wrong-app-store",
            shell_path=shell_path,
            environment=make_environment(wrong_app_store),
            should_succeed=False,
            expected_fragment="distribution attestation names a different App Store build",
        )

        wrong_keychain_environment = make_environment(success_chains[1])
        wrong_keychain_environment["PRODUCTION_KEYCHAIN_ACCESS_GROUPS_SHA256"] = synthetic_sha256(
            "wrong-keychain-groups"
        )
        run_gate(
            name="wrong-keychain-identity",
            shell_path=shell_path,
            environment=wrong_keychain_environment,
            should_succeed=False,
            expected_fragment="signed Keychain access groups differ from the independently retained production identity",
        )

        reversed_root = temporary_root / "reversed-taira-deployment"
        reversed_root.mkdir(mode=0o700)
        TAIRA_DEPLOYMENT, TAIRA_DEPLOYMENT_ENVIRONMENT = generate_taira_deployment(
            reversed_root,
            validator=release_root / "SoraPassport/Scripts" / TAIRA_DEPLOYMENT_VALIDATOR.name,
            evaluated_at=now,
            current_chain_id=TAIRA_RETIRED_CHAIN_ID,
        )
        reversed_common = build_common_evidence(
            reversed_root / "common",
            private_key,
            earliest_gate_epoch,
            funded_private_keys=funded_private_keys,
            funded_public_keys=funded_public_keys,
            funded_key_ids=funded_key_ids,
            funded_trust_sha256=funded_trust_sha256,
            readiness_path=readiness_path,
        )
        reversed_chain = build_chain(
            reversed_root / "success-1",
            target=1,
            common=reversed_common,
            private_key=private_key,
            current_evaluated_at=current_evaluated_at,
        )
        run_gate(
            name="success-reversed-operator-selected-taira",
            shell_path=shell_path,
            environment=make_environment(reversed_chain),
            should_succeed=True,
            expected_fragment="production rollout v3 gate to 1% qualified",
        )

    print("production rollout hermetic regression: 5 success paths and 35 fail-closed mutations passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except HarnessFailure as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
