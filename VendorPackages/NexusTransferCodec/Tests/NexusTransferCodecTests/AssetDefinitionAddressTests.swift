import Foundation
import XCTest
@testable import NexusTransferCodec

final class AssetDefinitionAddressTests: XCTestCase {
    func testPublishedAssetLiteralsRoundTripWithoutChangingTheirIdentity() throws {
        for literal in ["53SSUt68Qn5PdKMMrViDK57X6DG2", "6TEAJqbb8oEPmLncoNiMRbLEK6tw"] {
            let bytes = try XCTUnwrap(AssetDefinitionAddressCodec.uuidBytes(literal))
            XCTAssertEqual(bytes.count, 16)
            XCTAssertEqual(AssetDefinitionAddressCodec.definitionLiteral(uuidBytes: bytes), literal)
            XCTAssertEqual(AssetDefinitionAddressCodec.canonicalDefinitionLiteral(literal), literal)
        }
    }

    func testPublicBoundaryTrimsSurroundingWhitespaceButRejectsWhitespaceWithinAnAddress() {
        let literal = "53SSUt68Qn5PdKMMrViDK57X6DG2"
        XCTAssertEqual(AssetDefinitionAddressCodec.canonicalDefinitionLiteral(" \n\t" + literal + "\r\n"), literal)
        XCTAssertEqual(AssetDefinitionAddressCodec.uuidBytes(" " + literal + " "), AssetDefinitionAddressCodec.uuidBytes(literal))
        for raw in [nil, "", " \n", "53SS Ut68Qn5PdKMMrViDK57X6DG2", "53SS\nUt68Qn5PdKMMrViDK57X6DG2"] as [String?] {
            XCTAssertNil(AssetDefinitionAddressCodec.canonicalDefinitionLiteral(raw))
            XCTAssertNil(AssetDefinitionAddressCodec.uuidBytes(raw))
        }
    }

    func testInternalDecoderRequiresCanonicalSpellingAndChecksTheChecksum() {
        let literal = "53SSUt68Qn5PdKMMrViDK57X6DG2"
        for invalid in [" " + literal, literal + " ", literal + "#account", literal + "@domain",
                        literal + "$asset", literal + ":alias", "0", "O", "I", "l", "日本語", "1", "1111",
                        "53SSUt68Qn5PdKMMrViDK57X6DG3", "1" + literal] {
            XCTAssertNil(AssetDefinitionAddress.decode(invalid), invalid)
        }
    }

    func testEncoderRejectsInvalidUUIDLengthsVersionsAndVariants() throws {
        let bytes = try XCTUnwrap(AssetDefinitionAddressCodec.uuidBytes("53SSUt68Qn5PdKMMrViDK57X6DG2"))
        for count in [0, 1, 15, 17, 32] {
            XCTAssertNil(AssetDefinitionAddressCodec.definitionLiteral(uuidBytes: Data(repeating: 0, count: count)))
        }
        for version: UInt8 in [0, 1, 3, 5, 7, 15] {
            var invalid = bytes; invalid[6] = (invalid[6] & 15) | (version << 4)
            XCTAssertNil(AssetDefinitionAddressCodec.definitionLiteral(uuidBytes: invalid))
        }
        for variant: UInt8 in [0, 0x40, 0xc0] {
            var invalid = bytes; invalid[8] = (invalid[8] & 0x3f) | variant
            XCTAssertNil(AssetDefinitionAddressCodec.definitionLiteral(uuidBytes: invalid))
        }
    }

    func testDistinctValidUUIDsRemainDistinctThroughBase58CarryBoundaries() throws {
        var literals = Set<String>()
        for fill: UInt8 in [0, 1, 57, 58, 127, 128, 254, 255] {
            var bytes = Data(repeating: fill, count: 16)
            bytes[6] = (bytes[6] & 15) | 0x40; bytes[8] = (bytes[8] & 0x3f) | 0x80
            let literal = try XCTUnwrap(AssetDefinitionAddressCodec.definitionLiteral(uuidBytes: bytes))
            XCTAssertEqual(AssetDefinitionAddressCodec.uuidBytes(literal), bytes)
            XCTAssertTrue(literals.insert(literal).inserted)
        }
    }
}
