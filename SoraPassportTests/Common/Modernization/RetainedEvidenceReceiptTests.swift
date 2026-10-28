import CryptoKit
import Foundation
import Security
import XCTest
@testable import SoraPassport

final class RetainedEvidenceReceiptTests: XCTestCase {
    private typealias Harness = RetainedMigrationEvidenceHarness
    private let key = SymmetricKey(data: Data(repeating: 0x5a, count: 32))
    private let digest = String(repeating: "a", count: 64)
    private let now: Int64 = 1_800_000_000

    private func request(_ evidenceCase: Harness.EvidenceCase = .mnemonic12) throws -> Harness.AuthorizationRequest {
        var root: [String: Any] = [
            "schemaVersion": 3, "contractId": "sora-ios-wallet-migration-evidence-authorization-v3",
            "platform": "ios", "purpose": "retained-wallet-migration-observation", "releaseAuthorized": false,
            "authorizationId": "3a5398ab-e5e4-47ba-9fb4-d17972fc66cb", "authorizationKeyId": "fixture-key.1",
            "signatureAlgorithm": "ecdsa-p256-sha256", "runId": "c5326e4f-bb03-468d-849d-6054d7dd86ce",
            "sourceRevision": String(repeating: "a", count: 40), "caseKind": evidenceCase.kind.rawValue,
            "caseId": evidenceCase.rawValue, "issuedAtEpochSeconds": now - 60,
            "expiresAtEpochSeconds": now + 60, "maximumLaunchCount": 2
        ]
        for name in Harness.AuthorizationRequest.exactKeys where name.hasSuffix("Sha256") { root[name] = digest }
        return try Harness.AuthorizationRequest.parse(canonicalData: canonical(root), now: now)
    }
    private func canonical(_ object: Any) throws -> Data {
        var bytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        bytes.append(10); return bytes
    }
    private func transition(_ sequence: Int = 1, launch: Int = 1, kind: String = "authorized-launch") -> [String: Any] {
        var value: [String: Any] = ["sequence": sequence, "launchCount": launch, "kind": kind, "occurredAtEpochSeconds": now]
        if sequence > 1 { value["previousStateSha256"] = digest }
        return value
    }
    private func state(_ evidenceCase: Harness.EvidenceCase = .mnemonic12) throws -> [String: Any] {
        let r = try request(evidenceCase)
        var value: [String: Any] = [
            "schemaVersion": 3, "contractId": "sora-ios-wallet-migration-evidence-harness-state-v3", "platform": "ios",
            "status": "observed", "releaseAuthorized": false, "authorizationId": r.authorizationId,
            "authorizationRequestSha256": digest, "runId": r.runId, "caseKind": r.caseKind.rawValue,
            "caseId": r.evidenceCase.rawValue, "launchCount": 1, "phase": "authorized", "transitions": [transition()],
            "checkpointSequence": [], "recoveryArchiveExportVerified": false, "rollbackInjectionObserved": false,
            "rollbackRestorationVerified": false, "stateAuthenticationHmacSha256": ""
        ]
        if evidenceCase == .lowStorage { value["lowStorageConditionObserved"] = false }
        return value
    }
    private func authenticated(_ root: [String: Any]) throws -> Data {
        var root = root; root["stateAuthenticationHmacSha256"] = ""
        let mac = HMAC<SHA256>.authenticationCode(for: try canonical(root), using: key)
        root["stateAuthenticationHmacSha256"] = mac.map { String(format: "%02x", $0) }.joined()
        return try canonical(root)
    }
    @discardableResult private func load(_ root: [String: Any], _ evidenceCase: Harness.EvidenceCase = .mnemonic12) throws -> Harness.HarnessState {
        try Harness.loadState(authenticated(root), request: request(evidenceCase), requestSha: digest, authenticationKey: key)
    }
    private func receipt(_ kind: Harness.EvidenceCase, state: Harness.HarnessState? = nil,
                         comparison: Harness.KeychainComparison? = nil, behavior: Bool = true, recovery: Bool = false) throws -> [String: Any] {
        try Harness.makeReceipt(request: request(kind), requestSha256: digest,
            state: try state ?? load(self.state(kind), kind), finishedAtEpochSeconds: now + 20,
            stateSha256: String(repeating: "b", count: 64), route: recovery ? .recovery : .localAuthentication,
            outcome: kind.kind == .keychain ? "passed" : "observed",
            comparison: comparison ?? .init(identifierSetUnchanged: true, valuesByteForByteUnchanged: true, accessibilityUnchanged: true, credentialRewriteObserved: false),
            behaviorPassed: behavior, recoveryEntered: recovery)
    }
    private var unchanged: Harness.KeychainComparison { .init(identifierSetUnchanged: true, valuesByteForByteUnchanged: true, accessibilityUnchanged: true, credentialRewriteObserved: false) }
    private func observation(_ kind: Harness.EvidenceCase, state value: Harness.HarnessState, route: RetainedMigrationEvidenceApplicationRoute = .localAuthentication, comparison: Harness.KeychainComparison? = nil) throws -> (outcome: String, behaviorPassed: Bool, recoveryEntered: Bool) {
        Harness.evaluateObservation(request: try request(kind), state: value, route: route, comparison: comparison ?? unchanged)
    }
    func testSigningCohortsRequireAllThreeIndependentCredentialFacts() throws {
        for kind in [Harness.EvidenceCase.mnemonic12, .mnemonic15Retained, .mnemonic18Retained, .mnemonic21Retained, .irohaV1PairedKeys, .mnemonic24, .rawSeed, .legacySecret] {
            for probe in [false, true] { for expected in [false, true] { for succeeded in [false, true] {
                var value = try load(state(kind), kind)
                value.credentialBehaviorProbePassed = probe; value.signingExpectedObserved = expected; value.signingSucceededObserved = succeeded
                let result = try observation(kind, state: value)
                XCTAssertEqual(result.behaviorPassed, probe && expected && succeeded)
                XCTAssertEqual(result.outcome, probe && expected && succeeded ? "passed" : "failed")
                XCTAssertFalse(result.recoveryEntered)
            } } }
        }
    }
    func testWatchOnlyRequiresExplicitProofThatSigningWasNeitherExpectedNorSuccessful() throws {
        for probe in [false, true] { for expected in [false, true] { for succeeded in [false, true] {
            var value = try load(state(.watchOnly), .watchOnly)
            value.credentialBehaviorProbePassed = probe; value.signingExpectedObserved = expected; value.signingSucceededObserved = succeeded
            let result = try observation(.watchOnly, state: value)
            XCTAssertEqual(result.outcome, probe && !expected && !succeeded ? "passed" : "failed")
        } } }
        XCTAssertEqual(try observation(.watchOnly, state: load(state(.watchOnly), .watchOnly)).outcome, "failed")
    }
    func testMissingAndCorruptSecretsPassOnlyThroughRecoveryWithoutSuccessfulSigning() throws {
        for kind in [Harness.EvidenceCase.missingSecret, .corruptSecret] {
            for recovered in [false, true] { for succeeded in [nil, false, true] as [Bool?] {
                var value = try load(state(kind), kind); value.signingSucceededObserved = succeeded
                let result = try observation(kind, state: value, route: recovered ? .recovery : .localAuthentication)
                XCTAssertEqual(result.outcome, recovered && succeeded != true ? "passed" : "failed")
                XCTAssertEqual(result.recoveryEntered, recovered)
            } }
        }
    }
    func testCredentialCohortsRejectEveryIndependentKeychainMutation() throws {
        var value = try load(state()); value.credentialBehaviorProbePassed = true; value.signingExpectedObserved = true; value.signingSucceededObserved = true
        for comparison in [Harness.KeychainComparison(identifierSetUnchanged: false, valuesByteForByteUnchanged: true, accessibilityUnchanged: true, credentialRewriteObserved: false), .init(identifierSetUnchanged: true, valuesByteForByteUnchanged: false, accessibilityUnchanged: true, credentialRewriteObserved: false), .init(identifierSetUnchanged: true, valuesByteForByteUnchanged: true, accessibilityUnchanged: false, credentialRewriteObserved: false), .init(identifierSetUnchanged: true, valuesByteForByteUnchanged: true, accessibilityUnchanged: true, credentialRewriteObserved: true)] {
            let result = try observation(.mnemonic12, state: value, comparison: comparison)
            XCTAssertTrue(result.behaviorPassed); XCTAssertEqual(result.outcome, "failed")
        }
    }
    func testOrdinaryCredentialAndReinstallRoutesMustReachAWalletAuthenticationScreen() throws {
        for kind in [Harness.EvidenceCase.mnemonic12, .reinstallUpgrade] {
            var value = try load(state(kind), kind); value.credentialBehaviorProbePassed = true; value.signingExpectedObserved = true; value.signingSucceededObserved = true
            for route in [RetainedMigrationEvidenceApplicationRoute.onboarding, .legacyUpgradeReady, .localAuthentication, .pincodeSetup, .recovery] {
                let result = try observation(kind, state: value, route: route)
                let expected = route == .localAuthentication || route == .pincodeSetup
                XCTAssertEqual(result.outcome, expected ? (kind == .mnemonic12 ? "passed" : "observed") : "failed")
            }
        }
    }
    func testInterruptionBeforeSecretRetentionRequiresTheCheckpointAndUnchangedCredentials() throws {
        let kind = Harness.EvidenceCase.interruptionBeforeSecretRetention
        for checkpoint in [false, true] { for recovered in [false, true] {
            var value = try load(state(kind), kind); value.checkpointSequence = checkpoint ? [RetainedMigrationEvidenceCheckpoint.beforeSecretRetention.rawValue] : []
            XCTAssertEqual(try observation(kind, state: value, route: recovered ? .recovery : .localAuthentication).outcome, checkpoint && !recovered ? "observed" : "failed")
            let mutated = Harness.KeychainComparison(identifierSetUnchanged: true, valuesByteForByteUnchanged: false, accessibilityUnchanged: true, credentialRewriteObserved: false)
            XCTAssertEqual(try observation(kind, state: value, comparison: mutated).outcome, "failed")
        } }
    }
    func testPostRetentionInterruptionsRequireTheirOwnCheckpointAndRecoveryRoute() throws {
        let cases: [(Harness.EvidenceCase, RetainedMigrationEvidenceCheckpoint)] = [(.interruptionAfterSecretRetention, .afterSecretRetention), (.interruptionAfterCoreDataCommit, .afterCoreDataCommit), (.interruptionAfterNetworkStaging, .afterNetworkStaging), (.interruptionBeforeActivation, .beforeActivation)]
        for (kind, checkpoint) in cases { for observed in [false, true] { for recovered in [false, true] {
            var value = try load(state(kind), kind); value.checkpointSequence = observed ? [checkpoint.rawValue] : []
            XCTAssertEqual(try observation(kind, state: value, route: recovered ? .recovery : .localAuthentication).outcome, observed && recovered ? "observed" : "failed")
        } } }
    }
    func testProcessRestartNeedsBothTheSecondLaunchAndCommittedStoreCheckpoint() throws {
        let kind = Harness.EvidenceCase.processDeathRestart
        for launch in [1, 2] { for checkpoint in [false, true] {
            var value = try load(state(kind), kind); value.launchCount = launch; value.checkpointSequence = checkpoint ? [RetainedMigrationEvidenceCheckpoint.afterCoreDataCommit.rawValue] : []
            XCTAssertEqual(try observation(kind, state: value, route: .recovery).outcome, launch == 2 && checkpoint ? "observed" : "failed")
        } }
    }
    func testRollbackNeedsReplacementAndExactRestorationEvidence() throws {
        var value = try load(state(.rollback), .rollback)
        value.rollbackBeforeStoreTreeSha256 = digest; value.rollbackReplacementStoreTreeSha256 = String(repeating: "b", count: 64); value.rollbackRestoredStoreTreeSha256 = digest
        value.rollbackInjectionObserved = true; value.rollbackRestorationVerified = true
        XCTAssertEqual(try observation(.rollback, state: value, route: .recovery).outcome, "observed")
        for missing in 0..<6 {
            var incomplete = value
            switch missing {
            case 0: incomplete.rollbackInjectionObserved = false
            case 1: incomplete.rollbackRestorationVerified = false
            case 2: incomplete.rollbackBeforeStoreTreeSha256 = nil
            case 3: incomplete.rollbackReplacementStoreTreeSha256 = nil
            case 4: incomplete.rollbackReplacementStoreTreeSha256 = digest
            default: incomplete.rollbackRestoredStoreTreeSha256 = String(repeating: "c", count: 64)
            }
            XCTAssertEqual(try observation(.rollback, state: incomplete, route: .recovery).outcome, "failed")
        }
    }
    func testLowStorageAndArchiveExportRequireTheirExplicitObservedFacts() throws {
        for observed in [nil, false, true] as [Bool?] {
            var value = try load(state(.lowStorage), .lowStorage); value.lowStorageConditionObserved = observed
            XCTAssertEqual(try observation(.lowStorage, state: value, route: .recovery).outcome, observed == true ? "observed" : "failed")
        }
        for observed in [false, true] {
            var value = try load(state(.recoveryArchiveExport), .recoveryArchiveExport); value.recoveryArchiveExportVerified = observed
            XCTAssertEqual(try observation(.recoveryArchiveExport, state: value, route: .recovery).outcome, observed ? "observed" : "failed")
        }
    }
    func testReceiptBindsEveryPublicIdentityAndExplicitlyDisclaimsReleaseAuthority() throws {
        for kind in Harness.EvidenceCase.allCases where kind != .rollback {
            let result = try receipt(kind), r = try request(kind)
            XCTAssertEqual(result["schemaVersion"] as? Int, 3)
            XCTAssertEqual(result["contractId"] as? String, "sora-ios-wallet-migration-case-operation-receipt-v3")
            XCTAssertEqual(result["platform"] as? String, "ios"); XCTAssertEqual(result["status"] as? String, "observed")
            XCTAssertEqual(result["releaseAuthorized"] as? Bool, false)
            XCTAssertEqual(result["authorizationId"] as? String, r.authorizationId)
            XCTAssertEqual(result["authorizationKeyId"] as? String, r.authorizationKeyId)
            XCTAssertEqual(result["runId"] as? String, r.runId)
            XCTAssertEqual(result["sourceRevision"] as? String, r.sourceRevision)
            XCTAssertEqual(result["caseId"] as? String, kind.rawValue); XCTAssertEqual(result["caseKind"] as? String, kind.kind.rawValue)
            XCTAssertEqual(result["startedAtEpochSeconds"] as? Int64, now); XCTAssertEqual(result["finishedAtEpochSeconds"] as? Int64, now + 20)
            XCTAssertEqual(result["launchCount"] as? Int, 1); XCTAssertEqual(result["applicationRoute"] as? String, "local-authentication")
            XCTAssertEqual(result["checkpointSequence"] as? [String], [])
            for (name, value) in result where name.hasSuffix("Sha256") {
                XCTAssertEqual(value as? String, name == "harnessStateSha256" ? String(repeating: "b", count: 64) : digest, name)
            }
            let encoded = try canonical(result)
            XCTAssertFalse(encoded.isEmpty)
            XCTAssertNil(result[kind.kind == .keychain ? "deviceObservation" : "keychainObservation"])
        }
    }
    func testKeychainReceiptReportsOnlyAggregateObservationsAndExpectedSigningPolicy() throws {
        for kind in Harness.EvidenceCase.allCases where kind.kind == .keychain {
            var value = try load(state(kind), kind); value.signingSucceededObserved = kind.signingExpected
            let result = try receipt(kind, state: value)
            let observed = try XCTUnwrap(result["keychainObservation"] as? [String: Any])
            XCTAssertEqual(Set(observed.keys), Set(["identifierSetUnchanged", "valuesByteForByteUnchanged", "accessibilityUnchanged", "credentialRewriteObserved", "credentialBehaviorProbePassed", "signingExpected", "signingSucceeded", "recoveryRouteEntered"]))
            XCTAssertEqual(observed["signingExpected"] as? Bool, kind.signingExpected)
            XCTAssertEqual(observed["signingSucceeded"] as? Bool, kind.signingExpected)
            XCTAssertEqual(observed["identifierSetUnchanged"] as? Bool, true)
            XCTAssertEqual(observed["credentialRewriteObserved"] as? Bool, false)
        }
    }
    func testFailedCredentialObservationsArePreservedWithoutInventingSuccessfulSigning() throws {
        let comparison = Harness.KeychainComparison(identifierSetUnchanged: false, valuesByteForByteUnchanged: false, accessibilityUnchanged: false, credentialRewriteObserved: true)
        let result = try receipt(.corruptSecret, comparison: comparison, behavior: false, recovery: true)
        let observed = try XCTUnwrap(result["keychainObservation"] as? [String: Any])
        for name in ["identifierSetUnchanged", "valuesByteForByteUnchanged", "accessibilityUnchanged", "credentialBehaviorProbePassed", "signingSucceeded"] { XCTAssertEqual(observed[name] as? Bool, false) }
        XCTAssertEqual(observed["credentialRewriteObserved"] as? Bool, true); XCTAssertEqual(observed["recoveryRouteEntered"] as? Bool, true)
        XCTAssertEqual(result["applicationRoute"] as? String, "recovery")
    }
    func testDeviceObservationRequiresExternalValidationEvenWhenTheAppSawRecovery() throws {
        var value = try load(state(.recoveryArchiveExport), .recoveryArchiveExport); value.recoveryArchiveExportVerified = true
        let result = try receipt(.recoveryArchiveExport, state: value, recovery: true)
        let observed = try XCTUnwrap(result["deviceObservation"] as? [String: Any])
        XCTAssertEqual(observed["controllerValidationRequired"] as? Bool, true)
        XCTAssertEqual(observed["recoveryArchiveExportVerified"] as? Bool, true)
        XCTAssertEqual(observed["recoveryRouteEntered"] as? Bool, true)
        XCTAssertEqual(result["outcome"] as? String, "observed")
    }
    func testRestartObservationRequiresBothALaterLaunchAndTheDurableCheckpoint() throws {
        for launches in [1, 2] { for checkpoint in [false, true] {
            var value = try load(state(.processDeathRestart), .processDeathRestart); value.launchCount = launches
            value.checkpointSequence = checkpoint ? [RetainedMigrationEvidenceCheckpoint.afterCoreDataCommit.rawValue] : []
            let result = try receipt(.processDeathRestart, state: value)
            let observed = try XCTUnwrap(result["deviceObservation"] as? [String: Any])
            XCTAssertEqual(observed["processDeathRestartObserved"] as? Bool, launches == 2 && checkpoint)
        } }
    }
    func testRollbackReceiptRequiresAllThreeDistinctStageDigests() throws {
        var value = try load(state(.rollback), .rollback)
        XCTAssertThrowsError(try receipt(.rollback, state: value))
        value.rollbackBeforeStoreTreeSha256 = digest; XCTAssertThrowsError(try receipt(.rollback, state: value))
        value.rollbackReplacementStoreTreeSha256 = String(repeating: "c", count: 64); XCTAssertThrowsError(try receipt(.rollback, state: value))
        value.rollbackRestoredStoreTreeSha256 = digest; value.rollbackInjectionObserved = true; value.rollbackRestorationVerified = true
        let result = try receipt(.rollback, state: value, recovery: true)
        let observed = try XCTUnwrap(result["deviceObservation"] as? [String: Any])
        XCTAssertEqual(observed["rollbackBeforeStoreTreeSha256"] as? String, digest)
        XCTAssertEqual(observed["rollbackReplacementStoreTreeSha256"] as? String, String(repeating: "c", count: 64))
        XCTAssertEqual(observed["rollbackRestoredStoreTreeSha256"] as? String, digest)
        XCTAssertEqual(observed["rollbackInjectionObserved"] as? Bool, true); XCTAssertEqual(observed["rollbackRestorationVerified"] as? Bool, true)
    }
    func testLowStorageReceiptDoesNotAssumeObservationFromCaseName() throws {
        for fact in [false, true] {
            var value = try load(state(.lowStorage), .lowStorage); value.lowStorageConditionObserved = fact
            let result = try receipt(.lowStorage, state: value)
            XCTAssertEqual((result["deviceObservation"] as? [String: Any])?["lowStorageConditionObserved"] as? Bool, fact)
        }
    }
    func testPreRetentionInterruptionCarriesAllThreeIndependentKeychainChecks() throws {
        let comparison = Harness.KeychainComparison(identifierSetUnchanged: true, valuesByteForByteUnchanged: false, accessibilityUnchanged: true, credentialRewriteObserved: true)
        let result = try receipt(.interruptionBeforeSecretRetention, comparison: comparison)
        let observed = try XCTUnwrap(result["deviceObservation"] as? [String: Any])
        XCTAssertEqual(observed["retainedKeychainIdentifierSetUnchanged"] as? Bool, true)
        XCTAssertEqual(observed["retainedKeychainValuesUnchanged"] as? Bool, false)
        XCTAssertEqual(observed["retainedKeychainAccessibilityUnchanged"] as? Bool, true)
    }
    func testReceiptWithNoTransitionUsesTheExplicitObservationTime() throws {
        var value = try load(state()); value.transitions = []
        let result = try receipt(.mnemonic12, state: value)
        XCTAssertEqual(result["startedAtEpochSeconds"] as? Int64, now + 20)
    }
    private func keyRecord(tag: Any = Data("public-tag".utf8), value: Any = Data("public-test-material".utf8), accessibility: Any = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, accessGroup: Any? = "fixture-group") -> [String: Any] {
        var result: [String: Any] = [kSecAttrApplicationTag as String: tag, kSecValueData as String: value, kSecAttrAccessible as String: accessibility]
        result[kSecAttrAccessGroup as String] = accessGroup
        return result
    }
    private func parse(_ result: Any, status: OSStatus = errSecSuccess) throws -> Harness.KeychainSnapshot {
        try Harness.KeychainSnapshot.parse(status: status, result: result as CFTypeRef)
    }
    func testSecurityNoItemMeansAnEmptySnapshotButOtherErrorsCannotMasqueradeAsEmpty() throws {
        XCTAssertEqual(try Harness.KeychainSnapshot.parse(status: errSecItemNotFound, result: nil).records, [])
        for status in [errSecAuthFailed, errSecInteractionNotAllowed, errSecDecode] { XCTAssertThrowsError(try Harness.KeychainSnapshot.parse(status: status, result: nil)) }
        XCTAssertThrowsError(try Harness.KeychainSnapshot.parse(status: errSecSuccess, result: nil))
        XCTAssertThrowsError(try parse("invalid Security result"))
    }
    func testSingleAndArraySecurityResultsNormalizeTagsAndHaveStableByteOrdering() throws {
        let first = try parse(keyRecord(tag: "a", accessGroup: nil))
        XCTAssertEqual(first.records.count, 1); XCTAssertEqual(first.records[0].applicationTag, Data("a".utf8)); XCTAssertEqual(first.records[0].accessGroup, "")
        let array = try parse([keyRecord(tag: Data("z".utf8)), keyRecord(tag: "a")])
        XCTAssertEqual(array.records.map(\.applicationTag), [Data("a".utf8), Data("z".utf8)])
    }
    func testKeychainSnapshotRejectsAmbiguousAndOversizedRecords() throws {
        for value in [keyRecord(tag: 4), keyRecord(tag: Data()), keyRecord(tag: Data(repeating: 1, count: 4097)), keyRecord(value: "wrong type"), keyRecord(accessibility: ""), keyRecord(accessibility: String(repeating: "x", count: 257)), keyRecord(accessGroup: String(repeating: "x", count: 513))] {
            XCTAssertThrowsError(try parse(value))
        }
        XCTAssertThrowsError(try parse([keyRecord(), keyRecord()]))
        XCTAssertThrowsError(try parse(Array(repeating: keyRecord(), count: 4097)))
        var missing = keyRecord(); missing.removeValue(forKey: kSecValueData as String); XCTAssertThrowsError(try parse(missing))
        missing = keyRecord(); missing.removeValue(forKey: kSecAttrAccessible as String); XCTAssertThrowsError(try parse(missing))
    }
    func testSnapshotComparisonDetectsChangesToEachProtectedDimension() throws {
        let original = try parse(keyRecord())
        let same = original.compare(with: try parse(keyRecord()))
        XCTAssertTrue(same.identifierSetUnchanged); XCTAssertTrue(same.valuesByteForByteUnchanged); XCTAssertTrue(same.accessibilityUnchanged); XCTAssertFalse(same.credentialRewriteObserved)
        let changedValue = original.compare(with: try parse(keyRecord(value: Data("changed-public-fixture".utf8))))
        XCTAssertTrue(changedValue.identifierSetUnchanged); XCTAssertFalse(changedValue.valuesByteForByteUnchanged); XCTAssertTrue(changedValue.accessibilityUnchanged); XCTAssertTrue(changedValue.credentialRewriteObserved)
        for record in [keyRecord(accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly), keyRecord(accessGroup: "other-group")] {
            let comparison = original.compare(with: try parse(record))
            XCTAssertTrue(comparison.identifierSetUnchanged); XCTAssertTrue(comparison.valuesByteForByteUnchanged); XCTAssertFalse(comparison.accessibilityUnchanged); XCTAssertTrue(comparison.credentialRewriteObserved)
        }
        let renamed = original.compare(with: try parse(keyRecord(tag: "other-tag")))
        XCTAssertFalse(renamed.identifierSetUnchanged); XCTAssertFalse(renamed.valuesByteForByteUnchanged); XCTAssertFalse(renamed.accessibilityUnchanged); XCTAssertTrue(renamed.credentialRewriteObserved)
        XCTAssertTrue(original.compare(with: Harness.KeychainSnapshot(records: [])).credentialRewriteObserved)
    }
}
