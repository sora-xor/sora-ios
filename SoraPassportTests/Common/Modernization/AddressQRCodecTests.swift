// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import IrohaCrypto
import SSFUtils
import SoraFoundation
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

    func testAddressQRWithoutUsernameRetainsLegacyThreeFieldFormat() throws {
        let address = try soraAddress()
        let info = AddressQRInfo(address: address, rawPublicKey: publicKey, username: nil)
        let data = try AddressQREncoder().encode(info: info)
        XCTAssertEqual(String(decoding: data, as: UTF8.self).components(separatedBy: ":").count, 3)
        let decoded: QRInfo = try AddressQRDecoder(chainType: Chain.sora.addressType()).decode(data: data)
        XCTAssertEqual(decoded as? AddressQRInfo, info)
    }

    func testReceiveQRAllowsLegacyFiveFieldsWithoutAmount() throws {
        let address = try soraAddress()
        let key = publicKey.toHex(includePrefix: true)
        let decoded: SoraSubstrateQRInfo = try AddressQRDecoder(chainType: Chain.sora.addressType())
            .decode(data: Data("substrate:\(address):\(key)::\(xorAssetId)".utf8))
        XCTAssertEqual(decoded.address, address)
        XCTAssertEqual(decoded.assetId, xorAssetId)
        XCTAssertNil(decoded.amount)
    }

    func testReceiveQRUsesConfiguredSeparator() throws {
        let info = SoraSubstrateQRInfo(address: try soraAddress(), rawPublicKey: publicKey,
                                      username: nil, assetId: xorAssetId, amount: "0.000000000000000001")
        let data = try AddressQREncoder(separator: "|").encode(info: info)
        let decoded: SoraSubstrateQRInfo = try AddressQRDecoder(chainType: Chain.sora.addressType(), separator: "|")
            .decode(data: data)
        XCTAssertEqual(decoded.address, info.address)
        XCTAssertEqual(decoded.assetId, info.assetId)
        XCTAssertEqual(decoded.amount, info.amount)
    }

    func testBothDecodersRejectInvalidUTF8() {
        let decoder = AddressQRDecoder(chainType: Chain.sora.addressType())
        let bytes = Data([0xff, 0xfe])
        XCTAssertThrowsError(try decoder.decode(data: bytes) as QRInfo) {
            XCTAssertEqual($0 as? QRDecoderError, .brokenFormat)
        }
        XCTAssertThrowsError(try decoder.decode(data: bytes) as SoraSubstrateQRInfo) {
            XCTAssertEqual($0 as? QRDecoderError, .brokenFormat)
        }
    }

    func testAddressDecoderRejectsMissingOrExtraFields() throws {
        let base = "substrate:\(try soraAddress()):\(publicKey.toHex(includePrefix: true))"
        let decoder = AddressQRDecoder(chainType: Chain.sora.addressType())
        for raw in ["", "substrate", "substrate:address", base + ":name:unexpected"] {
            XCTAssertThrowsError(try decoder.decode(data: Data(raw.utf8)) as QRInfo) {
                XCTAssertEqual($0 as? QRDecoderError, .unexpectedNumberOfFields)
            }
        }
    }

    func testReceiveDecoderRejectsMissingOrExtraFields() throws {
        let base = "substrate:\(try soraAddress()):\(publicKey.toHex(includePrefix: true))"
        let decoder = AddressQRDecoder(chainType: Chain.sora.addressType())
        for raw in ["", base, base + ":name", base + "::\(xorAssetId):1:unexpected"] {
            XCTAssertThrowsError(try decoder.decode(data: Data(raw.utf8)) as SoraSubstrateQRInfo) {
                XCTAssertEqual($0 as? QRDecoderError, .unexpectedNumberOfFields)
            }
        }
    }

    func testReceiveDecoderRejectsForeignPrefixAndMismatchedKey() throws {
        let address = try soraAddress()
        let decoder = AddressQRDecoder(chainType: Chain.sora.addressType())
        let key = publicKey.toHex(includePrefix: true)
        XCTAssertThrowsError(try decoder.decode(data: Data("ethereum:\(address):\(key)::\(xorAssetId):1".utf8)) as SoraSubstrateQRInfo) {
            XCTAssertEqual($0 as? QRDecoderError, .undefinedPrefix)
        }
        let otherKey = Data(repeating: 0x11, count: 32).toHex(includePrefix: true)
        XCTAssertThrowsError(try decoder.decode(data: Data("substrate:\(address):\(otherKey)::\(xorAssetId):1".utf8)) as SoraSubstrateQRInfo) {
            XCTAssertEqual($0 as? QRDecoderError, .accountIdMismatch)
        }
    }

    func testBothDecodersRejectMalformedPublicKey() throws {
        let address = try soraAddress()
        let decoder = AddressQRDecoder(chainType: Chain.sora.addressType())
        for invalidKey in ["0xzz", "0x01", "0x"] {
            let base = "substrate:\(address):\(invalidKey)"
            XCTAssertThrowsError(try decoder.decode(data: Data(base.utf8)) as QRInfo)
            XCTAssertThrowsError(try decoder.decode(data: Data((base + "::\(xorAssetId):1").utf8)) as SoraSubstrateQRInfo)
        }
    }

    func testWalletReceiveRoundTripKeepsExactAmountAndAsset() throws {
        let info = ReceiveInfo(accountId: publicKey.toHex(), assetId: xorAssetId,
                               amount: AmountDecimal(string: "0.000000000000000001"), details: nil)
        let encoder = WalletQREncoder(networkType: Chain.sora.addressType(), publicKey: publicKey, username: nil)
        let decoded = try walletDecoder().decode(data: encoder.encode(receiverInfo: info))
        XCTAssertEqual(decoded, info)
    }

    func testWalletReceiveEncoderRejectsMissingAssetInsteadOfCrashing() {
        let encoder = WalletQREncoder(networkType: Chain.sora.addressType(), publicKey: publicKey, username: nil)
        for assetId in [String?.none, ""] {
            let info = ReceiveInfo(accountId: publicKey.toHex(), assetId: assetId, amount: nil, details: nil)
            XCTAssertThrowsError(try encoder.encode(receiverInfo: info)) {
                XCTAssertEqual($0 as? QREncoderError, .brokenData)
            }
        }
    }

    func testWalletReceiveDecoderDoesNotPrefillPartiallyParsedAmounts() throws {
        let base = "substrate:\(try soraAddress()):\(publicKey.toHex(includePrefix: true))::\(xorAssetId):"
        for amount in ["", "1,25", "1.25XOR", "1e+", "1.2.3"] {
            let decoded = try walletDecoder().decode(data: Data((base + amount).utf8))
            XCTAssertNil(decoded.amount, "Prefilled a different amount from \(amount.debugDescription)")
            XCTAssertEqual(decoded.assetId, xorAssetId)
            XCTAssertEqual(decoded.accountId, publicKey.toHex())
        }
    }

    func testWalletReceiveDecoderRejectsUnknownAsset() throws {
        let info = SoraSubstrateQRInfo(address: try soraAddress(), rawPublicKey: publicKey,
                                      username: nil, assetId: "unknown", amount: "1")
        XCTAssertThrowsError(try walletDecoder().decode(data: AddressQREncoder().encode(info: info)))
    }

    private func walletDecoder() -> WalletQRDecoder {
        let asset = WalletAsset(identifier: xorAssetId, name: LocalizableResource { _ in "XOR" },
                                symbol: "XOR", precision: 18)
        return WalletQRDecoder(networkType: Chain.sora.addressType(), assets: [asset])
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
