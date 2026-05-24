import MocksBasket
import XCTest

@testable import SSFQRService

final class QRDecoderTests: XCTestCase {
    func testBokoloCashDecoder() async throws {
        // arrange
        let address = "ivan_ivan@auki"
        let assetId = "090"
        let bokoloQRCodeString =
            "https://bokolodemo.page.link/data?qr=00020101021129180014\(address)520459995303\(assetId)5802LA5909Ivan%20Ivan6010Phnom%20Penh6304DCAF"
        let data = bokoloQRCodeString.data(using: .utf8)!
        let decoder = BokoloCashDecoder()

        // act
        let qrType = try decoder.decode(data: data)

        // assert
        XCTAssertNotNil(qrType)

        switch qrType {
        case let .bokoloCash(bokoloCashQRInfo):
            XCTAssertEqual(bokoloCashQRInfo.address, address)
            XCTAssertEqual(bokoloCashQRInfo.assetId, assetId)
            XCTAssertNil(bokoloCashQRInfo.transactionAmount)
        case .sora, .cex, .desiredCryptocurrency:
            XCTExpectFailure()
        }
    }

    func testBokoloCashDecoderWithAmount() async throws {
        // arrange
        let address = "ivan_ivan@auki"
        let assetId = "090"
        let amount = "1.5"
        let bokoloQRCodeString =
            "https://bokolodemo.page.link/data?qr=00020101021229180014\(address)520459995303\(assetId)5403\(amount)5802LA5909Ivan%20Ivan6010Phnom%20Penh6304A2CA"
        let data = bokoloQRCodeString.data(using: .utf8)
        XCTAssertNotNil(data)
        let decoder = BokoloCashDecoder()

        // act
        let qrType = try decoder.decode(data: data!)

        // assert
        XCTAssertNotNil(qrType)

        switch qrType {
        case let .bokoloCash(bokoloCashQRInfo):
            XCTAssertEqual(bokoloCashQRInfo.address, address)
            XCTAssertEqual(bokoloCashQRInfo.assetId, assetId)
            XCTAssertEqual(bokoloCashQRInfo.transactionAmount, amount)
        case .sora, .cex, .desiredCryptocurrency:
            XCTExpectFailure()
        }
    }

    func testSoraQRDecoder() async throws {
        // arrange
        let prefix = "substrate"
        let address = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let rawPublicKey = "0xbcc5ecf679ebd776866a04c212a4ec5dc45cefab57d7aa858c389844e212693f"
        let username = "Ivan"
        let assetId = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let amount = "123"
        let qrCodeString = "\(prefix):\(address):\(rawPublicKey):\(username):\(assetId):\(amount)"
        let data = qrCodeString.data(using: .utf8)
        let rawPublicKeyData = try Data(hexStringSSF: rawPublicKey)
        XCTAssertNotNil(data)
        let decoder = SoraQRDecoder()

        // act
        let qrType = try decoder.decode(data: data!)

        // assert
        XCTAssertNotNil(qrType)

        switch qrType {
        case let .sora(info):
            XCTAssertEqual(info.prefix, prefix)
            XCTAssertEqual(info.address, address)
            XCTAssertEqual(info.rawPublicKey, rawPublicKeyData)
            XCTAssertEqual(info.username, username)
            XCTAssertEqual(info.assetId, assetId)
            XCTAssertEqual(info.amount, amount)
        case .bokoloCash, .cex, .desiredCryptocurrency:
            XCTExpectFailure()
        }
    }

    func testSoraQRDecoderWithPrifix() async throws {
        // arrange
        let prefix = "substrate"
        let address = "0xcnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        let rawPublicKey = "0xbcc5ecf679ebd776866a04c212a4ec5dc45cefab57d7aa858c389844e212693f"
        let username = "Ivan"
        let assetId = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let amount = "123"
        let qrCodeString = "\(prefix):\(address):\(rawPublicKey):\(username):\(assetId):\(amount)"
        let data = qrCodeString.data(using: .utf8)
        let rawPublicKeyData = try Data(hexStringSSF: rawPublicKey)
        XCTAssertNotNil(data)
        let decoder = SoraQRDecoder()

        // act
        let qrType = try decoder.decode(data: data!)

        // assert
        XCTAssertNotNil(qrType)

        switch qrType {
        case let .sora(info):
            XCTAssertEqual(info.prefix, prefix)
            XCTAssertEqual(info.address, address)
            XCTAssertEqual(info.rawPublicKey, rawPublicKeyData)
            XCTAssertEqual(info.username, username)
            XCTAssertEqual(info.assetId, assetId)
            XCTAssertEqual(info.amount, amount)
        case .bokoloCash, .cex, .desiredCryptocurrency:
            XCTExpectFailure()
        }
    }

    func testQRDecoderMock() async throws {
        // arrange
        let decoder = QRDecoderMock()
        decoder.decodeDataReturnValue = .cex(.init(address: ""))

        // act
        _ = try decoder.decode(data: Data())

        // assert
        XCTAssertTrue(decoder.decodeDataCalled)
        XCTAssertEqual(decoder.decodeDataCallsCount, 1)
    }
}
