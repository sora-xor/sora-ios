import CryptoKit
import Foundation
import XCTest
@testable import NexusTransferCodec

final class TransferTests: XCTestCase {
    private let sender = Data(hex: "c050c5637a44fa8629fff3cccce2300cb362a63d99d95fc54145266f4332445a")
    private let recipient = Data(hex: "2012cb90ca60e8e5d8daf66e2272d2233e0486d557e8c66141ed8920177d7eb7")
    private let network = Data(hex: "32c903e5b3497e34c2b844ebfe8a39c19e6cf8f95d44c1ffb8ba9dcb42f91149")

    private func fixturePayload(fees: [NexusTransferCodec.FeeLimit] = []) throws -> Data {
        try NexusTransferCodec.payload(network: network, authorityKey: sender, recipientKey: recipient,
            assetDefinition: "53SSUt68Qn5PdKMMrViDK57X6DG2", amount: "12.34", creationTimeMs: 1_700_000_000_000,
            ttlMs: 30_000, nonce: 7, fees: fees, metadata: ["purpose": "nexus-app-fixture"])
    }

    func testCurrentSDKTransferVector() throws {
        let data = try Data(contentsOf: Bundle.module.url(forResource: "transfer", withExtension: "json")!)
        let fixture = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let expected = fixture["expected"] as! [String: Any]
        let payload = try fixturePayload()
        XCTAssertEqual(payload.hex, expected["payload_bytes_hex"] as? String)
        XCTAssertEqual(NexusTransferCodec.signingMessage(payload).hex, expected["payload_hash_hex"] as? String)
        XCTAssertEqual(NexusTransferCodec.transactionHash(payload).hex, expected["signed_transaction_hash_hex"] as? String)
        let signature = Data(hex: expected["wallet_signature_hex"] as! String)
        let wire = try NexusTransferCodec.envelope(payload: payload, signature: signature, publicKey: sender)
        XCTAssertEqual(wire.first, 1)
        XCTAssertThrowsError(try NexusTransferCodec.envelope(payload: payload + Data([0]), signature: signature, publicKey: sender))
        XCTAssertThrowsError(try NexusTransferCodec.envelope(payload: payload, signature: signature, publicKey: recipient))
    }

    func testAssetChecksumAndCanonicalAmount() throws {
        XCTAssertNotNil(AssetDefinitionAddressCodec.uuidBytes("6TEAJqbb8oEPmLncoNiMRbLEK6tw"))
        XCTAssertNil(AssetDefinitionAddressCodec.uuidBytes("6TEAJqbb8oEPmLncoNiMRbLEK6tx"))
        XCTAssertEqual(try NexusTransferCodec.canonicalQuantity("1.230000000"), "1.23")
        for invalid in ["0", "-1", "01", "1e2", "0.0000000001", "1.", " 1"] {
            XCTAssertThrowsError(try NexusTransferCodec.canonicalQuantity(invalid))
        }
        XCTAssertEqual(try NexusTransferCodec.canonicalQuantity("0", allowZero: true), "0")
    }

    func testFeesAreSignedAndKindsCannotRepeat() throws {
        let fee = NexusTransferCodec.FeeLimit(kind: 0, assetDefinition: "6TEAJqbb8oEPmLncoNiMRbLEK6tw", maximum: "0.01")
        XCTAssertNotEqual(try fixturePayload(), try fixturePayload(fees: [fee]))
        XCTAssertThrowsError(try fixturePayload(fees: [fee, fee]))
        XCTAssertThrowsError(try fixturePayload(fees: [.init(kind: 2, assetDefinition: fee.assetDefinition, maximum: "1")]))
    }
}

private extension Data {
    init(hex: String) { self.init(stride(from: 0, to: hex.count, by: 2).map { i in
        let start = hex.index(hex.startIndex, offsetBy: i)
        return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
    }) }
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
