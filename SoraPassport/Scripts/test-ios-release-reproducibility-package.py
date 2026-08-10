#!/usr/bin/env python3
"""Hermetic mutation tests for the iOS Release reproduction/package gate."""

from __future__ import annotations

import hashlib
import importlib.util
import os
import plistlib
import stat
import sys
import tempfile
import unittest
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).with_name("verify-ios-release-reproducibility-package.py")
SPEC = importlib.util.spec_from_file_location("release_package", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
release = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = release
SPEC.loader.exec_module(release)


REVISION = "1" * 40
CONTRACT_SHA = "2" * 64
BUILD_NUMBER = "2026081002"
APP_STORE_BUILD_NUMBER_LOWER_BOUND = "2026081001"
TAIRA_DEPLOYMENT = {
    "contractId": "sora-ios-taira-deployment-admission-v1",
    "manifestSha256": "c" * 64,
    "admissionSha256": "d" * 64,
    "currentChainId": "fc56984b-2be7-431d-840e-21514d1883f0",
    "retiredChainId": "809574f5-fee7-5e69-bfcf-52451e42d50f",
    "currentGenesisHash": "e" * 64,
    "retiredGenesisHash": "f" * 64,
    "currentDeploymentEpoch": "200",
    "retiredDeploymentEpoch": "100",
    "canonicalToriiBaseUrl": "https://public-01.taira.example.org",
    "publicMcpEndpoint": "https://public-01.taira.example.org/v1/mcp",
    "pendingRowPolicy":
        "schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation",
}
SIGNING_QUALIFICATION = {
    "schemaVersion": 1,
    "contractId": "sora-ios-production-signing-identity-qualification-v1",
    "platform": "ios",
    "status": "qualified",
    "runId": "11111111-2222-4333-8444-555555555555",
    "qualificationSequenceNumber": 9,
    "sourceRevision": REVISION,
    "assessedAtEpochSeconds": 1_700_000_000,
    "reviewedAtEpochSeconds": 1_700_000_100,
    "qualifiedAtEpochSeconds": 1_700_000_200,
    "qualificationContractSha256": "c" * 64,
    "trustRootSha256": "d" * 64,
    "releaseEvidenceProducerKeyId": "ios-signing-producer-hermetic",
    "independentReviewerKeyId": "ios-signing-reviewer-hermetic",
    "bundleIdentifier": "co.jp.soramitsu.sora",
    "developmentTeam": "YLWWUD25VZ",
    "applicationIdentifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
    "codeSignStyle": "Automatic",
    "configuredCodeSignIdentity": "iPhone Developer",
    "entitlementsPath": "SoraPassport/SoraPassport.entitlements",
    "sourceEntitlementsSha256":
        "97704a8960b4facceef54397a08fb5d0a456247c3627359215aa2a27df22656c",
    "signedEntitlementsSha256": "6" * 64,
    "keychainAccessGroupsSha256": "7" * 64,
    "productionDistributionCertificateSha256": "a" * 64,
    "productionProvisioningProfileUuid":
        "11111111-2222-3333-4444-555555555555",
    "productionProvisioningProfileName": "SORA App Store Distribution",
    "canonicalProvisioningProfileSha256": "9" * 64,
    "appStoreSigningContinuityReviewed": True,
    "privateKeyOrCredentialRecorded": False,
    "blockingReasons": [],
}
VENDORED_QUALIFICATION = {
    "schemaVersion": 1,
    "contractId": "sora-ios-vendored-binary-qualification-v1",
    "platform": "ios",
    "status": "qualified",
    "runId": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
    "qualificationSequenceNumber": 10,
    "sourceRevision": REVISION,
    "reviewedAtEpochSeconds": 1_700_000_100,
    "qualifiedAtEpochSeconds": 1_700_000_200,
    "qualificationContractSha256": "b" * 64,
    "trustRootSha256": "c" * 64,
    "evidenceManifestSha256": "d" * 64,
    "artifactEvidenceProducerKeyId": "ios-vendored-producer-hermetic",
    "independentReviewerKeyId": "ios-vendored-reviewer-hermetic",
    "artifactCount": 6,
    "completeInventory": True,
    "wholeTreeContentQualified": True,
    "sourceOrVendorIdentityQualified": True,
    "licenseAndNoticeQualified": True,
    "sbomQualified": True,
    "buildProvenanceQualified": True,
    "artifactAttestationsQualified": True,
    "duplicateSorawalletByteIdentityProven": True,
    "blockingReasons": [],
}


def write(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    path.chmod(0o600)


def digest(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {"sha256": hashlib.sha256(raw).hexdigest(), "byteCount": len(raw)}


class Fixture:
    def __init__(self, root: Path, *, identical_ipas: bool = False) -> None:
        self.root = root
        self.primary_repo = root / "primary-checkout"
        self.reproduction_repo = root / "reproduction-checkout"
        self.primary = self._build("primary", self.primary_repo, b"production-primary")
        reproduction_bytes = b"production-primary" if identical_ipas else b"production-reproduction"
        self.reproduction = self._build("reproduction", self.reproduction_repo, reproduction_bytes)
        self.output = root / "equivalence.json"

    def _identity(self, path: Path) -> dict[str, Any]:
        metadata = path.stat()
        return {"path": str(path), "device": metadata.st_dev, "inode": metadata.st_ino}

    def _build(self, role: str, repository: Path, ipa_raw: bytes) -> dict[str, Any]:
        repository.mkdir()
        dependencies = []
        for relative in release.DEPENDENCY_PATHS:
            target = repository / relative
            write(target, f"reviewed dependency manifest: {relative}\n".encode())
            dependencies.append({"path": relative, **digest(target)})
        signing = repository / release.SIGNING_RECEIPT.relative_to(release.ROOT)
        write(signing, release.canonical_json(SIGNING_QUALIFICATION))
        vendored = repository / release.VENDORED_RECEIPT.relative_to(release.ROOT)
        write(vendored, release.canonical_json(VENDORED_QUALIFICATION))
        derived = self.root / f"{role}-DerivedData"
        archive = self.root / f"{role}.xcarchive"
        export = self.root / f"{role}-export"
        for directory in (derived, archive, export):
            directory.mkdir()
        archived_app = archive / "Products/Applications/SoraPassport.app"
        archived_app.mkdir(parents=True)
        info_names = {
            "contractId": "SoraTairaDeploymentAdmissionContractId",
            "manifestSha256": "SoraTairaDeploymentManifestSha256",
            "admissionSha256": "SoraTairaDeploymentAdmissionSha256",
            "currentChainId": "SoraTairaCurrentChainId",
            "retiredChainId": "SoraTairaRetiredChainId",
            "currentGenesisHash": "SoraTairaCurrentGenesisHash",
            "retiredGenesisHash": "SoraTairaRetiredGenesisHash",
            "currentDeploymentEpoch": "SoraTairaCurrentDeploymentEpoch",
            "retiredDeploymentEpoch": "SoraTairaRetiredDeploymentEpoch",
            "canonicalToriiBaseUrl": "SoraTairaCanonicalToriiBaseUrl",
            "publicMcpEndpoint": "SoraTairaPublicMcpEndpoint",
            "pendingRowPolicy": "SoraTairaPendingRowPolicy",
        }
        write(
            archived_app / "Info.plist",
            plistlib.dumps(
                {
                    "CFBundleVersion": BUILD_NUMBER,
                    **{
                        info_names[key]: value
                        for key, value in TAIRA_DEPLOYMENT.items()
                    },
                },
                fmt=plistlib.FMT_BINARY,
                sort_keys=True,
            ),
        )
        ipa = export / "SoraPassport.ipa"
        archive_log = self.root / f"{role}-archive.log"
        export_log = self.root / f"{role}-export.log"
        write(ipa, ipa_raw)
        write(archive_log, f"{role} archive\n".encode())
        write(export_log, f"{role} export\n".encode())
        archive_content = self.root / f"{role}-archive-content-manifest.json"
        export_content = self.root / f"{role}-export-content-manifest.json"
        write(archive_content, release.canonical_json(release.content_manifest(archive, f"{role} archive")))
        write(export_content, release.canonical_json(release.content_manifest(export, f"{role} export")))
        manifest = {
            "format": release.BUILD_FORMAT,
            "role": role,
            "cleanCheckout": True,
            "sourceRevision": REVISION,
            "qualificationContractSha256": CONTRACT_SHA,
            "buildNumber": BUILD_NUMBER,
            "appStoreBuildNumberLowerBound":
                APP_STORE_BUILD_NUMBER_LOWER_BOUND,
            "tairaDeployment": dict(TAIRA_DEPLOYMENT),
            "checkoutIdentity": self._identity(repository),
            "derivedDataIdentity": self._identity(derived),
            "archiveIdentity": self._identity(archive),
            "exportIdentity": self._identity(export),
            "archiveContentManifest": {"path": str(archive_content), **digest(archive_content)},
            "exportContentManifest": {"path": str(export_content), **digest(export_content)},
            "ipa": {"path": str(ipa), **digest(ipa)},
            "dependencyManifests": dependencies,
            "signingIdentityReceipt": {"path": str(signing), **digest(signing)},
            "vendoredBinaryReceipt": {
                "path": str(vendored),
                **digest(vendored),
            },
            "logs": {
                "archive": {"path": str(archive_log), **digest(archive_log)},
                "export": {"path": str(export_log), **digest(export_log)},
            },
        }
        manifest_path = self.root / f"{role}-manifest.json"
        write(manifest_path, release.canonical_json(manifest))
        return {
            "ipa": ipa,
            "manifest": manifest,
            "manifest_path": manifest_path,
            "archive_log": archive_log,
            "export_log": export_log,
        }

    def inspection(self, path: Path) -> dict[str, Any]:
        raw = path.read_bytes()
        return {
            "ipaSha256": hashlib.sha256(raw).hexdigest(),
            "ipaByteCount": len(raw),
            "sourceRevision": REVISION,
            "qualificationContractSha256": CONTRACT_SHA,
            "tairaDeployment": dict(TAIRA_DEPLOYMENT),
            "bundleIdentifier": "co.jp.soramitsu.sora",
            "canonicalProjection": {"contractId": "projection-v2", "recordSha256": "3" * 64},
            "canonicalExecutableSha256": "4" * 64,
            "canonicalExecutableByteCount": 123,
            "canonicalInfo": {
                "CFBundleIdentifier": "co.jp.soramitsu.sora",
                "buildVersion": BUILD_NUMBER,
            },
            "entitlementProjection": [{"path": "SoraPassport", "sha256": "5" * 64}],
            "signedIdentity": {
                "applicationIdentifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
                "teamIdentifier": "YLWWUD25VZ",
                "signedEntitlementsSha256": "6" * 64,
                "keychainAccessGroupsSha256": "7" * 64,
                "embeddedProvisioningProfileSha256": "8" * 64,
                "canonicalProvisioningProfileSha256": "9" * 64,
                "provisioningProfileUuid": "11111111-2222-3333-4444-555555555555",
                "provisioningProfileName": "SORA App Store Distribution",
                "applicationSigningCertificateSha256": "a" * 64,
                "developerCertificateSha256": ["a" * 64],
                "codeDirectories": [{"codePath": "SoraPassport", "candidateCodeDirectorySha256": ["b" * 64]}],
            },
        }

    def compare(self, inspector=None) -> dict[str, Any]:
        return release.compare_releases(
            self.primary["ipa"],
            self.reproduction["ipa"],
            self.primary["manifest_path"],
            self.reproduction["manifest_path"],
            self.output,
            inspector or self.inspection,
        )

    def seal(self) -> tuple[Path, Path, str]:
        self.compare()
        receipt = self.root / "qualification.json"
        signature = self.root / "qualification.sig"
        write(
            receipt,
            release.canonical_json(
                {
                    "schemaVersion": 8,
                    "contractId": "sora-ios-wallet-migration-qualification-v8",
                    "status": "qualified",
                }
            ),
        )
        write(signature, b"detached-qualification-signature")
        package = self.root / "qualified-package.zip"
        release.seal_package(
            package,
            self.primary["ipa"],
            self.output,
            self.primary["manifest_path"],
            self.reproduction["manifest_path"],
            receipt,
            signature,
        )
        return package, signature, hashlib.sha256(receipt.read_bytes()).hexdigest()


class ReleaseReproducibilityPackageTests(unittest.TestCase):
    def temporary(self) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        temporary = tempfile.TemporaryDirectory(prefix="release-package-test.")
        root = Path(temporary.name).resolve()
        root.chmod(0o700)
        return temporary, root

    def test_contract_lint_and_decoded_mobileprovision_dates_are_canonical(self) -> None:
        release.lint_contract()
        self.assertEqual(len(release.DEPENDENCY_PATHS), 6)
        encoded = plistlib.dumps(
            {
                "CreationDate": datetime(2026, 8, 10, 1, 2, 3),
                "ExpirationDate": datetime(2027, 8, 10, 4, 5, 6),
                "DeveloperCertificates": [b"synthetic-certificate"],
                "Enabled": True,
                "Version": 1,
                "Name": "Hermetic Profile",
            },
            fmt=plistlib.FMT_XML,
            sort_keys=True,
        )
        decoded = plistlib.loads(encoded)
        self.assertIsInstance(decoded["CreationDate"], datetime)
        self.assertIsInstance(decoded["ExpirationDate"], datetime)
        self.assertEqual(
            release.plist_projection(decoded),
            {
                "CreationDate": {"dateUtc": "2026-08-10T01:02:03.000000Z"},
                "DeveloperCertificates": [
                    {
                        "byteCount": 21,
                        "dataSha256": hashlib.sha256(
                            b"synthetic-certificate"
                        ).hexdigest(),
                    }
                ],
                "Enabled": True,
                "ExpirationDate": {"dateUtc": "2027-08-10T04:05:06.000000Z"},
                "Name": "Hermetic Profile",
                "Version": 1,
            },
        )
        with self.assertRaisesRegex(
            release.ReleaseReproducibilityError,
            "unsupported plist value",
        ):
            release.plist_projection(1.5)

    def test_exact_ipa_bytes_select_deterministic_policy(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            receipt = Fixture(root, identical_ipas=True).compare()
            self.assertTrue(receipt["exactIpaByteEquality"])
            self.assertTrue(receipt["deterministicProductionExportDemonstrated"])
            self.assertEqual(receipt["equivalencePolicy"], "exact-ipa-bytes-v1")
            stale = dict(receipt)
            stale["derivedTestHost"] = {"sha256": "f" * 64}
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "stale, mixed"):
                release.parse_equivalence_receipt(release.canonical_json(stale))

    def test_different_container_bytes_never_claim_byte_equality(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            receipt = Fixture(root).compare()
            self.assertFalse(receipt["exactIpaByteEquality"])
            self.assertFalse(receipt["deterministicProductionExportDemonstrated"])
            self.assertTrue(receipt["signedContainerNondeterminismObserved"])
            self.assertEqual(receipt["equivalencePolicy"], "canonical-signed-application-equivalence-v1")

    def test_canonical_resource_projection_mutation_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            def inspector(path: Path) -> dict[str, Any]:
                value = fixture.inspection(path)
                if path == fixture.reproduction["ipa"]:
                    value["canonicalProjection"] = {"contractId": "projection-v2", "recordSha256": "c" * 64}
                return value
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "canonicalProjection differ"):
                fixture.compare(inspector)

    def test_code_directory_profile_entitlement_or_certificate_mutation_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            def inspector(path: Path) -> dict[str, Any]:
                value = fixture.inspection(path)
                if path == fixture.reproduction["ipa"]:
                    value["signedIdentity"]["developerCertificateSha256"] = ["d" * 64]
                return value
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "signedIdentity differ"):
                fixture.compare(inspector)

    def test_taira_manifest_or_admission_identity_mismatch_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            value = dict(fixture.reproduction["manifest"])
            value["tairaDeployment"] = dict(value["tairaDeployment"])
            value["tairaDeployment"]["admissionSha256"] = "a" * 64
            write(
                fixture.reproduction["manifest_path"],
                release.canonical_json(value),
            )
            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "Taira deployment admission changed",
            ):
                fixture.compare()

            info_names = {
                "contractId": "SoraTairaDeploymentAdmissionContractId",
                "manifestSha256": "SoraTairaDeploymentManifestSha256",
                "admissionSha256": "SoraTairaDeploymentAdmissionSha256",
                "currentChainId": "SoraTairaCurrentChainId",
                "retiredChainId": "SoraTairaRetiredChainId",
                "currentGenesisHash": "SoraTairaCurrentGenesisHash",
                "retiredGenesisHash": "SoraTairaRetiredGenesisHash",
                "currentDeploymentEpoch": "SoraTairaCurrentDeploymentEpoch",
                "retiredDeploymentEpoch": "SoraTairaRetiredDeploymentEpoch",
                "canonicalToriiBaseUrl": "SoraTairaCanonicalToriiBaseUrl",
                "publicMcpEndpoint": "SoraTairaPublicMcpEndpoint",
                "pendingRowPolicy": "SoraTairaPendingRowPolicy",
            }
            archive_info = {
                info_names[key]: value
                for key, value in TAIRA_DEPLOYMENT.items()
            }
            archive_info["SoraTairaCurrentDeploymentEpoch"] = "50"
            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "current Taira deployment epoch is not newer than retired",
            ):
                release.parse_taira_deployment_projection(
                    archive_info,
                    "regressed archive",
                )
            archive_info["SoraTairaCurrentDeploymentEpoch"] = "9007199254740992"
            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "currentDeploymentEpoch is not one positive canonical epoch",
            ):
                release.parse_taira_deployment_projection(
                    archive_info,
                    "out-of-range archive",
                )

    def test_stale_or_mixed_build_manifest_shape_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            stale = dict(fixture.primary["manifest"])
            stale["derivedTestHost"] = {"sha256": "e" * 64}
            write(fixture.primary["manifest_path"], release.canonical_json(stale))
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "stale, mixed"):
                fixture.compare()

    def test_build_number_is_newer_and_matches_both_signed_applications(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            stale = dict(fixture.primary["manifest"])
            stale["appStoreBuildNumberLowerBound"] = BUILD_NUMBER
            write(fixture.primary["manifest_path"], release.canonical_json(stale))
            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "not newer than its App Store lower bound",
            ):
                fixture.compare()

        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)

            def inspector(path: Path) -> dict[str, Any]:
                value = fixture.inspection(path)
                if path == fixture.reproduction["ipa"]:
                    value["canonicalInfo"]["buildVersion"] = "2026081003"
                return value

            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "signed IPA build number differs",
            ):
                fixture.compare(inspector)

    def test_same_checkout_or_derived_data_inode_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            value = dict(fixture.reproduction["manifest"])
            value["checkoutIdentity"] = fixture.primary["manifest"]["checkoutIdentity"]
            write(fixture.reproduction["manifest_path"], release.canonical_json(value))
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "checkout are not physically distinct"):
                fixture.compare()

    def test_missing_sixth_dependency_manifest_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            value = dict(fixture.reproduction["manifest"])
            value["dependencyManifests"] = value["dependencyManifests"][:-1]
            write(fixture.reproduction["manifest_path"], release.canonical_json(value))
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "exactly six"):
                fixture.compare()

    def test_sealed_download_preserves_exact_primary_candidate(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            package, signature, receipt_sha = fixture.seal()
            manifest = release.verify_package(package, fixture.primary["ipa"], receipt_sha, signature)
            self.assertEqual(manifest["members"]["candidate.ipa"]["sha256"], digest(fixture.primary["ipa"])["sha256"])
            self.assertEqual(
                manifest["members"]["signing-identity-receipt.json"]["sha256"],
                digest(
                    Path(
                        fixture.primary["manifest"]["signingIdentityReceipt"][
                            "path"
                        ]
                    )
                )["sha256"],
            )
            self.assertEqual(
                manifest["members"][
                    "vendored-binary-qualification-receipt.json"
                ]["sha256"],
                digest(
                    Path(
                        fixture.primary["manifest"]["vendoredBinaryReceipt"][
                            "path"
                        ]
                    )
                )["sha256"],
            )
            self.assertEqual(stat.S_IMODE(package.stat().st_mode), 0o600)
            changed_manifest = dict(manifest)
            changed_manifest["equivalencePolicy"] = "exact-ipa-bytes-v1"
            self._rewrite_member(
                package,
                "package-manifest.json",
                release.canonical_json(changed_manifest),
            )
            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "differs from its equivalence receipt",
            ):
                release.verify_package(
                    package,
                    fixture.primary["ipa"],
                    receipt_sha,
                    signature,
                )

    def test_candidate_member_byte_mutation_is_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            package, signature, receipt_sha = fixture.seal()
            self._rewrite_member(package, "candidate.ipa", b"mutated")
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "candidate[.]ipa|exact immutable primary IPA"):
                release.verify_package(package, fixture.primary["ipa"], receipt_sha, signature)

    def test_unexpected_member_and_member_mode_are_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            package, signature, receipt_sha = fixture.seal()
            with zipfile.ZipFile(package, "a") as archive:
                archive.writestr("unexpected", b"x")
            package.chmod(0o600)
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "member count"):
                release.verify_package(package, fixture.primary["ipa"], receipt_sha, signature)

    def test_package_symlink_hardlink_and_public_mode_are_rejected(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            package, signature, receipt_sha = fixture.seal()
            alias = root / "alias.zip"
            alias.symlink_to(package)
            with self.assertRaises(release.ReleaseReproducibilityError):
                release.verify_package(alias, fixture.primary["ipa"], receipt_sha, signature)
            hardlink = root / "hardlink.zip"
            os.link(package, hardlink)
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "regular inode"):
                release.verify_package(package, fixture.primary["ipa"], receipt_sha, signature)
            hardlink.unlink()
            package.chmod(0o644)
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "owner-only"):
                release.verify_package(package, fixture.primary["ipa"], receipt_sha, signature)

    def test_v7_qualification_receipt_cannot_be_sealed(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)
            fixture.compare()
            receipt = root / "qualification.json"
            signature = root / "qualification.sig"
            write(receipt, release.canonical_json({"schemaVersion": 7, "contractId": "sora-ios-wallet-migration-qualification-v7", "status": "qualified"}))
            write(signature, b"signature")
            late_mutation = Path(fixture.reproduction["manifest"]["archiveIdentity"]["path"]) / "late-mutation"
            write(late_mutation, b"changed after equivalence")
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "content changed"):
                release.seal_package(root / "package-after-mutation.zip", fixture.primary["ipa"], fixture.output, fixture.primary["manifest_path"], fixture.reproduction["manifest_path"], receipt, signature)
            late_mutation.unlink()
            with self.assertRaisesRegex(release.ReleaseReproducibilityError, "receipt v8"):
                release.seal_package(root / "package.zip", fixture.primary["ipa"], fixture.output, fixture.primary["manifest_path"], fixture.reproduction["manifest_path"], receipt, signature)

    def test_both_ipas_must_match_authenticated_signing_and_vendored_receipts(self) -> None:
        temporary, root = self.temporary()
        with temporary:
            fixture = Fixture(root)

            def inspector(path: Path) -> dict[str, Any]:
                value = fixture.inspection(path)
                value["signedIdentity"][
                    "applicationSigningCertificateSha256"
                ] = "e" * 64
                value["signedIdentity"]["developerCertificateSha256"] = [
                    "e" * 64
                ]
                return value

            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "applicationSigningCertificateSha256 differs from retained continuity",
            ):
                fixture.compare(inspector)

            vendored_path = Path(
                fixture.reproduction["manifest"]["vendoredBinaryReceipt"][
                    "path"
                ]
            )
            changed_vendored = dict(VENDORED_QUALIFICATION)
            changed_vendored["qualificationSequenceNumber"] = 11
            write(vendored_path, release.canonical_json(changed_vendored))
            changed_manifest = dict(fixture.reproduction["manifest"])
            changed_manifest["vendoredBinaryReceipt"] = {
                "path": str(vendored_path),
                **digest(vendored_path),
            }
            write(
                fixture.reproduction["manifest_path"],
                release.canonical_json(changed_manifest),
            )
            with self.assertRaisesRegex(
                release.ReleaseReproducibilityError,
                "vendored-binary receipt digests differ",
            ):
                fixture.compare()

    def test_ambiguous_json_tokens_are_rejected_before_shape_validation(self) -> None:
        for raw, fragment in (
            (b'{"value":1.0}\n', "floating-point"),
            (b'{"value":-0}\n', "negative zero"),
            (b'{"value":9007199254740992}\n', "safe-integer"),
            (b'{"value":1,"value":2}\n', "duplicate key"),
        ):
            with self.subTest(fragment=fragment):
                with self.assertRaisesRegex(
                    release.ReleaseReproducibilityError,
                    fragment,
                ):
                    release.parse_canonical_json(raw, "mutation")

    @staticmethod
    def _rewrite_member(package: Path, member: str, replacement: bytes) -> None:
        with zipfile.ZipFile(package, "r") as archive:
            records = [(info, archive.read(info)) for info in archive.infolist()]
        package.unlink()
        with zipfile.ZipFile(package, "w", allowZip64=True) as archive:
            for info, raw in records:
                archive.writestr(info, replacement if info.filename == member else raw)
        package.chmod(0o600)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ReleaseReproducibilityPackageTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
