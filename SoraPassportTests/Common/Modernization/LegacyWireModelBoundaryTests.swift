// SPDX-License-Identifier: Apache-2.0
import Foundation
import BigInt
import SoraKeystore
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

final class LegacyWireModelBoundaryTests: XCTestCase {
    private func status(_ json: String) throws -> ExtrinsicStatus { try JSONDecoder().decode(ExtrinsicStatus.self, from: Data(json.utf8)) }
    func testReadyStatusAcceptsTheRuntimeStringRepresentation() throws {
        guard case .ready = try status("\"ready\"") else { return XCTFail("Expected readiness") }
    }
    func testStatusObjectsPreserveTheirPeersAndBlockIdentities() throws {
        guard case .ready = try status(#"{"ready":null}"#) else { return XCTFail("Expected readiness") }
        guard case let .broadcast(peers) = try status(#"{"broadcast":["peer-a","peer-b"]}"#) else { return XCTFail("Expected broadcast") }
        XCTAssertEqual(peers, ["peer-a", "peer-b"])
        guard case let .inBlock(block) = try status(#"{"inBlock":"0x1234"}"#) else { return XCTFail("Expected block") }; XCTAssertEqual(block, "0x1234")
        guard case let .finalized(finalized) = try status(#"{"finalized":"0xabcd"}"#) else { return XCTFail("Expected finality") }; XCTAssertEqual(finalized, "0xabcd")
    }
    func testMalformedStatusValuesCannotBeReportedAsFinality() {
        for value in ["null", "[]", "4", "{}", #"{"futureStatus":"0x1234"}"#, #"{"broadcast":"peer"}"#, #"{"broadcast":[1]}"#, #"{"inBlock":3}"#, #"{"finalized":false}"#] {
            XCTAssertThrowsError(try status(value), value)
        }
    }
    func testScalarJSONRoundTripsWithoutChangingSupportedWireTypes() throws {
        let values = [JSONAny(UInt32.max), JSONAny("日本語"), JSONAny(true), JSONAny(false), JSONAny(-1.25), JSONAny(["first", "last"])]
        for value in values {
            let bytes = try JSONEncoder().encode(value)
            let restored = try JSONDecoder().decode(JSONAny.self, from: bytes)
            XCTAssertEqual(try JSONEncoder().encode(restored), bytes)
        }
        XCTAssertEqual(try JSONDecoder().decode(JSONAny.self, from: Data("4294967295".utf8)).value() as? UInt32, UInt32.max)
        XCTAssertEqual(try JSONDecoder().decode(JSONAny.self, from: Data("-1.25".utf8)).value() as? Double, -1.25)
    }
    func testUnsupportedLegacyJSONShapesStayAbsentInsteadOfCoercingToAnotherScalar() throws {
        for json in ["null", "{}", "[1,true]", #"{"amount":"1"}"#] {
            let value = try JSONDecoder().decode(JSONAny.self, from: Data(json.utf8))
            XCTAssertNil(value.value()); XCTAssertEqual(String(data: try JSONEncoder().encode(value), encoding: .utf8), "null")
        }
    }
    func testTokenBalancesReadEachNetworkIndependentlyAndPreserveDecimalPrecision() {
        let value = TokenBalancesData(balanceContext: [WalletOperationContextKey.Balance.soranet: "1.000000000000000001", WalletOperationContextKey.Balance.erc20: "9007199254740993.25"])
        XCTAssertEqual(value.soranet, Decimal(string: "1.000000000000000001")); XCTAssertEqual(value.ethereum, Decimal(string: "9007199254740993.25"))
        let missing = TokenBalancesData(balanceContext: [:]); XCTAssertEqual(missing.soranet, 0); XCTAssertEqual(missing.ethereum, 0)
        let malformed = TokenBalancesData(balanceContext: [WalletOperationContextKey.Balance.soranet: "invalid", WalletOperationContextKey.Balance.erc20: "invalid"])
        XCTAssertEqual(malformed.soranet, 0); XCTAssertEqual(malformed.ethereum, 0)
    }
    func testSendingBalancesCombineTransferAndWithdrawalWithoutCrossingNetworks() {
        let value = TokenBalancesData(sendingContext: [WalletOperationContextKey.SoranetTransfer.balance: "1.25", WalletOperationContextKey.SoranetWithdraw.balance: "2.5", WalletOperationContextKey.ERC20Transfer.balance: "4.75", WalletOperationContextKey.ERC20Withdraw.balance: "8.125"])
        XCTAssertEqual(value.soranet, Decimal(string: "3.75")); XCTAssertEqual(value.ethereum, Decimal(string: "12.875"))
        let empty = TokenBalancesData(sendingContext: [:]); XCTAssertEqual(empty.soranet, 0); XCTAssertEqual(empty.ethereum, 0)
        let bad = TokenBalancesData(sendingContext: [WalletOperationContextKey.SoranetTransfer.balance: "invalid", WalletOperationContextKey.SoranetWithdraw.balance: "invalid", WalletOperationContextKey.ERC20Transfer.balance: "invalid", WalletOperationContextKey.ERC20Withdraw.balance: "invalid"])
        XCTAssertEqual(bad.soranet, 0); XCTAssertEqual(bad.ethereum, 0)
    }
    func testMarketErrorsDistinguishReviewRetryBalanceAndRecoveryActions() throws {
        let cases: [(PolkamarktRuntimeError, String)] = [
            (.unavailable, "unavailable"), (.wrongChain, "mainnet"), (.unsupportedRuntime(spec: 133, transaction: 131), "133/131"), (.missingCall("buy"), "Polkamarkt.buy"),
            (.invalidQuote, "invalid"), (.staleQuote, "confirmed minimum"), (.invalidSlippage, "0.01%"), (.invalidAmount, "greater than zero"), (.marketUnavailable, "tradable"),
            (.mutationsDisabled, "temporarily disabled"), (.wrongWalletOrNetwork, "before signing"), (.insufficientKUSD, "KUSD"), (.insufficientShares, "share balance"), (.insufficientXOR, "network fee"),
            (.invalidTransactionHash, "transaction hash"), (.ambiguousSubmission, "not retried"), (.mutationInFlight, "still being prepared"), (.pendingRecovery, "reconciled first"), (.staleClaim, "Review the claim again")]
        for (error, expected) in cases { XCTAssertTrue(try XCTUnwrap(error.errorDescription).contains(expected), expected) }
    }
    func testRecoveryDiagnosticsNeverIncludeAssociatedWalletIdentifiersOrPaths() throws {
        let secret = "private-wallet-fixture-path"
        let cases: [(UserStorageMigrationError, String)] = [(.unknownStoreVersion, "unknown_store_version"), (.unavailableModel(secret), "unavailable_model"), (.incompleteMigrationPath(secret, secret), "incomplete_migration_path"), (.interruptedMigration, "interrupted_migration"), (.missingWalletStore, "missing_wallet_store"), (.missingWalletSecret(secret), "missing_wallet_secret"), (.emptyWalletSecret(secret), "empty_wallet_secret"), (.insufficientStorage, "insufficient_storage"), (.backupVerificationFailed(secret), "backup_verification_failed"), (.accountInventoryMismatch, "account_inventory_mismatch"), (.selectedAccountMismatch, "selected_account_mismatch")]
        for (error, code) in cases {
            XCTAssertFalse(try XCTUnwrap(error.errorDescription).isEmpty)
            XCTAssertEqual(UserStorageMigrationError.privacySafeOutcomeCode(for: error), code)
            let persisted = UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
            XCTAssertTrue(persisted.contains(code)); XCTAssertTrue(persisted.contains("preserved")); XCTAssertFalse(persisted.contains(secret))
        }
        let external = NSError(domain: secret, code: 1, userInfo: [NSLocalizedDescriptionKey: secret])
        XCTAssertEqual(UserStorageMigrationError.privacySafeOutcomeCode(for: external), "unexpected_failure")
        XCTAssertFalse(UserStorageMigrationError.privacySafeRecoveryDescription(for: external).contains(secret))
    }
}

extension LegacyWireModelBoundaryTests {
    private func ethereumSignature(_ v: String = "1b", r: String = String(repeating: "01", count: 32), s: String = String(repeating: "02", count: 32)) throws -> EthereumSignature {
        try JSONDecoder().decode(EthereumSignature.self, from: JSONSerialization.data(withJSONObject: ["v": v, "r": r, "s": s]))
    }
    func testEthereumSignaturePreservesTheRecoveryIdAndBothScalars() throws {
        for recoveryId: UInt8 in [0, 1, 27, 28, 255] {
            let signature = try ethereumSignature(String(format: "%02x", recoveryId))
            XCTAssertEqual(signature.vPart, recoveryId)
            XCTAssertEqual(signature.rPart, Data(repeating: 1, count: 32)); XCTAssertEqual(signature.sPart, Data(repeating: 2, count: 32))
        }
    }
    func testEthereumSignatureEncodesTheDocumentedHexFieldsWithoutDataBase64() throws {
        let signature = EthereumSignature(vPart: 28, rPart: Data(repeating: 0xaa, count: 32), sPart: Data(repeating: 0xbb, count: 32))
        let encoded = try JSONEncoder().encode(signature)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? [String: String],
            ["v": "1c", "r": String(repeating: "aa", count: 32), "s": String(repeating: "bb", count: 32)])
        let restored = try JSONDecoder().decode(EthereumSignature.self, from: encoded)
        XCTAssertEqual(restored.vPart, 28); XCTAssertEqual(restored.rPart, signature.rPart); XCTAssertEqual(restored.sPart, signature.sPart)
    }
    func testEthereumSignatureRejectsMissingOrMultipleRecoveryBytes() {
        for raw in ["", "0001", "010203", "gg"] { XCTAssertThrowsError(try ethereumSignature(raw)) }
    }
    func testEthereumSignatureRejectsMalformedScalarHexAndNonstringWireFields() throws {
        XCTAssertThrowsError(try ethereumSignature(r: "zz")); XCTAssertThrowsError(try ethereumSignature(s: "zz"))
        for field in ["v", "r", "s"] {
            var wire: [String: Any] = ["v": "1b", "r": "01", "s": "02"]; wire[field] = 1
            XCTAssertThrowsError(try JSONDecoder().decode(EthereumSignature.self, from: JSONSerialization.data(withJSONObject: wire)))
            wire.removeValue(forKey: field)
            XCTAssertThrowsError(try JSONDecoder().decode(EthereumSignature.self, from: JSONSerialization.data(withJSONObject: wire)))
        }
    }
    private func media(_ wire: [String: Any]) throws -> MediaItemData {
        try JSONDecoder().decode(MediaItemData.self, from: JSONSerialization.data(withJSONObject: wire))
    }
    func testImageMediaRetainsItsDiscriminatorAndExactUrl() throws {
        let url = URL(string: "https://example.test/image.png?size=2")!
        let value = try media(["type": "IMAGE", "url": url.absoluteString])
        XCTAssertEqual(value, .image(item: ImageData(url: url)))
        let encoded = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? [String: String], ["type": "IMAGE", "url": url.absoluteString])
    }
    func testVideoMediaPreservesPreviewAndDurationAcrossTheWire() throws {
        let value = try media(["type": "VIDEO", "url": "https://example.test/video.mp4", "previewUrl": "https://example.test/cover.png", "duration": 123])
        guard case let .video(video) = value else { return XCTFail("Video type must remain a video") }
        XCTAssertEqual(video.duration, 123); XCTAssertEqual(video.previewUrl?.lastPathComponent, "cover.png")
        XCTAssertEqual(try JSONDecoder().decode(MediaItemData.self, from: JSONEncoder().encode(value)), value)
    }
    func testVideoMediaDoesNotInventAMissingPreview() throws {
        let value = try media(["type": "VIDEO", "url": "https://example.test/video.mp4", "duration": 0])
        guard case let .video(video) = value else { return XCTFail("Expected video") }
        XCTAssertNil(video.previewUrl)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        XCTAssertNil(object["previewUrl"]); XCTAssertEqual(object["duration"] as? Int, 0)
    }
    func testMediaRejectsUnknownAndMissingDiscriminators() {
        for wire: [String: Any] in [["type": "AUDIO", "url": "https://example.test/file"], ["url": "https://example.test/image.png"], ["type": 1, "url": "https://example.test/image.png"]] {
            XCTAssertThrowsError(try media(wire))
        }
    }
    func testMediaRejectsFieldsThatCannotRepresentItsDeclaredType() {
        XCTAssertThrowsError(try media(["type": "IMAGE", "url": 5]))
        XCTAssertThrowsError(try media(["type": "VIDEO", "url": "https://example.test/video.mp4"]))
        XCTAssertThrowsError(try media(["type": "VIDEO", "url": "https://example.test/video.mp4", "duration": "123"]))
    }
    private func user(parent: String? = nil, expires: Int64? = nil) -> UserData {
        UserData(userId: "public-fixture-user", firstName: "Test", lastName: "User", username: nil,
            country: nil, phone: nil, inviteAcceptExpirationMoment: expires, parentId: parent,
            status: nil, services: nil, values: UserValuesData(userId: "public-fixture-user", invitationCode: "fixture-code"))
    }
    func testInvitationWithNoExpiryRemainsAvailableOnlyBeforeParentIsAssigned() {
        XCTAssertTrue(user().canAcceptInvitation); XCTAssertNil(user().invitationExpirationInterval)
        XCTAssertFalse(user(parent: "parent").canAcceptInvitation); XCTAssertNil(user(parent: "parent").invitationExpirationInterval)
    }
    func testExpiredInvitationCannotBeAcceptedOrExposeANegativeCountdown() {
        let expired = user(expires: Int64(Date().timeIntervalSince1970) - 100)
        XCTAssertFalse(expired.canAcceptInvitation); XCTAssertNil(expired.invitationExpirationInterval)
    }
    func testFutureInvitationCountdownStaysWithinTheRemainingWindow() throws {
        let value = user(expires: Int64(Date().timeIntervalSince1970) + 3_600)
        XCTAssertTrue(value.canAcceptInvitation)
        let remaining = try XCTUnwrap(value.invitationExpirationInterval)
        XCTAssertGreaterThan(remaining, 3_590); XCTAssertLessThanOrEqual(remaining, 3_600)
    }
    func testAcceptedInvitationIgnoresAFutureInvitationDeadline() {
        let value = user(parent: "already-associated", expires: Int64(Date().timeIntervalSince1970) + 3_600)
        XCTAssertFalse(value.canAcceptInvitation); XCTAssertNil(value.invitationExpirationInterval)
    }
    func testUserProfileUsesWireNamesForValuesAndServiceIdentifiers() throws {
        var value = user()
        value.services = [UserServiceData(userId: value.userId, serviceType: "fixture", serviceId: "did:fixture:1")]
        let bytes = try JSONEncoder().encode(value), object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertNotNil(object["userValues"]); XCTAssertNil(object["values"])
        let services = try XCTUnwrap(object["userServices"] as? [[String: Any]])
        XCTAssertEqual(services.first?["serviceDid"] as? String, "did:fixture:1"); XCTAssertNil(services.first?["serviceId"])
        XCTAssertEqual(try JSONDecoder().decode(UserData.self, from: bytes), value)
    }
    func testRawChainDataDistinguishesUtf8TextFromArbitraryBytes() {
        let text = ChainData.raw(data: Data("名前".utf8)), binary = ChainData.raw(data: Data([0xff, 0xfe]))
        XCTAssertEqual(text.stringValue, "名前"); XCTAssertEqual(text.dataValue, Data("名前".utf8))
        XCTAssertNil(binary.stringValue); XCTAssertEqual(binary.dataValue, Data([0xff, 0xfe])); XCTAssertNil(binary.imageValue)
    }
    func testAbsentChainDataHasNoTextImageOrBytes() {
        let value = ChainData.none
        XCTAssertNil(value.stringValue); XCTAssertNil(value.imageValue); XCTAssertNil(value.dataValue)
    }
    func testHashedChainDataShowsExactHexWithoutTreatingItAsAnImage() {
        let bytes = Data(repeating: 0xab, count: 32), hash = H256(value: Data(repeating: 0xab, count: 32))
        for value in [ChainData.blakeTwo256(data: hash), .keccak256(data: hash), .sha256(data: hash), .shaThree256(data: hash)] {
            XCTAssertEqual(value.stringValue, "0x" + String(repeating: "ab", count: 32)); XCTAssertEqual(value.dataValue, bytes); XCTAssertNil(value.imageValue)
        }
    }
    @MainActor
    func testRawChainImageRetainsItsPixelDimensions() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let bytes = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 2), format: format).pngData { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        }
        let value = ChainData.raw(data: bytes)
        XCTAssertEqual(try XCTUnwrap(value.imageValue).cgImage?.width, 3)
        XCTAssertEqual(value.imageValue?.cgImage?.height, 2); XCTAssertEqual(value.dataValue, bytes)
    }
    private func ledger() throws -> SoraPassport.StakingLedger {
        // SCALE fixture: stash, compact total=100, active=60, three
        // unlocking chunks (10 at era4, 20 at era5, 30 at era6), rewards7,8.
        let bytes = Data(repeating: 7, count: 32) + Data([0x91, 0x01, 0xf0, 0x0c, 0x28, 0x10, 0x50, 0x14, 0x78, 0x18, 0x08, 7, 0, 0, 0, 8, 0, 0, 0])
        return try SoraPassport.StakingLedger(scaleDecoder: ScaleDecoder(data: bytes))
    }
    func testStakingLedgerDecodesCompactAmountsAndEveryUnlockingEra() throws {
        let value = try ledger()
        XCTAssertEqual(value.stash.value, Data(repeating: 7, count: 32)); XCTAssertEqual(value.total, 100); XCTAssertEqual(value.active, 60)
        XCTAssertEqual(value.unlocking.map(\.value), [10, 20, 30]); XCTAssertEqual(value.unlocking.map(\.era), [4, 5, 6])
        XCTAssertEqual(value.claimedRewards, [7, 8])
    }
    func testStakingMaturityIncludesTheBoundaryEraAndNeverDoubleCountsChunks() throws {
        let value = try ledger()
        for (era, redeemable, waiting): (UInt32, BigUInt, BigUInt) in [(3, 0, 60), (4, 10, 50), (5, 30, 30), (6, 60, 0), (.max, 60, 0)] {
            XCTAssertEqual(value.redeemable(inEra: era), redeemable); XCTAssertEqual(value.unbounding(inEra: era), waiting)
            XCTAssertEqual(value.redeemable(inEra: era) + value.unbounding(inEra: era), 60)
        }
    }
    func testStakingLedgerRejectsATruncatedAccountOrBalance() {
        for bytes in [Data(), Data(repeating: 7, count: 31), Data(repeating: 7, count: 32)] {
            XCTAssertThrowsError(try SoraPassport.StakingLedger(scaleDecoder: ScaleDecoder(data: bytes)))
        }
    }
    func testLegacySigningPayloadKeepsTheCallNonceTipAndChainDomainsInOrder() throws {
        let payload = SoraPassport.ExtrinsicPayload(call: Call(moduleIndex: 4, callIndex: 2, arguments: Data([0xaa, 0xbb])),
            era: .immortal, nonce: 3, tip: 5, specVersion: 0x01020304, transactionVersion: 0x05060708,
            genesisHash: Data(repeating: 0x11, count: 32), blockHash: Data(repeating: 0x22, count: 32))
        let encoder = ScaleEncoder(); try payload.encode(scaleEncoder: encoder)
        let expected = Data([4, 2, 0xaa, 0xbb, 0, 12, 20, 4, 3, 2, 1, 8, 7, 6, 5]) + Data(repeating: 0x11, count: 32) + Data(repeating: 0x22, count: 32)
        XCTAssertEqual(try encoder.encode(), expected)
    }
    func testLegacySigningPayloadOmitsAbsentCallArgumentsAndEncodesMortalEra() throws {
        let payload = SoraPassport.ExtrinsicPayload(call: Call(moduleIndex: 1, callIndex: 2, arguments: nil), era: .mortal(period: 64, phase: 3),
            nonce: 0, tip: 0, specVersion: 1, transactionVersion: 2, genesisHash: Data(repeating: 1, count: 32), blockHash: Data(repeating: 2, count: 32))
        let encoder = ScaleEncoder(); try payload.encode(scaleEncoder: encoder)
        XCTAssertEqual(Data(try encoder.encode().prefix(6)), Data([1, 2, 0x35, 0, 0, 0]))
    }
}

extension LegacyWireModelBoundaryTests {
    func testNetworkRecoveryErrorsNeverRevealAssociatedWalletIdentifiers() throws {
        let identifier = "private-wallet-identifier-do-not-display"
        for error: WalletNetworkMigrationError in [.explicitRemovalTargetMissing(identifier), .legacyIdentityMismatch(identifier)] {
            let message = try XCTUnwrap(error.errorDescription)
            XCTAssertFalse(message.contains(identifier)); XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(UserStorageMigrationError.privacySafeRecoveryDescription(for: error).contains(identifier))
        }
    }
    func testNetworkRecoveryMessagesDistinguishMissingStateAndConflictingState() throws {
        let cases: [(WalletNetworkMigrationError, String)] = [
            (.missingSnapshot, "unavailable"), (.missingSelectedWallet, "selected wallet"),
            (.snapshotVerificationFailed, "did not verify"), (.explicitRemovalInventoryMismatch, "same accounts"),
            (.explicitRemovalSelectionMismatch, "selected wallet changed"), (.lifecycleMutationBusy, "still being committed"),
            (.walletRecoveryRequired, "preserved wallet state")]
        var messages = Set<String>()
        for (error, text) in cases { let message = try XCTUnwrap(error.errorDescription); XCTAssertTrue(message.contains(text), message); messages.insert(message) }
        XCTAssertEqual(messages.count, cases.count)
    }
    func testDerivationErrorsIdentifyTheFailedBoundaryWithoutIncludingKeyMaterial() throws {
        let cases: [(WalletNetworkMigrationError, String)] = [(.invalidMnemonic, "phrase"), (.invalidDerivationPath, "path"),
            (.nonHardenedDerivationComponent, "hardened"), (.invalidDerivationIndex, "index"), (.keyDerivationFailed, "derivation failed"), (.invalidPrivateKey, "private key is invalid")]
        for (error, text) in cases { XCTAssertTrue(try XCTUnwrap(error.errorDescription).contains(text), text) }
    }
    func testDurablePublicationErrorsDistinguishInvalidTargetFromCommitFailure() throws {
        let target = try XCTUnwrap(DurableFileWriter.Failure.invalidTarget.errorDescription)
        let commit = try XCTUnwrap(DurableFileWriter.Failure.fileSystemFailure.errorDescription)
        XCTAssertTrue(target.contains("target is invalid")); XCTAssertTrue(commit.contains("could not be committed")); XCTAssertNotEqual(target, commit)
    }
    func testCloudRestoreIdentityMismatchExplainsThatNoKeysWereChanged() {
        let identifier = "private-backup-identity"
        let message = WalletCloudBackupRecoveryError.userMessage(for: WalletNetworkMigrationError.legacyIdentityMismatch(identifier))
        XCTAssertTrue(message.contains("does not match")); XCTAssertTrue(message.contains("No wallet keys were changed")); XCTAssertFalse(message.contains(identifier))
    }
    func testCloudRestoreStorageFailureExplainsPreservationWithoutEchoingStorePath() {
        let path = "/private/wallets/sensitive.sqlite"
        let message = WalletCloudBackupRecoveryError.userMessage(for: UserStorageMigrationError.unavailableModel(path))
        XCTAssertTrue(message.contains("Existing wallet data was preserved")); XCTAssertFalse(message.contains(path))
    }
    func testCloudRestoreKeychainFailureIncludesStatusAndUnlockAction() {
        let message = WalletCloudBackupRecoveryError.userMessage(for: KeystoreSystemError(status: -25308))
        XCTAssertTrue(message.contains("-25308")); XCTAssertTrue(message.contains("Unlock it and try again"))
    }
    func testUnknownCloudFailureCannotEchoServerCredentialsInUserMessage() {
        let privateText = "private-token-in-server-response"
        let error = NSError(domain: privateText, code: 500, userInfo: [NSLocalizedDescriptionKey: privateText])
        let message = WalletCloudBackupRecoveryError.userMessage(for: error)
        XCTAssertTrue(message.contains("preserved")); XCTAssertFalse(message.contains(privateText))
    }
}
