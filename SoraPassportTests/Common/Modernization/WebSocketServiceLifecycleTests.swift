// SPDX-License-Identifier: Apache-2.0
import Foundation
import SSFUtils
import SoraFoundation
import Starscream
import XCTest

@testable import SoraPassport

private final class SocketLifecycleConnection: WebSocketConnectionProtocol {
  let engine: Engine = WSEngine(transport: TCPTransport(), certPinner: FoundationSecurity())
  let callbackQueue = DispatchQueue(label: "socket-lifecycle-fixture")
  weak var delegate: WebSocketDelegate?
  var connects = 0, disconnects = 0
  func connect() { connects += 1 }
  func disconnect(closeCode: UInt16) { disconnects += 1 }
  func forceDisconnect() { disconnects += 1 }
  func write(string: String, completion: (() -> Void)?) { completion?() }
  func write(stringData: Data, completion: (() -> Void)?) { completion?() }
  func write(data: Data, completion: (() -> Void)?) { completion?() }
  func write(ping: Data, completion: (() -> Void)?) { completion?() }
  func write(pong: Data, completion: (() -> Void)?) { completion?() }
}

private final class SocketLifecycleReachability: SSFUtils.ReachabilityManagerProtocol {
 var isReachable: Bool { true }
 func add(listener: SSFUtils.ReachabilityListenerDelegate) throws {}
 func remove(listener: SSFUtils.ReachabilityListenerDelegate) {}
}

/// Release builds log warnings and errors, so those levels must never carry
/// node response text: only its size or request id. Debug keeps the detail.
final class WebSocketEngineLogPrivacyTests: XCTestCase {
  private let address = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
  private func makeEngine() -> (WebSocketEngine, SocketLifecycleConnection, SocketLogRecorder) {
    let logger = SocketLogRecorder()
    let engine = WebSocketEngine(
      connectionName: nil, url: URL(string: "ws://127.0.0.1:9")!,
      reachabilityManager: SocketLifecycleReachability(), reconnectionStrategy: nil,
      autoconnect: false, pingInterval: 0, logger: logger)
    let connection = SocketLifecycleConnection()
    engine.connection = connection
    connection.delegate = engine
    return (engine, connection, logger)
  }
  func testUnparsableNodeResponseReachesReleaseLevelsBySizeOnly() {
    let (engine, connection, logger) = makeEngine()
    let response = #"{"jsonrpc":"2.0","method":"state_storage","params":{"subscription":7,"result":"\#(address) 1234.5678 XOR"}}"#
    engine.didReceive(event: .text(response), client: connection)
    engine.didReceive(event: .binary(Data(response.utf8)), client: connection)
    let expected = "Can't parse data of \(response.utf8.count) bytes"
    XCTAssertEqual(logger.releaseMessages, [expected, expected])
    XCTAssertTrue(logger.debugMessages.contains("Can't parse data: \(response)"))
  }
  func testUnparsableSubscriptionResponseReachesReleaseLevelsByRequestIdAndSize() {
    let (engine, connection, logger) = makeEngine()
    let failed = expectation(description: "subscription failure delivered")
    engine.addSubscription(JSONRPCSubscription<String>(
      requestId: 42, requestData: Data(), requestOptions: JSONRPCOptions(),
      updateClosure: { _ in XCTFail("The response has no subscription id") },
      failureClosure: { _, unsubscribed in
        XCTAssertTrue(unsubscribed)
        failed.fulfill()
      }))
    let response = #"{"jsonrpc":"2.0","id":42,"result":{"address":"\#(address)","free":"1234.5678"}}"#
    engine.didReceive(event: .text(response), client: connection)
    wait(for: [failed], timeout: 10)
    XCTAssertEqual(
      logger.releaseMessages,
      ["Did fail to parse subscription data for request 42 (\(response.utf8.count) bytes)"])
    XCTAssertTrue(logger.debugMessages.contains("Did fail to parse subscription data: \(response)"))
  }
  func testReleaseLevelsNeverContainTheResponseText() {
    let (engine, connection, logger) = makeEngine()
    engine.addSubscription(JSONRPCSubscription<String>(
      requestId: 7, requestData: Data(), requestOptions: JSONRPCOptions(),
      updateClosure: { _ in }, failureClosure: { _, _ in }))
    for response in [
      #"{"jsonrpc":"2.0","id":7,"result":["\#(address)"]}"#,
      #"{"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"result":"\#(address)"}}"#,
      "\(address) not json",
    ] {
      engine.didReceive(event: .text(response), client: connection)
    }
    XCTAssertEqual(logger.releaseMessages.count, 3)
    XCTAssertFalse(logger.releaseMessages.contains { $0.contains(address) || $0.contains("result") })
    XCTAssertEqual(logger.debugMessages.filter { $0.contains(address) }.count, 6, "Each text is kept at debug level")
  }
}
private final class SocketLogRecorder: SDKLoggerProtocol {
  private let lock = NSLock()
  private var entries = [(level: String, message: String)]()
  /// What a release build keeps.
  var releaseMessages: [String] { messages(at: ["warning", "error"]) }
  var debugMessages: [String] { messages(at: ["debug"]) }
  func verbose(message: String, file: String, function: String, line: Int) { record("verbose", message) }
  func debug(message: String, file: String, function: String, line: Int) { record("debug", message) }
  func info(message: String, file: String, function: String, line: Int) { record("info", message) }
  func warning(message: String, file: String, function: String, line: Int) { record("warning", message) }
  func error(message: String, file: String, function: String, line: Int) { record("error", message) }
  private func record(_ level: String, _ message: String) {
    lock.lock()
    entries.append((level, message))
    lock.unlock()
  }
  private func messages(at levels: Set<String>) -> [String] {
    lock.lock()
    defer { lock.unlock() }
    return entries.filter { levels.contains($0.level) }.map(\.message)
  }
}
