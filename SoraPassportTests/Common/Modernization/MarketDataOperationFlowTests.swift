// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

final class MarketDataOperationFlowTests: XCTestCase {
  private var session: URLSession!, queues = [OperationQueue]()
  override func setUp() {
    super.setUp()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MarketDataFixtureProtocol.self]
    session = URLSession(configuration: config)
    MarketDataFixtureProtocol.reset()
  }
  override func tearDown() {
    session.invalidateAndCancel()
    queues.forEach { $0.cancelAllOperations() }
    queues = []
    super.tearDown()
  }
  private func run<T>(_ op: BaseOperation<T>) async throws -> T {
    guard let network = op as? NetworkOperation<T> else {
      throw NSError(domain: "fixture", code: 1)
    }
    network.networkSession = session
    let queue = OperationQueue()
    queues.append(queue)
    let done = expectation(description: "bounded market response")
    op.completionBlock = { done.fulfill() }
    queue.addOperation(op)
    await fulfillment(of: [done], timeout: 2)
    return try XCTUnwrap(op.result).get()
  }
  private func price(_ ids: [String] = ["sora"], body: String? = nil, status: Int = 200)
    async throws -> [PriceData]
  {
    MarketDataFixtureProtocol.reply =
      body
      ?? "{\"sora\":{\"usd\":1.23456789,\"usd_24h_change\":-2.5,\"last_updated_at\":\(Int(Date().timeIntervalSince1970))}}"
    MarketDataFixtureProtocol.status = status
    return try await run(CoingeckoOperationFactory().fetchPriceOperation(for: ids))
  }
  private func rejected(_ body: String, status: Int = 200) async {
    do {
      _ = try await price(body: body, status: status)
      XCTFail("Expected rejected quote")
    } catch {}
  }
  func testPriceFactoryPreservesExactDecimalAndNegativeDailyChange() async throws {
    let rows = try await price()
    let row = try XCTUnwrap(rows.first)
    XCTAssertEqual(row.price, "1.23456789")
    XCTAssertEqual(row.usdDayChange, Decimal(string: "-2.5"))
  }
  func testPriceFactoryUsesGetJsonAndAnExplicitTimeout() async throws {
    _ = try await price()
    let request = try XCTUnwrap(MarketDataFixtureProtocol.requests.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.timeoutInterval, 20)
  }
  func testPriceFactoryIncludesFreshnessAndDailyChangeFields() async throws {
    _ = try await price()
    let url = try XCTUnwrap(MarketDataFixtureProtocol.requests.first?.url)
    let q = Dictionary(
      uniqueKeysWithValues: try XCTUnwrap(
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      ).map { ($0.name, $0.value) })
    XCTAssertEqual(q["vs_currencies"], "usd")
    XCTAssertEqual(q["include_24hr_change"], "true")
    XCTAssertEqual(q["include_last_updated_at"], "true")
  }
  func testPriceRowsFollowTheRequestedAssetOrder() async throws {
    let t = Int(Date().timeIntervalSince1970)
    let rows = try await price(
      ["second", "first"],
      body:
        "{\"first\":{\"usd\":1,\"last_updated_at\":\(t)},\"second\":{\"usd\":2,\"last_updated_at\":\(t)}}"
    )
    XCTAssertEqual(rows.map(\.price), ["2", "1"])
  }
  func testTokenQuerySeparatorsCannotInjectAnExtraParameter() async throws {
    let id = "token&vs_currencies=eur"
    let t = Int(Date().timeIntervalSince1970)
    _ = try await price([id], body: "{\"\(id)\":{\"usd\":1,\"last_updated_at\":\(t)}}")
    let u = try XCTUnwrap(MarketDataFixtureProtocol.requests.first?.url)
    let q = try XCTUnwrap(URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems)
    XCTAssertEqual(q.filter { $0.name == "vs_currencies" }.map(\.value), ["usd"])
    XCTAssertEqual(q.first { $0.name == "ids" }?.value, id)
  }
  func testMissingRequestedPriceCannotProduceAPartialSuccess() async { await rejected("{}") }
  func testMissingFreshnessTimestampIsRejected() async { await rejected("{\"sora\":{\"usd\":1}}") }
  func testStaleQuoteIsRejected() async {
    await rejected(
      "{\"sora\":{\"usd\":1,\"last_updated_at\":\(Int(Date().timeIntervalSince1970)-1000)}}")
  }
  func testFutureQuoteIsRejected() async {
    await rejected(
      "{\"sora\":{\"usd\":1,\"last_updated_at\":\(Int(Date().timeIntervalSince1970)+120)}}")
  }
  func testZeroQuoteIsRejected() async {
    await rejected(
      "{\"sora\":{\"usd\":0,\"last_updated_at\":\(Int(Date().timeIntervalSince1970))}}")
  }
  func testNegativeQuoteIsRejected() async {
    await rejected(
      "{\"sora\":{\"usd\":-1,\"last_updated_at\":\(Int(Date().timeIntervalSince1970))}}")
  }
  func testMalformedJsonCannotProducePriceRows() async { await rejected("malformed") }
  func testHttpFailureCannotBeDecodedAsASuccessfulQuote() async {
    await rejected("{}", status: 503)
  }
  func testMissingDailyChangeIsPreservedAsUnknown() async throws {
    let rows = try await price(
      body: "{\"sora\":{\"usd\":1,\"last_updated_at\":\(Int(Date().timeIntervalSince1970))}}")
    XCTAssertNil(rows.first?.usdDayChange)
  }
  func testTransportFailurePropagatesAsAFailedPriceRead() async {
    MarketDataFixtureProtocol.failure = URLError(.timedOut)
    do {
      _ = try await price()
      XCTFail("Expected transport failure")
    } catch {}
  }
  private func phishing(_ body: String) async throws -> [PhishingItem] {
    MarketDataFixtureProtocol.reply = body
    return try await run(
      GitHubOperationFactory().fetchPhishingListOperation(
        URL(string: "https://fixture.invalid/phishing.json")!))
  }
  private func address(_ byte: UInt8, type: UInt16 = 69) throws -> String {
    try SS58AddressFactory().addressFromAccountId(
      data: Data(repeating: byte, count: 32), type: SNAddressType(type))
  }
  func testPhishingFactoryDecodesPublicKeysAndSourceNames() async throws {
    let a = try address(1)
    let rows = try await phishing("{\"fixture-source\":[\"\(a)\"]}")
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.source, "fixture-source")
    XCTAssertEqual(rows.first?.publicKey, Data(repeating: 1, count: 32).toHex())
  }
  func testPhishingFactorySupportsKnownAlternativeNetworkPrefixes() async throws {
    let a = try address(2, type: 42)
    let rows = try await phishing("{\"source\":[\"\(a)\"]}")
    XCTAssertEqual(rows.first?.publicKey, Data(repeating: 2, count: 32).toHex())
  }
  func testPhishingFactoryCannotTruncateAnExtendedNetworkPrefix() async throws {
    let a = try address(3, type: 1000)
    let rows = try await phishing("{\"source\":[\"\(a)\"]}")
    XCTAssertEqual(rows.first?.publicKey, Data(repeating: 3, count: 32).toHex())
  }
  func testPhishingFactoryPreservesAllSources() async throws {
    let a = try address(1)
    let b = try address(2)
    let rows = try await phishing("{\"a\":[\"\(a)\"],\"b\":[\"\(b)\"]}")
    XCTAssertEqual(Set(rows.map(\.source)), ["a", "b"])
  }
  func testPhishingFactoryRejectsMalformedJson() async {
    do {
      _ = try await phishing("{bad")
      XCTFail("Expected invalid list")
    } catch {}
  }
  func testPhishingFactoryRejectsAnInvalidAddress() async {
    do {
      _ = try await phishing("{\"source\":[\"bad-address\"]}")
      XCTFail("Expected invalid address")
    } catch {}
  }
  func testPhishingFactoryPreservesAnExplicitEmptyList() async throws {
    let rows = try await phishing("{}")
    XCTAssertTrue(rows.isEmpty)
  }
}
private final class MarketDataFixtureProtocol: URLProtocol {
  static let lock = NSLock()
  static var reply = "{}", status = 200
  static var failure: Error?
  private static var captured = [URLRequest]()
  static var requests: [URLRequest] {
    lock.lock()
    defer { lock.unlock() }
    return captured
  }
  static func reset() {
    lock.lock()
    defer { lock.unlock() }
    captured = []
    reply = "{}"
    status = 200
    failure = nil
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock()
    Self.captured.append(request)
    let body = Self.reply
    let status = Self.status
    let error = Self.failure
    Self.lock.unlock()
    if let error {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: nil,
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
