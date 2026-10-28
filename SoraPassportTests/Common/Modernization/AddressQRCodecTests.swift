// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import IrohaCrypto
import SSFUtils
import XCTest
@testable import SoraPassport

/// Pins the SORA address QR wire format. The app declares the format constants
/// itself since 3.9.0 (it no longer links SSFQRService), so a QR code shown by
/// 3.8.x or by another SORA wallet must still decode, and a QR code shown by
/// 3.9.0 must still be readable by them.
final class AddressQRCodecTests: XCTestCase {
    private let publicKey = try! Data(
        hexStringSSF: "0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d"
    )
    private let xorAssetId =
        "0x0200000000000000000000000000000000000000000000000000000000000000"

    private func soraAddress() throws -> String {
        try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: Chain.sora.addressType()
        )
    }

    func testWireConstantsAreUnchanged() {
        XCTAssertEqual(SubstrateQRConstants.prefix, "substrate")
        XCTAssertEqual(SubstrateQRConstants.fieldsSeparator, ":")
    }

    func testAddressQRRoundTripKeepsAddressAndKey() throws {
        let address = try soraAddress()
        let info = AddressQRInfo(address: address, rawPublicKey: publicKey, username: "Main")

        let data = try AddressQREncoder().encode(info: info)
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "substrate:\(address):\(publicKey.toHex(includePrefix: true)):Main"
        )

        let decoded: QRInfo = try AddressQRDecoder(chainType: Chain.sora.addressType())
            .decode(data: data)
        let addressInfo = try XCTUnwrap(decoded as? AddressQRInfo)
        XCTAssertEqual(addressInfo, info)
    }

    func testReceiveQRRoundTripKeepsAssetAndAmount() throws {
        let address = try soraAddress()
        let info = SoraSubstrateQRInfo(
            address: address,
            rawPublicKey: publicKey,
            username: nil,
            assetId: xorAssetId,
            amount: "1.5"
        )

        let data = try AddressQREncoder().encode(info: info)
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "substrate:\(address):\(publicKey.toHex(includePrefix: true))::\(xorAssetId):1.5"
        )

        let decoded: SoraSubstrateQRInfo = try AddressQRDecoder(
            chainType: Chain.sora.addressType()
        ).decode(data: data)
        XCTAssertEqual(decoded.address, address)
        XCTAssertEqual(decoded.rawPublicKey, publicKey)
        XCTAssertEqual(decoded.assetId, xorAssetId)
        XCTAssertEqual(decoded.amount, "1.5")
    }

    func testDecoderRejectsForeignPrefixAndMismatchedKey() throws {
        let address = try soraAddress()
        let decoder = AddressQRDecoder(chainType: Chain.sora.addressType())
        let key = publicKey.toHex(includePrefix: true)

        XCTAssertThrowsError(
            try decoder.decode(data: Data("ethereum:\(address):\(key)".utf8)) as QRInfo
        ) { error in
            XCTAssertEqual(error as? QRDecoderError, .undefinedPrefix)
        }

        let otherKey = Data(repeating: 0x11, count: 32).toHex(includePrefix: true)
        XCTAssertThrowsError(
            try decoder.decode(data: Data("substrate:\(address):\(otherKey)".utf8)) as QRInfo
        ) { error in
            XCTAssertEqual(error as? QRDecoderError, .accountIdMismatch)
        }
    }
}
