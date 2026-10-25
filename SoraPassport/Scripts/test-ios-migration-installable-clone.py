#!/usr/bin/env python3
"""Hermetic contract tests for archive-derived installable clones."""

from __future__ import annotations

import datetime
import hashlib
import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("create-ios-migration-installable-clone.py")
SPEC = importlib.util.spec_from_file_location("ios_installable_clone", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("installable-clone controller cannot be loaded")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class InstallableCloneContractTests(unittest.TestCase):
    def profile(self):
        certificate = b"reviewed-certificate-der"
        return {
            "Entitlements": {
                "application-identifier": f"{MODULE.TEAM_IDENTIFIER}.*",
                "com.apple.developer.team-identifier": MODULE.TEAM_IDENTIFIER,
                "keychain-access-groups": [
                    f"{MODULE.TEAM_IDENTIFIER}.*",
                    "com.apple.token",
                ],
                "get-task-allow": True,
            },
            "DeveloperCertificates": [certificate],
            "ProvisionedDevices": ["00008110-001234567890001E"],
            "ExpirationDate": datetime.datetime.utcnow() + datetime.timedelta(days=30),
            "TeamIdentifier": [MODULE.TEAM_IDENTIFIER],
        }, hashlib.sha1(certificate).hexdigest()

    def production_entitlements(self):
        return {
            "application-identifier": (
                f"{MODULE.TEAM_IDENTIFIER}.{MODULE.BUNDLE_IDENTIFIER}"
            ),
            "com.apple.developer.team-identifier": MODULE.TEAM_IDENTIFIER,
        }

    def test_registered_device_profile_is_exact_and_bounded(self):
        profile, identity = self.profile()
        entitlements = MODULE.validate_profile(
            profile,
            identity,
            "00008110-001234567890001E",
            self.production_entitlements(),
        )
        self.assertEqual(entitlements, self.production_entitlements())
        self.assertNotIn("keychain-access-groups", entitlements)
        self.assertNotIn("get-task-allow", entitlements)
        self.assertNotIn("com.apple.token", repr(entitlements))

        application_id = entitlements["application-identifier"]
        explicit = dict(entitlements)
        explicit["keychain-access-groups"] = [application_id]
        self.assertEqual(
            MODULE.effective_keychain_access_groups(
                entitlements, "implicit default"
            ),
            MODULE.effective_keychain_access_groups(
                explicit, "explicit default"
            ),
        )
        shared_first = dict(entitlements)
        shared_first["keychain-access-groups"] = [
            f"{MODULE.TEAM_IDENTIFIER}.shared.sora",
            application_id,
        ]
        app_first = dict(entitlements)
        app_first["keychain-access-groups"] = [
            application_id,
            f"{MODULE.TEAM_IDENTIFIER}.shared.sora",
        ]
        self.assertNotEqual(
            MODULE.effective_keychain_access_groups(shared_first, "shared first"),
            MODULE.effective_keychain_access_groups(app_first, "app first"),
        )
        for mutation in (
            lambda value: value.update(ProvisionedDevices=["other-device"]),
            lambda value: value["Entitlements"].update(
                {"keychain-access-groups": ["com.apple.token"]}
            ),
            lambda value: value.update(ProvisionsAllDevices=True),
        ):
            broken, identity = self.profile()
            mutation(broken)
            with self.assertRaises(MODULE.CloneError):
                MODULE.validate_profile(
                    broken,
                    identity,
                    "00008110-001234567890001E",
                    self.production_entitlements(),
                )

    def test_clone_is_archive_derived_and_non_authorizing(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("inspect_and_extract_ipa", source)
        self.assertIn('identity["cloneSigningEntitlements"]', source)
        self.assertIn("derive-ios-migration-test-host.py", source)
        self.assertIn("validate_installable_clone_receipt", source)
        self.assertIn('"canonicalProjectionEqual": True', source)
        self.assertIn('"registeredDeviceUdidSha256"', source)
        self.assertIn('"rebuiltApplicationAccepted": False', source)
        self.assertIn('"releaseAuthorized": False', source)
        self.assertNotIn("xcodebuild", source)
        self.assertNotIn("--upload", source)
        self.assertNotIn("--qualification-private-key", source)

    def test_contract_lint_is_stable(self):
        MODULE.lint_contract()
        controller = MODULE.load_controller()
        self.assertEqual(
            MODULE.CONTRACT_ID,
            "sora-ios-wallet-migration-installable-clone-v1",
        )
        self.assertEqual(controller.INSTALLABLE_CLONE_CONTRACT_ID, MODULE.CONTRACT_ID)
        self.assertEqual(len(controller.REQUEST_KEYS), 26)
        self.assertEqual(
            controller.CLONE_BOUND_AUTHORIZATION_KEYS,
            {
                "qualificationContractSha256",
                "productionIpaSha256",
                "installedAppRawTreeSha256",
                "installedExecutableSha256",
                "productionCanonicalProjectionSha256",
                "installedCanonicalProjectionSha256",
                "canonicalProjectionReceiptSha256",
                "canonicalProjectorSourceSha256",
            },
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
