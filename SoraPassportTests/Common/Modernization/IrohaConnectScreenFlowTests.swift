// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import CryptoKit
import Foundation
import SSFUtils
import SoraFoundation
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class IrohaConnectScreenFlowTests: XCTestCase {
    private var language = "en"
    private var fixtures: [ConnectScreenFixture] = []
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { fixtures.forEach { $0.screen.applicationDidEnterBackground(); $0.window.isHidden = true }; fixtures.removeAll(); LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func make(start: Bool = true, age: TimeInterval = 0) throws -> ConnectScreenFixture { let f = try ConnectScreenFixture(age: age); fixtures.append(f); f.screen.loadViewIfNeeded(); if start { f.screen.viewDidAppear(false) }; return f }
    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async { for _ in 0..<100 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }; XCTFail("Connect screen did not reach the expected state", file: file, line: line) }
    func testInitialScreenShowsNetworkAccountAndDisabledConnectAction() throws { let f = try make(start: false); XCTAssertTrue(f.text.contains("SORA Taira Testnet")); XCTAssertTrue(f.text.contains("fixture-account-i105")); XCTAssertFalse(try f.button("Connecting…").isEnabled); XCTAssertEqual(f.socket.connects, 0) }
    func testFirstAppearanceUsesOnlyTheQualifiedRelayAndProtocol() throws { let f = try make(); XCTAssertEqual(f.socket.connects, 1); XCTAssertEqual(f.transportURL, f.launch.webSocketURL); XCTAssertEqual(f.transportProtocol, f.launch.webSocketProtocol) }
    func testRepeatedAppearanceDoesNotCreateAnotherSocket() throws { let f = try make(); f.screen.viewDidAppear(false); XCTAssertEqual(f.socket.connects, 1) }
    func testOpenedRelayWaitsForAnAppWithoutEnablingApproval() throws { let f = try make(); f.socket.onOpen?(); XCTAssertTrue(f.text.contains("waiting for the app")); XCTAssertFalse(try f.button("Connecting…").isEnabled); XCTAssertTrue(f.signatures.isEmpty) }
    func testOpenFrameDisplaysExactAppIdentityAndRequestedDomains() throws { let f = try make(); try f.open(); XCTAssertTrue(f.text.contains("Fixture app")); XCTAssertTrue(f.text.contains("https://example.app")); XCTAssertTrue(f.text.contains("example.app")); XCTAssertTrue(try f.button("Authenticate & connect").isEnabled); XCTAssertFalse(try f.button("Decline connection").isHidden) }
    func testMissingAppMetadataIsShownAsUnknownWithoutInventingAName() throws { let f = try make(); try f.open(metadata: nil); XCTAssertTrue(f.text.contains("Unknown app")); XCTAssertTrue(f.signatures.isEmpty) }
    func testConnectOnlyPermissionDoesNotOfferSigningAccess() throws { let f = try make(); try f.open(permissions: nil); XCTAssertTrue(f.text.contains("Connect only (no signing)")) }
    func testTransactionPermissionIsDisclosedBeforeApproval() throws { let f = try make(); try f.open(permissions: .init(methods: ["sign_transaction"], events: [], resources: nil)); XCTAssertTrue(f.text.contains("transaction signatures")) }
    func testAuthenticationStartsOnlyAfterTheApproveButtonIsTapped() throws { let f = try make(); try f.open(); XCTAssertTrue(f.auth.completions.isEmpty); try f.button("Authenticate & connect").sendActions(for: .touchUpInside); XCTAssertEqual(f.auth.completions.count, 1); XCTAssertTrue(f.signatures.isEmpty); XCTAssertFalse(try f.button("Authenticate & connect").isEnabled) }
    func testAuthenticationCancellationAllowsAReviewRetryWithoutSigning() throws { let f = try make(); try f.open(); try f.button("Authenticate & connect").sendActions(for: .touchUpInside); f.auth.finish(.failure(IrohaConnectError.authenticationFailed)); XCTAssertTrue(f.text.contains("Nothing was approved")); XCTAssertTrue(try f.button("Authenticate & connect").isEnabled); XCTAssertTrue(f.signatures.isEmpty) }
    func testSuccessfulApprovalReturnsARealAccountBoundProof() throws { let f = try make(); try f.approve(); XCTAssertEqual(f.signatures.count, 1); XCTAssertTrue(f.text.contains("Connected securely")); XCTAssertFalse(try f.button("Waiting for a request…").isEnabled); let frame = try IrohaConnectWire.decodeFrame(try XCTUnwrap(f.socket.sent.first)); guard case let .control(.approve(_, account, _, _, signature)) = frame.kind else { return XCTFail("Expected approval proof") }; XCTAssertEqual(account, f.account.accountId); XCTAssertTrue(f.signingKey.publicKey.isValidSignature(signature, for: f.signatures[0])) }
    func testApprovalSigningFailureBlocksSession() throws { let f = try make(); f.rejectSigning = true; try f.open(); try f.button("Authenticate & connect").sendActions(for: .touchUpInside); f.auth.finish(.success(())); XCTAssertTrue(f.text.contains("Request blocked")); XCTAssertGreaterThan(f.socket.cancels, 0) }
    func testBackgroundingDuringAuthenticationCannotApproveLater() throws { let f = try make(); try f.open(); try f.button("Authenticate & connect").sendActions(for: .touchUpInside); f.screen.applicationDidEnterBackground(); f.auth.finish(.success(())); XCTAssertTrue(f.signatures.isEmpty); XCTAssertGreaterThan(f.socket.cancels, 0) }
    func testBackgroundingBeforeAppearanceCannotStartANewConnection() throws { let f = try make(start: false); f.screen.applicationDidEnterBackground(); f.screen.viewDidAppear(false); XCTAssertEqual(f.socket.connects, 0) }
    func testDecliningPairingSendsRejectionWithoutAuthentication() throws { let f = try make(); try f.open(); try f.button("Decline connection").sendActions(for: .touchUpInside); XCTAssertTrue(f.auth.completions.isEmpty); XCTAssertTrue(f.signatures.isEmpty); XCTAssertGreaterThan(f.socket.cancels, 0); let frame = try IrohaConnectWire.decodeFrame(try XCTUnwrap(f.socket.sent.first)); guard case .control(.reject) = frame.kind else { return XCTFail("Expected pairing rejection") } }
    func testMalformedFrameTerminatesTheSession() throws { let f = try make(); f.socket.onData?(Data([0])); XCTAssertTrue(f.text.contains("Request blocked")); XCTAssertGreaterThan(f.socket.cancels, 0); XCTAssertTrue(try f.button("Done").isEnabled) }
    func testSocketFailureShowsAClosedReviewWithoutSigning() throws { let f = try make(); f.socket.onFailure?(IrohaConnectError.connectionFailed); XCTAssertTrue(f.text.contains("Request blocked")); XCTAssertTrue(f.signatures.isEmpty) }
    func testRemoteCloseShowsTheProvidedReason() throws { let f = try make(); f.socket.onClosed?("App finished"); XCTAssertTrue(f.text.contains("Connection closed")); XCTAssertTrue(f.text.contains("App finished")); XCTAssertTrue(try f.button("Done").isEnabled) }
    func testLateSocketOpenCannotReplaceTerminalState() throws { let f = try make(); f.socket.onClosed?("Finished"); f.socket.onOpen?(); XCTAssertTrue(f.text.contains("Connection closed")) }
    func testLateIncomingFrameCannotReopenClosedSession() throws { let f = try make(); f.socket.onClosed?("Finished"); try f.open(); XCTAssertTrue(f.text.contains("Connection closed")); XCTAssertTrue(f.signatures.isEmpty) }
    func testTransientMessageCannotReplaceTerminalStatus() throws { let f = try make(); f.socket.onClosed?("Finished"); f.screen.showTransientMessage("A different request"); XCTAssertTrue(f.text.contains("Connection closed")); XCTAssertFalse(f.text.contains("A different request")) }
    func testExpiredLaunchNeverEnablesApproval() async throws { let f = try make(age: IrohaConnectSessionEngine.approvalLifetime + 1); await wait { f.text.contains("Request blocked") }; XCTAssertTrue(f.signatures.isEmpty); XCTAssertGreaterThan(f.socket.cancels, 0) }
    func testReadableMessageIsDisplayedCompletelyBeforeSigning() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Authorize exact message\nAmount: 12 XOR".utf8)))); XCTAssertTrue(f.text.contains("Authorize exact message\nAmount: 12 XOR")); XCTAssertTrue(f.text.contains("Sign this message?")); XCTAssertTrue(try f.button("Sign message").isEnabled); XCTAssertEqual(f.signatures.count, 1) }
    func testOpaqueTransactionRemainsUnsignable() throws { let f = try make(); try f.approve(permissions: .init(methods: ["sign_transaction"], events: [], resources: nil)); try f.send(.signRequest(.transaction(bytes: Data([1, 2, 3])))); XCTAssertTrue(f.text.contains("Cannot review request")); XCTAssertFalse(try f.button("Cannot sign this request").isEnabled); XCTAssertEqual(f.signatures.count, 1) }
    func testUnreadableMessageRemainsUnsignable() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data([0xff])))); XCTAssertTrue(f.text.contains("Signing unavailable")); XCTAssertFalse(try f.button("Cannot sign this request").isEnabled); XCTAssertEqual(f.signatures.count, 1) }
    func testDiagnosticDisclosureStartsCollapsedAndContainsExactDigest() throws { let f = try make(); try f.approve(); let bytes = Data("Review me".utf8); try f.send(.signRequest(.raw(domain: "example.app", bytes: bytes))); let button = try f.button("Technical details"); XCTAssertEqual(button.accessibilityValue, "Collapsed"); button.sendActions(for: .touchUpInside); XCTAssertEqual(button.accessibilityValue, "Expanded"); let digest = Data(SHA256.hash(data: bytes)).map { String(format: "%02x", $0) }.joined(); XCTAssertTrue(f.visibleText.contains(digest)); button.sendActions(for: .touchUpInside); XCTAssertEqual(button.accessibilityValue, "Collapsed"); XCTAssertFalse(f.visibleText.contains(digest)) }
    func testDecliningSignatureReturnsEncryptedRejectionAndKeepsConnectionOpen() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Review me".utf8)))); try f.button("Decline signature").sendActions(for: .touchUpInside); XCTAssertTrue(f.text.contains("connection remains open")); XCTAssertEqual(f.signatures.count, 1); guard case .signError = try f.lastPayload() else { return XCTFail("Expected encrypted signature rejection") }; XCTAssertEqual(f.socket.cancels, 0) }
    func testDecliningSignatureHidesItsDiagnosticDisclosure() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Review me".utf8)))); try f.button("Technical details").sendActions(for: .touchUpInside); try f.button("Decline signature").sendActions(for: .touchUpInside); XCTAssertTrue(try f.button("Technical details").isHidden); XCTAssertFalse(f.visibleText.contains("SHA-256")) }
    func testSignatureAuthenticationCancellationDoesNotSign() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Review me".utf8)))); try f.button("Sign message").sendActions(for: .touchUpInside); f.auth.finish(.failure(IrohaConnectError.authenticationFailed)); XCTAssertEqual(f.signatures.count, 1); XCTAssertTrue(f.text.contains("request remains unsigned")); XCTAssertTrue(try f.button("Authenticate & sign").isEnabled) }
    func testSigningReturnsARealSignatureForTheReviewedRequest() throws { let f = try make(); try f.approve(); let bytes = Data("Review me".utf8); try f.send(.signRequest(.raw(domain: "example.app", bytes: bytes))); try f.button("Sign message").sendActions(for: .touchUpInside); f.auth.finish(.success(())); XCTAssertEqual(f.signatures.count, 2); XCTAssertTrue(f.text.contains("Signature returned securely")); guard case let .signResult(signature) = try f.lastPayload() else { return XCTFail("Expected signature") }; XCTAssertTrue(f.signingKey.publicKey.isValidSignature(signature, for: try XCTUnwrap(f.signatures.last))) }
    func testSuccessfulSigningHidesThePreviousDiagnosticDisclosure() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Review me".utf8)))); try f.button("Technical details").sendActions(for: .touchUpInside); try f.button("Sign message").sendActions(for: .touchUpInside); f.auth.finish(.success(())); XCTAssertTrue(try f.button("Technical details").isHidden); XCTAssertFalse(f.visibleText.contains("SHA-256")) }
    func testBackgroundingDuringSignatureAuthenticationPreventsSigning() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Review me".utf8)))); try f.button("Sign message").sendActions(for: .touchUpInside); f.screen.applicationDidEnterBackground(); f.auth.finish(.success(())); XCTAssertEqual(f.signatures.count, 1) }
    func testFreshSignatureRequestResetsThePreviousDisclosure() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("First message".utf8)))); try f.button("Technical details").sendActions(for: .touchUpInside); try f.button("Decline signature").sendActions(for: .touchUpInside); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Second message".utf8)))); XCTAssertEqual(try f.button("Technical details").accessibilityValue, "Collapsed"); XCTAssertFalse(f.visibleText.contains("First message")); XCTAssertTrue(f.visibleText.contains("Second message")) }
    func testDisplayEventUpdatesTheConnectedScreenWithoutSigning() throws { let f = try make(); try f.approve(); try f.send(.display(title: "Request complete", body: "You can return to the app")); XCTAssertTrue(f.text.contains("Request complete")); XCTAssertTrue(f.text.contains("You can return to the app")); XCTAssertEqual(f.signatures.count, 1) }
    func testTerminalSessionHidesAnEarlierRequestDisclosure() throws { let f = try make(); try f.approve(); try f.send(.signRequest(.raw(domain: "example.app", bytes: Data("Review me".utf8)))); try f.button("Technical details").sendActions(for: .touchUpInside); f.socket.onClosed?("Finished"); XCTAssertTrue(try f.button("Technical details").isHidden); XCTAssertFalse(f.visibleText.contains("SHA-256")) }
}

@MainActor
private final class ConnectScreenFixture {
    let launch: IrohaConnectLaunch
    let appPrivate: Curve25519.KeyAgreement.PrivateKey
    let signingKey: Curve25519.Signing.PrivateKey
    let account: IrohaConnectWalletContext
    let socket = ConnectScreenSocket()
    let auth = ConnectScreenAuth()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let directory: URL
    var signatures: [Data] = [], rejectSigning = false
    var transportURL: URL?, transportProtocol: String?
    var keys: IrohaConnectDirectionKeys?
    var sequence: UInt64 = 2
    lazy var screen: IrohaConnectViewController = {
        let provider = try! IrohaConnectWalletProvider(store: WalletNetworkStore(baseURL: directory), selectedAccount: { nil })
        return IrohaConnectViewController(launch: launch, account: account, walletProvider: provider, authenticator: auth, socketFactory: { [unowned self] url, proto in self.transportURL = url; self.transportProtocol = proto; return self.socket }, signer: { [unowned self] bytes, _ in self.signatures.append(bytes); if self.rejectSigning { throw IrohaConnectError.authenticationFailed }; return try self.signingKey.signature(for: bytes) })
    }()
    init(age: TimeInterval) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("ConnectScreen-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        appPrivate = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x11, count: 32))
        signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 0x42, count: 32))
        account = IrohaConnectWalletContext(walletId: "fixture-wallet", networkId: .taira, accountId: "fixture-account-i105", publicKey: signingKey.publicKey.rawRepresentation)
        let network = try IrohaConnectNetworkLiteral(IrohaConnectLaunch.tairaNetworkId), nonce = Data((0..<16).map { UInt8($0) })
        let sid = try (Data("iroha-connect|sid|".utf8) + network.bytes + appPrivate.publicKey.rawRepresentation + nonce).blake2b32()
        var url = URLComponents(); url.scheme = "irohaconnect"; url.host = "connect"
        url.queryItems = [URLQueryItem(name: "sid", value: sid.screenBase64URL), URLQueryItem(name: "network_id", value: network.literal), URLQueryItem(name: "app_pk", value: appPrivate.publicKey.rawRepresentation.screenBase64URL), URLQueryItem(name: "nonce", value: nonce.screenBase64URL), URLQueryItem(name: "node", value: "https://taira.sora.org"), URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "role", value: "wallet"), URLQueryItem(name: "token", value: Data(repeating: 0xa1, count: 32).screenBase64URL), URLQueryItem(name: "relay", value: Data(repeating: 0xb2, count: 32).screenBase64URL)]
        launch = try IrohaConnectLaunch.parse(XCTUnwrap(url.url), receivedAt: Date().addingTimeInterval(-age))
        window.rootViewController = UIViewController()
    }
    deinit { keys?.wipe(); try? FileManager.default.removeItem(at: directory) }
    func open(metadata: IrohaConnectAppMetadata? = .init(name: "Fixture app", url: "https://example.app", iconHash: nil), permissions: IrohaConnectPermissions? = .init(methods: ["sign_raw"], events: [], resources: ["example.app"])) throws { socket.onData?(IrohaConnectWire.encodeOpenForTesting(sid: launch.sid, appPublicKey: launch.appPublicKey, network: launch.network, metadata: metadata, permissions: permissions)) }
    func approve(permissions: IrohaConnectPermissions? = .init(methods: ["sign_raw"], events: [], resources: ["example.app"])) throws { try open(permissions: permissions); try button("Authenticate & connect").sendActions(for: .touchUpInside); auth.finish(.success(())); let frame = try IrohaConnectWire.decodeFrame(XCTUnwrap(socket.sent.first)); guard case let .control(.approve(walletPublicKey, _, _, _, _)) = frame.kind else { throw IrohaConnectError.authenticationFailed }; keys = try IrohaConnectCrypto.directionKeys(walletPrivateKey: appPrivate, appPublicKey: walletPublicKey, sid: launch.sid) }
    func send(_ payload: IrohaConnectEnvelopePayload) throws { let envelope = try IrohaConnectWire.encodeEnvelope(sequence: sequence, payload: payload); let cipher = try IrohaConnectCrypto.encrypt(envelope: envelope, key: XCTUnwrap(keys).appToWallet, sid: launch.sid, direction: 0, sequence: sequence); socket.onData?(IrohaConnectWire.encodeCiphertext(sid: launch.sid, direction: 0, sequence: sequence, bytes: cipher)); sequence += 1 }
    func lastPayload() throws -> IrohaConnectEnvelopePayload { let frame = try IrohaConnectWire.decodeFrame(XCTUnwrap(socket.sent.last)); guard case let .ciphertext(_, data) = frame.kind else { throw IrohaConnectError.protocolViolation("Expected encrypted fixture response") }; let plain = try IrohaConnectCrypto.decrypt(ciphertext: data, key: XCTUnwrap(keys).walletToApp, sid: launch.sid, direction: 1, sequence: frame.sequence); return try IrohaConnectWire.decodeEnvelope(plain).1 }
    func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    func button(_ title: String) throws -> UIButton { try XCTUnwrap(descendants(screen.view).compactMap { $0 as? UIButton }.first { ($0.configuration?.title ?? $0.title(for: .normal)) == title }) }
    var text: String { descendants(screen.view).compactMap { ($0 as? UILabel)?.text ?? ($0 as? UITextView)?.text }.joined(separator: "\n") }
    var visibleText: String { descendants(screen.view).filter { !$0.isHidden }.compactMap { ($0 as? UILabel)?.text ?? ($0 as? UITextView)?.text }.joined(separator: "\n") }
}
private final class ConnectScreenAuth: IrohaConnectAuthenticating {
    var completions: [(Result<Void, Error>) -> Void] = []; var reasons: [String] = []
    func authenticate(reason: String, completion: @escaping (Result<Void, Error>) -> Void) { reasons.append(reason); completions.append(completion) }
    func finish(_ result: Result<Void, Error>) { completions.removeFirst()(result) }
}
private final class ConnectScreenSocket: IrohaConnectTransport {
    var onOpen: (() -> Void)?, onData: ((Data) -> Void)?, onClosed: ((String) -> Void)?, onFailure: ((Error) -> Void)?
    var connects = 0, cancels = 0; var sent: [Data] = []
    func connect() { connects += 1 }; func send(_ data: Data) { sent.append(data) }; func cancel() { cancels += 1 }
}

private extension Data { var screenBase64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") } }
