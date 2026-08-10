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
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode() + b"\n"


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
        self.manifest = self.value(current)
        self._keypair(self.operator_private, self.operator_public)
        self._keypair(self.reviewer_private, self.reviewer_public)

    @staticmethod
    def value(current: str) -> dict[str, Any]:
        retired = OLD if current == NEW else NEW
        return {
            "schemaVersion": 1,
            "contractId": "sora-taira-deployment-manifest-v1",
            "manifestId": f"taira-deployment-{current[:8]}",
            "issuedAtEpochSeconds": EVALUATED_AT - 60,
            "expiresAtEpochSeconds": EVALUATED_AT + 3_600,
            "authorities": {
                "operatorKeyId": "release-operator-2026",
                "reviewerKeyId": "deployment-reviewer-2026",
            },
            "pendingRowPolicy": {
                "schemaVersion": 77,
                "preserveExactChainUuid": True,
                "mismatchedCurrentDisposition": "quarantine-recovery-only",
                "reinterpretationAllowed": False,
            },
            "epochs": [
                {
                    "chainId": current,
                    "role": "current",
                    "deploymentEpoch": 200,
                    "genesisHash": synthetic(f"current-{current}"),
                    "canonicalToriiBaseUrl": "https://public-01.taira.example.org",
                    "publicMcpEndpoint": "https://public-01.taira.example.org/v1/mcp",
                },
                {
                    "chainId": retired,
                    "role": "retired",
                    "deploymentEpoch": 100,
                    "genesisHash": synthetic(f"retired-{retired}"),
                    "canonicalToriiBaseUrl": None,
                    "publicMcpEndpoint": None,
                },
            ],
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

    def command(self, *, operator_pin: str | None = None, reviewer_pin: str | None = None) -> list[str]:
        return [
            "/usr/bin/python3", "-B", "-I", "-S", str(TOOL), "--verify-protected",
            "--manifest", str(self.manifest_path),
            "--operator-signature", str(self.operator_signature),
            "--reviewer-signature", str(self.reviewer_signature),
            "--operator-public-key", str(self.operator_public),
            "--reviewer-public-key", str(self.reviewer_public),
            "--operator-key-sha256", operator_pin or hashlib.sha256(self.operator_public.read_bytes()).hexdigest(),
            "--reviewer-key-sha256", reviewer_pin or hashlib.sha256(self.reviewer_public.read_bytes()).hexdigest(),
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
            "canonicalToriiBaseUrl": "https://taira.sora.org",
            "publicMcpEndpoint": "https://taira.sora.org/v1/mcp",
        }))
        self.assertIn("must not use taira.sora.org", error)

    def test_rejects_non_https_and_non_exact_mcp_routes(self) -> None:
        self.assertIn("HTTPS", self.mutation(lambda value: value["epochs"][0].update({
            "canonicalToriiBaseUrl": "http://public-01.taira.example.org",
            "publicMcpEndpoint": "http://public-01.taira.example.org/v1/mcp",
        })))
        self.assertIn("explicit canonical /v1/mcp", self.mutation(
            lambda value: value["epochs"][0].update({"publicMcpEndpoint": "https://public-01.taira.example.org/mcp"})
        ))

    def test_rejects_missing_or_duplicate_known_uuid(self) -> None:
        self.assertIn("both known UUIDs", self.mutation(lambda value: value["epochs"][1].update({"chainId": NEW})))
        self.assertIn("known UUIDs", self.mutation(lambda value: value["epochs"][1].update({"chainId": "00000000-0000-4000-8000-000000000001"})))

    def test_rejects_duplicate_genesis_or_epoch(self) -> None:
        self.assertIn("distinct", self.mutation(lambda value: value["epochs"][1].update({"genesisHash": value["epochs"][0]["genesisHash"]})))
        self.assertIn("distinct", self.mutation(lambda value: value["epochs"][1].update({"deploymentEpoch": value["epochs"][0]["deploymentEpoch"]})))
        self.assertIn("newer", self.mutation(lambda value: value["epochs"][0].update({"deploymentEpoch": 50})))

    def test_rejects_transport_on_retired_identity(self) -> None:
        self.assertIn("must not authorize transport", self.mutation(lambda value: value["epochs"][1].update({
            "canonicalToriiBaseUrl": "https://retired.taira.example.org",
            "publicMcpEndpoint": "https://retired.taira.example.org/v1/mcp",
        })))

    def test_rejects_schema77_reinterpretation_or_policy_drift(self) -> None:
        self.assertIn("schema-77", self.mutation(lambda value: value["pendingRowPolicy"].update({"reinterpretationAllowed": True})))
        self.assertIn("schema-77", self.mutation(lambda value: value["pendingRowPolicy"].update({"mismatchedCurrentDisposition": "rewrite-current"})))

    def test_rejects_stale_expired_and_future_manifests(self) -> None:
        self.assertIn("older than seven days", self.mutation(lambda value: value.update({
            "issuedAtEpochSeconds": EVALUATED_AT - 8 * 24 * 60 * 60,
            "expiresAtEpochSeconds": EVALUATED_AT + 1,
        })))
        self.assertIn("issued too far", self.mutation(lambda value: value.update({
            "issuedAtEpochSeconds": EVALUATED_AT + 61,
            "expiresAtEpochSeconds": EVALUATED_AT + 3600,
        })))

    def test_rejects_stale_mixed_and_noncanonical_shapes(self) -> None:
        self.assertIn("stale, mixed", self.mutation(lambda value: value.update({"repositorySelectedCurrent": NEW})))
        workspace = Workspace()
        workspace.write_and_sign()
        workspace.manifest_path.write_bytes(json.dumps(workspace.manifest, indent=2).encode())
        os.chmod(workspace.manifest_path, 0o600)
        self.assertIn("not canonical JSON", workspace.invoke(False).stderr.decode())

    def test_rejects_bad_signature_and_key_pin(self) -> None:
        self.assertIn("signature verification failed", self.mutation(
            lambda value: value.update({"manifestId": "changed-after-signing"}), stale_signature=True
        ))
        workspace = Workspace()
        workspace.write_and_sign()
        result = subprocess.run(
            workspace.command(operator_pin=synthetic("wrong-key")),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=SAFE_ENV, timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protected SHA-256 pin", result.stderr.decode())

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
        workspace.manifest["authorities"]["reviewerKeyId"] = workspace.manifest["authorities"]["operatorKeyId"]
        workspace.write_and_sign()
        self.assertIn("distinct canonical identifiers", workspace.invoke(False).stderr.decode())


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TairaDeploymentAdmissionTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if result.wasSuccessful():
        print(f"iOS Taira deployment admission: {result.testsRun} cases passed")
    raise SystemExit(0 if result.wasSuccessful() else 1)
