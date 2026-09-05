#!/usr/bin/env python3
"""Hermetic success and fail-closed tests for vendored XCFramework admission."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
import uuid
from pathlib import Path
from unittest import mock


SOURCE_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).with_name("verify-ios-vendored-binary-qualification.py")
OPENSSL = Path("/usr/bin/openssl")
PRIVATE_TMP = Path("/private/tmp")
SOURCE_REVISION = "1" * 40
RUN_ID = "11111111-2222-4333-8444-555555555555"
SEQUENCE = 7
BLOCKED_NAMES = (
    "ios-vendored-binary-qualification.blocked.json",
    "ios-vendored-binary-qualification-evidence.blocked.json",
    "ios-vendored-binary-qualification-trust.blocked.json",
    "ios-vendored-binary-readiness.json",
)


def load_verifier() -> object:
    name = f"vendored_binary_{uuid.uuid4().hex}"
    specification = importlib.util.spec_from_file_location(name, SCRIPT)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


def canonical_json(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
        + "\n"
    ).encode("utf-8")


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def synthetic_digest(label: str) -> str:
    return digest(f"vendored-binary-hermetic:{label}".encode("utf-8"))


def write(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)


def run(arguments: list[str]) -> None:
    subprocess.run(
        arguments,
        check=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env={"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"},
    )


class QualifiedFixture:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.repository = root / "repository"
        self.protected = root / "protected"
        self.repository.mkdir(mode=0o700)
        self.protected.mkdir(mode=0o700)
        self.verifier = load_verifier()
        self._bind_repository()
        self._write_contract_files()
        self.artifacts = self._write_artifacts()
        self.contract_sha256 = self._contract_sha256()
        self.producer_private, self.producer_public = self._keypair("producer")
        self.reviewer_private, self.reviewer_public = self._keypair("reviewer")
        self.producer_key_sha256 = digest(self.producer_public.read_bytes())
        self.reviewer_key_sha256 = digest(self.reviewer_public.read_bytes())
        self._write_qualified_records()
        self._sign_all()
        self.environment = self._environment()

    def _bind_repository(self) -> None:
        fixture_root = self.repository / "Fixtures/Modernization"
        self.verifier.ROOT = self.repository
        self.verifier.FIXTURES = fixture_root
        self.verifier.RECEIPT = fixture_root / "ios-vendored-binary-qualification.json"
        self.verifier.EVIDENCE = (
            fixture_root / "ios-vendored-binary-qualification-evidence.json"
        )
        self.verifier.TRUST = (
            fixture_root / "ios-vendored-binary-qualification-trust.json"
        )
        self.verifier.BLOCKED_RECEIPT = (
            fixture_root / "ios-vendored-binary-qualification.blocked.json"
        )
        self.verifier.BLOCKED_EVIDENCE = (
            fixture_root / "ios-vendored-binary-qualification-evidence.blocked.json"
        )
        self.verifier.BLOCKED_TRUST = (
            fixture_root / "ios-vendored-binary-qualification-trust.blocked.json"
        )
        self.verifier.LEGACY_READINESS = (
            fixture_root / "ios-vendored-binary-readiness.json"
        )

    def _write_contract_files(self) -> None:
        source_fixtures = SOURCE_ROOT / "Fixtures/Modernization"
        for relative in self.verifier.CONTRACT_FILES:
            target = self.repository / relative
            name = Path(relative).name
            if name in BLOCKED_NAMES:
                write(target, (source_fixtures / name).read_bytes())
            else:
                write(target, f"hermetic contract input: {relative}\n".encode("utf-8"))

    def _tree_files(self, artifact_id: str) -> dict[str, bytes]:
        if artifact_id in (
            "shared-sorawallet",
            "sora-wallet-binary-sorawallet",
        ):
            return {
                "Info.plist": b"identical-sorawallet-info",
                "ios-arm64/sorawallet": b"identical-sorawallet-binary",
            }
        return {
            "Info.plist": f"{artifact_id}-info".encode("utf-8"),
            f"ios-arm64/{artifact_id}": f"{artifact_id}-binary".encode("utf-8"),
        }

    def _write_artifacts(self) -> list[dict[str, object]]:
        records: list[dict[str, object]] = []
        for artifact_id, tree_path in self.verifier.ARTIFACTS:
            for relative, raw in self._tree_files(artifact_id).items():
                write(self.repository / tree_path / relative, raw)
            state = self.verifier.inventory_tree(tree_path, artifact_id)
            entries = {path: value[0] for path, value in state.items()}
            manifest_raw = "".join(
                f"{entries[path]}  {path}\n" for path in sorted(entries)
            ).encode("utf-8")
            manifest_path = self.repository / self.verifier.expected_manifest_path(
                artifact_id
            )
            write(manifest_path, manifest_raw)
            review_values = {
                "sourceOrVendorIdentityEvidenceSha256": synthetic_digest(
                    f"{artifact_id}:source"
                ),
                "licenseAndNoticeEvidenceSha256": synthetic_digest(
                    f"{artifact_id}:license"
                ),
                "sbomSha256": synthetic_digest(f"{artifact_id}:sbom"),
                "buildProvenanceSha256": synthetic_digest(f"{artifact_id}:build"),
                "artifactAttestationSha256": synthetic_digest(
                    f"{artifact_id}:attestation"
                ),
            }
            provenance = {
                "schemaVersion": 2,
                "format": "sora-ios-vendored-binary-provenance-v2",
                "platform": "ios",
                "artifactId": artifact_id,
                "treePath": tree_path,
                "independentReviewStatus": "qualified",
                "reviewedFileCount": len(entries),
                "contentManifestSha256": digest(manifest_raw),
                **review_values,
            }
            provenance_raw = canonical_json(provenance)
            write(
                self.repository / self.verifier.expected_provenance_path(artifact_id),
                provenance_raw,
            )
            records.append(
                {
                    "id": artifact_id,
                    "treePath": tree_path,
                    "contentManifestPath": self.verifier.expected_manifest_path(
                        artifact_id
                    ),
                    "provenancePath": self.verifier.expected_provenance_path(
                        artifact_id
                    ),
                    "reviewedFileCount": len(entries),
                    "contentManifestSha256": digest(manifest_raw),
                    "provenanceSha256": digest(provenance_raw),
                    **review_values,
                    "treeContentSha256": self.verifier.tree_content_sha256(entries),
                }
            )
        return records

    def _contract_sha256(self) -> str:
        snapshots = self.root / "contract-snapshots"
        snapshots.mkdir(mode=0o700)
        return self.verifier.contract_sha256(self.verifier.StableInputs(snapshots))

    def _keypair(self, label: str) -> tuple[Path, Path]:
        private = self.protected / f"{label}-private.pem"
        public = self.protected / f"{label}-public.pem"
        run(
            [
                str(OPENSSL),
                "ecparam",
                "-name",
                "prime256v1",
                "-genkey",
                "-noout",
                "-out",
                str(private),
            ]
        )
        run([str(OPENSSL), "ec", "-in", str(private), "-pubout", "-out", str(public)])
        private.chmod(0o600)
        public.chmod(0o600)
        return private, public

    def _write_qualified_records(self) -> None:
        now = int(time.time())
        self.trust = {
            "schemaVersion": 1,
            "contractId": "sora-ios-vendored-binary-qualification-trust-v1",
            "platform": "ios",
            "status": "qualified",
            "signatureAlgorithm": "ecdsa-p256-sha256",
            "authorities": {
                "artifactEvidenceProducer": {
                    "role": "artifact-evidence-producer",
                    "keyId": "ios-vendored-artifact-producer-hermetic",
                    "publicKeyPemSha256": self.producer_key_sha256,
                    "enabled": True,
                },
                "independentReviewer": {
                    "role": "independent-reviewer",
                    "keyId": "ios-vendored-independent-reviewer-hermetic",
                    "publicKeyPemSha256": self.reviewer_key_sha256,
                    "enabled": True,
                },
            },
            "replayPolicy": {
                "maximumQualificationAgeSeconds": 2_592_000,
                "maximumRunDurationSeconds": 172_800,
                "maximumReviewDelaySeconds": 86_400,
            },
            "blockingReasons": [],
        }
        write(self.verifier.TRUST, canonical_json(self.trust))
        trust_sha256 = digest(self.verifier.TRUST.read_bytes())
        self.evidence = {
            "schemaVersion": 1,
            "contractId": "sora-ios-vendored-binary-evidence-v1",
            "platform": "ios",
            "status": "qualified",
            "runId": RUN_ID,
            "qualificationSequenceNumber": SEQUENCE,
            "sourceRevision": SOURCE_REVISION,
            "runStartedAtEpochSeconds": now - 300,
            "runFinishedAtEpochSeconds": now - 240,
            "producedAtEpochSeconds": now - 180,
            "qualificationContractSha256": self.contract_sha256,
            "trustRootSha256": trust_sha256,
            "artifactEvidenceProducerKeyId":
                "ios-vendored-artifact-producer-hermetic",
            "independentReviewerKeyId":
                "ios-vendored-independent-reviewer-hermetic",
            "artifacts": self.artifacts,
            "duplicateAssertions": [
                {
                    "leftId": "shared-sorawallet",
                    "rightId": "sora-wallet-binary-sorawallet",
                    "byteIdentical": True,
                    "contentManifestSha256": self.artifacts[3][
                        "contentManifestSha256"
                    ],
                    "treeContentSha256": self.artifacts[3]["treeContentSha256"],
                }
            ],
            "blockingReasons": [],
        }
        write(self.verifier.EVIDENCE, canonical_json(self.evidence))
        evidence_sha256 = digest(self.verifier.EVIDENCE.read_bytes())
        self.receipt = {
            "schemaVersion": 1,
            "contractId": "sora-ios-vendored-binary-qualification-v1",
            "platform": "ios",
            "status": "qualified",
            "runId": RUN_ID,
            "qualificationSequenceNumber": SEQUENCE,
            "sourceRevision": SOURCE_REVISION,
            "reviewedAtEpochSeconds": now - 120,
            "qualifiedAtEpochSeconds": now - 60,
            "qualificationContractSha256": self.contract_sha256,
            "trustRootSha256": trust_sha256,
            "evidenceManifestSha256": evidence_sha256,
            "artifactEvidenceProducerKeyId":
                "ios-vendored-artifact-producer-hermetic",
            "independentReviewerKeyId":
                "ios-vendored-independent-reviewer-hermetic",
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
        write(self.verifier.RECEIPT, canonical_json(self.receipt))

    def _sign(self, payload: Path, private: Path, signature: Path) -> None:
        run(
            [
                str(OPENSSL),
                "dgst",
                "-sha256",
                "-sign",
                str(private),
                "-out",
                str(signature),
                str(payload),
            ]
        )

    def _sign_all(self) -> None:
        self.receipt_signature = self.protected / "receipt.sig"
        self.producer_signature = self.protected / "evidence-producer.sig"
        self.reviewer_signature = self.protected / "evidence-reviewer.sig"
        self._sign(
            self.verifier.RECEIPT,
            self.reviewer_private,
            self.receipt_signature,
        )
        self._sign(
            self.verifier.EVIDENCE,
            self.producer_private,
            self.producer_signature,
        )
        self._sign(
            self.verifier.EVIDENCE,
            self.reviewer_private,
            self.reviewer_signature,
        )
        self.receipt_signature.chmod(0o600)
        self.producer_signature.chmod(0o600)
        self.reviewer_signature.chmod(0o600)

    def _environment(self) -> dict[str, str]:
        return {
            "IOS_VENDORED_BINARY_QUALIFICATION_SOURCE_REVISION": SOURCE_REVISION,
            "IOS_VENDORED_BINARY_QUALIFICATION_RUN_ID": RUN_ID,
            "IOS_VENDORED_BINARY_QUALIFICATION_SEQUENCE_NUMBER": str(SEQUENCE),
            "IOS_VENDORED_BINARY_QUALIFICATION_CONTRACT_SHA256":
                self.contract_sha256,
            "IOS_VENDORED_BINARY_QUALIFICATION_TRUST_SHA256":
                digest(self.verifier.TRUST.read_bytes()),
            "IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_SHA256":
                self.producer_key_sha256,
            "IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_SHA256":
                self.reviewer_key_sha256,
            "IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_PATH":
                str(self.producer_public),
            "IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_PATH":
                str(self.reviewer_public),
            "IOS_VENDORED_BINARY_QUALIFICATION_RECEIPT_SIGNATURE_PATH":
                str(self.receipt_signature),
            "IOS_VENDORED_BINARY_QUALIFICATION_EVIDENCE_PRODUCER_SIGNATURE_PATH":
                str(self.producer_signature),
            "IOS_VENDORED_BINARY_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH":
                str(self.reviewer_signature),
        }

    def verify(self) -> str:
        with mock.patch.dict(os.environ, self.environment, clear=True):
            return self.verifier.verify_qualified()

    def rewrite_receipt(self) -> None:
        write(self.verifier.RECEIPT, canonical_json(self.receipt))
        self._sign(
            self.verifier.RECEIPT,
            self.reviewer_private,
            self.receipt_signature,
        )


class VendoredBinaryQualificationTests(unittest.TestCase):
    def temporary(self) -> tempfile.TemporaryDirectory[str]:
        return tempfile.TemporaryDirectory(
            prefix="sora-ios-vendored-binary-test.",
            dir=str(PRIVATE_TMP) if PRIVATE_TMP.is_dir() else None,
        )

    def test_blocked_repository_templates_are_exact(self) -> None:
        verifier = load_verifier()
        verifier.lint_templates()
        self.assertRegex(verifier.source_contract_sha256(), r"^[0-9a-f]{64}$")

    def test_qualified_dual_signature_and_six_tree_path_succeeds(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            self.assertEqual(fixture.verify(), digest(fixture.verifier.RECEIPT.read_bytes()))

    def test_floating_negative_zero_oversize_and_duplicate_json_are_rejected(self) -> None:
        verifier = load_verifier()
        for raw, fragment in (
            (b'{"value":1.0}\n', "floating-point"),
            (b'{"value":-0}\n', "negative zero"),
            (b'{"value":9007199254740992}\n', "safe-integer"),
            (b'{"value":1,"value":2}\n', "duplicate key"),
        ):
            with self.subTest(fragment=fragment):
                with self.assertRaisesRegex(SystemExit, fragment):
                    verifier.load_json_bytes(raw, "mutation")
        with self.assertRaisesRegex(SystemExit, "canonical JSON"):
            verifier.load_json_bytes(
                b'{ "value": 1 }\n', "mutation", canonical=True
            )

    def test_noncanonical_protected_sequence_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            fixture.environment[
                "IOS_VENDORED_BINARY_QUALIFICATION_SEQUENCE_NUMBER"
            ] = "07"
            with self.assertRaisesRegex(SystemExit, "sequence is not canonical"):
                fixture.verify()

    def test_wrong_reviewer_signature_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            fixture.receipt_signature.write_bytes(b"not-a-valid-signature")
            with self.assertRaisesRegex(SystemExit, "signature is invalid"):
                fixture.verify()

    def test_tree_byte_mutation_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            target = (
                fixture.repository
                / fixture.verifier.ARTIFACTS[0][1]
                / "Info.plist"
            )
            target.write_bytes(target.read_bytes() + b"-mutated")
            with self.assertRaisesRegex(SystemExit, "differs from its complete content manifest"):
                fixture.verify()

    def test_tree_symlink_substitution_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            target = (
                fixture.repository
                / fixture.verifier.ARTIFACTS[1][1]
                / "Info.plist"
            )
            target.unlink()
            target.symlink_to(fixture.producer_public)
            with self.assertRaisesRegex(SystemExit, "symlink or special node"):
                fixture.verify()

    def test_duplicate_sorawallet_tree_drift_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            target = (
                fixture.repository
                / fixture.verifier.ARTIFACTS[5][1]
                / "ios-arm64/sorawallet"
            )
            target.write_bytes(b"different-sorawallet-binary")
            with self.assertRaisesRegex(SystemExit, "differs from its complete content manifest"):
                fixture.verify()

    def test_stale_receipt_shape_is_rejected_even_when_resigned(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            fixture.receipt["legacySelfReview"] = True
            fixture.rewrite_receipt()
            with self.assertRaisesRegex(SystemExit, "missing or unreviewed fields"):
                fixture.verify()

    def test_repository_sorawallet_trees_are_currently_byte_identical(self) -> None:
        verifier = load_verifier()
        left = verifier.inventory_tree(verifier.ARTIFACTS[3][1], "left sorawallet")
        right = verifier.inventory_tree(verifier.ARTIFACTS[5][1], "right sorawallet")
        self.assertEqual(
            {path: value[0] for path, value in left.items()},
            {path: value[0] for path, value in right.items()},
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
