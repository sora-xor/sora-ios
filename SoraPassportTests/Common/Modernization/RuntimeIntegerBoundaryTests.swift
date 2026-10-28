// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import SoraPassport

final class RuntimeIntegerBoundaryTests: XCTestCase {
    private static let coder: Result<RuntimeCoderFactory, Error> = Result {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(chainId: PIIndexerClient.soraMainnetGenesis, runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131, metadata: Data(contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil), ownTypes: Data(contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")), dataHasher: .twox256)
        return RuntimeCoderFactory(catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131, metadata: snapshot.metadata)
    }
    private func encode(_ value: String, type: String) throws -> Data { let encoder = try Self.coder.get().createEncoder(); try encoder.append(value, ofType: type); return try encoder.encode() }
    private func decode(_ data: Data, type: String) throws -> String? { let decoder = try Self.coder.get().createDecoder(from: data); let value = try decoder.read(type: type); XCTAssertEqual(decoder.remained, 0); return value.stringValue }
    private func unsigned(_ bits: Int) throws {
        let type = "u\(bits)", bytes = bits / 8, limit = BigUInt(1) << bits
        XCTAssertEqual(try encode("0", type: type), Data(repeating: 0, count: bytes))
        XCTAssertEqual(try encode(String(limit - 1), type: type), Data(repeating: 255, count: bytes))
        XCTAssertEqual(try decode(Data(repeating: 255, count: bytes), type: type), String(limit - 1))
        for invalid in [String(limit), "-1", "1.5", "1suffix"] { XCTAssertThrowsError(try encode(invalid, type: type), "\(type): \(invalid)") }
    }
    private func signedEncoding(_ bits: Int) throws {
        let type = "i\(bits)", bytes = bits / 8, edge = BigInt(1) << (bits - 1)
        XCTAssertEqual(try encode("-1", type: type), Data(repeating: 255, count: bytes))
        XCTAssertEqual(try encode(String(-edge), type: type), Data(repeating: 0, count: bytes - 1) + Data([128]))
        XCTAssertEqual(try encode(String(edge - 1), type: type), Data(repeating: 255, count: bytes - 1) + Data([127]))
        for invalid in [String(edge), String(-edge - 1), "-1.5", "1suffix"] { XCTAssertThrowsError(try encode(invalid, type: type), "\(type): \(invalid)") }
    }
    private func signedDecoding(_ bits: Int) throws {
        let type = "i\(bits)", bytes = bits / 8, edge = BigInt(1) << (bits - 1)
        XCTAssertEqual(try decode(Data(repeating: 255, count: bytes), type: type), "-1")
        XCTAssertEqual(try decode(Data(repeating: 0, count: bytes - 1) + Data([128]), type: type), String(-edge))
        XCTAssertEqual(try decode(Data(repeating: 255, count: bytes - 1) + Data([127]), type: type), String(edge - 1))
        XCTAssertEqual(try decode(Data(repeating: 0, count: bytes), type: type), "0")
        XCTAssertThrowsError(try decode(Data(repeating: 0, count: bytes - 1), type: type))
    }
    func testUnsignedWidthAndOverflow8() throws { try unsigned(8) }
    func testSignedTwosComplementEncoding8() throws { try signedEncoding(8) }
    func testSignedTwosComplementDecoding8() throws { try signedDecoding(8) }
    func testUnsignedWidthAndOverflow16() throws { try unsigned(16) }
    func testSignedTwosComplementEncoding16() throws { try signedEncoding(16) }
    func testSignedTwosComplementDecoding16() throws { try signedDecoding(16) }
    func testUnsignedWidthAndOverflow32() throws { try unsigned(32) }
    func testSignedTwosComplementEncoding32() throws { try signedEncoding(32) }
    func testSignedTwosComplementDecoding32() throws { try signedDecoding(32) }
    func testUnsignedWidthAndOverflow64() throws { try unsigned(64) }
    func testSignedTwosComplementEncoding64() throws { try signedEncoding(64) }
    func testSignedTwosComplementDecoding64() throws { try signedDecoding(64) }
    func testUnsignedWidthAndOverflow128() throws { try unsigned(128) }
    func testSignedTwosComplementEncoding128() throws { try signedEncoding(128) }
    func testSignedTwosComplementDecoding128() throws { try signedDecoding(128) }
    func testUnsignedWidthAndOverflow256() throws { try unsigned(256) }
    func testSignedTwosComplementEncoding256() throws { try signedEncoding(256) }
    func testSignedTwosComplementDecoding256() throws { try signedDecoding(256) }
    func testFailedUnsignedAppendDoesNotPoisonFollowingBytes() throws {
        let encoder = try Self.coder.get().createEncoder(); try encoder.append("1", ofType: "u8")
        XCTAssertThrowsError(try encoder.append("256", ofType: "u8"))
        try encoder.append("2", ofType: "u8"); XCTAssertEqual(try encoder.encode(), Data([1, 2]))
    }
    func testFailedSignedAppendDoesNotPoisonFollowingBytes() throws {
        let encoder = try Self.coder.get().createEncoder(); try encoder.append("1", ofType: "i8")
        XCTAssertThrowsError(try encoder.append("128", ofType: "i8"))
        try encoder.append("-1", ofType: "i8"); XCTAssertEqual(try encoder.encode(), Data([1, 255]))
    }
    func testMixedSignedAndUnsignedFieldsPreserveExactWidthsAndCursor() throws {
        let coder = try Self.coder.get(), encoder = coder.createEncoder()
        try encoder.append("-2", ofType: "i16"); try encoder.append("16909060", ofType: "u32"); try encoder.append("-128", ofType: "i8")
        let wire = try encoder.encode(); XCTAssertEqual(wire, Data([254, 255, 4, 3, 2, 1, 128]))
        let decoder = try coder.createDecoder(from: wire)
        XCTAssertEqual(try decoder.read(type: "i16").stringValue, "-2"); XCTAssertEqual(try decoder.read(type: "u32").stringValue, "16909060"); XCTAssertEqual(try decoder.read(type: "i8").stringValue, "-128"); XCTAssertEqual(decoder.remained, 0)
    }
}
