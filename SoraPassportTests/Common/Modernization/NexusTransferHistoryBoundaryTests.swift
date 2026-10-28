import Foundation
import XCTest
@testable import SoraPassport

final class NexusTransferHistoryBoundaryTests: XCTestCase {
    private let account = "testuﾛ1NｼXCeｱﾈﾁRｴUﾀPWﾏVｱrﾋhESEbpﾂｾ9Vﾗ5ﾇJｵavsｷ26TMSNN"
    private let receiver = "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
    private let asset = NexusAssetDefinitionIdentity.tairaXorDefinitionID
    private let transactionHash = String(repeating: "a", count: 64)
    private var configuration: NexusNetworkConfiguration { NexusNetworkConfiguration.taira! }
    private func json(_ value: Any) throws -> NexusJSONValue {
        try JSONDecoder().decode(NexusJSONValue.self, from: JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]))
    }
    private func transfer(_ changes: [String: Any] = [:]) -> [String: Any] {
        ["source": "\(asset)#\(account)", "destination": receiver, "object": "1.25"].merging(changes) { _, new in new }
    }
    private func instruction(_ value: [String: Any]? = nil, variant: String = "Asset", changes: [String: Any] = [:]) -> [String: Any] {
        ["transaction_status": "Committed", "kind": "Transfer", "transaction_hash": transactionHash,
         "created_at": "2026-04-04T00:00:00Z", "block": 42, "authority": account, "index": 0,
         "box": ["json": ["kind": "Transfer", "payload": ["variant": variant, "value": value ?? transfer()]]]]
            .merging(changes) { _, new in new }
    }
    private func page(_ rows: [Any], pagination: [String: Any] = [:]) throws -> NexusTairaTransferHistoryPage {
        try NexusTairaTransferHistoryParser.page(result: json(["body": ["items": rows, "pagination":
            ["page": 1, "per_page": 100, "total_pages": 1, "total_items": rows.count].merging(pagination) { _, new in new }]]),
            configuration: configuration, account: account, assetDefinitionID: asset)
    }
    func testInstructionProjectionPreservesTransferIdentityAndTimestamp() throws {
        let result = try page([instruction()])
        XCTAssertEqual(result.sourceItemIDs, ["\(transactionHash):0"])
        XCTAssertEqual(result.sourceItemCount, 1)
        XCTAssertEqual(result.items.first?.transactionHash, transactionHash)
        XCTAssertEqual(result.items.first?.sender, account)
        XCTAssertEqual(result.items.first?.receiver, receiver)
        XCTAssertEqual(result.items.first?.amount.rawValue, "1.25")
        XCTAssertEqual(result.items.first?.timestampMilliseconds, 1_775_260_800_000)
    }
    func testBatchSupportsDocumentedEntryNamesAndFiltersOtherAssets() throws {
        for key in ["entries", "transfers", "items"] {
            let outgoing = transfer(["asset_definition": asset])
            let incoming = transfer(["asset_definition": asset, "source": "\(asset)#\(receiver)", "destination": account, "object": "2.5"])
            let irrelevant = transfer(["asset_definition": "other"])
            let result = try page([instruction([key: [outgoing, irrelevant, incoming]], variant: "AssetBatch")])
            XCTAssertEqual(result.items.map(\.amount.rawValue), ["1.25", "2.5"])
            XCTAssertEqual(result.items.map(\.sender), [account, receiver])
            XCTAssertEqual(result.items.map(\.receiver), [receiver, account])
            XCTAssertEqual(result.sourceItemIDs, ["\(transactionHash):0"])
        }
    }
    func testBatchRejectsMissingEntriesNonObjectsAndNoMatchingTransfers() {
        for value: [String: Any] in [[:], ["entries": [1]], ["entries": []], ["entries": [transfer(["asset_definition": "other"])]]] {
            XCTAssertThrowsError(try page([instruction(value, variant: "AssetBatch")]))
        }
    }
    func testBatchAcceptsDocumentedDefinitionAliases() throws {
        for key in ["asset_definition", "assetDefinition", "asset_definition_id"] {
            XCTAssertEqual(try page([instruction(["entries": [transfer([key: asset])]], variant: "AssetBatch")]).items.count, 1)
        }
    }
    func testDecimalObjectSupportsMantissaNamesAndScaleBoundaries() throws {
        for key in ["value", "amount", "mantissa"] {
            for (scale, mantissa, expected) in [(0, "123", "123"), (2, "123", "1.23"), (3, "123", "0.123"), (9, "1", "0.000000001")] {
                let result = try page([instruction(transfer(["object": ["scale": scale, key: mantissa]]))])
                XCTAssertEqual(result.items.first?.amount.rawValue, expected)
            }
        }
        XCTAssertEqual(try page([instruction(transfer(["object": ["scale": "2", "value": "123"]]))]).items.first?.amount.rawValue, "1.23")
    }
    func testDecimalObjectRejectsInvalidScalesMantissasAndZero() {
        for object: Any in [["scale": -1, "value": "1"], ["scale": 10, "value": "1"], ["scale": "x", "value": "1"],
                            ["scale": 1, "value": "-1"], ["scale": 1, "value": "a"], ["scale": 1, "value": 123],
                            ["scale": 1], ["value": "123"], ["scale": 0, "value": "0"], false, NSNull(), 3] {
            XCTAssertThrowsError(try page([instruction(transfer(["object": object]))]))
        }
    }
    func testAmountRejectsOverlongAndInexactWireStrings() {
        for value in ["0", "-1", "1e2", "1\n", " 1", "0.0000000001", String(repeating: "9", count: 9000)] {
            XCTAssertThrowsError(try page([instruction(transfer(["object": value]))]), value)
        }
    }
    func testTimestampSupportsSecondsMillisecondsAndFractionalISO8601() throws {
        for (timestamp, expected): (String, Int64) in [("1775260800", 1_775_260_800_000), ("1775260800000", 1_775_260_800_000),
                                                      ("2026-04-04T00:00:00.125Z", 1_775_260_800_125)] {
            XCTAssertEqual(try page([instruction(changes: ["created_at": timestamp])]).items.first?.timestampMilliseconds, expected)
        }
    }
    func testTimestampRejectsMissingMalformedZeroAndOversizedValues() {
        for value: Any in [NSNull(), "", "0", "-1", "not-a-date", String(repeating: "9", count: 65), "18446744073709551615", 1_775_260_800] {
            XCTAssertThrowsError(try page([instruction(changes: ["created_at": value])]))
        }
    }
    func testExplicitSourceMustAgreeWithTheEmbeddedAccount() throws {
        XCTAssertEqual(try page([instruction(transfer(["source_account": account]))]).items.first?.sender, account)
        XCTAssertThrowsError(try page([instruction(transfer(["source_account": receiver]))]))
    }
    func testDefinitionOnlySourceRequiresExplicitAccountForIncomingTransfers() throws {
        for key in ["source_account", "from", "account"] {
            let result = try page([instruction(transfer(["source": asset, key: receiver, "destination": account]))])
            XCTAssertEqual(result.items.first?.sender, receiver)
        }
        XCTAssertThrowsError(try page([instruction(transfer(["source": asset, "destination": account]))]))
    }
    func testEmbeddedSourceRejectsMissingAccountAndMultipleSeparators() {
        for source in [asset + "#", asset + "#" + account + "#extra", asset + "#invalid"] {
            XCTAssertThrowsError(try page([instruction(transfer(["source": source]))]))
        }
    }
    func testSourceAndDestinationAliasesKeepTheSameTransfer() throws {
        for sourceKey in ["source_id", "asset", "asset_id", "asset_definition", "assetDefinition", "asset_definition_id"] {
            var row = transfer(); let source = row.removeValue(forKey: "source"); row[sourceKey] = source
            XCTAssertEqual(try page([instruction(row)]).items.first?.sender, account)
        }
        for destinationKey in ["destination_id", "to", "account_id"] {
            var row = transfer(); let destination = row.removeValue(forKey: "destination"); row[destinationKey] = destination
            XCTAssertEqual(try page([instruction(row)]).items.first?.receiver, receiver)
        }
        for amountKey in ["amount", "quantity", "value"] {
            var row = transfer(); let amount = row.removeValue(forKey: "object"); row[amountKey] = amount
            XCTAssertEqual(try page([instruction(row)]).items.first?.amount.rawValue, "1.25")
        }
    }
    func testUnrelatedAssetOrAccountCannotBecomeWalletHistory() {
        XCTAssertThrowsError(try page([instruction(transfer(["source": "different#" + account]))]))
        XCTAssertThrowsError(try page([instruction(transfer(["source": "\(asset)#\(receiver)"]))]))
    }
    func testRequiredInstructionWitnessesCannotBeOmittedOrChanged() {
        for changes: [String: Any] in [["transaction_status": "Rejected"], ["transaction_status": " Committed"], ["kind": "Mint"],
                                      ["transaction_hash": "0x" + transactionHash], ["transaction_hash": transactionHash.uppercased()], ["block": 0],
                                      ["block": "42"], ["authority": "invalid"], ["index": -1], ["index": UInt64(UInt32.max) + 1],
                                      ["box": [:]], ["box": ["json": ["kind": "Mint"]]]] {
            XCTAssertThrowsError(try page([instruction(changes: changes)]))
        }
        XCTAssertThrowsError(try page([instruction(variant: "Unknown")]))
    }
    func testPaginationRequiresExactUnsignedNumericWitnesses() {
        for key in ["page", "per_page", "total_pages", "total_items"] {
            for value: Any in ["1", -1, 1.5, NSNull(), true] { XCTAssertThrowsError(try page([instruction()], pagination: [key: value])) }
        }
        XCTAssertThrowsError(try page([instruction()], pagination: ["per_page": 0]))
        XCTAssertThrowsError(try page([instruction()], pagination: ["total_items": 0]))
    }
    func testDuplicateInstructionIdentityIsRejectedButDistinctIndicesAreRetained() throws {
        XCTAssertThrowsError(try page([instruction(), instruction()]))
        let result = try page([instruction(), instruction(changes: ["index": 1])])
        XCTAssertEqual(result.sourceItemIDs, ["\(transactionHash):0", "\(transactionHash):1"])
    }
    func testNonObjectInstructionIsRejected() { XCTAssertThrowsError(try page(["invalid"])) }
    func testEmptyHistoryPreservesAuthoritativeCounts() throws {
        let result = try page([], pagination: ["total_pages": 0])
        XCTAssertTrue(result.items.isEmpty); XCTAssertEqual(result.totalItems, 0); XCTAssertEqual(result.sourceItemCount, 0)
    }
}
