import CryptoKit
import Foundation
import XCTest
@testable import NexusTransferCodec

final class TairaClientTests: XCTestCase {
    private let authority = "testuﾛ1PﾀR2LBﾃﾋQ8ﾅﾚHｱﾍmtX5Aﾉｽ2ｽヱﾙVｳﾁoJXWpﾄﾖFｸｼ8RC99U"
    private func draft(time: UInt64 = TairaClient.now()) throws -> TairaClient.Draft {
        try .init(authority: authority, authorityHeader: "0x00", authorityKey: Data(repeating: 1, count: 32),
                  recipientKey: Data(repeating: 2, count: 32), amount: "1.25", createdAt: time, nonce: 1)
    }
    private func response(maximum: String? = "0.000000001") -> [String: Any] {
        let components: [[String: Any]] = maximum.map { [["kind": ["kind": "nexus", "value": NSNull()],
            "asset_definition_id": TairaClient.xorDefinition, "max_amount": $0]] } ?? []
        return ["intent": ["payer": "authority", "value": ["charge_limits": components, "gas_limit": NSNull()]],
            "observation": ["ledger_time_ms": 1, "next_block_height": 73, "route_dataspace_id": 0],
            "components": components, "capacities": [],
            "decision": ["status": "accepted", "value": ["debit_source": ["kind": "account", "value": authority], "program_revision": NSNull()]]]
    }
    private func decode(_ value: [String: Any]) throws -> TairaClient.Quote {
        try TairaClient.decodeQuote(JSONSerialization.data(withJSONObject: value), draft: draft(time: 1_700_000_000_000))
    }
    func testQuoteBindsFeesAndRetainsExactPayloadAcrossObservations() throws {
        let first = try decode(response())
        var changed = response(); changed["observation"] = ["ledger_time_ms": 999, "next_block_height": 74, "route_dataspace_id": 0]
        XCTAssertEqual(first.identity, try decode(changed).identity)
        XCTAssertNotEqual(first.identity, try decode(response(maximum: "0.000000002")).identity)
        XCTAssertEqual(first.payload, try draft(time: 1_700_000_000_000).payload(fees: first.fees))
        XCTAssertEqual(try decode(response(maximum: nil)).maxima, [])
        XCTAssertEqual(try decode(response(maximum: "0")).maxima, ["0"])
    }
    func testQuoteRejectsPayerComponentAssetAndPrecisionSubstitution() throws {
        var changed = response(); changed["components"] = []
        XCTAssertThrowsError(try decode(changed))
        changed = response(); changed["decision"] = ["status": "accepted", "value": ["debit_source": ["kind": "account", "value": "different"], "program_revision": NSNull()]]
        XCTAssertThrowsError(try decode(changed))
        for quantity in ["-1", "0.0000000001", "01", "1.00", "1e2"] {
            XCTAssertThrowsError(try decode(response(maximum: quantity)))
        }
        changed = response()
        let wrongAsset: [[String: Any]] = [["kind": ["kind": "nexus", "value": NSNull()],
            "asset_definition_id": "53SSUt68Qn5PdKMMrViDK57X6DG2", "max_amount": "0.01"]]
        changed["components"] = wrongAsset
        changed["intent"] = ["payer": "authority", "value": ["charge_limits": wrongAsset, "gas_limit": NSNull()]]
        XCTAssertThrowsError(try decode(changed))
        changed = response(); changed["extra"] = true
        XCTAssertThrowsError(try decode(changed))
    }
    func testSlowQuoteCannotPublishAnExpiredDraft() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let draft = try TairaClient.Draft(authority: authority, authorityHeader: "0x00",
            authorityKey: key.publicKey.rawRepresentation, recipientKey: Data(repeating: 2, count: 32),
            amount: "1", createdAt: TairaClient.now() - 79_000, nonce: 1)
        let client = TairaClient(transport: { _, _ in
            try await Task.sleep(nanoseconds: 1_100_000_000)
            return Data("{}".utf8)
        })
        do {
            _ = try await client.quote(draft) { try key.signature(for: $0) }
            XCTFail("Expired quote returned")
        } catch TairaClient.Failure.quoteExpired { } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testExpiredDraftCannotBeSignedOrRequoted() throws {
        let value = try draft(time: 1_700_000_000_000)
        XCTAssertNoThrow(try value.requireFresh(now: value.createdAt + 79_999))
        XCTAssertThrowsError(try value.requireFresh(now: value.createdAt + 80_000))
        XCTAssertThrowsError(try value.requireFresh(now: value.createdAt - 5_001))
    }
    func testFreshnessAtBothClockToleranceBoundaries() throws {
        let value = try draft(time: 100_000)
        XCTAssertNoThrow(try value.requireFresh(now: 95_000))
        XCTAssertThrowsError(try value.requireFresh(now: 94_999))
        XCTAssertNoThrow(try value.requireFresh(now: 179_999))
        XCTAssertThrowsError(try value.requireFresh(now: 180_000))
    }

    func testFreshnessHandlesExtremeTimestampsWithoutOverflow() throws {
        let future = try draft(time: UInt64.max)
        XCTAssertThrowsError(try future.requireFresh(now: 0))
        XCTAssertNoThrow(try future.requireFresh(now: UInt64.max))
        XCTAssertNoThrow(try future.requireFresh(now: UInt64.max - 5_000))
        XCTAssertThrowsError(try future.requireFresh(now: UInt64.max - 5_001))
        let previous = try draft(time: UInt64.max - 80_000)
        XCTAssertThrowsError(try previous.requireFresh(now: UInt64.max))
        XCTAssertThrowsError(try draft(time: 1).requireFresh(now: UInt64.max))
    }

    func testQuoteRejectsBadSignaturesBeforeCallingTransport() async throws {
        let client = TairaClient(transport: { _, _ in
            XCTFail("An unauthenticated quote request reached the transport")
            return Data()
        })
        for signature in [Data(), Data(repeating: 0, count: 64)] {
            do {
                _ = try await client.quote(draft()) { _ in signature }
                XCTFail("Invalid signature accepted")
            } catch TairaClient.Failure.invalidResponse { }
        }
    }

    func testQuotePreservesSignerErrorsWithoutSendingARequest() async throws {
        enum SignerFailure: Error { case locked }
        let client = TairaClient(transport: { _, _ in
            XCTFail("A locked signer must not make a quote request")
            return Data()
        })
        do {
            _ = try await client.quote(draft()) { _ in throw SignerFailure.locked }
            XCTFail("Signer failure swallowed")
        } catch SignerFailure.locked { }
    }

    func testQuoteRejectsBooleanNegativeFractionalAndOverflowingObservationIntegers() throws {
        for value in [true, -1, 1.5, "1", NSNull(), NSNumber(value: Double(UInt64.max))] as [Any] {
            var changed = response()
            changed["observation"] = ["ledger_time_ms": value, "next_block_height": 73, "route_dataspace_id": 0]
            XCTAssertThrowsError(try decode(changed), "Accepted \(value)")
        }
        for value in [false, -1, 0, 1.5, "73"] as [Any] {
            var changed = response()
            changed["observation"] = ["ledger_time_ms": 1, "next_block_height": value, "route_dataspace_id": 0]
            XCTAssertThrowsError(try decode(changed), "Accepted \(value)")
        }
    }

    func testQuoteRejectsExtraCapacityAndUnsupportedGasLimit() throws {
        var changed = response(); changed["capacities"] = [["amount": "1"]]
        XCTAssertThrowsError(try decode(changed))
        changed = response()
        var intent = try XCTUnwrap(changed["intent"] as? [String: Any])
        var value = try XCTUnwrap(intent["value"] as? [String: Any])
        value["gas_limit"] = 1
        intent["value"] = value
        changed["intent"] = intent
        XCTAssertThrowsError(try decode(changed))
    }

    func testFeeRequestAuthenticationBindsNetworkBodyTimeAndNonce() throws {
        let body = try draft().quoteBody()
        let first = TairaClient.authMessage(body: body, timestamp: 123, nonce: "nonce1")
        XCTAssertTrue(first.starts(with: Data("iroha.app.request.network.v1\0".utf8) + TairaClient.networkBytes))
        XCTAssertNotEqual(first, TairaClient.authMessage(body: body + Data([32]), timestamp: 123, nonce: "nonce1"))
        XCTAssertNotEqual(first, TairaClient.authMessage(body: body, timestamp: 124, nonce: "nonce1"))
        XCTAssertNotEqual(first, TairaClient.authMessage(body: body, timestamp: 123, nonce: "nonce2"))
        let root = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        let payload = root["payload"] as! [String: Any]
        XCTAssertNil(payload["chain"])
        XCTAssertEqual((payload["domain"] as? [String: String])?["value"], TairaClient.networkLiteral)
    }
    func testCheckpointUsesFreshChallengeNetworkAndAppliedHeight() async throws {
        let client = TairaClient(transport: { request, _ in
            if request.url!.path.contains("attestation") {
                return try JSONSerialization.data(withJSONObject: ["body": [
                    "challenge": request.value(forHTTPHeaderField: "X-Iroha-Finality-Challenge")!.uppercased(),
                    "network_id": TairaClient.networkLiteral, "genesis_block_hash": TairaClient.networkLiteral,
                    "observed_at_unix_ms": TairaClient.now(), "status": ["applied_height": 72, "committed_height": 73]]])
            }
            XCTAssertEqual(request.url!.path, "/v1/explorer/blocks/72")
            return try JSONSerialization.data(withJSONObject: ["height": 72, "hash": "hash:09FCDDC1EB8103B2CB29779CDD466E0E098124CB180EA02A1EF30726191F2B71#D98F"])
        })
        let checkpoint = try await client.checkpoint()
        XCTAssertEqual(checkpoint.height, 72)
        XCTAssertEqual(checkpoint.hash, "09fcddc1eb8103b2cb29779cdd466e0e098124cb180ea02a1ef30726191f2b71")
        let wrong = TairaClient(transport: { _, _ in Data("{\"body\":{\"network_id\":\"wrong\"}}".utf8) })
        do { _ = try await wrong.checkpoint(); XCTFail("wrong network accepted") } catch { }
    }
}
