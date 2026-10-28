// SPDX-License-Identifier: Apache-2.0
import CryptoKit
import Foundation
import SSFUtils
import XCTest

@testable import SoraPassport

final class IrohaConnectSessionBoundaryTests: XCTestCase {
  private func make(
    open: Bool = true, connected: Bool = false, metadata: IrohaConnectAppMetadata? = nil,
    permissions: IrohaConnectPermissions? = .init(
      methods: ["sign_raw"], events: [], resources: ["fixture.example"])
  ) throws -> ConnectBoundaryFixture {
    let f = try ConnectBoundaryFixture()
    if open { _ = try f.open(metadata: metadata, permissions: permissions) }
    if connected { try f.approve() }
    return f
  }
  private func errorCode(_ data: Data, _ f: ConnectBoundaryFixture) throws -> String {
    let payload = try f.outbound(data)
    guard case .signError(let code, _) = payload else {
      XCTFail("Expected encrypted error")
      return ""
    }
    return code
  }
  func testApprovalBeforeOpenClosesWithoutCallingSigner() throws {
    let f = try make(open: false)
    var n = 0
    XCTAssertThrowsError(
      try f.engine.approve(
        account: f.account,
        signer: { _ in
          n += 1
          return Data()
        }, now: f.now))
    XCTAssertEqual(n, 0)
    XCTAssertTrue(f.engine.isClosed)
  }
  func testWrongApprovalNetworkIsRejectedBeforeSigning() throws {
    let f = try make()
    let a = IrohaConnectWalletContext(
      walletId: "fixture", networkId: .sora2, accountId: f.account.accountId,
      publicKey: f.account.publicKey)
    XCTAssertThrowsError(
      try f.engine.approve(
        account: a,
        signer: { _ in
          XCTFail("No signature allowed")
          return Data()
        }, now: f.now))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testWrongApprovalPublicKeyLengthCannotSign() throws {
    let f = try make()
    let a = IrohaConnectWalletContext(
      walletId: "fixture", networkId: .taira, accountId: f.account.accountId, publicKey: Data([1]))
    XCTAssertThrowsError(
      try f.engine.approve(
        account: a,
        signer: { _ in
          XCTFail("No signature allowed")
          return Data()
        }, now: f.now))
  }
  func testInvalidApprovalSignatureDoesNotEstablishAccountOrKeys() throws {
    let f = try make()
    XCTAssertThrowsError(
      try f.engine.approve(
        account: f.account, agreementPrivateKey: f.agreementSeed,
        signer: { _ in Data(repeating: 0, count: 64) }, now: f.now))
    XCTAssertNil(f.engine.approvedAccount)
    XCTAssertNil(f.engine.pendingRequest)
  }
  func testApprovalSignerFailureCanBeRetriedWithoutChangingAccount() throws {
    let f = try make()
    XCTAssertThrowsError(
      try f.engine.approve(
        account: f.account, signer: { _ in throw ConnectBoundaryError.offline }, now: f.now))
    try f.approve()
    XCTAssertEqual(f.engine.approvedAccount, f.account)
  }
  func testRejectBeforeOpenClosesWithoutProducingAnInvalidFrame() throws {
    let f = try make(open: false)
    XCTAssertNil(try f.engine.rejectPairing())
    XCTAssertTrue(f.engine.isClosed)
  }
  func testRejectingAPairingCreatesAReasonedControlFrameAndClearsState() throws {
    let f = try make()
    let bytes = try XCTUnwrap(f.engine.rejectPairing(reason: "No consent"))
    let frame = try IrohaConnectWire.decodeFrame(bytes)
    guard case .control(.reject(_, let id, let reason)) = frame.kind else {
      return XCTFail("Expected rejection")
    }
    XCTAssertEqual(id, "user_rejected")
    XCTAssertEqual(reason, "No consent")
    XCTAssertTrue(f.engine.isClosed)
    XCTAssertNil(f.engine.approvedAccount)
  }
  func testPairingRejectionBoundsAnOversizedReason() throws {
    let f = try make()
    let bytes = try XCTUnwrap(f.engine.rejectPairing(reason: String(repeating: "x", count: 600)))
    let frame = try IrohaConnectWire.decodeFrame(bytes)
    guard case .control(.reject(_, _, let reason)) = frame.kind else { return XCTFail() }
    XCTAssertEqual(reason.count, 512)
  }
  func testSecondOpenBeforeConsentClosesTheSession() throws {
    let f = try make()
    XCTAssertThrowsError(try f.open())
    XCTAssertTrue(f.engine.isClosed)
  }
  func testAnOpenFrameAfterConnectionCannotRenegotiatePermissions() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(try f.open())
    XCTAssertNil(f.engine.approvedAccount)
    XCTAssertTrue(f.engine.isClosed)
  }
  func testApprovalAtLifetimeBoundaryExpiresBeforeSigning() throws {
    let f = try make()
    XCTAssertThrowsError(
      try f.engine.approve(
        account: f.account,
        signer: { _ in
          XCTFail()
          return Data()
        }, now: f.now.addingTimeInterval(120))
    ) { XCTAssertEqual($0 as? IrohaConnectError, .expired) }
    XCTAssertTrue(f.engine.isClosed)
  }
  func testBackwardsClockBeforeOpenIsNotAccepted() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(try f.open(now: f.now.addingTimeInterval(-1)))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testLeadingWhitespaceInApplicationNameIsRejected() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(try f.open(metadata: .init(name: " Fixture", url: nil, iconHash: nil)))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testControlCharacterInApplicationNameIsRejected() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(try f.open(metadata: .init(name: "Fixture\napp", url: nil, iconHash: nil)))
  }
  func testOversizedApplicationNameIsRejected() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(
      try f.open(metadata: .init(name: String(repeating: "a", count: 129), url: nil, iconHash: nil))
    )
  }
  func testMetadataUrlCannotContainCredentials() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(
      try f.open(
        metadata: .init(name: "Fixture", url: "https://user:password@example.com", iconHash: nil)))
  }
  func testMetadataUrlCannotContainAFragment() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(
      try f.open(
        metadata: .init(name: "Fixture", url: "https://example.com/#hidden", iconHash: nil)))
  }
  func testMetadataRequiresHttps() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(
      try f.open(metadata: .init(name: "Fixture", url: "http://example.com", iconHash: nil)))
  }
  func testMalformedIconHashIsRejected() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(
      try f.open(metadata: .init(name: "Fixture", url: nil, iconHash: "not-hex")))
  }
  func testCanonicalMetadataIsDeliveredForUserReviewUnchanged() throws {
    let f = try make(open: false)
    let m = IrohaConnectAppMetadata(
      name: "Fixture", url: "https://example.com", iconHash: String(repeating: "ab", count: 32))
    let r = try f.open(metadata: m)
    guard case .open(let actual, _) = r.event else { return XCTFail() }
    XCTAssertEqual(actual, m)
    XCTAssertTrue(r.outbound.isEmpty)
  }
  func testUnsupportedPermissionCannotReachTheConsentScreen() throws {
    let f = try make(open: false)
    XCTAssertThrowsError(
      try f.open(permissions: .init(methods: ["delete_wallet"], events: [], resources: nil)))
  }
  func testSecondSignatureRequestClosesAndErasesTheFirst() throws {
    let f = try make(connected: true)
    _ = try f.request()
    XCTAssertThrowsError(try f.request(sequence: 3))
    XCTAssertTrue(f.engine.isClosed)
    XCTAssertNil(f.engine.pendingRequest)
    XCTAssertNil(f.engine.approvedAccount)
  }
  func testDisplayCannotReplaceAnActiveSigningReview() throws {
    let f = try make(connected: true)
    _ = try f.request()
    XCTAssertThrowsError(try f.receive(.display(title: "replacement", body: "hidden"), sequence: 3))
    XCTAssertNil(f.engine.pendingRequest)
  }
  func testDisplayPayloadPreservesTitleAndBodyWithoutRequestingSignature() throws {
    let f = try make(connected: true)
    let r = try f.receive(.display(title: "Information", body: "Read only"))
    XCTAssertEqual(r.event, .display(title: "Information", body: "Read only"))
    XCTAssertNil(f.engine.pendingRequest)
    XCTAssertTrue(r.outbound.isEmpty)
  }
  func testDisplayTitleLimitIsMeasuredInUtf8Bytes() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(
      try f.receive(.display(title: String(repeating: "界", count: 171), body: "body")))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testDisplayBodyCannotExceedItsBound() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(
      try f.receive(.display(title: "Title", body: String(repeating: "x", count: 8193))))
  }
  func testAppCannotSendAWalletOnlySignatureResult() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(try f.receive(.signResult(signature: Data(repeating: 1, count: 64))))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testAppCannotSendAWalletOnlySignatureError() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(try f.receive(.signError(code: "error", message: "wrong direction")))
  }
  func testEncryptedAppCloseErasesTheApprovedIdentity() throws {
    let f = try make(connected: true)
    let r = try f.receive(.close(who: 0, code: 1000, reason: "App closed", retryable: false))
    XCTAssertEqual(r.event, .closed(reason: "App closed"))
    XCTAssertTrue(f.engine.isClosed)
    XCTAssertNil(f.engine.approvedAccount)
  }
  func testEncryptedAppRejectionClosesWithItsReason() throws {
    let f = try make(connected: true)
    let r = try f.receive(.reject(code: 4001, codeId: "cancel", reason: "App cancelled"))
    XCTAssertEqual(r.event, .closed(reason: "App cancelled"))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testDecliningSignatureReturnsEncryptedUserRejectionAndClearsRequest() throws {
    let f = try make(connected: true)
    _ = try f.request()
    XCTAssertEqual(try errorCode(f.engine.rejectPendingSignature(now: f.now), f), "USER_REJECTED")
    XCTAssertNil(f.engine.pendingRequest)
    XCTAssertFalse(f.engine.isClosed)
  }
  func testRejectingSignatureAtItsLifetimeBoundaryReturnsExpired() throws {
    let f = try make(connected: true)
    _ = try f.request()
    XCTAssertEqual(
      try errorCode(f.engine.rejectPendingSignature(now: f.now.addingTimeInterval(120)), f),
      "REQUEST_EXPIRED")
    XCTAssertNil(f.engine.pendingRequest)
  }
  func testBackwardsRequestClockReturnsExpiredWithoutSigning() throws {
    let f = try make(connected: true)
    _ = try f.request()
    let b = try f.engine.approvePendingSignature(
      account: f.account,
      signer: { _ in
        XCTFail()
        return Data()
      }, now: f.now.addingTimeInterval(-1))
    XCTAssertEqual(try errorCode(b, f), "REQUEST_EXPIRED")
  }
  func testSignatureApprovalMustUseTheApprovedWalletIdentity() throws {
    let f = try make(connected: true)
    _ = try f.request()
    let a = IrohaConnectWalletContext(
      walletId: "other", networkId: .taira, accountId: f.account.accountId,
      publicKey: f.account.publicKey)
    XCTAssertThrowsError(
      try f.engine.approvePendingSignature(
        account: a,
        signer: { _ in
          XCTFail()
          return Data()
        }, now: f.now))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testRejectWithoutPendingRequestFailsClosed() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(try f.engine.rejectPendingSignature(now: f.now))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testInvalidSigningResultClosesAndErasesPendingConsent() throws {
    let f = try make(connected: true)
    _ = try f.request()
    XCTAssertThrowsError(
      try f.engine.approvePendingSignature(
        account: f.account, signer: { _ in Data(repeating: 0, count: 64) }, now: f.now))
    XCTAssertTrue(f.engine.isClosed)
    XCTAssertNil(f.engine.pendingRequest)
  }
  func testTransportEnvelopeSequenceMustEqualItsOuterFrameSequence() throws {
    let f = try make(connected: true)
    XCTAssertThrowsError(try f.receive(.display(title: "Title", body: "Body"), innerSequence: 3))
    XCTAssertTrue(f.engine.isClosed)
  }
  func testClosingTwiceEmitsOnlyOneEncryptedClose() throws {
    let f = try make(connected: true)
    let b = try XCTUnwrap(f.engine.close(reason: "Done"))
    guard case .close(_, _, let reason, _) = try f.outbound(b) else { return XCTFail() }
    XCTAssertEqual(reason, "Done")
    XCTAssertNil(f.engine.close())
    XCTAssertNil(f.engine.approvedAccount)
  }
}
private enum ConnectBoundaryError: Error { case offline }
private final class ConnectBoundaryFixture {
  let now = Date(timeIntervalSince1970: 1_800_000_000), launch: IrohaConnectLaunch,
    engine: IrohaConnectSessionEngine, signingKey: Curve25519.Signing.PrivateKey,
    account: IrohaConnectWalletContext, agreementSeed = Data(repeating: 0x33, count: 32)
  var keys: IrohaConnectDirectionKeys?
  init() throws {
    let network = try IrohaConnectNetworkLiteral(IrohaConnectLaunch.tairaNetworkId)
    let app = try Curve25519.KeyAgreement.PrivateKey(
      rawRepresentation: Data(repeating: 0x11, count: 32))
    let nonce = Data((0..<16).map(UInt8.init))
    let sid = try
      (Data("iroha-connect|sid|".utf8) + network.bytes + app.publicKey.rawRepresentation + nonce)
      .blake2b32()
    var u = URLComponents()
    u.scheme = "irohaconnect"
    u.host = "connect"
    u.queryItems = [
      URLQueryItem(name: "sid", value: sid.boundaryBase64),
      URLQueryItem(name: "network_id", value: network.literal),
      URLQueryItem(name: "app_pk", value: app.publicKey.rawRepresentation.boundaryBase64),
      URLQueryItem(name: "nonce", value: nonce.boundaryBase64),
      URLQueryItem(name: "node", value: "https://taira.sora.org"),
      URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "role", value: "wallet"),
      URLQueryItem(name: "token", value: Data(repeating: 0xa1, count: 32).boundaryBase64),
      URLQueryItem(name: "relay", value: Data(repeating: 0xb2, count: 32).boundaryBase64),
    ]
    launch = try IrohaConnectLaunch.parse(XCTUnwrap(u.url), receivedAt: now)
    engine = IrohaConnectSessionEngine(launch: launch)
    signingKey = try Curve25519.Signing.PrivateKey(
      rawRepresentation: Data(repeating: 0x42, count: 32))
    account = .init(
      walletId: "fixture-wallet", networkId: .taira, accountId: "fixture-account",
      publicKey: signingKey.publicKey.rawRepresentation)
  }
  deinit { keys?.wipe() }
  func open(
    metadata: IrohaConnectAppMetadata? = nil,
    permissions: IrohaConnectPermissions? = .init(
      methods: ["sign_raw"], events: [], resources: ["fixture.example"]), now: Date? = nil
  ) throws -> IrohaConnectSessionResult {
    try engine.receive(
      IrohaConnectWire.encodeOpenForTesting(
        sid: launch.sid, appPublicKey: launch.appPublicKey, network: launch.network,
        metadata: metadata, permissions: permissions), now: now ?? self.now)
  }
  func approve() throws {
    _ = try engine.approve(
      account: account, agreementPrivateKey: agreementSeed,
      signer: { try self.signingKey.signature(for: $0) }, now: now)
    keys = try IrohaConnectCrypto.directionKeys(
      walletPrivateKey: Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementSeed),
      appPublicKey: launch.appPublicKey, sid: launch.sid)
  }
  func request(sequence: UInt64 = 2) throws -> IrohaConnectSessionResult {
    try receive(
      .signRequest(.raw(domain: "fixture.example", bytes: Data("Public review message".utf8))),
      sequence: sequence)
  }
  func receive(
    _ payload: IrohaConnectEnvelopePayload, sequence: UInt64 = 2, innerSequence: UInt64? = nil
  ) throws -> IrohaConnectSessionResult {
    let e = try IrohaConnectWire.encodeEnvelope(
      sequence: innerSequence ?? sequence, payload: payload)
    let encrypted = try IrohaConnectCrypto.encrypt(
      envelope: e, key: XCTUnwrap(keys).appToWallet, sid: launch.sid, direction: 0,
      sequence: sequence)
    return try engine.receive(
      IrohaConnectWire.encodeCiphertext(
        sid: launch.sid, direction: 0, sequence: sequence, bytes: encrypted), now: now)
  }
  func outbound(_ bytes: Data) throws -> IrohaConnectEnvelopePayload {
    let frame = try IrohaConnectWire.decodeFrame(bytes)
    guard case .ciphertext(_, let ciphertext) = frame.kind else {
      throw ConnectBoundaryError.offline
    }
    let plain = try IrohaConnectCrypto.decrypt(
      ciphertext: ciphertext, key: XCTUnwrap(keys).walletToApp, sid: launch.sid, direction: 1,
      sequence: frame.sequence)
    return try IrohaConnectWire.decodeEnvelope(plain).1
  }
}
extension Data {
  fileprivate var boundaryBase64: String {
    base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(
      of: "/", with: "_"
    ).replacingOccurrences(of: "=", with: "")
  }
}
