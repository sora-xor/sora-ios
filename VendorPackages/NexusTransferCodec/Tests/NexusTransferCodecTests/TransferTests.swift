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

    func testCanonicalQuantityRejectsTrailingLineTerminatorsAndEmbeddedWhitespace() {
        for invalid in ["1\n", "1\r", "1\r\n", "1\u{0085}", "1\u{2028}", "1\u{2029}",
                        "1\t", "1 ", "1\n2", "1\0", "١", "１", "+1", "NaN"] {
            XCTAssertThrowsError(try NexusTransferCodec.canonicalQuantity(invalid), "Accepted \(invalid.debugDescription)")
            XCTAssertThrowsError(try NexusTransferCodec.canonicalQuantity(invalid, allowZero: true),
                                 "Fee amount accepted \(invalid.debugDescription)")
        }
    }

    func testQuantityCanonicalizationPreservesSmallestUnitAndRejectsZeroTransfers() throws {
        XCTAssertEqual(try NexusTransferCodec.canonicalQuantity("0.000000001"), "0.000000001")
        XCTAssertEqual(try NexusTransferCodec.canonicalQuantity("100.000000000"), "100")
        XCTAssertEqual(try NexusTransferCodec.canonicalQuantity("0.000000000", allowZero: true), "0")
        XCTAssertThrowsError(try NexusTransferCodec.canonicalQuantity("0.000000000"))
        XCTAssertThrowsError(try NexusTransferCodec.canonicalQuantity(String(repeating: "9", count: 165)))
        XCTAssertEqual(try NexusTransferCodec.quantity("1.230000000", allowZero: false),
                       try NexusTransferCodec.quantity("1.23", allowZero: false))
    }

    func testQuantityEncodingUsesMinimalPositiveSignedMagnitude() throws {
        // Each magnitude is framed as a four-byte byte count plus little-endian signed bytes,
        // followed by the four-byte decimal scale. 128 needs an extra zero sign byte.
        XCTAssertEqual(try NexusTransferCodec.quantity("127", allowZero: false),
                       Data([5, 1, 0, 0, 0, 127, 4, 0, 0, 0, 0]))
        XCTAssertEqual(try NexusTransferCodec.quantity("128", allowZero: false),
                       Data([6, 2, 0, 0, 0, 128, 0, 4, 0, 0, 0, 0]))
        XCTAssertEqual(try NexusTransferCodec.quantity("0.000000001", allowZero: false),
                       Data([5, 1, 0, 0, 0, 1, 4, 9, 0, 0, 0]))
        XCTAssertEqual(try NexusTransferCodec.quantity("0", allowZero: true),
                       Data([5, 1, 0, 0, 0, 0, 4, 0, 0, 0, 0]))
    }

    func testQuantityEncodingHonorsSigned512BitBoundary() throws {
        let largest = "6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042047"
        let overflow = "6703903964971298549787012499102923063739682910296196688861780721860882015036773488400937149083451713845015929093243025426876941405973284973216824503042048"
        let expected = Data([68, 64, 0, 0, 0]) + Data(repeating: 255, count: 63)
            + Data([127, 4, 0, 0, 0, 0])
        XCTAssertEqual(try NexusTransferCodec.quantity(largest, allowZero: false), expected)
        XCTAssertThrowsError(try NexusTransferCodec.quantity(overflow, allowZero: false))
        XCTAssertThrowsError(try NexusTransferCodec.quantity(String(repeating: "9", count: 164), allowZero: false))
    }

    func testPayloadRejectsInvalidLifetimeAndOverflow() throws {
        for (creation, ttl, nonce) in [(UInt64(0), UInt64(1), UInt32?.none),
                                      (1, 0, nil), (1, 100_001, nil), (1, 1, 0),
                                      (UInt64.max, 1, nil), (UInt64.max - 99_999, 100_000, nil)] {
            XCTAssertThrowsError(try payload(creation: creation, ttl: ttl, nonce: nonce))
        }
        XCTAssertNoThrow(try payload(creation: 1, ttl: 1, nonce: nil))
        XCTAssertNoThrow(try payload(creation: UInt64.max - 100_000, ttl: 100_000, nonce: UInt32.max))
    }

    func testPayloadRejectsInvalidNetworkAndAccountKeys() throws {
        for invalid in [Data(), Data(repeating: 1, count: 31), Data(repeating: 1, count: 33),
                        Data(repeating: 2, count: 32)] {
            XCTAssertThrowsError(try payload(network: invalid))
        }
        for invalid in [Data(), Data(repeating: 1, count: 31), Data(repeating: 1, count: 33),
                        Data(repeating: 0, count: 32)] {
            XCTAssertThrowsError(try payload(sender: invalid))
            XCTAssertThrowsError(try payload(recipient: invalid))
        }
    }

    func testMetadataIsDeterministicAndInvalidNamesAreRejected() throws {
        var left: [String: String] = [:]
        left["z"] = "last"; left["a"] = "first"
        var right: [String: String] = [:]
        right["a"] = "first"; right["z"] = "last"
        XCTAssertEqual(try payload(metadata: left), try payload(metadata: right))
        XCTAssertNotEqual(try payload(metadata: left), try payload(metadata: ["z": "changed", "a": "first"]))
        XCTAssertNoThrow(try payload(metadata: [String(repeating: "a", count: 255): ""]))
        for name in ["", " ", "a b", "a#b", "a$b", "a@b", "a\n", "日本語", String(repeating: "a", count: 256)] {
            XCTAssertThrowsError(try payload(metadata: [name: "value"]), "Accepted \(name.debugDescription)")
        }
    }

    func testFeeOrderingAndInvalidAssetsAreRejected() throws {
        let asset = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"
        let nexus = NexusTransferCodec.FeeLimit(kind: 0, assetDefinition: asset, maximum: "0")
        let gas = NexusTransferCodec.FeeLimit(kind: 1, assetDefinition: asset, maximum: "1")
        XCTAssertNoThrow(try fixturePayload(fees: [nexus, gas]))
        XCTAssertThrowsError(try fixturePayload(fees: [gas, nexus]))
        XCTAssertThrowsError(try fixturePayload(fees: [.init(kind: 0, assetDefinition: asset, maximum: "-1")]))
        XCTAssertThrowsError(try fixturePayload(fees: [.init(kind: 0, assetDefinition: asset + "x", maximum: "1")]))
        XCTAssertThrowsError(try NexusTransferCodec.transferFrame(authorityKey: sender, recipientKey: recipient,
                                                                 assetDefinition: asset + "x", amount: "1"))
    }

    private func payload(network: Data? = nil, sender: Data? = nil, recipient: Data? = nil,
                         creation: UInt64 = 1_700_000_000_000, ttl: UInt64 = 30_000,
                         nonce: UInt32? = 7, metadata: [String: String] = [:]) throws -> Data {
        try NexusTransferCodec.payload(network: network ?? self.network, authorityKey: sender ?? self.sender,
                                       recipientKey: recipient ?? self.recipient,
                                       assetDefinition: "53SSUt68Qn5PdKMMrViDK57X6DG2", amount: "12.34",
                                       creationTimeMs: creation, ttlMs: ttl, nonce: nonce, metadata: metadata)
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
