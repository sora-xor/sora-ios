import CryptoKit
import Foundation
import XCTest
@testable import SoraPassport

final class RetainedEvidenceStateTests: XCTestCase {
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
    func testAuthenticatedInitialStateRestoresEverySupportedCase() throws {
        for c in Harness.EvidenceCase.allCases {
            let result = try load(state(c), c)
            XCTAssertEqual(result.caseId, c.rawValue); XCTAssertEqual(result.launchCount, 1)
            XCTAssertEqual(result.transitions.count, 1); XCTAssertEqual(result.transitions[0].kind, "authorized-launch")
        }
    }
    func testHmacBindsPayloadAndAuthenticationKey() throws {
        let data = try authenticated(state())
        XCTAssertThrowsError(try Harness.loadState(data, request: request(), requestSha: digest, authenticationKey: SymmetricKey(data: Data(repeating: 0, count: 32))))
        var changed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); changed["phase"] = "tampered"
        XCTAssertThrowsError(try Harness.loadState(canonical(changed), request: request(), requestSha: digest, authenticationKey: key))
        for mac in ["", String(repeating: "A", count: 64), String(repeating: "0", count: 64), "xyz"] {
            changed["stateAuthenticationHmacSha256"] = mac
            XCTAssertThrowsError(try Harness.loadState(canonical(changed), request: request(), requestSha: digest, authenticationKey: key))
        }
    }
    func testAuthenticatedStateRequiresItsCanonicalEncoding() throws {
        let data = try authenticated(state())
        for bytes in [Data(data.dropLast()), data + Data([10]), Data(" ".utf8) + data] {
            XCTAssertThrowsError(try Harness.loadState(bytes, request: request(), requestSha: digest, authenticationKey: key))
        }
    }
    func testSignedContractAndAuthorizationBindingsCannotBeRepurposed() throws {
        for (name, replacement): (String, Any) in [
            ("schemaVersion", 4), ("contractId", "other"), ("platform", "android"), ("status", "verified"),
            ("releaseAuthorized", true), ("authorizationId", "other"), ("authorizationRequestSha256", "other"),
            ("runId", "other"), ("caseKind", "device"), ("caseId", "watch-only")
        ] {
            var value = try state(); value[name] = replacement
            XCTAssertThrowsError(try load(value), name)
        }
    }
    func testLaunchBudgetAndTransitionChainRemainBounded() throws {
        for count in [0, 3] { var value = try state(); value["launchCount"] = count; XCTAssertThrowsError(try load(value)) }
        var value = try state(); value["transitions"] = []; XCTAssertThrowsError(try load(value))
        value = try state(); value["transitions"] = Array(repeating: transition(), count: 129); XCTAssertThrowsError(try load(value))
        value = try state(); value["previousStateSha256"] = digest; XCTAssertThrowsError(try load(value))
        value = try state(); value["transitions"] = [transition(), transition(2, launch: 2)]; value["launchCount"] = 2
        XCTAssertThrowsError(try load(value))
        value["previousStateSha256"] = digest
        XCTAssertEqual(try load(value).launchCount, 2)
        value["previousStateSha256"] = "bad"; XCTAssertThrowsError(try load(value))
    }
    func testTransitionMetadataIsValidatedAfterAuthentication() throws {
        for (name, replacement): (String, Any) in [("sequence", 0), ("launchCount", 0), ("launchCount", 2),
            ("kind", "../escape"), ("checkpoint", "bad value"), ("occurredAtEpochSeconds", 1_577_836_799),
            ("previousStateSha256", "bad"), ("previousStateSha256", digest)] {
            var item = transition(); item[name] = replacement
            var value = try state(); value["transitions"] = [item]; XCTAssertThrowsError(try load(value), name)
        }
        var value = try state(); value["transitions"] = [transition(kind: "checkpoint")]
        XCTAssertThrowsError(try load(value))
    }
    func testLaterTransitionsRequirePreviousDigestAndMonotonicLaunchCounts() throws {
        var value = try state(); value["launchCount"] = 2; value["previousStateSha256"] = digest
        var second = transition(2, launch: 2); second.removeValue(forKey: "previousStateSha256")
        value["transitions"] = [transition(), second]; XCTAssertThrowsError(try load(value))
        value["transitions"] = [transition(), transition(2, launch: 2), transition(3, launch: 1, kind: "checkpoint")]
        XCTAssertThrowsError(try load(value))
        value["transitions"] = [transition(), transition(2, launch: 2), transition(3, launch: 2, kind: "checkpoint")]
        XCTAssertEqual(try load(value).transitions.count, 3)
    }
    func testCheckpointSequenceRejectsUnknownAndRepeatedCheckpoints() throws {
        var value = try state(); value["checkpointSequence"] = ["unknown"]
        XCTAssertThrowsError(try load(value))
        let checkpoint = RetainedMigrationEvidenceCheckpoint.afterCoreDataCommit.rawValue
        value["checkpointSequence"] = [checkpoint]; XCTAssertEqual(try load(value).checkpointSequence, [checkpoint])
        value["checkpointSequence"] = [checkpoint, checkpoint]; XCTAssertThrowsError(try load(value))
    }
    func testLowStorageObservationMustBelongToTheAuthorizedCase() throws {
        var value = try state(); value["lowStorageConditionObserved"] = true; XCTAssertThrowsError(try load(value))
        value = try state(.lowStorage); value.removeValue(forKey: "lowStorageConditionObserved")
        XCTAssertThrowsError(try load(value, .lowStorage))
        value["lowStorageConditionObserved"] = true; XCTAssertEqual(try load(value, .lowStorage).lowStorageConditionObserved, true)
    }
    func testArchiveExportRequiresTheMatchingCaseAndTransition() throws {
        var value = try state(); value["recoveryArchiveExportVerified"] = true; XCTAssertThrowsError(try load(value))
        value = try state(.recoveryArchiveExport); value["recoveryArchiveExportVerified"] = true
        XCTAssertThrowsError(try load(value, .recoveryArchiveExport))
        value["transitions"] = [transition(), transition(2, kind: "recovery-archive-export")]; value["previousStateSha256"] = digest
        XCTAssertTrue(try load(value, .recoveryArchiveExport).recoveryArchiveExportVerified)
    }
    func testRollbackEvidenceCannotAppearInOtherCases() throws {
        for name in ["rollbackBeforeStoreTreeSha256", "rollbackReplacementStoreTreeSha256", "rollbackRestoredStoreTreeSha256"] {
            var value = try state(); value[name] = digest; XCTAssertThrowsError(try load(value))
            value = try state(.rollback); value[name] = "bad"; XCTAssertThrowsError(try load(value, .rollback))
        }
        for name in ["rollbackInjectionObserved", "rollbackRestorationVerified"] {
            var value = try state(); value[name] = true; XCTAssertThrowsError(try load(value))
        }
    }
    func testRollbackRestorationRequiresCompleteMatchingEvidence() throws {
        var value = try state(.rollback); value["rollbackInjectionObserved"] = true
        XCTAssertThrowsError(try load(value, .rollback))
        value["rollbackBeforeStoreTreeSha256"] = digest; XCTAssertThrowsError(try load(value, .rollback))
        value["rollbackReplacementStoreTreeSha256"] = String(repeating: "b", count: 64)
        XCTAssertTrue(try load(value, .rollback).rollbackInjectionObserved)
        value["rollbackRestorationVerified"] = true; XCTAssertThrowsError(try load(value, .rollback))
        value["rollbackRestoredStoreTreeSha256"] = String(repeating: "c", count: 64); XCTAssertThrowsError(try load(value, .rollback))
        value["rollbackRestoredStoreTreeSha256"] = digest; XCTAssertThrowsError(try load(value, .rollback))
        value["transitions"] = [transition(), transition(2, kind: "rollback-restoration")]; value["previousStateSha256"] = digest
        XCTAssertTrue(try load(value, .rollback).rollbackRestorationVerified)
        value["rollbackInjectionObserved"] = false; XCTAssertThrowsError(try load(value, .rollback))
    }
    private func verifySignature(_ key: P256.Signing.PrivateKey, data: Data, signature: Data,
                                 changes: [String: Any] = [:], removing: String? = nil) throws {
        let request = try request()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var info: [String: Any] = ["CFBundleIdentifier": "org.sora.evidence-fixture." + UUID().uuidString,
            "CFBundlePackageType": "BNDL", "CFBundleName": "EvidenceFixture",
            "SoraMigrationEvidenceAuthorizationKeyId": request.authorizationKeyId,
            "SoraMigrationEvidenceAuthorizationPublicKeyX963Base64": key.publicKey.x963Representation.base64EncodedString(),
            "SoraMigrationEvidenceSourceRevision": request.sourceRevision,
            "SoraMigrationEvidenceQualificationContractSha256": request.qualificationContractSha256]
        info.merge(changes) { _, replacement in replacement }
        if let removing { info.removeValue(forKey: removing) }
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: directory.appendingPathComponent("Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url: directory))
        try Harness.shared.verifyAuthorizationSignature(requestData: data, signatureData: signature, request: request, bundle: bundle)
    }
    func testAuthorizationSignatureAcceptsOnlyTheExactPayloadAndBundledAuthority() throws {
        let key = P256.Signing.PrivateKey(), payload = Data("public test authorization".utf8)
        let signature = try key.signature(for: payload).derRepresentation
        XCTAssertNoThrow(try verifySignature(key, data: payload, signature: signature))
        XCTAssertThrowsError(try verifySignature(key, data: payload + Data([10]), signature: signature))
        XCTAssertThrowsError(try verifySignature(P256.Signing.PrivateKey(), data: payload, signature: signature))
    }
    func testAuthorizationSignatureRequiresEveryBundleBinding() throws {
        let key = P256.Signing.PrivateKey(), payload = Data("public test authorization".utf8)
        let signature = try key.signature(for: payload).derRepresentation
        for name in ["SoraMigrationEvidenceAuthorizationKeyId", "SoraMigrationEvidenceAuthorizationPublicKeyX963Base64", "SoraMigrationEvidenceSourceRevision", "SoraMigrationEvidenceQualificationContractSha256"] {
            XCTAssertThrowsError(try verifySignature(key, data: payload, signature: signature, removing: name), name)
            XCTAssertThrowsError(try verifySignature(key, data: payload, signature: signature, changes: [name: 1]), name)
        }
    }
    func testAuthorizationSignatureCannotBeReboundToAnotherBuildOrContract() throws {
        let key = P256.Signing.PrivateKey(), payload = Data("public test authorization".utf8)
        let signature = try key.signature(for: payload).derRepresentation
        for (name, value) in [("SoraMigrationEvidenceAuthorizationKeyId", "other-authority"), ("SoraMigrationEvidenceAuthorizationKeyId", "../unsafe"), ("SoraMigrationEvidenceSourceRevision", String(repeating: "b", count: 40)), ("SoraMigrationEvidenceQualificationContractSha256", String(repeating: "b", count: 64))] {
            XCTAssertThrowsError(try verifySignature(key, data: payload, signature: signature, changes: [name: value]), name)
        }
    }
    func testAuthorizationSignatureRejectsMalformedAndUnresolvedPublicKeys() throws {
        let key = P256.Signing.PrivateKey(), payload = Data("public test authorization".utf8)
        let signature = try key.signature(for: payload).derRepresentation
        let encoded = key.publicKey.x963Representation.base64EncodedString()
        for value in ["", "$(AUTHORITY_PUBLIC_KEY)", "not-base64", encoded + "\n", Data(repeating: 0, count: 64).base64EncodedString(), Data(repeating: 0, count: 65).base64EncodedString(), (Data([4]) + Data(repeating: 0xff, count: 64)).base64EncodedString()] {
            XCTAssertThrowsError(try verifySignature(key, data: payload, signature: signature, changes: ["SoraMigrationEvidenceAuthorizationPublicKeyX963Base64": value]))
        }
    }
    func testAuthorizationSignatureRejectsMalformedAndTrailingDERBytes() throws {
        let key = P256.Signing.PrivateKey(), payload = Data("public test authorization".utf8)
        let signature = try key.signature(for: payload).derRepresentation
        for bytes in [Data(), Data(signature.dropLast()), signature + Data([0]), Data(repeating: 0, count: 64)] {
            XCTAssertThrowsError(try verifySignature(key, data: payload, signature: bytes))
        }
    }

}
