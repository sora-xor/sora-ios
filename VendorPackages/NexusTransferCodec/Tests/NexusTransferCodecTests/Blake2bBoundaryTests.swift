import Foundation
import XCTest
@testable import NexusTransferCodec

final class Blake2bBoundaryTests: XCTestCase {
    private func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

    // Independent known answers generated with Python hashlib.blake2b. Input
    // byte i is i modulo 256; cases straddle the 128-byte compression boundary.
    func testKnownAnswersAcrossCompressionBlockBoundaries() {
        let vectors: [(Int, String, String)] = [
            (0, "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8", "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce"),
            (1, "03170a2e7597b7b7e3d84c05391d139a62b157e78786d8c082f29dcf4c111314", "2fa3f686df876995167e7c2e5d74c4c7b6e48f8068fe0e44208344d480f7904c36963e44115fe3eb2a3ac8694c28bcb4f5a0f3276f2e79487d8219057a506e4b"),
            (127, "f2fe67ff342e21b8f45e8f2e0bcd1d9243245d50ee6c78042e9c491388791c72", "b6292669ccd38d5f01caae96ba272c76a879a45743afa0725d83b9ebb26665b731f1848c52f11972b6644f554c064fa90780dbbbf3a89d4fc31f67df3e5857ef"),
            (128, "c3582f71ebb2be66fa5dd750f80baae97554f3b015663c8be377cfcb2488c1d1", "2319e3789c47e2daa5fe807f61bec2a1a6537fa03f19ff32e87eecbfd64b7e0e8ccff439ac333b040f19b0c4ddd11a61e24ac1fe0f10a039806c5dcc0da3d115"),
            (129, "f7f3c46ba2564ff4c4c162da1f5b605f9f1c4aa6a20652a9f9a337c1a2f5b9c9", "f59711d44a031d5f97a9413c065d1e614c417ede998590325f49bad2fd444d3e4418be19aec4e11449ac1a57207898bc57d76a1bcf3566292c20c683a5c4648f"),
            (255, "1d0850ee9bca0abc9601e9deabe1418fedec2fb6ac4150bd5302d2430f9be943", "5b21c5fd8868367612474fa2e70e9cfa2201ffeee8fafab5797ad58fefa17c9b5b107da4a3db6320baaf2c8617d5a51df914ae88da3867c2d41f0cc14fa67928"),
            (256, "39a7eb9fedc19aabc83425c6755dd90e6f9d0c804964a1f4aaeea3b9fb599835", "1ecc896f34d3f9cac484c73f75f6a5fb58ee6784be41b35f46067b9c65c63a6794d3d744112c653f73dd7deb6666204c5a9bfa5b46081fc10fdbe7884fa5cbf8"),
            (257, "45f7f084c30bac7cbae2e1963bc6e6b0d8cb227a12927e97fb941d288fb1f9a3", "d8bfe068de0b4f9fa876a3f8024eb9f7b0029fd5dcf251199e065cee89e1a282c8dbf0442f2ade7294ac1c6be19b388dc990c34d8cb79f5f10c54fa813834fda"),
        ]
        for (length, expected256, expected512) in vectors {
            let data = Data((0..<length).map { UInt8($0 % 256) })
            XCTAssertEqual(hex(Blake2b.hash256(data)), expected256, "length \(length)")
            XCTAssertEqual(hex(Blake2b.hash512(data)), expected512, "length \(length)")
        }
    }

    func testPersonalizationKnownAnswersAndZeroPadding() {
        let input = Data("abc".utf8)
        let vectors: [(String, String, String)] = [
            ("a", "9cb8b27b0507e50b3624da3c0e839df1bfa02e2d285f8149060af88a7f4a8e76", "2786c449a4986bd69a7546dfb9f38266035fe8c35d5176706c14ea5160b439bb4d34185f34bf69ce61a434e2907194527fac216b9b87bcfaa16f50906f19abdd"),
            ("0123456789abcdef", "139dad3b92ad7c4601ae1ba6c616ca59699c6b1e8e789d095e1bec905871f612", "30c7fb5d5824341814d3992da32b37384b936b1ee179b123ba508392a4b84e377675a86c8e9383091a1a599a221be96823dab17e511fa754a2843ad7d9e448d8"),
        ]
        for (personal, expected256, expected512) in vectors {
            XCTAssertEqual(hex(Blake2b.hash256(input, personal: Data(personal.utf8))), expected256)
            XCTAssertEqual(hex(Blake2b.hash512(input, personal: Data(personal.utf8))), expected512)
        }
        XCTAssertEqual(Blake2b.hash256(input, personal: Data()), Blake2b.hash256(input))
        XCTAssertEqual(Blake2b.hash512(input, personal: Data()), Blake2b.hash512(input))
        XCTAssertEqual(Blake2b.hash256(input, personal: Data("a".utf8)),
                       Blake2b.hash256(input, personal: Data("a".utf8) + Data(repeating: 0, count: 15)))
    }
}
