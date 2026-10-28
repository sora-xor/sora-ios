import BigInt
// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import SSFUtils
import XCTest

@testable import SoraPassport

final class ExtrinsicProcessingBehaviorTests: XCTestCase {
  private let alice = Data(repeating: 3, count: 32), bob = Data(repeating: 4, count: 32),
    carol = Data(repeating: 5, count: 32)
  private static let coder: Result<RuntimeCoderFactory, Error> = Result {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
      chainId: PIIndexerClient.soraMainnetGenesis,
      runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(
        chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131,
        metadata: Data(
          contentsOf: root.appendingPathComponent(
            "Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil),
      ownTypes: Data(
        contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")),
      dataHasher: .twox256)
    return RuntimeCoderFactory(
      catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131,
      metadata: snapshot.metadata)
  }
  private func signature(_ sender: Data) throws -> ExtrinsicSignature {
    ExtrinsicSignature(
      address: try MultiAddress.accoundId(sender).processingFixtureJSON(),
      signature: try MultiSignature.sr25519(data: Data(repeating: 0, count: 64))
        .processingFixtureJSON(), extra: .init(era: .immortal, nonce: 0, tip: 0),
      type: "MultiSignature")
  }
  private func transfer(from: Data? = nil, to: Data? = nil) throws -> Extrinsic {
    let args = SoraTransferCall(
      receiver: to ?? bob, amount: 100, assetId: AssetId(wrappedValue: WalletAssetId.val.rawValue))
    return Extrinsic(
      signature: try signature(from ?? alice),
      call: try RuntimeCall(moduleName: "Assets", callName: "transfer", args: args)
        .processingFixtureJSON())
  }
  private func generic(from: Data? = nil) throws -> Extrinsic {
    Extrinsic(
      signature: try signature(from ?? alice),
      call: try RuntimeCall(moduleName: "System", callName: "remark", args: ProcessingEmptyArgs())
        .processingFixtureJSON())
  }
  private func event(
    _ module: String = "System", _ name: String = "ExtrinsicSuccess", index: UInt32 = 0,
    data: [Any] = []
  ) throws -> EventRecord {
    try JSONDecoder().decode(
      EventRecord.self,
      from: JSONSerialization.data(withJSONObject: [
        "phase": ["ApplyExtrinsic", String(index)], "event": [module, [name, data]],
      ]))
  }
  private func process(
    _ extrinsic: Extrinsic, owner: Data? = nil, events: [EventRecord]? = nil, index: UInt32 = 0
  ) throws -> ExtrinsicProcessingResult? {
    ExtrinsicProcessor(accountId: (owner ?? alice).toHex(includePrefix: true)).process(
      extrinsicIndex: index, extrinsic: extrinsic, eventRecords: try events ?? [event()],
      coderFactory: try Self.coder.get())
  }
  private func address(_ data: Data) throws -> String {
    try SS58AddressFactory().address(fromAccountId: data, type: SNAddressType(chain: .sora))
  }
  func testOutgoingTransferIdentifiesReceiverAndSuccessfulStatus() throws {
    let tx = try transfer()
    let result = try XCTUnwrap(process(tx))
    XCTAssertEqual(result.peerId, try address(bob))
    XCTAssertTrue(result.isSuccess)
    XCTAssertTrue(result.callPath.isTransfer)
  }
  func testIncomingTransferIdentifiesSender() throws {
    let result = try XCTUnwrap(process(transfer(), owner: bob))
    XCTAssertEqual(result.peerId, try address(alice))
  }
  func testSelfTransferKeepsTheSamePeer() throws {
    let result = try XCTUnwrap(process(transfer(to: alice)))
    XCTAssertEqual(result.peerId, try address(alice))
  }
  func testUnrelatedTransferIsNotAttributedToTheWallet() throws {
    XCTAssertNil(try process(transfer(), owner: carol))
  }
  func testFailedTransferRetainsFailureStatusAndPeer() throws {
    let result = try XCTUnwrap(process(transfer(), events: [event("System", "ExtrinsicFailed")]))
    XCTAssertFalse(result.isSuccess)
    XCTAssertEqual(result.peerId, try address(bob))
  }
  func testMissingOutcomeCannotInventSuccessfulTransfer() throws {
    XCTAssertNil(try process(transfer(), events: []))
  }
  func testAnotherExtrinsicsStatusCannotConfirmThisTransfer() throws {
    XCTAssertNil(try process(transfer(), events: [event(index: 1)]))
  }
  func testFinalizationEventsCannotConfirmAnExtrinsic() throws {
    let record = try JSONDecoder().decode(
      EventRecord.self,
      from: JSONSerialization.data(withJSONObject: [
        "phase": ["Finalization"], "event": ["System", ["ExtrinsicSuccess", []]],
      ]))
    XCTAssertNil(try process(transfer(), events: [record]))
  }
  func testConflictingSuccessAndFailureEventsRemainUnresolved() throws {
    XCTAssertNil(try process(transfer(), events: [event(), event("System", "ExtrinsicFailed")]))
  }
  func testConflictingFailureAndSuccessEventsRemainUnresolved() throws {
    XCTAssertNil(try process(transfer(), events: [event("System", "ExtrinsicFailed"), event()]))
  }
  func testDuplicateSuccessEventsRemainUnresolved() throws {
    XCTAssertNil(try process(transfer(), events: [event(), event()]))
  }
  func testUnknownEventModuleDoesNotConfirmTransaction() throws {
    XCTAssertNil(try process(transfer(), events: [event("Unknown", "ExtrinsicSuccess")]))
  }
  func testNonterminalSystemEventDoesNotConfirmTransaction() throws {
    XCTAssertNil(try process(transfer(), events: [event("System", "NewAccount")]))
  }
  func testExactLargeDedicatedFeeIsPreserved() throws {
    let raw = "123456789012345678901234567890"
    let result = try XCTUnwrap(
      process(
        transfer(),
        events: [
          event(), event("XorFee", "FeeWithdrawn", data: [alice.toHex(includePrefix: true), raw]),
        ]))
    XCTAssertEqual(result.fee, BigUInt(raw))
  }
  func testDedicatedFeeForAnotherExtrinsicIsIgnored() throws {
    let result = try XCTUnwrap(
      process(
        transfer(), events: [event(), event("XorFee", "FeeWithdrawn", index: 1, data: ["999"])]))
    XCTAssertNil(result.fee)
  }
  func testAbsentFeeRemainsUnknown() throws { XCTAssertNil(try process(transfer())?.fee) }
  func testMalformedDedicatedFeeIsNotInventedAsZero() throws {
    let result = try XCTUnwrap(
      process(transfer(), events: [event(), event("XorFee", "FeeWithdrawn", data: [])]))
    XCTAssertNil(result.fee)
  }
  func testNegativeDedicatedFeeIsNotInventedAsZero() throws {
    let result = try XCTUnwrap(
      process(transfer(), events: [event(), event("XorFee", "FeeWithdrawn", data: ["-1"])]))
    XCTAssertNil(result.fee)
  }
  func testBalanceDepositFeeFallbackSumsExactParts() throws {
    let result = try XCTUnwrap(
      process(
        transfer(),
        events: [
          event(), event("Balances", "Deposit", data: [alice.toHex(includePrefix: true), "3"]),
          event("Balances", "Deposit", data: [bob.toHex(includePrefix: true), "7"]),
        ]))
    XCTAssertEqual(result.fee, 10)
  }
  func testDedicatedFeeIsNotDoubleCountedWithBalanceDeposits() throws {
    let result = try XCTUnwrap(
      process(
        transfer(),
        events: [
          event(), event("XorFee", "FeeWithdrawn", data: [alice.toHex(includePrefix: true), "10"]),
          event("Balances", "Deposit", data: [alice.toHex(includePrefix: true), "10"]),
        ]))
    XCTAssertEqual(result.fee, 10)
  }
  func testDepositFromAnotherExtrinsicDoesNotInflateFee() throws {
    let result = try XCTUnwrap(
      process(
        transfer(),
        events: [
          event(), event("Balances", "Deposit", data: [alice.toHex(includePrefix: true), "3"]),
          event("Balances", "Deposit", index: 1, data: [alice.toHex(includePrefix: true), "99"]),
        ]))
    XCTAssertEqual(result.fee, 3)
  }
  func testMalformedAccountIdentifierCannotMatchATransfer() throws {
    let p = ExtrinsicProcessor(accountId: "not-hex")
    XCTAssertNil(p.account)
    XCTAssertNil(
      p.process(
        extrinsicIndex: 0, extrinsic: try transfer(), eventRecords: [try event()],
        coderFactory: try Self.coder.get()))
  }
  func testSignedGenericCallRetainsItsOwnStatusAndFee() throws {
    let result = try XCTUnwrap(
      process(generic(), events: [event(), event("XorFee", "FeeWithdrawn", data: ["5"])]))
    XCTAssertEqual(result.callPath.moduleName, "System")
    XCTAssertEqual(result.callPath.callName, "remark")
    XCTAssertNil(result.peerId)
    XCTAssertEqual(result.fee, 5)
  }
  func testUnrelatedGenericCallIsIgnored() throws { XCTAssertNil(try process(generic(from: bob))) }
  func testUnsignedGenericCallIsNotAttributedToTheAccount() throws {
    let tx = try generic()
    XCTAssertNil(try process(Extrinsic(signature: nil, call: tx.call)))
  }
  func testGenericCallWithoutStatusIsIgnored() throws {
    XCTAssertNil(try process(generic(), events: []))
  }
  func testMigrationKeepsItsOwnStatusWithoutTransferPeerOrFee() throws {
    let call = RuntimeCall(
      moduleName: "IrohaMigration", callName: "migrate",
      args: MigrateCall(
        irohaAddress: "fixture@sora", irohaPublicKey: "public", irohaSignature: "fixture"))
    let result = try XCTUnwrap(
      process(Extrinsic(signature: signature(alice), call: call.processingFixtureJSON())))
    XCTAssertNil(result.peerId)
    XCTAssertNil(result.fee)
    XCTAssertEqual(result.callPath.moduleName, "IrohaMigration")
  }
  func testBatchFindsTheWalletsTransferAfterAnUndecodableCall() throws {
    let inner = try transfer()
    let call = RuntimeCall(
      moduleName: "Utility", callName: "batchAll",
      args: BatchArgs(calls: [.dictionaryValue([:]), inner.call]))
    let result = try XCTUnwrap(
      process(Extrinsic(signature: signature(alice), call: call.processingFixtureJSON())))
    XCTAssertTrue(result.callPath.isTransfer)
    XCTAssertEqual(result.peerId, try address(bob))
  }
  func testFailedBatchTransferCannotBeShownAsSuccessful() throws {
    let call = RuntimeCall(
      moduleName: "Utility", callName: "batchAll", args: BatchArgs(calls: [try transfer().call]))
    let result = try XCTUnwrap(
      process(
        Extrinsic(signature: signature(alice), call: call.processingFixtureJSON()),
        events: [event("System", "ExtrinsicFailed")]))
    XCTAssertFalse(result.isSuccess)
  }
  func testMalformedRawExtrinsicIsRejected() throws {
    let processor = ExtrinsicProcessor(accountId: alice.toHex(includePrefix: true))
    XCTAssertNil(
      processor.process(
        extrinsicIndex: 0, extrinsicData: Data([0xff]), eventRecords: [try event()],
        coderFactory: try Self.coder.get()))
  }
}

private struct ProcessingEmptyArgs: Codable {}
extension Encodable {
  fileprivate func processingFixtureJSON() throws -> JSON {
    let data = try JSONEncoder.scaleCompatible().encode(SoraPassport.EncodingContainer(value: self))
    return try JSONDecoder.scaleCompatible(snakeCase: false).decode(
      SoraPassport.JsonContainer.self, from: data
    ).value
  }
}
