#!/usr/bin/env python3
"""Hermetic/static regressions for the iOS production promotion controller."""

from __future__ import annotations

import hashlib
import importlib.util
import inspect
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "SoraPassport/Scripts/run-ios-production-promotion.py"
PIPELINE = ROOT / "Jenkinsfile.production-promotion"
LEGACY = ROOT / "Jenkinsfile"
SOURCE_GATE = ROOT / "SoraPassport/Scripts/verify-modernization-dependencies.sh"
ROLLOUT_HARNESS = ROOT / "SoraPassport/Scripts/test-production-rollout-contract.py"
ROLLOUT_VALIDATOR = ROOT / "SoraPassport/Scripts/verify-production-rollout-json.py"
SPEC = importlib.util.spec_from_file_location("ios_production_promotion", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("production promotion controller cannot be loaded")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
ROLLOUT_SPEC = importlib.util.spec_from_file_location(
    "ios_production_rollout_validator", ROLLOUT_VALIDATOR
)
if ROLLOUT_SPEC is None or ROLLOUT_SPEC.loader is None:
    raise RuntimeError("production rollout validator cannot be loaded")
ROLLOUT_MODULE = importlib.util.module_from_spec(ROLLOUT_SPEC)
ROLLOUT_SPEC.loader.exec_module(ROLLOUT_MODULE)


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


class ProductionPromotionTests(unittest.TestCase):
    def executable(self, root: Path, name: str = "controller") -> tuple[Path, str]:
        path = root / name
        path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        path.chmod(0o700)
        return path, hashlib.sha256(path.read_bytes()).hexdigest()

    def lower_bound(self, root: Path, *, captured: int, controller_sha: str) -> Path:
        path = root / "lower-bound.json"
        path.write_bytes(
            canonical(
                {
                    "schemaVersion": 1,
                    "contractId": MODULE.LOWER_BOUND_CONTRACT_ID,
                    "status": "observed",
                    "bundleIdentifier": MODULE.BUNDLE_IDENTIFIER,
                    "sourceRevision": "1" * 40,
                    "lowerBound": "42",
                    "queriedAtEpochSeconds": captured,
                    "controllerExecutableSha256": controller_sha,
                }
            )
        )
        return path

    def test_controller_contract_lints(self) -> None:
        result = subprocess.run(
            ["/usr/bin/python3", "-B", "-I", "-S", str(SCRIPT), "--lint-contract"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "iOS production promotion controller contract: OK\n")

    def test_legacy_pipeline_remains_non_authorizing(self) -> None:
        source = LEGACY.read_text(encoding="utf-8")
        self.assertIn("legacy pipeline is not an authorized production promotion controller", source)
        self.assertNotIn("run-ios-production-promotion.py", source)
        self.assertNotIn("PRODUCTION_ROLLOUT_TARGET_PERCENT", source)

    def test_pipeline_orders_two_one_shot_builds_before_qualification(self) -> None:
        source = PIPELINE.read_text(encoding="utf-8")
        markers = [
            "--phase initialize",
            "--phase release-tests",
            "--phase archive",
            "--phase compare",
            "--phase qualify",
            "--phase upload",
            "--phase rollout",
        ]
        positions = [source.index(marker) for marker in markers]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(source.count("--phase archive --state"), 2)
        self.assertIn("disableConcurrentBuilds()", source)
        self.assertIn("skipDefaultCheckout(true)", source)
        self.assertIn("credentialsId: 'ios-keychain-credentials'", source)
        self.assertIn("usernameVariable: 'IOS_SIGNING_KEYCHAIN_PATH'", source)
        self.assertIn("passwordVariable: 'IOS_SIGNING_KEYCHAIN_PASSWORD'", source)
        self.assertIn("/usr/bin/security unlock-keychain", source)
        self.assertIn("/usr/bin/security lock-keychain", source)

    def test_advance_phases_have_no_build_or_test_entry_point(self) -> None:
        for function in (
            MODULE.phase_qualify,
            MODULE.phase_upload,
            MODULE.phase_rollout,
        ):
            source = inspect.getsource(function)
            self.assertNotIn("ARCHIVER", source)
            self.assertNotIn("RELEASE_TESTS", source)
            self.assertNotIn("xcodebuild", source)

    def test_controller_has_only_fixed_argv_execution(self) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("shell=True", source)
        self.assertNotIn("os.system", source)
        self.assertNotIn("eval(", source)
        self.assertIn("subprocess.run([str(executable), *arguments]", source)
        self.assertIn('"--idempotency-key"', source)
        expected = hashlib.sha256(
            (
                "bundleIdentifier=co.jp.soramitsu.sora\n"
                "buildNumber=43\n"
                f"ipaSha256={'2' * 64}"
            ).encode()
        ).hexdigest()
        self.assertEqual(MODULE.upload_idempotency_key("43", "2" * 64), expected)

    def test_post_upload_authentication_uses_only_stable_signature_inputs(self) -> None:
        source = inspect.getsource(MODULE.authenticate_post_upload_artifact)
        self.assertIn("receipt_bytes, _ = stable_read", source)
        self.assertIn("signature_bytes, _ = stable_read", source)
        self.assertIn("public_key_bytes, _ = stable_read", source)
        self.assertIn("verify_p256_signature_bytes(", source)
        self.assertIn('"IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256"', source)
        self.assertIn('"IOS_TAIRA_DEPLOYMENT_VERIFIED_ADMISSION_SHA256"', source)
        upload_source = inspect.getsource(MODULE.phase_upload)
        freshness_call = "require_fresh_taira_admission_for_live_release(state)"
        self.assertEqual(upload_source.count(freshness_call), 2)
        controller_call = upload_source.index("run_external_controller(")
        self.assertLess(upload_source.index(freshness_call), controller_call)
        self.assertGreater(upload_source.rindex(freshness_call), controller_call)

    def test_live_release_rejects_stale_or_future_taira_admission(self) -> None:
        current_epoch = 2_000_000_000

        def state_for(root: Path, evaluated_at: int) -> dict[str, object]:
            admission = root / f"admission-{evaluated_at}.json"
            admission.write_bytes(
                canonical({"evaluatedAtEpochSeconds": evaluated_at})
            )
            return {
                "builds": {
                    "primary": {
                        "tairaAdmission": MODULE.file_record(
                            admission,
                            MODULE.MAX_JSON_BYTES,
                            "primary Taira admission",
                        )
                    }
                }
            }

        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            root = Path(raw)
            MODULE.require_fresh_taira_admission_for_live_release(
                state_for(
                    root,
                    current_epoch - MODULE.MAX_TAIRA_DEPLOYMENT_ROLLOUT_AGE_SECONDS,
                ),
                now=current_epoch,
            )
            for invalid in (
                current_epoch - MODULE.MAX_TAIRA_DEPLOYMENT_ROLLOUT_AGE_SECONDS - 1,
                current_epoch + 1,
            ):
                with self.subTest(evaluated_at=invalid):
                    with self.assertRaisesRegex(
                        MODULE.PromotionError,
                        "stale or future-dated",
                    ):
                        MODULE.require_fresh_taira_admission_for_live_release(
                            state_for(root, invalid),
                            now=current_epoch,
                        )

    def test_equal_size_artifact_path_swap_breaks_snapshot_binding(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            receipt = Path(raw) / "artifact.json"
            authenticated = canonical({"a": 1})
            swapped = canonical({"b": 1})
            self.assertEqual(len(authenticated), len(swapped))
            receipt.write_bytes(authenticated)
            authenticated_sha = hashlib.sha256(authenticated).hexdigest()
            receipt.write_bytes(swapped)
            with mock.patch.dict(
                os.environ,
                {"IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256": authenticated_sha},
                clear=False,
            ):
                with self.assertRaisesRegex(
                    ROLLOUT_MODULE.ValidationError,
                    "bytes differ from the verifier-pinned snapshot",
                ):
                    ROLLOUT_MODULE.load_verifier_pinned_json(
                        str(receipt),
                        "IOS_PRODUCTION_ARTIFACT_RECEIPT_VERIFIED_SHA256",
                        "artifact identity receipt",
                    )

    def test_fresh_controller_lower_bound_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            root = Path(raw)
            path = self.lower_bound(root, captured=1_000_000, controller_sha="a" * 64)
            self.assertEqual(
                MODULE.parse_lower_bound_receipt(
                    path,
                    source_revision="1" * 40,
                    controller_sha256="a" * 64,
                    now=1_000_100,
                ),
                "42",
            )

    def test_stale_controller_lower_bound_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            path = self.lower_bound(Path(raw), captured=1_000_000, controller_sha="a" * 64)
            with self.assertRaisesRegex(MODULE.PromotionError, "not a fresh"):
                MODULE.parse_lower_bound_receipt(
                    path,
                    source_revision="1" * 40,
                    controller_sha256="a" * 64,
                    now=1_000_301,
                )

    def test_canonical_protected_executable_and_pin_are_accepted(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            path, digest = self.executable(Path(raw))
            record = MODULE.inspect_controller(str(path), digest, "test")
            self.assertEqual(record["sha256"], digest)
            self.assertEqual(record["path"], str(path))

    def test_missing_controller_pin_is_rejected(self) -> None:
        names = MODULE.CONTROLLER_ENVIRONMENTS["appStore"]
        with mock.patch.dict(os.environ, {names[0]: "/private/tmp/missing"}, clear=True):
            with self.assertRaisesRegex(MODULE.PromotionError, "path and SHA-256 pin"):
                MODULE.controller_from_environment("appStore")

    def test_symbolic_controller_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            root = Path(raw)
            path, digest = self.executable(root, "real")
            alias = root / "alias"
            alias.symlink_to(path)
            with self.assertRaisesRegex(MODULE.PromotionError, "symbolic or noncanonical"):
                MODULE.inspect_controller(str(alias), digest, "test")

    def test_wrong_controller_pin_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            path, _ = self.executable(Path(raw))
            with self.assertRaisesRegex(MODULE.PromotionError, "differs from its protected"):
                MODULE.inspect_controller(str(path), "b" * 64, "test")

    def test_group_writable_controller_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            path, digest = self.executable(Path(raw))
            path.chmod(0o720)
            with self.assertRaisesRegex(MODULE.PromotionError, "group/world mutation"):
                MODULE.inspect_controller(str(path), digest, "test")

    def test_controller_content_drift_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            path, digest = self.executable(Path(raw))
            record = MODULE.inspect_controller(str(path), digest, "appStore")
            path.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            path.chmod(0o700)
            names = MODULE.CONTROLLER_ENVIRONMENTS["appStore"]
            with mock.patch.dict(os.environ, {names[0]: str(path), names[1]: digest}, clear=False):
                with self.assertRaisesRegex(MODULE.PromotionError, "differs from its protected"):
                    MODULE.verify_controller_record(record, "appStore")

    def test_state_rejects_build_before_tests_and_rollout_skip(self) -> None:
        base = MODULE.empty_state(
            "1" * 40,
            "43",
            "42",
            {},
            {name: {} for name in MODULE.CONTROLLER_ENVIRONMENTS},
            {name: {} for name in MODULE.ROLE_NAMES},
        )
        base["builds"] = {"primary": {}}
        with self.assertRaisesRegex(MODULE.PromotionError, "build before full Release tests"):
            MODULE.validate_state(base)
        base["releaseTests"] = {"primary": {}, "reproduction": {}}
        base["builds"]["reproduction"] = {}
        base["qualifiedPackage"] = {
            "package": {},
            "qualificationReceiptSha256": "2" * 64,
            "ipaSha256": "3" * 64,
            "qualificationEvidenceOverlay": {
                relative.as_posix(): {}
                for relative in MODULE.QUALIFICATION_OVERLAY_RELATIVES
            },
        }
        base["equivalenceReceipt"] = {}
        base["postUploadArtifact"] = {"receipt": {}, "signature": {}}
        base["rollouts"] = [{"targetPercent": 5}]
        with self.assertRaisesRegex(MODULE.PromotionError, "out of order"):
            MODULE.validate_state(base)

    def test_post_compare_checkout_drift_outside_signed_overlay_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            checkout = Path(raw)
            subprocess.run(["/usr/bin/git", "init", "-q", str(checkout)], check=True)
            subprocess.run(
                ["/usr/bin/git", "-C", str(checkout), "config", "user.email", "test@example.invalid"],
                check=True,
            )
            subprocess.run(
                ["/usr/bin/git", "-C", str(checkout), "config", "user.name", "Promotion Test"],
                check=True,
            )
            baseline = checkout / "baseline"
            baseline.write_text("exact\n", encoding="utf-8")
            subprocess.run(["/usr/bin/git", "-C", str(checkout), "add", "baseline"], check=True)
            subprocess.run(
                ["/usr/bin/git", "-C", str(checkout), "commit", "-qm", "baseline"],
                check=True,
            )
            baseline.write_text("drift\n", encoding="utf-8")
            revision = subprocess.run(
                ["/usr/bin/git", "-C", str(checkout), "rev-parse", "HEAD"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            ).stdout.strip()
            with self.assertRaisesRegex(MODULE.PromotionError, "not completely clean"):
                MODULE.verify_clean_checkout(checkout, revision, "post-compare checkout")
            with self.assertRaisesRegex(MODULE.PromotionError, "non-evidence checkout path"):
                MODULE.capture_qualification_overlay(checkout)

    def test_distribution_mutation_must_bind_exact_admitted_target(self) -> None:
        with tempfile.TemporaryDirectory(dir="/private/tmp") as raw:
            root = Path(raw)
            now = int(time.time())
            state = {
                "sourceRevision": "1" * 40,
                "buildNumber": "43",
                "builds": {"primary": {"ipa": {"sha256": "2" * 64}}},
            }
            receipt = root / "mutation.json"
            value = {
                "schemaVersion": 1,
                "contractId": MODULE.MUTATION_CONTRACT_ID,
                "status": "applied",
                "bundleIdentifier": MODULE.BUNDLE_IDENTIFIER,
                "sourceRevision": "1" * 40,
                "buildNumber": "43",
                "candidateIpaSha256": "2" * 64,
                "artifactIdentityReceiptSha256": "3" * 64,
                "rolloutReceiptSha256": "4" * 64,
                "targetPercent": 1,
                "appliedAtEpochSeconds": now,
                "controllerExecutableSha256": "5" * 64,
            }
            receipt.write_bytes(canonical(value))
            MODULE.parse_mutation_receipt(
                receipt,
                state=state,
                target=1,
                artifact_sha="3" * 64,
                rollout_sha="4" * 64,
                controller_sha="5" * 64,
                not_before=now,
            )
            value["targetPercent"] = 5
            receipt.write_bytes(canonical(value))
            with self.assertRaisesRegex(MODULE.PromotionError, "differs from"):
                MODULE.parse_mutation_receipt(
                    receipt,
                    state=state,
                    target=1,
                    artifact_sha="3" * 64,
                    rollout_sha="4" * 64,
                    controller_sha="5" * 64,
                    not_before=now,
                )

    def test_rollout_case_timeout_is_ci_safe_and_aggregate_stays_bounded(self) -> None:
        harness = ROLLOUT_HARNESS.read_text(encoding="utf-8")
        gate = SOURCE_GATE.read_text(encoding="utf-8")
        self.assertIn("HARNESS_TIMEOUT_SECONDS = 1200", harness)
        self.assertIn("timeout=bounded_timeout(180)", harness)
        self.assertNotIn("timeout=bounded_timeout(90)", harness)
        self.assertIn("timeout=bounded_timeout(180)", gate)


if __name__ == "__main__":
    unittest.main()
