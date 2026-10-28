// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import SSFUtils
import SoraFoundation
import Starscream
import XCTest

@testable import SoraPassport

@MainActor
final class WebSocketServiceLifecycleTests: XCTestCase {
  private var fixtures = [SocketLifecycleFixture]()
  private func make() -> SocketLifecycleFixture {
    let f = SocketLifecycleFixture()
    fixtures.append(f)
    return f
  }
  override func tearDown() {
    fixtures.forEach { $0.service.throttle() }
    fixtures.removeAll()
    super.tearDown()
  }
  private func drain() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
  }
  func testInitialServiceDoesNotCreateAConnectionUntilSetup() {
    let f = make()
    XCTAssertTrue(f.service.isThrottled)
    XCTAssertNil(f.service.connection)
    XCTAssertTrue(f.factory.engines.isEmpty)
  }
  func testSetupCreatesOneActiveEngineAndBindsApplicationEvents() {
    let f = make()
    f.service.setup()
    XCTAssertFalse(f.service.isThrottled)
    XCTAssertEqual(f.factory.autoconnect, [true])
    XCTAssertTrue(f.handler.delegate === f.service)
    XCTAssertTrue(f.service.connection === f.factory.engines.first)
  }
  func testRepeatedSetupDoesNotCreateDuplicateConnections() {
    let f = make()
    f.service.setup()
    f.service.setup()
    XCTAssertEqual(f.factory.engines.count, 1)
  }
  func testThrottleDisconnectsAndReleasesTheEngine() {
    let f = make()
    f.service.setup()
    let engine = f.factory.engines[0]
    f.service.throttle()
    XCTAssertTrue(f.service.isThrottled)
    XCTAssertNil(f.service.engine)
    XCTAssertNil(engine.delegate)
    XCTAssertGreaterThan(f.factory.connections[0].disconnects, 0)
  }
  func testRepeatedThrottleDoesNotDisconnectAgain() {
    let f = make()
    f.service.setup()
    f.service.throttle()
    let count = f.factory.connections[0].disconnects
    f.service.throttle()
    XCTAssertEqual(f.factory.connections[0].disconnects, count)
  }
  func testEqualSettingsKeepTheExistingConnection() {
    let f = make()
    f.service.setup()
    let engine = f.service.engine
    f.service.update(settings: f.first)
    XCTAssertEqual(f.factory.engines.count, 1)
    XCTAssertTrue(f.service.engine === engine)
  }
  func testChangedSettingsReplaceAndDisconnectTheOldEngine() {
    let f = make()
    f.service.setup()
    let old = f.factory.engines[0]
    f.service.update(settings: f.second)
    XCTAssertEqual(f.factory.urls, [f.first.url, f.second.url])
    XCTAssertNil(old.delegate)
    XCTAssertGreaterThan(f.factory.connections[0].disconnects, 0)
    XCTAssertTrue(f.service.engine === f.factory.engines[1])
  }
  func testChangingSettingsWhileThrottledDefersConnectionUntilSetup() {
    let f = make()
    f.service.update(settings: f.second)
    XCTAssertTrue(f.factory.engines.isEmpty)
    f.service.setup()
    XCTAssertEqual(f.factory.urls, [f.second.url])
  }
  func testBackgroundDisconnectsAndForegroundReconnectsOnce() {
    let f = make()
    f.service.setup()
    f.background()
    XCTAssertFalse(f.service.isActive)
    let c = f.factory.connections[0]
    XCTAssertGreaterThan(c.disconnects, 0)
    let before = c.connects
    f.foreground()
    f.foreground()
    XCTAssertTrue(f.service.isActive)
    XCTAssertEqual(c.connects, before + 1)
  }
  func testSettingsChangeInBackgroundDoesNotAutoconnect() {
    let f = make()
    f.service.setup()
    f.background()
    f.service.update(settings: f.second)
    XCTAssertEqual(f.factory.autoconnect, [true, false])
    XCTAssertEqual(f.factory.connections[1].connects, 0)
  }
  func testBackgroundStateIsRememberedWhileTheServiceIsThrottled() {
    let f = make()
    f.service.setup()
    f.service.throttle()
    f.background()
    XCTAssertFalse(f.service.isActive)
    f.service.setup()
    XCTAssertEqual(f.factory.autoconnect, [true, false])
  }
  func testForegroundStateIsRememberedWhileTheServiceIsThrottled() {
    let f = make()
    f.service.setup()
    f.background()
    f.service.throttle()
    f.foreground()
    XCTAssertTrue(f.service.isActive)
    f.service.setup()
    XCTAssertEqual(f.factory.autoconnect, [true, true])
  }
  func testFirstConnectionAttemptDoesNotShowANetworkFailure() async {
    let f = make()
    f.service.setup()
    f.emit(.connecting(attempt: 1))
    await drain()
    XCTAssertEqual(f.status.unreachable, 0)
    XCTAssertTrue(f.listener.urls.isEmpty)
  }
  func testRetriedConnectionReportsItsCurrentURLAndMainThreadStatus() async {
    let f = make()
    f.service.setup()
    f.emit(.connecting(attempt: 2))
    await drain()
    XCTAssertEqual(f.listener.urls, [f.first.url])
    XCTAssertEqual(f.status.unreachable, 1)
    XCTAssertTrue(f.status.threads.allSatisfy { $0 })
  }
  func testConnectedEngineReportsReachableStatus() async {
    let f = make()
    f.service.setup()
    f.emit(.connected)
    await drain()
    XCTAssertEqual(f.status.reachable, 1)
    XCTAssertTrue(f.status.threads.allSatisfy { $0 })
  }
  func testRemovingAListenerStopsFutureNotifications() async {
    let f = make()
    f.service.setup()
    f.service.removeStateListener(f.listener)
    f.emit(.connecting(attempt: 2))
    await drain()
    XCTAssertTrue(f.listener.urls.isEmpty)
  }
  func testAddingTheSameListenerTwiceDoesNotDuplicateNotifications() async {
    let f = make()
    f.service.setup()
    f.service.addStateListener(f.listener)
    f.emit(.connecting(attempt: 2))
    await drain()
    XCTAssertEqual(f.listener.urls, [f.first.url])
  }
  func testListenersAreHeldWeakly() {
    let f = make()
    var listener: SocketLifecycleListener? = SocketLifecycleListener()
    weak var reference = listener
    f.service.addStateListener(listener!)
    listener = nil
    XCTAssertNil(reference)
  }
  func testRemovingOneListenerPreservesOtherListeners() async {
    let f = make()
    let other = SocketLifecycleListener()
    f.service.addStateListener(other)
    f.service.setup()
    f.service.removeStateListener(f.listener)
    f.emit(.connecting(attempt: 3))
    await drain()
    XCTAssertTrue(f.listener.urls.isEmpty)
    XCTAssertEqual(other.urls, [f.first.url])
  }
  func testCallbacksFromReplacedEnginesCannotMarkTheCurrentNetworkDown() async {
    let f = make()
    f.service.setup()
    let old = f.factory.engines[0]
    f.service.update(settings: f.second)
    f.service.webSocketDidChangeState(engine: old, from: .notConnected, to: .connecting(attempt: 2))
    await drain()
    XCTAssertTrue(f.listener.urls.isEmpty)
    XCTAssertEqual(f.status.unreachable, 0)
  }
  func testCallbacksFromAThrottledEngineCannotMarkTheNetworkReachable() async {
    let f = make()
    f.service.setup()
    let old = f.factory.engines[0]
    f.service.throttle()
    f.service.webSocketDidChangeState(engine: old, from: .notConnected, to: .connected)
    await drain()
    XCTAssertEqual(f.status.reachable, 0)
  }
  func testQueuedReachabilityFromAnOldConnectionIsDiscardedAfterReplacement() async {
    let f = make()
    f.service.setup()
    f.emit(.connected)
    f.service.update(settings: f.second)
    await drain()
    XCTAssertEqual(f.status.reachable, 0)
  }
  func testPassiveConnectionStatesDoNotInventAvailabilityChanges() async {
    let f = make()
    f.service.setup()
    f.emit(.notConnected)
    f.emit(.waitingReconnection(attempt: 1))
    f.emit(.notReachable)
    await drain()
    XCTAssertEqual(f.status.reachable, 0)
    XCTAssertEqual(f.status.unreachable, 0)
    XCTAssertTrue(f.listener.urls.isEmpty)
  }
  func testDefaultFactoryRespectsDisabledAutoconnect() {
    let engine = WebSocketEngineFactory().createEngine(
      for: URL(string: "ws://127.0.0.1:9")!, autoconnect: false)
    defer { engine.disconnectIfNeeded() }
    guard case .notConnected = engine.state else {
      return XCTFail("A background or throttled service must not open a socket")
    }
  }
}
private final class SocketLifecycleFixture {
  let first = WebSocketServiceSettings(
    url: URL(string: "wss://first.invalid")!, addressType: nil, address: nil)
  let second = WebSocketServiceSettings(
    url: URL(string: "wss://second.invalid")!, addressType: nil, address: nil)
  let handler = SocketLifecycleHandler(), factory = SocketLifecycleFactory(),
    status = SocketLifecycleStatus(), listener = SocketLifecycleListener()
  let service: WebSocketService
  init() {
    service = WebSocketService(settings: first, applicationHandler: handler, engineFactory: factory)
    service.networkStatusPresenter = status
    service.addStateListener(listener)
  }
  func background() {
    service.didReceiveDidEnterBackground(
      notification: Notification(name: UIApplication.didEnterBackgroundNotification))
  }
  func foreground() {
    service.didReceiveDidBecomeActive(
      notification: Notification(name: UIApplication.didBecomeActiveNotification))
  }
  func emit(_ state: WebSocketEngine.State) {
    service.webSocketDidChangeState(engine: service.engine!, from: .notConnected, to: state)
  }
}
private final class SocketLifecycleHandler: ApplicationHandlerProtocol {
  weak var delegate: ApplicationHandlerDelegate?
}
private final class SocketLifecycleFactory: WebSocketEngineFactoryProtocol {
  var engines = [WebSocketEngine](), connections = [SocketLifecycleConnection](),
    autoconnect = [Bool](), urls = [URL]()
  func createEngine(for url: URL, autoconnect: Bool) -> WebSocketEngine {
    let engine = WebSocketEngine(
      connectionName: nil, url: url, reachabilityManager: SocketLifecycleReachability(), reconnectionStrategy: nil,
      autoconnect: false, pingInterval: 0)
    let connection = SocketLifecycleConnection()
    engine.connection = connection
    connection.delegate = engine
    engines.append(engine)
    connections.append(connection)
    self.autoconnect.append(autoconnect)
    urls.append(url)
    if autoconnect { engine.connectIfNeeded() }
    return engine
  }
}
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
private final class SocketLifecycleListener: WebSocketServiceStateListener {
  var urls = [URL]()
  func websocketNetworkDown(url: URL) { urls.append(url) }
}
private final class SocketLifecycleStatus: NetworkAvailabilityLayerInteractorOutputProtocol {
  var reachable = 0, unreachable = 0, threads = [Bool]()
  func didDecideUnreachableNodesAllertPresentation() {}
  func didDecideUnreachableStatusPresentation() {
    unreachable += 1
    threads.append(Thread.isMainThread)
  }
  func didDecideReachableStatusPresentation() {
    reachable += 1
    threads.append(Thread.isMainThread)
  }
}

private final class SocketLifecycleReachability: SSFUtils.ReachabilityManagerProtocol {
 var isReachable: Bool { true }
 func add(listener: SSFUtils.ReachabilityListenerDelegate) throws {}
 func remove(listener: SSFUtils.ReachabilityListenerDelegate) {}
}
