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
