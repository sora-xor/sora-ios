// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import Foundation
import XCTest

@testable import SoraPassport

final class QRPermissionLifecycleTests: XCTestCase {
  private var fixtures = [CapturePermissionFixture]()
  override func tearDown() {
    fixtures.forEach {
      $0.service.stop()
      $0.permissions.answer(false)
    }
    fixtures = []
    super.tearDown()
  }
  private func make(_ status: AVAuthorizationStatus) -> CapturePermissionFixture {
    let f = CapturePermissionFixture(status: status)
    fixtures.append(f)
    return f
  }
  private func drain(_ f: CapturePermissionFixture) async {
    await withCheckedContinuation { continuation in
      WalletQRCaptureService.processingQueue.async { f.callbacks.async { continuation.resume() } }
    }
  }
  func testAuthorizedStartConfiguresAndStartsExactlyOneSession() async {
    let f = make(.authorized)
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.session.starts, 1)
    XCTAssertEqual(f.delegate.sessions.count, 1)
    XCTAssertTrue(f.delegate.sessions.first === f.session)
    XCTAssertEqual(f.permissions.requests, 0)
  }
  func testDeniedPermissionReportsThePreviousDenialWithoutSessionAccess() async {
    let f = make(.denied)
    f.service.start()
    await drain(f)
    XCTAssertEqual(
      f.delegate.errors.first as? WalletQRCaptureServiceError, .deviceAccessDeniedPreviously)
    XCTAssertEqual(f.session.starts, 0)
    XCTAssertEqual(f.permissions.requests, 0)
  }
  func testRestrictedPermissionReportsRestrictionWithoutPrompting() async {
    let f = make(.restricted)
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.delegate.errors.first as? WalletQRCaptureServiceError, .deviceAccessRestricted)
    XCTAssertEqual(f.permissions.requests, 0)
  }
  func testUndeterminedPermissionWaitsForThePermissionResult() async {
    let f = make(.notDetermined)
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.permissions.requests, 1)
    XCTAssertTrue(f.delegate.sessions.isEmpty)
    XCTAssertTrue(f.delegate.errors.isEmpty)
  }
  func testNewPermissionDenialReportsTheCurrentDenial() async {
    let f = make(.notDetermined)
    f.service.start()
    f.permissions.answer(false)
    await drain(f)
    XCTAssertEqual(f.delegate.errors.first as? WalletQRCaptureServiceError, .deviceAccessDeniedNow)
    XCTAssertEqual(f.session.starts, 0)
  }
  func testNewPermissionGrantStartsTheSession() async {
    let f = make(.notDetermined)
    f.service.start()
    f.permissions.answer(true)
    await drain(f)
    XCTAssertEqual(f.session.starts, 1)
    XCTAssertEqual(f.delegate.sessions.count, 1)
  }
  func testStopBeforePermissionGrantCannotRestartTheCamera() async {
    let f = make(.notDetermined)
    f.service.start()
    f.service.stop()
    f.permissions.answer(true)
    await drain(f)
    XCTAssertEqual(f.session.starts, 0)
    XCTAssertTrue(f.delegate.sessions.isEmpty)
  }
  func testStopBeforePermissionDenialIgnoresTheObsoleteError() async {
    let f = make(.notDetermined)
    f.service.start()
    f.service.stop()
    f.permissions.answer(false)
    await drain(f)
    XCTAssertTrue(f.delegate.errors.isEmpty)
  }
  func testRepeatedStartDuringPermissionPromptDoesNotRequestAgain() async {
    let f = make(.notDetermined)
    f.service.start()
    f.service.start()
    XCTAssertEqual(f.permissions.requests, 1)
    f.permissions.answer(true)
    await drain(f)
    XCTAssertEqual(f.session.starts, 1)
  }
  func testRepeatedAuthorizedStartDoesNotDuplicateSetupCallbacks() async {
    let f = make(.authorized)
    f.service.start()
    await drain(f)
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.session.starts, 1)
    XCTAssertEqual(f.delegate.sessions.count, 1)
  }
  func testStopStopsTheExistingSession() async {
    let f = make(.authorized)
    f.service.start()
    await drain(f)
    f.service.stop()
    await drain(f)
    XCTAssertEqual(f.session.stops, 1)
  }
  func testRestartReusesTheExistingSessionAndNotifiesItsDelegate() async {
    let f = make(.authorized)
    f.service.start()
    await drain(f)
    f.service.stop()
    await drain(f)
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.session.starts, 2)
    XCTAssertEqual(f.delegate.sessions.count, 2)
    XCTAssertTrue(f.service.captureSession === f.session)
  }
  func testSessionConfigurationFailureIsDeliveredOnTheSelectedQueue() async {
    let f = make(.authorized)
    f.configurationError = CapturePermissionError.failed
    f.service.start()
    await drain(f)
    XCTAssertTrue(f.delegate.errors.first is CapturePermissionError)
    XCTAssertEqual(f.delegate.callbackQueues, [true])
    XCTAssertEqual(f.session.starts, 0)
  }
  func testSessionConfigurationCanRetryAfterFailure() async {
    let f = make(.authorized)
    f.configurationError = CapturePermissionError.failed
    f.service.start()
    await drain(f)
    f.configurationError = nil
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.session.starts, 1)
    XCTAssertEqual(f.delegate.sessions.count, 1)
  }
  func testAllSessionSetupCallbacksUseTheRequestedQueue() async {
    let f = make(.authorized)
    f.service.start()
    await drain(f)
    XCTAssertEqual(f.delegate.callbackQueues, [true])
  }
  func testDelegateIsWeaklyOwned() {
    let f = make(.authorized)
    var delegate: CapturePermissionDelegate? = CapturePermissionDelegate(key: f.key)
    weak var observed = delegate
    f.service.delegate = delegate
    delegate = nil
    XCTAssertNil(observed)
    XCTAssertNil(f.service.delegate)
  }
}
private enum CapturePermissionError: Error { case failed }
private final class CapturePermissionFixture {
  let key = DispatchSpecificKey<Bool>(),
    callbacks = DispatchQueue(label: "capture-fixture-callback"),
    session = CapturePermissionSession(), permissions = CapturePermissionRequest()
  let status: AVAuthorizationStatus
  var configurationError: Error?
  lazy var delegate = CapturePermissionDelegate(key: key)
  lazy var service = WalletQRCaptureService(
    matcher: CapturePermissionMatcher(), delegate: delegate, delegateQueue: callbacks,
    authorizationStatus: { [weak self] in self?.status ?? .denied },
    requestAccess: { [weak self] in self?.permissions.request($0) },
    makeSession: { [weak self] _ in
      guard let self else { throw CapturePermissionError.failed }
      if let error = self.configurationError { throw error }
      return self.session
    })
  init(status: AVAuthorizationStatus) {
    self.status = status
    callbacks.setSpecific(key: key, value: true)
  }
}
private final class CapturePermissionRequest {
  var requests = 0
  private var answerBlock: ((Bool) -> Void)?
  func request(_ completion: @escaping (Bool) -> Void) {
    requests += 1
    answerBlock = completion
  }
  func answer(_ allowed: Bool) {
    let callback = answerBlock
    answerBlock = nil
    callback?(allowed)
  }
}
private final class CapturePermissionSession: AVCaptureSession {
  private(set) var starts = 0, stops = 0
  override func startRunning() { starts += 1 }
  override func stopRunning() { stops += 1 }
}
private final class CapturePermissionMatcher: WalletQRMatcherProtocol {
  func match(code: String) -> Bool { false }
}
private final class CapturePermissionDelegate: WalletQRCaptureServiceDelegate {
  let key: DispatchSpecificKey<Bool>
  var errors = [Error](), sessions = [AVCaptureSession](), callbackQueues = [Bool]()
  init(key: DispatchSpecificKey<Bool>) { self.key = key }
  func qrCapture(service: WalletQRCaptureServiceProtocol, didSetup session: AVCaptureSession) {
    sessions.append(session)
    callbackQueues.append(DispatchQueue.getSpecific(key: key) == true)
  }
  func qrCapture(service: WalletQRCaptureServiceProtocol, didMatch code: String) {}
  func qrCapture(service: WalletQRCaptureServiceProtocol, didFailMatching code: String) {}
  func qrCapture(service: WalletQRCaptureServiceProtocol, didReceive error: Error) {
    errors.append(error)
    callbackQueues.append(DispatchQueue.getSpecific(key: key) == true)
  }
}
