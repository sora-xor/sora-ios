// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import XCTest
import sorawallet

@testable import SoraPassport

final class HistoryTransactionMappingFlowTests: XCTestCase {
  private let owner = "history-owner"
  private func mapper() -> HistoryTransactionMapper {
    HistoryTransactionMapper(myAddress: owner, assets: [])
  }
  private func params(_ values: [String: String]) -> [TxHistoryItemParam] {
    values.map { .init(paramName: $0.key, paramValue: $0.value) }
  }
  private func item(
    _ path: KmmCallCodingPath, _ values: [String: String]? = [:], success: Bool = true,
    nested: [TxHistoryItemNested]? = nil
  ) -> TxHistoryItem {
    TxHistoryItem(
      id: "0xtransaction", blockHash: "0xblock", module: path.moduleName, method: path.callName,
      timestamp: "1700000000", networkFee: "1000000000000000", success: success, data: values.map(params),
      nestedData: nested)
  }
  private func mapped<T>(_ type: T.Type, _ item: TxHistoryItem) throws -> T {
    try XCTUnwrap(try mapper().map(items: [item]).first as? T)
  }
  private var transfer: [String: String] {
    ["from": owner, "to": "peer", "amount": "1.000000000000000001", "assetId": "VAL"]
  }
  private var swap: [String: String] {
    [
      "baseAssetId": "XOR", "targetAssetId": "VAL", "baseAssetAmount": "2.5",
      "targetAssetAmount": "7.25", "selectedMarket": "XYKPool",
    ]
  }
  private var liquidity: [String: String] {
    [
      "baseAssetId": "XOR", "targetAssetId": "VAL", "baseAssetAmount": "2.5",
      "targetAssetAmount": "7.25",
    ]
  }
  private var farm: [String: String] {
    ["baseAssetId": "XOR", "assetId": "VAL", "rewardAssetId": "PSWAP", "amount": "12.5"]
  }
  private func nested(_ method: String, module: String = "poolXYK") -> TxHistoryItemNested {
    .init(
      module: module, method: method, hash: "0xnested",
      data: params([
        "input_asset_a": "XOR", "input_asset_b": "VAL", "input_a_desired": "2.5",
        "input_b_desired": "7.25",
      ]))
  }
  func testOutgoingTransferPreservesExactAmountAndPeer() throws {
    let tx = try mapped(TransferTransaction.self, item(.transfer, transfer))
    XCTAssertEqual(tx.amount.decimalValue, Decimal(string: "1.000000000000000001"))
    XCTAssertEqual(tx.peer, "peer")
    XCTAssertEqual(tx.tokenId, "VAL")
    XCTAssertEqual(tx.transferType, .outcoming)
  }
  func testIncomingTransferUsesSenderAsPeer() throws {
    let tx = try mapped(
      TransferTransaction.self,
      item(.transfer, ["from": "peer", "to": owner, "amount": "1", "assetId": "VAL"]))
    XCTAssertEqual(tx.peer, "peer")
    XCTAssertEqual(tx.transferType, .incoming)
  }
  func testKeepAliveTransferUsesTheSameMapping() throws {
    XCTAssertEqual(
      try mapped(TransferTransaction.self, item(.transferKeepAlive, transfer)).tokenId, "VAL")
  }
  func testCapitalizedTransferUsesTheSameMapping() throws {
    XCTAssertEqual(
      try mapped(TransferTransaction.self, item(.adarTransfer, transfer)).tokenId, "VAL")
  }
  func testBaseTransactionPreservesHashBlockTimestampAndFee() throws {
    let tx = try mapped(TransferTransaction.self, item(.transfer, transfer))
    XCTAssertEqual(tx.base.txHash, "0xtransaction")
    XCTAssertEqual(tx.base.blockHash, "0xblock")
    XCTAssertEqual(tx.base.timestamp, "1700000000")
    XCTAssertEqual(tx.base.fee.decimalValue, Decimal(string: "1000000000000000"))
    XCTAssertEqual(tx.base.status, .success)
  }
  func testFailedCallRemainsFailed() throws {
    XCTAssertEqual(
      try mapped(TransferTransaction.self, item(.transfer, transfer, success: false)).base.status,
      .failed)
  }
  func testReferralBondAndUnbondRetainTheirKinds() throws {
    let bond = try mapped(
      ReferralBondTransaction.self, item(.bondReferralBalance, ["amount": "12.5"]))
    let unbond = try mapped(
      ReferralBondTransaction.self, item(.unbondReferralBalance, ["amount": "12.5"]))
    XCTAssertEqual(bond.type, .bond)
    XCTAssertEqual(unbond.type, .unbond)
    XCTAssertEqual(bond.amount.decimalValue, Decimal(string: "12.5"))
  }
  func testOwnReferrerUsesDestination() throws {
    let tx = try mapped(
      SetReferrerTransaction.self, item(.setReferral, ["from": owner, "to": "referrer"]))
    XCTAssertTrue(tx.isMyReferrer)
    XCTAssertEqual(tx.who, "referrer")
  }
  func testReferralFromAnotherAccountUsesSender() throws {
    let tx = try mapped(
      SetReferrerTransaction.self, item(.setReferral, ["from": "referral", "to": owner]))
    XCTAssertFalse(tx.isMyReferrer)
    XCTAssertEqual(tx.who, "referral")
  }
  func testSwapPreservesBothTokenAndAmountAssociations() throws {
    let tx = try mapped(Swap.self, item(.swap, swap))
    XCTAssertEqual(tx.fromTokenId, "XOR")
    XCTAssertEqual(tx.toTokenId, "VAL")
    XCTAssertEqual(tx.fromAmount.decimalValue, Decimal(string: "2.5"))
    XCTAssertEqual(tx.toAmount.decimalValue, Decimal(string: "7.25"))
  }
  func testUnknownSwapMarketFallsBackToSmart() throws {
    var fields = swap
    fields["selectedMarket"] = "unknown"
    XCTAssertEqual(try mapped(Swap.self, item(.swap, fields)).market, .smart)
  }
  func testDepositLiquidityKeepsAmountsWithTheirOriginalTokens() throws {
    let tx = try mapped(Liquidity.self, item(.depositLiquidity, liquidity))
    XCTAssertEqual(tx.firstTokenId, "XOR")
    XCTAssertEqual(tx.firstAmount.decimalValue, Decimal(string: "2.5"))
    XCTAssertEqual(tx.secondTokenId, "VAL")
    XCTAssertEqual(tx.secondAmount.decimalValue, Decimal(string: "7.25"))
    XCTAssertEqual(tx.type, .add)
  }
  func testWithdrawLiquidityKeepsAmountsWithTheirOriginalTokens() throws {
    let tx = try mapped(Liquidity.self, item(.withdrawLiquidity, liquidity))
    XCTAssertEqual(tx.firstTokenId, "XOR")
    XCTAssertEqual(tx.secondTokenId, "VAL")
    XCTAssertEqual(tx.type, .withdraw)
  }
  func testFarmDepositUsesTheAccountWhoseHistoryWasRequested() throws {
    let tx = try mapped(FarmLiquidity.self, item(.farmDeposit, farm))
    XCTAssertEqual(tx.sender, owner)
    XCTAssertEqual(tx.firstTokenId, "XOR")
    XCTAssertEqual(tx.secondTokenId, "VAL")
    XCTAssertEqual(tx.rewardTokenId, "PSWAP")
    XCTAssertEqual(tx.type, .add)
  }
  func testFarmWithdrawUsesTheRequestedAccountAndExactAmount() throws {
    let tx = try mapped(FarmLiquidity.self, item(.farmWithdraw, farm))
    XCTAssertEqual(tx.sender, owner)
    XCTAssertEqual(tx.amount.decimalValue, Decimal(string: "12.5"))
    XCTAssertEqual(tx.type, .withdraw)
  }
  func testRewardClaimUsesTheRequestedHistoryAccount() throws {
    let tx = try mapped(
      ClaimReward.self, item(.getRewards, ["amount": "3.25", "assetId": "PSWAP"]))
    XCTAssertEqual(tx.peer, owner)
    XCTAssertEqual(tx.rewardTokenId, "PSWAP")
    XCTAssertEqual(tx.amount.decimalValue, Decimal(string: "3.25"))
  }
  func testBatchDepositMapsItsNestedAmounts() throws {
    let tx = try mapped(Liquidity.self, item(.batchUtility, nested: [nested("depositLiquidity")]))
    XCTAssertEqual(tx.firstTokenId, "XOR")
    XCTAssertEqual(tx.secondTokenId, "VAL")
    XCTAssertEqual(tx.firstAmount.decimalValue, Decimal(string: "2.5"))
    XCTAssertEqual(tx.type, .add)
  }
  func testAtomicBatchDepositMapsItsNestedAmounts() throws {
    XCTAssertEqual(
      try mapped(Liquidity.self, item(.batchAllUtility, nested: [nested("depositLiquidity")])).type,
      .add)
  }
  func testBatchWithdrawalMapsItsNestedAmounts() throws {
    let tx = try mapped(Liquidity.self, item(.batchUtility, nested: [nested("withdrawLiquidity")]))
    XCTAssertEqual(tx.firstTokenId, "XOR")
    XCTAssertEqual(tx.secondAmount.decimalValue, Decimal(string: "7.25"))
    XCTAssertEqual(tx.type, .withdraw)
  }
  func testAtomicBatchWithdrawalMapsItsNestedAmounts() throws {
    XCTAssertEqual(
      try mapped(Liquidity.self, item(.batchAllUtility, nested: [nested("withdrawLiquidity")]))
        .type, .withdraw)
  }
  func testForeignNestedModuleCannotMasqueradeAsPoolLiquidity() throws {
    XCTAssertTrue(
      try mapper().map(items: [
        item(.batchUtility, nested: [nested("depositLiquidity", module: "unknown")])
      ]).isEmpty)
  }
  func testUnsupportedCallProducesNoFakeTransaction() throws {
    XCTAssertTrue(
      try mapper().map(items: [item(.init(moduleName: "system", callName: "remark"))]).isEmpty)
  }
  func testEmptyBatchProducesNoFakeLiquidity() throws {
    XCTAssertTrue(try mapper().map(items: [item(.batchUtility, nested: [])]).isEmpty)
  }
  func testMissingDataForKnownCallIsRejected() {
    for path in [
      KmmCallCodingPath.transfer, .bondReferralBalance, .unbondReferralBalance, .setReferral, .swap,
      .depositLiquidity, .withdrawLiquidity, .getRewards, .farmDeposit, .farmWithdraw,
    ] { XCTAssertThrowsError(try mapper().map(items: [item(path, nil)]), path.callName) }
  }
  func testEveryAmountBearingCallRejectsMalformedAmounts() {
    for path in [
      KmmCallCodingPath.transfer, .bondReferralBalance, .unbondReferralBalance, .getRewards,
      .farmDeposit, .farmWithdraw,
    ] {
      var f = transfer.merging(farm) { _, n in n }
      f["amount"] = "1trailing"
      XCTAssertThrowsError(try mapper().map(items: [item(path, f)]), path.callName)
    }
  }
  func testSwapValidatesTheSecondAmount() {
    var f = swap
    f["targetAssetAmount"] = "-1"
    XCTAssertThrowsError(try mapper().map(items: [item(.swap, f)]))
  }
  func testLiquidityValidatesTheSecondAmount() {
    var f = liquidity
    f["targetAssetAmount"] = "NaN"
    XCTAssertThrowsError(try mapper().map(items: [item(.depositLiquidity, f)]))
  }
  func testMappingPreservesSourceOrderWithoutDroppingKnownRows() throws {
    let rows = try mapper().map(items: [
      item(.transfer, transfer), item(.getRewards, ["amount": "1", "assetId": "PSWAP"]),
    ])
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(rows[0] is TransferTransaction)
    XCTAssertTrue(rows[1] is ClaimReward)
  }
}
