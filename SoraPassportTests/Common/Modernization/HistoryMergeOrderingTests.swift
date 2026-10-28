// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import SSFUtils
import SoraFoundation
import XCTest

@testable import SoraPassport

final class HistoryMergeOrderingTests: XCTestCase {
  private let address = "public-history-owner"
  private func local(
    _ id: String = "0x01", status: TransactionHistoryItem.Status = .success, block: UInt64? = 10,
    time: Int64 = 100
  ) -> TransactionHistoryItem {
    .init(
      sender: address, receiver: nil, status: status, txHash: id, timestamp: time, fee: "0",
      blockNumber: block, txIndex: nil,
      callPath: .init(moduleName: "SORA2", callName: "pending_submission"), call: Data())
  }
  private func remote(_ id: String = "0x02", block: UInt64 = 20, time: Int64 = 200) -> MergeRemote {
    .init(id: id, block: block, time: time)
  }
  private func manager() -> TransactionHistoryMergeManager {
    .init(
      address: address, networkType: 69,
      asset: WalletAsset(
        identifier: WalletAssetId.xor.rawValue, name: LocalizableResource { _ in "XOR" },
        symbol: "XOR", precision: 18), addressFactory: SS58AddressFactory())
  }
  private func before(_ left: TransactionHistoryMergeItem, _ right: TransactionHistoryMergeItem)
    -> Bool
  { left.compareWithItem(right) }
  func testPendingLocalSortsBeforeNewerSuccessfulLocal() {
    XCTAssertTrue(
      before(
        .local(item: local(status: .pending, block: nil, time: 1)),
        .local(item: local(status: .success, block: 100, time: 1000))))
  }
  func testSuccessfulLocalCannotSortBeforeAnOlderPendingLocal() {
    XCTAssertFalse(
      before(
        .local(item: local(status: .success, block: 100, time: 1000)),
        .local(item: local(status: .pending, block: nil, time: 1))))
  }
  func testFailedLocalCannotSortBeforeAPendingLocal() {
    XCTAssertFalse(
      before(
        .local(item: local(status: .failed, block: 100, time: 1000)),
        .local(item: local(status: .pending, block: nil, time: 1))))
  }
  func testPendingLocalsUseDescendingTimestamp() {
    XCTAssertTrue(
      before(
        .local(item: local(status: .pending, block: nil, time: 200)),
        .local(item: local(status: .pending, block: nil, time: 100))))
  }
  func testEqualLocalsDoNotCompareBeforeThemselves() {
    let value = TransactionHistoryMergeItem.local(item: local(status: .pending))
    XCTAssertFalse(before(value, value))
  }
  func testFinalizedLocalsUseBlockHeightBeforeTimestamp() {
    XCTAssertTrue(
      before(.local(item: local(block: 20, time: 1)), .local(item: local(block: 10, time: 1000))))
  }
  func testEqualLocalBlocksUseDescendingTimestamp() {
    XCTAssertTrue(
      before(.local(item: local(block: 10, time: 200)), .local(item: local(block: 10, time: 100))))
  }
  func testMissingLocalBlockUsesTimestamp() {
    XCTAssertTrue(
      before(.local(item: local(block: nil, time: 200)), .local(item: local(block: 10, time: 100))))
  }
  func testPendingLocalSortsBeforeRemoteRegardlessOfAge() {
    XCTAssertTrue(
      before(
        .local(item: local(status: .pending, block: nil, time: 1)),
        .remote(remote: remote(time: 1000))))
  }
  func testRemoteNeverSortsBeforePendingLocal() {
    XCTAssertFalse(
      before(
        .remote(remote: remote(time: 1000)),
        .local(item: local(status: .pending, block: nil, time: 1))))
  }
  func testFinalizedLocalAndRemoteCompareByBlockHeight() {
    XCTAssertTrue(
      before(.local(item: local(block: 30, time: 1)), .remote(remote: remote(block: 20, time: 200)))
    )
  }
  func testRemoteAndFinalizedLocalCompareByBlockHeight() {
    XCTAssertTrue(
      before(.remote(remote: remote(block: 30, time: 1)), .local(item: local(block: 20, time: 200)))
    )
  }
  func testEqualMixedBlocksCompareTimestamps() {
    XCTAssertTrue(
      before(
        .remote(remote: remote(block: 20, time: 200)), .local(item: local(block: 20, time: 100))))
  }
  func testRemotesUseDescendingBlockNumber() {
    XCTAssertTrue(
      before(
        .remote(remote: remote(block: 30, time: 1)), .remote(remote: remote(block: 20, time: 200))))
  }
  func testEqualRemoteBlocksUseDescendingTimestamp() {
    XCTAssertTrue(
      before(
        .remote(remote: remote(block: 20, time: 200)), .remote(remote: remote(block: 20, time: 100))
      ))
  }
  func testIdenticalRemoteDoesNotSortBeforeItself() {
    let r = TransactionHistoryMergeItem.remote(remote: remote())
    XCTAssertFalse(before(r, r))
  }
  func testComparatorIsAntisymmetricAcrossPendingAndFinalizedRows() {
    let values: [TransactionHistoryMergeItem] = [
      .local(item: local(status: .pending, block: nil, time: 1)),
      .local(item: local(status: .success, block: 10, time: 100)),
      .local(item: local(status: .failed, block: 20, time: 200)),
      .remote(remote: remote(block: 30, time: 300)),
    ]
    for left in values {
      for right in values { XCTAssertFalse(before(left, right) && before(right, left)) }
    }
  }
  func testEmptyHistoryReturnsNoRowsOrRemovals() {
    let r = manager().merge(remoteItems: [], localItems: [])
    XCTAssertTrue(r.historyItems.isEmpty)
    XCTAssertTrue(r.identifiersToRemove.isEmpty)
  }
  func testRemoteHistoryIsSortedBeforeConversion() {
    let a = remote("a", block: 10, time: 100)
    let b = remote("b", block: 20, time: 200)
    let r = manager().merge(remoteItems: [a, b], localItems: [])
    XCTAssertEqual(r.historyItems.map(\.transactionId), ["b", "a"])
  }
  func testRemoteConversionReceivesTheOwnerAndNetwork() {
    let a = remote()
    _ = manager().merge(remoteItems: [a], localItems: [])
    XCTAssertEqual(a.addresses, [address])
    XCTAssertEqual(a.networks, [69])
  }
  func testRemoteConversionMayExcludeAnUnsupportedRecord() {
    let a = remote()
    a.unsupported = true
    let r = manager().merge(remoteItems: [a], localItems: [])
    XCTAssertTrue(r.historyItems.isEmpty)
  }
  func testRemoteHashReplacesTheExactLocalRow() {
    let r = manager().merge(
      remoteItems: [remote("0xAB", time: 100)],
      localItems: [local("0xab", status: .pending, time: 200)])
    XCTAssertEqual(r.identifiersToRemove, ["0xab"])
    XCTAssertEqual(r.historyItems.count, 1)
    XCTAssertEqual(r.historyItems.first?.transactionId, "0xAB")
  }
  func testRemoteWithoutAHashCannotRemoveAPendingRow() {
    let a = remote()
    a.hash = nil
    let r = manager().merge(
      remoteItems: [a], localItems: [local("0xab", status: .pending, time: 1)])
    XCTAssertTrue(r.identifiersToRemove.isEmpty)
    XCTAssertEqual(r.historyItems.count, 2)
  }
  func testMalformedRemoteHashCannotRemoveAPendingRow() {
    let a = remote("not-hex")
    let r = manager().merge(
      remoteItems: [a], localItems: [local("0xab", status: .pending, time: 1)])
    XCTAssertTrue(r.identifiersToRemove.isEmpty)
    XCTAssertEqual(r.historyItems.count, 2)
  }
  func testOlderFinalizedLocalIsRemovedOnlyBeyondTheRemoteBoundary() {
    let r = manager().merge(
      remoteItems: [remote(time: 100)],
      localItems: [local("0xaa", time: 99), local("0xbb", time: 100)])
    XCTAssertEqual(r.identifiersToRemove, ["0xaa"])
    XCTAssertTrue(r.historyItems.contains { $0.transactionId == "0xbb" })
  }
  func testUnsortedRemotePageUsesItsActualOldestTimestamp() {
    let r = manager().merge(
      remoteItems: [remote("0x01", time: 100), remote("0x02", time: 200)],
      localItems: [local("0xab", time: 150)])
    XCTAssertTrue(r.identifiersToRemove.isEmpty)
    XCTAssertTrue(r.historyItems.contains { $0.transactionId == "0xab" })
  }
  func testPendingLocalRemainsFirstAfterMergingFinalizedRows() {
    let r = manager().merge(
      remoteItems: [remote(time: 200)],
      localItems: [
        local("0xaa", status: .pending, block: nil, time: 1), local("0xbb", block: 30, time: 300),
      ])
    XCTAssertEqual(r.historyItems.first?.transactionId, "0xaa")
  }
  func testLocalOnlyHistoryRetainsAllCompletedRows() {
    let r = manager().merge(
      remoteItems: [], localItems: [local("0xaa", time: 1), local("0xbb", time: 2)])
    XCTAssertTrue(r.identifiersToRemove.isEmpty)
    XCTAssertEqual(r.historyItems.count, 2)
  }
}
private final class MergeRemote: WalletRemoteHistoryItemProtocol {
  let identifier: String, itemBlockNumber: UInt64, itemTimestamp: Int64
  var hash: String?, unsupported = false, addresses = [String](), networks = [SNAddressType]()
  var itemExtrinsicIndex: UInt16 { 0 }
  var extrinsicHash: String? { hash }
  var label: WalletRemoteHistorySourceLabel { .transfers }
  init(id: String, block: UInt64, time: Int64) {
    identifier = id
    hash = id
    itemBlockNumber = block
    itemTimestamp = time
  }
  func createTransactionForAddress(
    _ address: String, networkType: SNAddressType, asset: WalletAsset,
    addressFactory: SS58AddressFactoryProtocol
  ) -> AssetTransactionData? {
    addresses.append(address)
    networks.append(networkType)
    guard !unsupported else { return nil }
    return AssetTransactionData(
      transactionId: identifier, status: .commited, assetId: asset.identifier, peerId: address,
      peerFirstName: nil, peerLastName: nil, peerName: nil, details: "", amount: .init(value: 1),
      fees: [], timestamp: itemTimestamp, type: TransactionType.incoming.rawValue, reason: nil,
      context: nil)
  }
}
