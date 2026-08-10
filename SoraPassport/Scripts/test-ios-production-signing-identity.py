#!/usr/bin/env python3
"""Hermetic success and fail-closed tests for production-signing admission."""

from __future__ import annotations

import hashlib
import importlib.util
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
SCRIPT = Path(__file__).with_name("verify-ios-production-signing-identity.py")
OPENSSL = Path("/usr/bin/openssl")
PRIVATE_TMP = Path("/private/tmp")
SOURCE_REVISION = "1" * 40
RUN_ID = "11111111-2222-4333-8444-555555555555"
SEQUENCE = 9
COPIED_CONTRACT_NAMES = {
    "ios-production-signing-identity.json",
    "ios-production-signing-identity-qualification.blocked.json",
    "ios-production-signing-identity-qualification-trust.blocked.json",
}


def load_verifier() -> object:
    name = f"production_signing_{uuid.uuid4().hex}"
    specification = importlib.util.spec_from_file_location(name, SCRIPT)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


def write(path: Path, raw: bytes, *, private: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    if private:
        path.chmod(0o600)


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
        self.contract_sha256 = self._contract_sha256()
        self.producer_private, self.producer_public = self._keypair(
            "producer", "prime256v1"
        )
        self.reviewer_private, self.reviewer_public = self._keypair(
            "reviewer", "prime256v1"
        )
        self.producer_key_sha256 = self.digest(self.producer_public.read_bytes())
        self.reviewer_key_sha256 = self.digest(self.reviewer_public.read_bytes())
        self._write_records()
        self._sign_all()
        self.environment = self._environment()

    @staticmethod
    def digest(raw: bytes) -> str:
        return hashlib.sha256(raw).hexdigest()

    def synthetic_digest(self, label: str) -> str:
        return self.digest(f"signing-hermetic:{label}".encode("utf-8"))

    def _bind_repository(self) -> None:
        fixtures = self.repository / "Fixtures/Modernization"
        self.verifier.ROOT = self.repository
        self.verifier.FIXTURES = fixtures
        self.verifier.INVENTORY = fixtures / "ios-production-signing-identity.json"
        self.verifier.RECEIPT = (
            fixtures / "ios-production-signing-identity-qualification.json"
        )
        self.verifier.TRUST = (
            fixtures / "ios-production-signing-identity-qualification-trust.json"
        )
        self.verifier.BLOCKED_RECEIPT = (
            fixtures / "ios-production-signing-identity-qualification.blocked.json"
        )
        self.verifier.BLOCKED_TRUST = (
            fixtures
            / "ios-production-signing-identity-qualification-trust.blocked.json"
        )

    def _write_contract_files(self) -> None:
        for relative in self.verifier.CONTRACT_FILES:
            target = self.repository / relative
            name = Path(relative).name
            if name in COPIED_CONTRACT_NAMES:
                source = SOURCE_ROOT / "Fixtures/Modernization" / name
                write(target, source.read_bytes())
            elif relative == "SoraPassport/SoraPassport.entitlements":
                write(target, b"hermetic source entitlements\n")
            else:
                write(target, f"hermetic signing contract: {relative}\n".encode())

    def _contract_sha256(self) -> str:
        snapshots = self.root / "contract-snapshots"
        snapshots.mkdir(mode=0o700)
        inputs = self.verifier.StableInputs(snapshots)
        return self.verifier.contract_sha256(inputs)

    def _keypair(self, label: str, curve: str) -> tuple[Path, Path]:
        private = self.protected / f"{label}-private.pem"
        public = self.protected / f"{label}-public.pem"
        run(
            [
                str(OPENSSL), "ecparam", "-name", curve, "-genkey", "-noout",
                "-out", str(private),
            ]
        )
        run(
            [
                str(OPENSSL), "ec", "-in", str(private), "-pubout", "-out",
                str(public),
            ]
        )
        private.chmod(0o600)
        public.chmod(0o600)
        return private, public

    def _write_records(self) -> None:
        now = int(time.time())
        self.trust = {
            "schemaVersion": 1,
            "contractId": "sora-ios-production-signing-identity-trust-v1",
            "platform": "ios",
            "status": "qualified",
            "signatureAlgorithm": "ecdsa-p256-sha256",
            "authorities": {
                "releaseEvidenceProducer": {
                    "role": "release-evidence-producer",
                    "keyId": "ios-signing-producer-hermetic",
                    "publicKeyPemSha256": self.producer_key_sha256,
                    "enabled": True,
                },
                "independentReviewer": {
                    "role": "independent-reviewer",
                    "keyId": "ios-signing-reviewer-hermetic",
                    "publicKeyPemSha256": self.reviewer_key_sha256,
                    "enabled": True,
                },
            },
            "replayPolicy": {
                "maximumQualificationAgeSeconds": 2_592_000,
                "maximumReviewDelaySeconds": 86_400,
            },
            "blockingReasons": [],
        }
        write(self.verifier.TRUST, self.verifier.canonical_json(self.trust))
        source_raw = (
            self.repository / "SoraPassport/SoraPassport.entitlements"
        ).read_bytes()
        self.receipt = {
            "schemaVersion": 1,
            "contractId":
                "sora-ios-production-signing-identity-qualification-v1",
            "platform": "ios",
            "status": "qualified",
            "runId": RUN_ID,
            "qualificationSequenceNumber": SEQUENCE,
            "sourceRevision": SOURCE_REVISION,
            "assessedAtEpochSeconds": now - 300,
            "reviewedAtEpochSeconds": now - 180,
            "qualifiedAtEpochSeconds": now - 60,
            "qualificationContractSha256": self.contract_sha256,
            "trustRootSha256": self.digest(self.verifier.TRUST.read_bytes()),
            "releaseEvidenceProducerKeyId": "ios-signing-producer-hermetic",
            "independentReviewerKeyId": "ios-signing-reviewer-hermetic",
            "bundleIdentifier": "co.jp.soramitsu.sora",
            "developmentTeam": "YLWWUD25VZ",
            "applicationIdentifier": "YLWWUD25VZ.co.jp.soramitsu.sora",
            "codeSignStyle": "Automatic",
            "configuredCodeSignIdentity": "iPhone Developer",
            "entitlementsPath": "SoraPassport/SoraPassport.entitlements",
            "sourceEntitlementsSha256": self.digest(source_raw),
            "signedEntitlementsSha256": self.synthetic_digest("signed-entitlements"),
            "keychainAccessGroupsSha256": self.synthetic_digest("keychain-groups"),
            "productionDistributionCertificateSha256":
                self.synthetic_digest("distribution-certificate"),
            "productionProvisioningProfileUuid":
                "11111111-2222-3333-8444-555555555555",
            "productionProvisioningProfileName": "SORA App Store Distribution",
            "canonicalProvisioningProfileSha256":
                self.synthetic_digest("canonical-profile"),
            "appStoreSigningContinuityReviewed": True,
            "privateKeyOrCredentialRecorded": False,
            "blockingReasons": [],
        }
        write(self.verifier.RECEIPT, self.verifier.canonical_json(self.receipt))

    def _sign(self, private: Path, signature: Path) -> None:
        run(
            [
                str(OPENSSL), "dgst", "-sha256", "-sign", str(private),
                "-out", str(signature), str(self.verifier.RECEIPT),
            ]
        )
        signature.chmod(0o600)

    def _sign_all(self) -> None:
        self.producer_signature = self.protected / "producer.sig"
        self.reviewer_signature = self.protected / "reviewer.sig"
        self._sign(self.producer_private, self.producer_signature)
        self._sign(self.reviewer_private, self.reviewer_signature)

    def _environment(self) -> dict[str, str]:
        return {
            "IOS_SIGNING_IDENTITY_SOURCE_REVISION": SOURCE_REVISION,
            "IOS_SIGNING_IDENTITY_RUN_ID": RUN_ID,
            "IOS_SIGNING_IDENTITY_SEQUENCE_NUMBER": str(SEQUENCE),
            "IOS_SIGNING_IDENTITY_CONTRACT_SHA256": self.contract_sha256,
            "IOS_SIGNING_IDENTITY_TRUST_SHA256":
                self.digest(self.verifier.TRUST.read_bytes()),
            "IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_SHA256":
                self.producer_key_sha256,
            "IOS_SIGNING_IDENTITY_REVIEWER_PUBLIC_KEY_SHA256":
                self.reviewer_key_sha256,
            "IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_PATH":
                str(self.producer_public),
            "IOS_SIGNING_IDENTITY_REVIEWER_PUBLIC_KEY_PATH":
                str(self.reviewer_public),
            "IOS_SIGNING_IDENTITY_PRODUCER_SIGNATURE_PATH":
                str(self.producer_signature),
            "IOS_SIGNING_IDENTITY_REVIEWER_SIGNATURE_PATH":
                str(self.reviewer_signature),
        }

    def rewrite_receipt(self) -> None:
        write(self.verifier.RECEIPT, self.verifier.canonical_json(self.receipt))
        self._sign_all()

    def rewrite_trust(self) -> None:
        write(self.verifier.TRUST, self.verifier.canonical_json(self.trust))
        self.environment["IOS_SIGNING_IDENTITY_TRUST_SHA256"] = self.digest(
            self.verifier.TRUST.read_bytes()
        )

    def verify(self) -> str:
        with mock.patch.dict(os.environ, self.environment, clear=True):
            return self.verifier.verify_qualified()


class ProductionSigningIdentityTests(unittest.TestCase):
    def temporary(self) -> tempfile.TemporaryDirectory[str]:
        return tempfile.TemporaryDirectory(
            prefix="sora-ios-signing-test.",
            dir=str(PRIVATE_TMP) if PRIVATE_TMP.is_dir() else None,
        )

    def test_blocked_templates_are_exact(self) -> None:
        verifier = load_verifier()
        verifier.lint_templates()
        self.assertRegex(verifier.source_contract_sha256(), r"^[0-9a-f]{64}$")

    def test_qualified_dual_signature_path_succeeds(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            self.assertEqual(
                fixture.verify(), fixture.digest(fixture.verifier.RECEIPT.read_bytes())
            )

    def test_ambiguous_json_tokens_are_rejected(self) -> None:
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

    def test_noncanonical_protected_sequence_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            fixture.environment["IOS_SIGNING_IDENTITY_SEQUENCE_NUMBER"] = "09"
            with self.assertRaisesRegex(SystemExit, "sequence is not canonical"):
                fixture.verify()

    def test_wrong_reviewer_signature_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            write(
                fixture.reviewer_signature,
                fixture.producer_signature.read_bytes(),
                private=True,
            )
            with self.assertRaisesRegex(SystemExit, "reviewer receipt signature is invalid"):
                fixture.verify()

    def test_wrong_producer_signature_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            write(
                fixture.producer_signature,
                fixture.reviewer_signature.read_bytes(),
                private=True,
            )
            with self.assertRaisesRegex(SystemExit, "producer receipt signature is invalid"):
                fixture.verify()

    def test_stale_receipt_shape_is_rejected_even_when_resigned(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            fixture.receipt["selfAuthorized"] = True
            fixture.rewrite_receipt()
            with self.assertRaisesRegex(SystemExit, "stale, mixed, or incomplete shape"):
                fixture.verify()

    def test_expired_receipt_is_rejected_even_when_resigned(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            now = int(time.time())
            fixture.receipt["assessedAtEpochSeconds"] = now - 2_700_300
            fixture.receipt["reviewedAtEpochSeconds"] = now - 2_700_180
            fixture.receipt["qualifiedAtEpochSeconds"] = now - 2_700_060
            fixture.rewrite_receipt()
            with self.assertRaisesRegex(SystemExit, "qualification is stale"):
                fixture.verify()

    def test_contract_bound_source_mutation_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            project = fixture.repository / "SoraPassport.xcodeproj/project.pbxproj"
            project.write_bytes(project.read_bytes() + b"late source mutation\n")
            with self.assertRaisesRegex(SystemExit, "contract differs"):
                fixture.verify()

    def test_non_p256_producer_key_is_rejected(self) -> None:
        with self.temporary() as temporary:
            fixture = QualifiedFixture(Path(temporary))
            _, public = fixture._keypair("producer-p384", "secp384r1")
            fixture.producer_public = public
            fixture.producer_key_sha256 = fixture.digest(public.read_bytes())
            fixture.trust["authorities"]["releaseEvidenceProducer"][
                "publicKeyPemSha256"
            ] = fixture.producer_key_sha256
            fixture.rewrite_trust()
            fixture.environment[
                "IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_SHA256"
            ] = fixture.producer_key_sha256
            fixture.environment[
                "IOS_SIGNING_IDENTITY_PRODUCER_PUBLIC_KEY_PATH"
            ] = str(public)
            with self.assertRaisesRegex(SystemExit, "must use ECDSA P-256"):
                fixture.verify()


if __name__ == "__main__":
    unittest.main(verbosity=2)
