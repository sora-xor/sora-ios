// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import XCTest

@testable import SoraPassport

final class WalletServiceDispatchFlowTests: XCTestCase {
  private let marker = DispatchSpecificKey<String>()
  private var operationQueues = [OperationQueue]()
  override func tearDown() {
    operationQueues.forEach {
      $0.isSuspended = false
      $0.cancelAllOperations()
    }
    operationQueues = []
    super.tearDown()
  }
  private func make() -> (WalletService, WalletNetworkOperationFactoryProtocolMock, DispatchQueue) {
    let factory = WalletNetworkOperationFactoryProtocolMock()
    let operations = OperationQueue()
    let callbacks = DispatchQueue(label: "wallet-service-callback-fixture")
    callbacks.setSpecific(key: marker, value: "callback")
    operationQueues.append(operations)
    return (
      WalletService(operationFactory: factory, operationQueue: operations), factory, callbacks
    )
  }
  private func wrapper<T>(_ value: T) -> CompoundOperationWrapper<T> {
    CompoundOperationWrapper(targetOperation: ClosureOperation { value })
  }
  private func failure<T>() -> CompoundOperationWrapper<T> {
    CompoundOperationWrapper(targetOperation: ClosureOperation { throw DispatchFlowError.offline })
  }
  private var transfer: TransferInfo {
    TransferInfo(
      source: "sender", destination: "recipient",
      amount: AmountDecimal(string: "1.000000000000000001")!, asset: "asset", details: "memo",
      fees: [], context: ["key": "value"])
  }
  func testBalanceReadPreservesExactValuesAndUsesRequestedCallbackQueue() async {
    let (s, f, q) = make()
    let done = expectation(description: "balance")
    let expected = BalanceData(
      identifier: "asset", balance: AmountDecimal(string: "0.000000000000000001")!)
    f.balanceClosure = { ids in
      XCTAssertEqual(ids, ["asset"])
      return self.wrapper([expected])
    }
    s.fetchBalance(for: ["asset"], runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertEqual(try? result?.get(), [expected])
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testHistoryReadPreservesFilterAndPaginationCursor() async {
    let (s, f, q) = make()
    let done = expectation(description: "history")
    var filter = WalletHistoryRequest(assets: ["asset"])
    filter.filter = "recipient"
    filter.type = "transfer"
    let page = Pagination(count: 7, context: ["cursor": "next"])
    f.historyClosure = { request, pagination in
      XCTAssertEqual(request, filter)
      XCTAssertEqual(pagination, page)
      return self.wrapper(nil)
    }
    s.fetchTransactionHistory(for: filter, pagination: page, runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .success(nil)? = result else {
        done.fulfill()
        return XCTFail("Authoritative empty history changed")
      }
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testTransferMetadataCarriesTheBoundAssetSenderAndReceiver() async {
    let (s, f, q) = make()
    let done = expectation(description: "metadata")
    let info = TransferMetadataInfo(assetId: "asset", sender: "sender", receiver: "receiver")
    f.transferMetadataClosure = { value in
      XCTAssertEqual(value.assetId, "asset")
      XCTAssertEqual(value.sender, "sender")
      XCTAssertEqual(value.receiver, "receiver")
      return self.wrapper(nil)
    }
    s.fetchTransferMetadata(for: info, runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertNotNil(result)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testTransferPassesExactIntentAndReturnsTheTransportBytes() async {
    let (s, f, q) = make()
    let done = expectation(description: "transfer")
    f.transferClosure = { info in
      XCTAssertEqual(info.source, "sender")
      XCTAssertEqual(info.destination, "recipient")
      XCTAssertEqual(info.amount.decimalValue, Decimal(string: "1.000000000000000001"))
      XCTAssertEqual(info.context, ["key": "value"])
      return self.wrapper(Data([1, 2, 3]))
    }
    s.transfer(info: transfer, runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertEqual(try? result?.get(), Data([1, 2, 3]))
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testSearchPreservesTheWholeQueryAndRunsCompletionOnRequestedQueue() async {
    let (s, f, q) = make()
    let done = expectation(description: "search")
    f.searchClosure = { text in
      XCTAssertEqual(text, "name with spaces")
      return self.wrapper([])
    }
    s.search(for: "name with spaces", runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertEqual((try? result?.get())?.count, 0)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testContactsCompletesOnTheRequestedQueue() async {
    let (s, f, q) = make()
    let done = expectation(description: "contacts")
    f.contactsClosure = { self.wrapper([]) }
    s.fetchContacts(runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertEqual((try? result?.get())?.count, 0)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testWithdrawalMetadataPreservesTheSelectedOption() async {
    let (s, f, q) = make()
    let done = expectation(description: "withdraw metadata")
    f.withdrawMetadataClosure = { info in
      XCTAssertEqual(info.assetId, "asset")
      XCTAssertEqual(info.option, "target-network")
      return self.wrapper(nil)
    }
    s.fetchWithdrawalMetadata(
      for: WithdrawMetadataInfo(assetId: "asset", option: "target-network"), runCompletionIn: q
    ) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertNotNil(result)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testWithdrawalPreservesDestinationAndExactAmount() async {
    let (s, f, q) = make()
    let done = expectation(description: "withdraw")
    f.withdrawClosure = { info in
      XCTAssertEqual(info.destinationAccountId, "destination")
      XCTAssertEqual(info.assetId, "asset")
      XCTAssertEqual(info.amount.decimalValue, Decimal(string: "0.000000000000000001"))
      XCTAssertEqual(info.details, "memo")
      return self.wrapper(Data([4, 5]))
    }
    s.withdraw(
      info: WithdrawInfo(
        destinationAccountId: "destination", assetId: "asset",
        amount: AmountDecimal(string: "0.000000000000000001")!, details: "memo", fees: []),
      runCompletionIn: q
    ) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      XCTAssertEqual(try? result?.get(), Data([4, 5]))
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testBalanceDependencyCompletesBeforeTheTargetRead() async {
    let (s, f, q) = make()
    let done = expectation(description: "dependencies")
    var value = 0
    let dependency = ClosureOperation { value = 42 }
    let target = ClosureOperation<[BalanceData]?> {
      XCTAssertEqual(value, 42)
      return []
    }
    target.addDependency(dependency)
    f.balanceClosure = { _ in
      CompoundOperationWrapper(targetOperation: target, dependencies: [dependency])
    }
    s.fetchBalance(for: [], runCompletionIn: q) { result in
      XCTAssertNotNil(result)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
    XCTAssertTrue(dependency.isFinished)
  }
  func testCancellingQueuedBalanceCancelsItsDependenciesWithoutReading() async {
    let (s, f, q) = make()
    let done = expectation(description: "cancelled")
    s.operationQueue.isSuspended = true
    let dependency = ClosureOperation<Void> { XCTFail("Cancelled dependency executed") }
    let target = ClosureOperation<[BalanceData]?> {
      XCTFail("Cancelled balance read executed")
      return []
    }
    target.addDependency(dependency)
    f.balanceClosure = { _ in
      CompoundOperationWrapper(targetOperation: target, dependencies: [dependency])
    }
    let call = s.fetchBalance(for: [], runCompletionIn: q) { _ in done.fulfill() }
    call.cancel()
    s.operationQueue.isSuspended = false
    await fulfillment(of: [done], timeout: 2)
    XCTAssertTrue(target.isCancelled)
    XCTAssertTrue(dependency.isCancelled)
  }
  func testBalanceFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.balanceClosure = { _ in self.failure() }
    s.fetchBalance(for: [], runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testHistoryFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.historyClosure = { _, _ in self.failure() }
    s.fetchTransactionHistory(
      for: WalletHistoryRequest(), pagination: Pagination(count: 7), runCompletionIn: q
    ) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testTransferMetadataFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.transferMetadataClosure = { _ in self.failure() }
    s.fetchTransferMetadata(
      for: TransferMetadataInfo(assetId: "asset", sender: "sender", receiver: "receiver"),
      runCompletionIn: q
    ) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testTransferFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.transferClosure = { _ in self.failure() }
    s.transfer(info: transfer, runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testSearchFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.searchClosure = { _ in self.failure() }
    s.search(for: "name", runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testContactsFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.contactsClosure = { self.failure() }
    s.fetchContacts(runCompletionIn: q) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testWithdrawalMetadataFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.withdrawMetadataClosure = { _ in self.failure() }
    s.fetchWithdrawalMetadata(
      for: WithdrawMetadataInfo(assetId: "asset", option: "network"), runCompletionIn: q
    ) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
  func testWithdrawalFailurePreservesTheOriginalError() async {
    let (s, f, q) = make()
    let done = expectation(description: "failure")
    f.withdrawClosure = { _ in self.failure() }
    s.withdraw(
      info: WithdrawInfo(
        destinationAccountId: "destination", assetId: "asset", amount: AmountDecimal(value: 1),
        details: "", fees: []), runCompletionIn: q
    ) { result in
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.marker), "callback")
      guard case .failure(let error)? = result else {
        done.fulfill()
        return XCTFail("Failure became success")
      }
      XCTAssertTrue(error is DispatchFlowError)
      done.fulfill()
    }
    await fulfillment(of: [done], timeout: 2)
  }
}
private enum DispatchFlowError: Error { case offline }
