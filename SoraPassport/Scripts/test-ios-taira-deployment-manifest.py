#!/usr/bin/env python3
"""Hermetic mutation tests for protected iOS Taira deployment admission."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "SoraPassport/Scripts/verify-ios-taira-deployment-manifest.py"
OLD = "809574f5-fee7-5e69-bfcf-52451e42d50f"
NEW = "fc56984b-2be7-431d-840e-21514d1883f0"
EVALUATED_AT = 2_000_000_000
SAFE_ENV = {"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"}


def canonical(value: Any) -> bytes:
    return json.dumps(
        value, indent=2, ensure_ascii=False, separators=(",", ": ")
    ).encode() + b"\n"


def synthetic(label: str) -> str:
    return hashlib.sha256(label.encode()).hexdigest()


class Workspace:
    def __init__(self, current: str = NEW):
        self.root = Path(tempfile.mkdtemp(prefix="ios-taira-admission-")).resolve()
        os.chmod(self.root, 0o700)
        self.operator_private = self.root / "operator-private.pem"
        self.operator_public = self.root / "operator-public.pem"
        self.reviewer_private = self.root / "reviewer-private.pem"
        self.reviewer_public = self.root / "reviewer-public.pem"
        self.manifest_path = self.root / "manifest.json"
        self.operator_signature = self.root / "operator.sig"
        self.reviewer_signature = self.root / "reviewer.sig"
        self.output = self.root / "admission.json"
        self._keypair(self.operator_private, self.operator_public)
        self._keypair(self.reviewer_private, self.reviewer_public)
        self.operator_pin = self._spki_pin(self.operator_public)
        self.reviewer_pin = self._spki_pin(self.reviewer_public)
        self.manifest = self.value(
            current,
            self.operator_pin,
            self.reviewer_pin,
        )

    @staticmethod
    def value(
        current: str,
        operator_pin: str,
        reviewer_pin: str,
    ) -> dict[str, Any]:
        retired = OLD if current == NEW else NEW
        return {
            "schemaVersion": 1,
            "contractId": "sora-taira-deployment-epoch-manifest-v1",
            "status": "qualified",
            "networkId": "taira",
            "manifestSequenceNumber": 17,
            "issuedAtEpochSeconds": EVALUATED_AT - 60,
            "reviewedAtEpochSeconds": EVALUATED_AT - 30,
            "currentEpoch": 200,
            "authorities": {
                "operator": {
                    "keyId": "release-operator-2026",
                    "publicKeySha256": operator_pin,
                },
                "independentReviewer": {
                    "keyId": "deployment-reviewer-2026",
                    "publicKeySha256": reviewer_pin,
                },
            },
            "pendingRowPolicy": {
                "schemaVersion": 77,
                "preserveExactChainUuid": True,
                "mismatchedCurrentDisposition": "quarantine-recovery-only",
                "reinterpretationAllowed": False,
            },
            "epochs": [
                {
                    "epoch": 200,
                    "chainId": current,
                    "genesisSha256": synthetic(f"current-{current}"),
                    "i105Discriminant": 369,
                    "status": "current",
                    "toriiBaseUrl": "https://public-01.taira.example.org",
                    "publicNodeMcpEndpoint": "https://public-01.taira.example.org/v1/mcp",
                    "explorerBaseUrl": "https://explorer.taira.example.org",
                },
                {
                    "epoch": 100,
                    "chainId": retired,
                    "genesisSha256": synthetic(f"retired-{retired}"),
                    "i105Discriminant": 369,
                    "status": "retired",
                    "toriiBaseUrl": None,
                    "publicNodeMcpEndpoint": None,
                    "explorerBaseUrl": None,
                },
            ],
            "authorization": {
                "authorizesDeploymentIdentity": True,
                "authorizesFundedCanary": False,
                "authorizesRelease": False,
            },
        }

    def _run(self, arguments: list[str], *, check: bool = True) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            arguments,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_ENV,
            timeout=30,
            check=check,
        )

    def _keypair(self, private: Path, public: Path) -> None:
        self._run(["/usr/bin/openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(private)])
        self._run(["/usr/bin/openssl", "pkey", "-in", str(private), "-pubout", "-out", str(public)])
        os.chmod(private, 0o600)
        os.chmod(public, 0o600)

    def _spki_pin(self, public: Path) -> str:
        result = self._run([
            "/usr/bin/openssl", "pkey", "-pubin", "-in", str(public),
            "-outform", "DER",
        ])
        return hashlib.sha256(result.stdout).hexdigest()

    def write_and_sign(self, *, sign_before_mutation: dict[str, Any] | None = None) -> None:
        signed_value = self.manifest if sign_before_mutation is None else sign_before_mutation
        self.manifest_path.write_bytes(canonical(signed_value))
        os.chmod(self.manifest_path, 0o600)
        for private, signature in (
            (self.operator_private, self.operator_signature),
            (self.reviewer_private, self.reviewer_signature),
        ):
            self._run([
                "/usr/bin/openssl", "dgst", "-sha256", "-sign", str(private),
                "-out", str(signature), str(self.manifest_path),
            ])
            os.chmod(signature, 0o600)
        if sign_before_mutation is not None:
            self.manifest_path.write_bytes(canonical(self.manifest))
            os.chmod(self.manifest_path, 0o600)

    def command(
        self,
        *,
        operator_pin: str | None = None,
        reviewer_pin: str | None = None,
        expected_sequence: str = "17",
    ) -> list[str]:
        return [
            "/usr/bin/python3", "-B", "-I", "-S", str(TOOL), "--verify-protected",
            "--manifest", str(self.manifest_path),
            "--operator-signature", str(self.operator_signature),
            "--reviewer-signature", str(self.reviewer_signature),
            "--operator-public-key", str(self.operator_public),
            "--reviewer-public-key", str(self.reviewer_public),
            "--operator-key-sha256", operator_pin or self.operator_pin,
            "--reviewer-key-sha256", reviewer_pin or self.reviewer_pin,
            "--expected-manifest-sequence-number", expected_sequence,
            "--evaluated-at-epoch-seconds", str(EVALUATED_AT),
            "--output", str(self.output),
        ]

    def invoke(self, expected_success: bool) -> subprocess.CompletedProcess[bytes]:
        result = self._run(self.command(), check=False)
        if expected_success and result.returncode != 0:
            raise AssertionError(result.stderr.decode())
        if not expected_success and result.returncode == 0:
            raise AssertionError(result.stdout.decode())
        return result


class TairaDeploymentAdmissionTests(unittest.TestCase):
    def success(self, current: str) -> dict[str, Any]:
        workspace = Workspace(current)
        workspace.write_and_sign()
        result = workspace.invoke(True)
        self.assertIn(f"currentChainId={current}", result.stdout.decode())
        receipt = json.loads(workspace.output.read_text())
        self.assertEqual(receipt["current"]["chainId"], current)
        self.assertEqual(receipt["retired"]["chainId"], OLD if current == NEW else NEW)
        self.assertEqual(receipt["manifestSequenceNumber"], 17)
        self.assertEqual(stat.S_IMODE(workspace.output.stat().st_mode), 0o600)
        return receipt

    def mutation(self, mutate: Callable[[dict[str, Any]], None], *, stale_signature: bool = False) -> str:
        workspace = Workspace()
        original = copy.deepcopy(workspace.manifest)
        mutate(workspace.manifest)
        workspace.write_and_sign(sign_before_mutation=original if stale_signature else None)
        return workspace.invoke(False).stderr.decode()

    def test_lint_reports_blocked_repository_state(self) -> None:
        result = subprocess.run(
            ["/usr/bin/python3", "-B", "-I", "-S", str(TOOL), "--lint-contract"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=SAFE_ENV, timeout=30, check=True,
        )
        self.assertIn("blocked; no admitted manifest", result.stdout.decode())

    def test_both_operator_selected_current_mappings_are_admitted(self) -> None:
        first = self.success(NEW)
        second = self.success(OLD)
        self.assertNotEqual(first["current"]["genesisHash"], second["current"]["genesisHash"])

    def test_rejects_convenience_route(self) -> None:
        error = self.mutation(lambda value: value["epochs"][0].update({
            "toriiBaseUrl": "https://taira.sora.org",
            "publicNodeMcpEndpoint": "https://taira.sora.org/v1/mcp",
        }))
        self.assertIn("must not use taira.sora.org", error)
        self.assertIn("must not use taira.sora.org", self.mutation(
            lambda value: value["epochs"][0].update({
                "explorerBaseUrl": "https://taira.sora.org",
            })
        ))
        self.assertIn("canonical explicit public HTTPS origin", self.mutation(
            lambda value: value["epochs"][0].update({
                "toriiBaseUrl": "https://public-01.taira.example.org:443",
                "publicNodeMcpEndpoint": "https://public-01.taira.example.org:443/v1/mcp",
            })
        ))

    def test_rejects_non_https_and_non_exact_mcp_routes(self) -> None:
        self.assertIn("HTTPS", self.mutation(lambda value: value["epochs"][0].update({
            "toriiBaseUrl": "http://public-01.taira.example.org",
            "publicNodeMcpEndpoint": "http://public-01.taira.example.org/v1/mcp",
        })))
        self.assertIn("explicit canonical /v1/mcp", self.mutation(
            lambda value: value["epochs"][0].update({"publicNodeMcpEndpoint": "https://public-01.taira.example.org/mcp"})
        ))

    def test_rejects_missing_or_duplicate_known_uuid(self) -> None:
        self.assertIn("both known UUIDs", self.mutation(lambda value: value["epochs"][1].update({"chainId": NEW})))
        self.assertIn("known UUIDs", self.mutation(lambda value: value["epochs"][1].update({"chainId": "00000000-0000-4000-8000-000000000001"})))

    def test_rejects_duplicate_genesis_or_epoch(self) -> None:
        self.assertIn("distinct", self.mutation(lambda value: value["epochs"][1].update({"genesisSha256": value["epochs"][0]["genesisSha256"]})))
        self.assertIn("distinct", self.mutation(lambda value: value["epochs"][1].update({"epoch": value["epochs"][0]["epoch"]})))
        self.assertIn("newer", self.mutation(lambda value: value["epochs"][0].update({"epoch": 50})))

    def test_rejects_transport_on_retired_identity(self) -> None:
        self.assertIn("must not authorize routes", self.mutation(lambda value: value["epochs"][1].update({
            "toriiBaseUrl": "https://retired.taira.example.org",
            "publicNodeMcpEndpoint": "https://retired.taira.example.org/v1/mcp",
        })))

    def test_rejects_schema77_reinterpretation_or_policy_drift(self) -> None:
        self.assertIn("schema-77", self.mutation(lambda value: value["pendingRowPolicy"].update({"reinterpretationAllowed": True})))
        self.assertIn("schema-77", self.mutation(lambda value: value["pendingRowPolicy"].update({"mismatchedCurrentDisposition": "rewrite-current"})))

    def test_rejects_stale_and_future_reviews(self) -> None:
        self.assertIn("stale", self.mutation(lambda value: value.update({
            "issuedAtEpochSeconds": EVALUATED_AT - 8 * 24 * 60 * 60 - 60,
            "reviewedAtEpochSeconds": EVALUATED_AT - 8 * 24 * 60 * 60,
        })))
        self.assertIn("future-dated", self.mutation(lambda value: value.update({
            "issuedAtEpochSeconds": EVALUATED_AT,
            "reviewedAtEpochSeconds": EVALUATED_AT + 61,
        })))

    def test_rejects_stale_mixed_and_noncanonical_shapes(self) -> None:
        self.assertIn("stale, mixed", self.mutation(lambda value: value.update({"repositorySelectedCurrent": NEW})))
        workspace = Workspace()
        workspace.write_and_sign()
        workspace.manifest_path.write_bytes(json.dumps(workspace.manifest, separators=(",", ":")).encode())
        os.chmod(workspace.manifest_path, 0o600)
        self.assertIn("not canonical JSON", workspace.invoke(False).stderr.decode())

    def test_rejects_bad_signature_and_key_pin(self) -> None:
        self.assertIn("signature verification failed", self.mutation(
            lambda value: value.update({"reviewedAtEpochSeconds": EVALUATED_AT - 29}),
            stale_signature=True,
        ))
        workspace = Workspace()
        workspace.write_and_sign()
        result = subprocess.run(
            workspace.command(operator_pin=synthetic("wrong-key")),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=SAFE_ENV, timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protected key pins differ", result.stderr.decode())

    def test_rejects_manifest_sequence_different_from_protected_release_sequence(self) -> None:
        workspace = Workspace()
        workspace.write_and_sign()
        result = subprocess.run(
            workspace.command(expected_sequence="16"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=SAFE_ENV,
            timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protected exact release sequence", result.stderr.decode())

    def test_signature_verification_consumes_only_protected_in_memory_bytes(self) -> None:
        source = TOOL.read_text()
        self.assertNotIn("validate_public_key(operator_key_path", source)
        self.assertNotIn("validate_public_key(reviewer_key_path", source)
        self.assertNotIn("verify_signature(manifest_path", source)
        self.assertIn("input_bytes=manifest_raw", source)
        self.assertIn("pass_fds=(key_descriptor, signature_descriptor)", source)

    def test_rejects_symlink_hardlink_permissions_and_existing_output(self) -> None:
        workspace = Workspace()
        workspace.write_and_sign()
        target = workspace.root / "manifest-target.json"
        workspace.manifest_path.rename(target)
        workspace.manifest_path.symlink_to(target)
        self.assertIn("aliases", workspace.invoke(False).stderr.decode())

        workspace = Workspace()
        workspace.write_and_sign()
        hardlink = workspace.root / "manifest-hardlink.json"
        os.link(workspace.manifest_path, hardlink)
        self.assertIn("hardlink-free", workspace.invoke(False).stderr.decode())

        workspace = Workspace()
        workspace.write_and_sign()
        os.chmod(workspace.reviewer_public, 0o644)
        self.assertIn("owner-only", workspace.invoke(False).stderr.decode())

        workspace = Workspace()
        workspace.write_and_sign()
        workspace.output.write_text("occupied")
        os.chmod(workspace.output, 0o600)
        self.assertIn("must be fresh", workspace.invoke(False).stderr.decode())

    def test_rejects_same_operator_and_reviewer_authority(self) -> None:
        workspace = Workspace()
        workspace.manifest["authorities"]["independentReviewer"]["keyId"] = \
            workspace.manifest["authorities"]["operator"]["keyId"]
        workspace.write_and_sign()
        self.assertIn("authorities or protected key pins differ", workspace.invoke(False).stderr.decode())


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TairaDeploymentAdmissionTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if result.wasSuccessful():
        print(f"iOS Taira deployment admission: {result.testsRun} cases passed")
    raise SystemExit(0 if result.wasSuccessful() else 1)
