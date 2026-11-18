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

// Historical page-number responses remain fixtures for interoperability tests.
// The wallet now requests cursor-based history.
struct NexusTairaTransferHistoryPage {
    let items: [NexusTransferHistoryItem]
    let sourceItemCount: Int
    let sourceItemIDs: [String]
    let page: UInt64
    let perPage: UInt64
    let totalPages: UInt64
    let totalItems: UInt64



    func validate(expectedPage: Int, maximumPageSize: Int) throws {
        guard
            expectedPage > 0,
            maximumPageSize > 0,
            page == UInt64(expectedPage),
            perPage == UInt64(maximumPageSize),
            sourceItemIDs.count == sourceItemCount,
            Set(sourceItemIDs).count == sourceItemIDs.count,
            (totalPages == 0) == (totalItems == 0),
            page <= max(totalPages, 1),
            totalPages == totalItems.dividedRoundingUp(by: perPage)
        else {
            throw NexusToriiError.invalidResponse
        }
        let (precedingItemCount, overflow) = (page - 1)
            .multipliedReportingOverflow(by: perPage)
        guard !overflow, precedingItemCount <= totalItems else {
            throw NexusToriiError.invalidResponse
        }
        let expectedItemCount = min(
            perPage,
            totalItems - precedingItemCount
        )
        guard
            let canonicalSourceItemCount = UInt64(exactly: sourceItemCount),
            canonicalSourceItemCount == expectedItemCount
        else {
            throw NexusToriiError.invalidResponse
        }
    }
}

private extension UInt64 {
    func dividedRoundingUp(by divisor: UInt64) -> UInt64 {
        guard self > 0 else { return 0 }
        return 1 + (self - 1) / divisor
    }
}

/// Decoder for the historical page-number `iroha.instructions.list` projection.
enum NexusTairaTransferHistoryParser {
    static func page(
        result: NexusJSONValue,
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> NexusTairaTransferHistoryPage {
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        guard
            let structured = result.objectValue,
            let body = structured["body"]?.objectValue,
            let sourceItems = body["items"]?.arrayValue,
            let pagination = body["pagination"]?.objectValue,
            let page = canonicalUInt64(pagination["page"]),
            let perPage = canonicalUInt64(pagination["per_page"]),
            perPage > 0,
            let totalPages = canonicalUInt64(pagination["total_pages"]),
            let totalItems = canonicalUInt64(pagination["total_items"]),
            UInt64(sourceItems.count) <= totalItems
        else {
            throw NexusToriiError.invalidResponse
        }

        var items: [NexusTransferHistoryItem] = []
        var sourceItemIDs: [String] = []
        for value in sourceItems {
            guard let instruction = value.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            let parsed = try parseInstruction(
                instruction,
                configuration: configuration,
                account: canonicalAccount,
                assetDefinitionID: assetDefinitionID
            )
            guard
                let rawHash = instruction["transaction_hash"]?
                    .exactWireStringValue,
                let hash = NexusTransactionHash.normalized(rawHash),
                hash == rawHash,
                let index = canonicalUInt64(instruction["index"]),
                index <= UInt64(UInt32.max)
            else {
                throw NexusToriiError.invalidResponse
            }
            sourceItemIDs.append("\(hash):\(index)")
            items.append(contentsOf: parsed)
        }
        guard Set(sourceItemIDs).count == sourceItemIDs.count else {
            throw NexusToriiError.invalidResponse
        }
        return NexusTairaTransferHistoryPage(
            items: items,
            sourceItemCount: sourceItems.count,
            sourceItemIDs: sourceItemIDs,
            page: page,
            perPage: perPage,
            totalPages: totalPages,
            totalItems: totalItems
        )
    }

    private static func parseInstruction(
        _ instruction: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> [NexusTransferHistoryItem] {
        guard
            let status = exactString(
                instruction["transaction_status"],
                maximumBytes: 32
            ),
            status.lowercased() == "committed",
            let kind = exactString(instruction["kind"], maximumBytes: 64),
            let rawHash = exactString(
                instruction["transaction_hash"],
                maximumBytes: 64
            ),
            let hash = NexusTransactionHash.normalized(rawHash),
            hash == rawHash,
            let timestamp = parseTimestamp(
                instruction["created_at"]?.exactWireStringValue
            ),
            timestamp > 0,
            let block = canonicalUInt64(instruction["block"]),
            block > 0,
            let authority = instruction["authority"]?.exactWireStringValue,
            (try? IrohaAddressCodec.parse(
                authority,
                expectedDiscriminant: configuration.i105Discriminant
            )) != nil
        else {
            throw NexusToriiError.invalidResponse
        }
        guard kind == "Transfer" else {
            throw NexusToriiError.invalidResponse
        }
        guard
            let box = instruction["box"]?.objectValue,
            let json = box["json"]?.objectValue,
            json["kind"]?.exactWireStringValue == "Transfer",
            let payload = json["payload"]?.objectValue,
            let variant = payload["variant"]?.exactWireStringValue
        else {
            throw NexusToriiError.invalidResponse
        }

        let transfers: [ParsedTransfer]
        switch variant {
        case "Asset":
            guard let value = payload["value"]?.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            transfers = try parseTransfer(
                value,
                configuration: configuration,
                account: account,
                assetDefinitionID: assetDefinitionID
            ).map { [$0] } ?? []
        case "AssetBatch":
            guard let value = payload["value"]?.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            let entries = ["entries", "transfers", "items"].lazy
                .compactMap { value[$0]?.arrayValue }
                .first
            guard let entries else {
                throw NexusToriiError.invalidResponse
            }
            transfers = try entries.compactMap { entry in
                guard let object = entry.objectValue else {
                    throw NexusToriiError.invalidResponse
                }
                guard
                    firstExactString(
                        in: object,
                        keys: [
                            "asset_definition", "assetDefinition",
                            "asset_definition_id",
                        ]
                    ) == assetDefinitionID
                else {
                    return nil
                }
                return try parseTransfer(
                    object,
                    configuration: configuration,
                    account: account,
                    assetDefinitionID: assetDefinitionID
                )
            }
        default:
            throw NexusToriiError.invalidResponse
        }
        guard !transfers.isEmpty else {
            throw NexusToriiError.invalidResponse
        }
        return transfers.map {
            NexusTransferHistoryItem(
                transactionHash: hash,
                timestampMilliseconds: timestamp,
                amount: $0.amount,
                sender: $0.sender,
                receiver: $0.receiver
            )
        }
    }

    private struct ParsedTransfer {
        let amount: PIQuantity
        let sender: String
        let receiver: String
    }

    private static func parseTransfer(
        _ value: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> ParsedTransfer? {
        let source = firstExactString(
            in: value,
            keys: [
                "source", "source_id", "asset", "asset_id",
                "asset_definition", "assetDefinition",
                "asset_definition_id",
            ]
        )
        let embeddedSourceAccount: String?
        if source == nil || source == assetDefinitionID {
            embeddedSourceAccount = nil
        } else if let source,
                  source.hasPrefix("\(assetDefinitionID)#")
        {
            let suffix = String(source.dropFirst(assetDefinitionID.count + 1))
            guard !suffix.isEmpty, !suffix.contains("#") else {
                throw NexusToriiError.invalidResponse
            }
            embeddedSourceAccount = suffix
        } else {
            return nil
        }
        guard
            let destination = firstExactString(
                in: value,
                keys: [
                    "destination", "destination_id", "to", "account_id",
                ]
            ),
            let rawAmount = ["object", "amount", "quantity", "value"].lazy
                .compactMap({ value[$0] }).first
        else {
            throw NexusToriiError.invalidResponse
        }
        let explicitSource = firstExactString(
            in: value,
            keys: ["source_account", "from", "account"]
        )
        let canonicalDestination = try IrohaAddressCodec.parse(
            destination,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        let canonicalExplicitSource = try explicitSource.map {
            try IrohaAddressCodec.parse(
                $0,
                expectedDiscriminant: configuration.i105Discriminant
            ).i105
        }
        let canonicalEmbeddedSource = try embeddedSourceAccount.map {
            try IrohaAddressCodec.parse(
                $0,
                expectedDiscriminant: configuration.i105Discriminant
            ).i105
        }
        if let canonicalExplicitSource, let canonicalEmbeddedSource,
           canonicalExplicitSource != canonicalEmbeddedSource
        {
            throw NexusToriiError.invalidResponse
        }
        let canonicalSource = canonicalExplicitSource ?? canonicalEmbeddedSource
        let incoming = canonicalDestination == account
        let outgoing = canonicalSource == account
        guard incoming || outgoing else {
            return nil
        }
        let amount = try parseAmount(
            rawAmount,
            maximumScale: NexusAmountPolicy.maximumScale(
                for: configuration.networkId
            )
        )
        guard let sender = outgoing ? account : canonicalSource else {
            throw NexusToriiError.invalidResponse
        }
        return ParsedTransfer(
            amount: amount,
            sender: sender,
            receiver: incoming ? account : canonicalDestination
        )
    }

    private static func parseAmount(
        _ value: NexusJSONValue,
        maximumScale: Int
    ) throws -> PIQuantity {
        let raw: String?
        if let string = value.exactWireStringValue {
            raw = string
        } else if let object = value.objectValue {
            let scaleText = object["scale"]?.exactWireStringValue ??
                canonicalUInt64(object["scale"]).map(String.init)
            let mantissa = ["value", "amount", "mantissa"].lazy
                .compactMap { object[$0]?.exactWireStringValue }.first
            if
                let scaleText,
                let scale = Int(scaleText),
                (0 ... maximumScale).contains(scale),
                let mantissa,
                mantissa.range(
                    of: #"^[0-9]+$"#,
                    options: .regularExpression
                ) != nil
            {
                raw = decimalString(mantissa: mantissa, scale: scale)
            } else {
                raw = nil
            }
        } else {
            raw = nil
        }
        guard
            let raw,
            raw.utf8.count <= PIQuantity.maximumWireBytes,
            let exact = NexusExactDecimal(raw),
            exact.unscaled > 0,
            exact.scale <= maximumScale
        else {
            throw NexusToriiError.invalidResponse
        }
        return try PIQuantity(raw)
    }

    private static func decimalString(
        mantissa: String,
        scale: Int
    ) -> String {
        guard scale > 0 else { return mantissa }
        if mantissa.count <= scale {
            return "0." + String(repeating: "0", count: scale - mantissa.count) +
                mantissa
        }
        let split = mantissa.index(mantissa.endIndex, offsetBy: -scale)
        return "\(mantissa[..<split]).\(mantissa[split...])"
    }

    private static func parseTimestamp(_ value: String?) -> Int64? {
        guard let value, !value.isEmpty, value.utf8.count <= 64 else {
            return nil
        }
        if value.unicodeScalars.allSatisfy({ (48 ... 57).contains($0.value) }),
           let integer = Int64(value)
        {
            guard integer < 10_000_000_000 else {
                return integer
            }
            let multiplied = integer.multipliedReportingOverflow(by: 1_000)
            return multiplied.overflow ? nil : multiplied.partialValue
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: value) ?? plain.date(from: value)
        else {
            return nil
        }
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds > 0,
              milliseconds <= Double(Int64.max)
        else {
            return nil
        }
        return Int64(milliseconds.rounded())
    }

    private static func firstExactString(
        in object: [String: NexusJSONValue],
        keys: [String]
    ) -> String? {
        keys.lazy.compactMap {
            exactString(object[$0], maximumBytes: 8_192)
        }.first
    }

    private static func exactString(
        _ value: NexusJSONValue?,
        maximumBytes: Int
    ) -> String? {
        guard
            let string = value?.exactWireStringValue,
            !string.isEmpty,
            string == string.trimmingCharacters(in: .whitespacesAndNewlines),
            string.utf8.count <= maximumBytes
        else {
            return nil
        }
        return string
    }

    private static func canonicalUInt64(
        _ value: NexusJSONValue?
    ) -> UInt64? {
        guard let value, case let .number(raw) = value else {
            return nil
        }
        guard
            raw == "0" || raw.range(
                of: #"^[1-9][0-9]{0,19}$"#,
                options: .regularExpression
            ) != nil
        else {
            return nil
        }
        return UInt64(raw)
    }
}
