// SPDX-License-Identifier: Apache-2.0
import Foundation
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
