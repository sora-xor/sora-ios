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

extension ExtrinsicProcessingBehaviorTests {
  private func builder() -> SoraPassport.ExtrinsicBuilder {
    SoraPassport.ExtrinsicBuilder(specVersion: 133, transactionVersion: 131,
      genesisHash: PIIndexerClient.soraMainnetGenesis)
  }
  private func builderCall(to receiver: Data? = nil) -> RuntimeCall<SoraTransferCall> {
    RuntimeCall(moduleName: "Assets", callName: "transfer", args: SoraTransferCall(
      receiver: receiver ?? bob, amount: 100, assetId: AssetId(wrappedValue: WalletAssetId.val.rawValue)))
  }
  private func signedBuilder(type: SoraPassport.CryptoType = .sr25519) throws -> SoraPassport.ExtrinsicBuilder {
    let coder = try Self.coder.get()
    return try builder().with(address: MultiAddress.accoundId(alice)).with(nonce: 7)
      .adding(call: builderCall()).signing(by: { _ in Data(repeating: 0x2a, count: type == .ecdsa ? 65 : 64) },
        of: type, using: coder.createEncoder(), metadata: coder.metadata)
  }
  func testBuilderRejectsEmptyTransaction() throws {
    XCTAssertThrowsError(try builder().buildExtrinsic(metadata: Self.coder.get().metadata)) { error in
      guard case SoraPassport.ExtrinsicBuilderError.missingCall = error else { return XCTFail("Unexpected error: \(error)") }
    }
  }
  func testBuilderRejectsSigningWithoutAddressBeforeInvokingSigner() throws {
    let coder = try Self.coder.get()
    var signed = false
    XCTAssertThrowsError(try builder().adding(call: builderCall()).signing(by: { _ in signed = true; return Data() },
      of: .ed25519, using: coder.createEncoder(), metadata: coder.metadata)) { error in
      guard case SoraPassport.ExtrinsicBuilderError.missingAddress = error else { return XCTFail("Unexpected error: \(error)") }
    }
    XCTAssertFalse(signed)
  }
  func testBuilderKeepsSingleCallUnwrappedAndUnsigned() throws {
    let call = builderCall()
    let tx = try builder().adding(call: call).buildExtrinsic(metadata: Self.coder.get().metadata)
    XCTAssertEqual(tx.call, try call.processingFixtureJSON())
    XCTAssertNil(tx.signature)
  }
  func testBuilderDefaultsToAtomicBatchAndPreservesCallOrder() throws {
    let first = builderCall(), second = builderCall(to: carol)
    let tx = try builder().adding(call: first).adding(call: second).buildExtrinsic(metadata: Self.coder.get().metadata)
    let expected = RuntimeCall(moduleName: "Utility", callName: "batch_all",
      args: BatchArgs(calls: [try first.processingFixtureJSON(), try second.processingFixtureJSON()]))
    XCTAssertEqual(tx.call, try expected.processingFixtureJSON())
  }
  func testBuilderCanSelectNonAtomicBatchWithoutReorderingCalls() throws {
    let first = builderCall(), second = builderCall(to: carol)
    let tx = try builder().with(shouldUseAtomicBatch: false).adding(call: first).adding(call: second)
      .buildExtrinsic(metadata: Self.coder.get().metadata)
    let expected = RuntimeCall(moduleName: "Utility", callName: "batch",
      args: BatchArgs(calls: [try first.processingFixtureJSON(), try second.processingFixtureJSON()]))
    XCTAssertEqual(tx.call, try expected.processingFixtureJSON())
  }
  func testBuilderPreservesRawCallBytes() throws {
    let raw = Data([0x02, 0x03, 0x00, 0xff])
    let tx = try builder().adding(rawCall: raw).buildExtrinsic(metadata: Self.coder.get().metadata)
    XCTAssertEqual(tx.call, .stringValue("020300ff"))
    XCTAssertNil(tx.signature)
  }
  func testBuilderSupportsMixedRawAndTypedBatchCalls() throws {
    let raw = Data([0x02, 0x03]), call = builderCall()
    let tx = try builder().adding(rawCall: raw).adding(call: call).buildExtrinsic(metadata: Self.coder.get().metadata)
    let expected = RuntimeCall(moduleName: "Utility", callName: "batch_all",
      args: BatchArgs(calls: [.stringValue("0203"), try call.processingFixtureJSON()]))
    XCTAssertEqual(tx.call, try expected.processingFixtureJSON())
  }
  func testBuilderEncodesEd25519SignatureWithCorrectVariant() throws {
    let tx = try signedBuilder(type: .ed25519).buildExtrinsic(metadata: Self.coder.get().metadata)
    XCTAssertEqual(tx.signature?.signature, try MultiSignature.ed25519(data: Data(repeating: 0x2a, count: 64)).processingFixtureJSON())
    XCTAssertEqual(tx.signature?.address, try MultiAddress.accoundId(alice).processingFixtureJSON())
    XCTAssertEqual(tx.signature?.extra.nonce, 7)
  }
  func testBuilderEncodesEcdsaSignatureWithCorrectVariantAndLength() throws {
    let tx = try signedBuilder(type: .ecdsa).buildExtrinsic(metadata: Self.coder.get().metadata)
    XCTAssertEqual(tx.signature?.signature, try MultiSignature.ecdsa(data: Data(repeating: 0x2a, count: 65)).processingFixtureJSON())
  }
  func testBuilderSigningReceivesExactlyTheBuiltPayload() throws {
    let coder = try Self.coder.get()
    let b = try builder().with(address: MultiAddress.accoundId(alice)).with(nonce: 9).with(tip: 42).adding(call: builderCall())
    let expected = try b.buildSignature(encodingBy: coder.createEncoder(), metadata: coder.metadata)
    var received: Data?
    _ = try b.signing(by: { received = $0; return Data(repeating: 1, count: 64) },
      of: .sr25519, using: coder.createEncoder(), metadata: coder.metadata)
    XCTAssertEqual(received, expected)
    XCTAssertFalse(expected.isEmpty)
    let tx = try b.buildExtrinsic(metadata: coder.metadata)
    XCTAssertEqual(tx.signature?.extra.tip, 42)
    XCTAssertEqual(tx.signature?.extra.nonce, 9)
  }
  func testBuilderHashesPayloadsLongerThan256Bytes() throws {
    let coder = try Self.coder.get()
    let b = try builder().with(address: MultiAddress.accoundId(alice)).adding(call: builderCall())
    for _ in 0..<8 { _ = try b.adding(call: builderCall()) }
    let payload = try b.buildSignature(encodingBy: coder.createEncoder(), metadata: coder.metadata)
    XCTAssertEqual(payload.count, 32)
  }
  func testBuilderPropagatesSignerFailureWithoutCreatingSignature() throws {
    enum Failure: Error { case denied }
    let coder = try Self.coder.get()
    let b = try builder().with(address: MultiAddress.accoundId(alice)).adding(call: builderCall())
    XCTAssertThrowsError(try b.signing(by: { _ in throw Failure.denied }, of: .sr25519,
      using: coder.createEncoder(), metadata: coder.metadata)) { XCTAssertTrue($0 is Failure) }
    XCTAssertNil(try b.buildExtrinsic(metadata: coder.metadata).signature)
  }
  func testBuilderChangingAddressInvalidatesSignature() throws {
    let b = try signedBuilder().with(address: MultiAddress.accoundId(carol))
    XCTAssertNil(try b.buildExtrinsic(metadata: Self.coder.get().metadata).signature)
  }
  func testBuilderChangingNonceInvalidatesSignature() throws {
    let b = try signedBuilder().with(nonce: 8)
    XCTAssertNil(try b.buildExtrinsic(metadata: Self.coder.get().metadata).signature)
  }
  func testBuilderChangingTipInvalidatesSignature() throws {
    let b = try signedBuilder().with(tip: 123)
    XCTAssertNil(try b.buildExtrinsic(metadata: Self.coder.get().metadata).signature)
  }
  func testBuilderChangingMortalityInvalidatesSignature() throws {
    let b = try signedBuilder().with(era: .mortal(period: 64, phase: 3), blockHash: String(repeating: "ab", count: 32))
    XCTAssertNil(try b.buildExtrinsic(metadata: Self.coder.get().metadata).signature)
  }
  func testBuilderAddingTypedCallInvalidatesSignature() throws {
    let b = try signedBuilder().adding(call: builderCall(to: carol))
    XCTAssertNil(try b.buildExtrinsic(metadata: Self.coder.get().metadata).signature)
  }
  func testBuilderAddingRawCallInvalidatesSignature() throws {
    let b = try signedBuilder().adding(rawCall: Data([2, 3]))
    XCTAssertNil(try b.buildExtrinsic(metadata: Self.coder.get().metadata).signature)
  }
  func testBuilderChangingBatchModeInvalidatesSignature() throws {
    let coder = try Self.coder.get()
    let b = try signedBuilder().adding(call: builderCall(to: carol))
    _ = try b.signing(by: { _ in Data(repeating: 1, count: 64) }, of: .sr25519,
      using: coder.createEncoder(), metadata: coder.metadata)
    XCTAssertNotNil(try b.buildExtrinsic(metadata: coder.metadata).signature)
    _ = b.with(shouldUseAtomicBatch: false)
    XCTAssertNil(try b.buildExtrinsic(metadata: coder.metadata).signature)
  }
  func testBuilderCanSignAgainAfterMutationWithUpdatedNonceAndTip() throws {
    let coder = try Self.coder.get()
    let b = try signedBuilder().with(nonce: 99).with(tip: 12345)
    _ = try b.signing(by: { _ in Data(repeating: 2, count: 64) }, of: .ed25519,
      using: coder.createEncoder(), metadata: coder.metadata)
    let tx = try b.buildExtrinsic(metadata: coder.metadata)
    XCTAssertEqual(tx.signature?.extra.nonce, 99)
    XCTAssertEqual(tx.signature?.extra.tip, 12345)
    XCTAssertEqual(tx.signature?.signature, try MultiSignature.ed25519(data: Data(repeating: 2, count: 64)).processingFixtureJSON())
  }
  func testExtrinsicCheckRecognizesNamespacedGenericExtensionsAndCachesTheMapping() throws {
    let metadata = try Self.coder.get().metadata
    let input = "fixture30::ChargeTransactionPayment<Runtime>"
    XCTAssertEqual(ExtrinsicCheck.from(string: input, runtimeMetadata: metadata), .txPayment)
    XCTAssertEqual(ExtrinsicCheck.from(string: input, runtimeMetadata: metadata), .txPayment)
    XCTAssertEqual(ExtrinsicCheck.matching(typeName: input), .txPayment)
  }
  func testExtrinsicCheckRejectsUnknownExtensionsAndEmptyNames() throws {
    let metadata = try Self.coder.get().metadata
    for input in ["", "fixture30::UnknownCheck<Runtime>", "CheckNonceSuffix", "::"] {
      XCTAssertNil(ExtrinsicCheck.from(string: input, runtimeMetadata: metadata))
      XCTAssertNil(ExtrinsicCheck.matching(typeName: input))
    }
  }
  func testExtrinsicCheckClassifiesExtraAndAdditionalSignedBytes() {
    let extra: Set<ExtrinsicCheck> = [.mortality, .nonce, .txPayment, .assetTxPayment, .metadataHash]
    let additional: Set<ExtrinsicCheck> = [.specVersion, .txVersion, .genesis, .mortality, .metadataHash]
    for check in ExtrinsicCheck.allCases {
      XCTAssertEqual(check.writesExtra, extra.contains(check), check.rawValue)
      XCTAssertEqual(check.writesAdditionalSigned, additional.contains(check), check.rawValue)
    }
  }
}
