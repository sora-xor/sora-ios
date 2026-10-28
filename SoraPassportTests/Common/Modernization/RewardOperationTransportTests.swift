// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

final class RewardOperationTransportTests: XCTestCase {
  private var session: URLSession!, queues = [OperationQueue]()
  private let endpoint = URL(string: "https://reward-fixture.invalid/graphql")!
  override func setUp() {
    super.setUp()
    RewardTransportFixture.reset()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RewardTransportFixture.self]
    session = URLSession(configuration: config)
  }
  override func tearDown() {
    session.invalidateAndCancel()
    queues.forEach { $0.cancelAllOperations() }
    queues = []
    super.tearDown()
  }
  private var rewardBody: String {
    #"{"data":{"historyElements":{"nodes":[{"id":"reward-1","timestamp":"1700000000","address":"owner","blockHash":"0xblock","networkFee":"0","execution":{"success":true},"data":{"amount":"9007199254740993123456789","isReward":true,"era":7,"validator":"validator"}}]}}}"#
  }
  private var referralBody: String {
    #"{"data":{"referrerRewards":{"pageInfo":{"hasNextPage":false,"endCursor":"last"},"nodes":[{"id":"referral-1","timestamp":"1700000000","blockHeight":"9007199254740993","referral":"friend","referrer":"owner","amount":"1.000000000000000001"}]}}}"#
  }
  private func run<T>(_ op: BaseOperation<T>, body: String, status: Int = 200) async throws -> T {
    let network = try XCTUnwrap(op as? NetworkOperation<T>)
    network.networkSession = session
    RewardTransportFixture.body = body
    RewardTransportFixture.status = status
    let q = OperationQueue()
    queues.append(q)
    let done = expectation(description: "reward response")
    op.completionBlock = { done.fulfill() }
    q.addOperation(op)
    await fulfillment(of: [done], timeout: 2)
    return try XCTUnwrap(op.result).get()
  }
  private func reward(_ body: String? = nil, address: String = "owner", status: Int = 200)
    async throws -> SubqueryRewardOrSlashData
  {
    try await run(
      SubqueryRewardOperationFactory(url: endpoint).createOperation(address: address),
      body: body ?? rewardBody, status: status)
  }
  private func referral(_ body: String? = nil, address: String = "owner", status: Int = 200)
    async throws -> SubqueryReferrerRewardsData
  {
    try await run(
      SubqueryReferrerRewardsOperationFactory(url: endpoint).createOperation(referrer: address),
      body: body ?? referralBody, status: status)
  }
  private func object() throws -> [String: Any] {
    try XCTUnwrap(
      try JSONSerialization.jsonObject(with: XCTUnwrap(RewardTransportFixture.lastBody))
        as? [String: Any])
  }
  private func reject(
    _ block: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line
  ) async {
    do {
      try await block()
      XCTFail("Incomplete rewards accepted", file: file, line: line)
    } catch {}
  }
  func testRewardFactoryPreservesExactAtomicAmountAndEra() async throws {
    let response = try await reward()
    let r = try XCTUnwrap(response.historyElements.nodes.first)
    let data = try r.data.map(to: SubqueryRewardOrSlash.self)
    XCTAssertEqual(r.identifier, "reward-1")
    XCTAssertEqual(data.amount, "9007199254740993123456789")
    XCTAssertEqual(data.era, 7)
    XCTAssertTrue(data.isReward)
  }
  func testRewardQueryRequestsEveryRequiredHistoryField() async throws {
    _ = try await reward()
    let q = try XCTUnwrap(object()["query"] as? String)
    for key in ["blockHash", "networkFee", "data", "execution"] {
      XCTAssertTrue(q.contains(key), key)
    }
  }

  func testRewardQueryUsesPostJsonAndRequestedEndpoint() async throws {
    _ = try await reward()
    let r = try XCTUnwrap(RewardTransportFixture.request)
    XCTAssertEqual(r.url, endpoint)
    XCTAssertEqual(r.httpMethod, "POST")
    XCTAssertEqual(r.value(forHTTPHeaderField: "Content-Type"), "application/json")
  }
  func testRewardQueryRequestsDescendingHistoryAndNonNullRewards() async throws {
    _ = try await reward()
    let q = try XCTUnwrap(object()["query"] as? String)
    XCTAssertTrue(q.contains("TIMESTAMP_DESC"))
    XCTAssertTrue(q.contains("reward: { isNull: false }"))
    XCTAssertTrue(q.contains("equalTo: \"owner\""))
  }
  func testRewardAddressCannotBreakOutOfItsGraphQLString() async throws {
    let address = "owner\"}\n injected{value"
    _ = try await reward(address: address)
    let q = try XCTUnwrap(object()["query"] as? String)
    let escaped = String(data: try JSONEncoder().encode(address), encoding: .utf8)!
    XCTAssertTrue(q.contains(escaped))
    XCTAssertFalse(q.contains("\ninjected"))
  }
  func testEmptyRewardHistoryIsAValidEmptyResult() async throws {
    let r = try await reward(#"{"data":{"historyElements":{"nodes":[]}}}"#)
    XCTAssertTrue(r.historyElements.nodes.isEmpty)
  }
  func testRewardGraphQLErrorIsPropagated() async {
    await reject { _ = try await self.reward(#"{"errors":[{"message":"offline"}]}"#) }
  }
  func testRewardPartialDataWithErrorsIsNotPresentedAsComplete() async {
    await reject {
      _ = try await self.reward(
        #"{"data":{"historyElements":{"nodes":[]}},"errors":[{"message":"incomplete"}]}"#)
    }
  }
  func testRewardMalformedEnvelopeFails() async { await reject { _ = try await self.reward("{}") } }
  func testRewardHttpFailureCannotLookLikeEmptyHistory() async {
    await reject { _ = try await self.reward(status: 503) }
  }
  func testRewardTransportFailurePropagates() async {
    RewardTransportFixture.failure = URLError(.notConnectedToInternet)
    await reject { _ = try await self.reward() }
  }
  func testReferralFactoryPreservesExactAmountAndPublicAttribution() async throws {
    let r = try await referral().referrerRewards.nodes.first
    XCTAssertEqual(r?.identifier, "referral-1")
    XCTAssertEqual(r?.amount.decimalValue, Decimal(string: "1.000000000000000001"))
    XCTAssertEqual(r?.blockHeight, "9007199254740993")
    XCTAssertEqual(r?.referral, "friend")
    XCTAssertEqual(r?.referrer, "owner")
  }
  func testReferralQueryUsesPostJson() async throws {
    _ = try await referral()
    let r = try XCTUnwrap(RewardTransportFixture.request)
    XCTAssertEqual(r.url, endpoint)
    XCTAssertEqual(r.httpMethod, "POST")
    XCTAssertEqual(r.value(forHTTPHeaderField: "Content-Type"), "application/json")
  }
  func testReferralQueryIncludesItsPaginationMetadata() async throws {
    let r = try await referral()
    XCTAssertFalse(r.referrerRewards.pageInfo.hasNextPage)
    XCTAssertEqual(r.referrerRewards.pageInfo.endCursor, "last")
    let q = try XCTUnwrap(object()["query"] as? String)
    XCTAssertTrue(q.contains("hasNextPage"))
    XCTAssertTrue(q.contains("equalTo: \"owner\""))
  }
  func testReferrerCannotBreakOutOfItsGraphQLString() async throws {
    let address = "owner\\\"\nnext"
    _ = try await referral(address: address)
    let q = try XCTUnwrap(object()["query"] as? String)
    XCTAssertTrue(q.contains(String(data: try JSONEncoder().encode(address), encoding: .utf8)!))
  }
  func testEmptyReferralHistoryPreservesEmptyPagination() async throws {
    let r = try await referral(
      #"{"data":{"referrerRewards":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}"#
    )
    XCTAssertTrue(r.referrerRewards.nodes.isEmpty)
    XCTAssertNil(r.referrerRewards.pageInfo.endCursor)
  }
  func testReferralGraphQLErrorIsPropagated() async {
    await reject { _ = try await self.referral(#"{"errors":[{"message":"offline"}]}"#) }
  }
  func testReferralPartialDataWithErrorsIsNotPresentedAsComplete() async {
    await reject {
      _ = try await self.referral(
        #"{"data":{"referrerRewards":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}},"errors":[{"message":"incomplete"}]}"#
      )
    }
  }
  func testReferralMalformedEnvelopeFails() async {
    await reject { _ = try await self.referral("{broken") }
  }
  func testReferralHttpFailureCannotLookLikeEmptyHistory() async {
    await reject { _ = try await self.referral(status: 503) }
  }
  func testReferralTransportFailurePropagates() async {
    RewardTransportFixture.failure = URLError(.timedOut)
    await reject { _ = try await self.referral() }
  }
}
private final class RewardTransportFixture: URLProtocol {
  static var body = "{}", status = 200, failure: Error?, request: URLRequest?, lastBody: Data?
  static func reset() {
    body = "{}"
    status = 200
    failure = nil
    request = nil
    lastBody = nil
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.request = request
    var data = request.httpBody ?? Data()
    if data.isEmpty, let s = request.httpBodyStream {
      s.open()
      defer { s.close() }
      var b = [UInt8](repeating: 0, count: 4096)
      while s.hasBytesAvailable {
        let n = s.read(&b, maxLength: b.count)
        if n <= 0 { break }
        data.append(b, count: n)
      }
    }
    Self.lastBody = data
    if let failure = Self.failure {
      client?.urlProtocol(self, didFailWithError: failure)
      return
    }
    let r = HTTPURLResponse(
      url: request.url!, statusCode: Self.status, httpVersion: nil,
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: r, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
