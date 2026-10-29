// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import Photos
import UIKit
import RobinHood
import SoraFoundation
import SoraKeystore
import SoraUIKit
import SoraUI
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

private final class PermissionScannerView: UIViewController, ScanQRViewProtocol {
    var presented = [UIViewController]()
    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presented.append(controller); completion?()
    }
    var controller: UIViewController { self }
    var completeDismissal = true
    var sessions = 0; var alerts: [String] = []; var settingsPrompts = 0; var dismissals = 0
    func didReceive(session: AVCaptureSession) { sessions += 1 }
    func presentAlert(title: String) { alerts.append(title) }
    func askOpenApplicationSettings(with message: String, title: String?, from view: ControllerBackedProtocol?, locale: Locale?) { settingsPrompts += 1 }
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; if completeDismissal { completion?() } }
}
private final class PermissionScannerCapture: WalletQRCaptureServiceFactoryProtocol, WalletQRCaptureServiceProtocol {
    weak var delegate: WalletQRCaptureServiceDelegate?
    var delegateQueue = DispatchQueue.main
    var matcher: WalletQRMatcherProtocol?
    var starts = 0; var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func createService(with matcher: WalletQRMatcherProtocol, delegate: WalletQRCaptureServiceDelegate?, delegateQueue: DispatchQueue?) -> WalletQRCaptureServiceProtocol {
        self.matcher = matcher; self.delegate = delegate; return self
    }
}
private final class PermissionScannerCoder: WalletQRCoderFactoryProtocol, WalletQRDecoderProtocol, WalletQREncoderProtocol {
    func createEncoder() -> WalletQREncoderProtocol { self }
    func createDecoder() -> WalletQRDecoderProtocol { self }
    func encode(receiverInfo: ReceiveInfo) throws -> Data { Data(receiverInfo.accountId.utf8) }
    func decode(data: Data) throws -> ReceiveInfo { ReceiveInfo(accountId: String(decoding: data, as: UTF8.self), assetId: nil, amount: nil, details: nil) }
}
private struct PermissionScannerLocal: InvoiceLocalSearchEngineProtocol {
    func searchByAccountId(_ accountId: String) -> SearchData? { SearchData(accountId: accountId, firstName: "Local recipient", lastName: "") }
}
private struct PermissionScannerShare: AccountShareFactoryProtocol {
    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { [] }
}
private final class PermissionScannerMarket: MarketCapServiceProtocol {
    func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class PermissionScannerCall: CancellableCall { var cancellations = 0; func cancel() { cancellations += 1 } }
private final class PermissionScannerNetwork: WalletServiceProtocol {
    var queries: [String] = []; var completions: [SearchCompletionBlock] = []; var calls: [PermissionScannerCall] = []
    private let unused = WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock())
    func search(for searchString: String, runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall {
        queries.append(searchString); completions.append(completionBlock); let call = PermissionScannerCall(); calls.append(call); return call
    }
    func fetchBalance(for assets: [String], runCompletionIn queue: DispatchQueue, completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall { unused.fetchBalance(for: assets, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransactionHistory(for filter: WalletHistoryRequest, pagination: Pagination, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall { unused.fetchTransactionHistory(for: filter, pagination: pagination, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransferMetadata(for info: TransferMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransferMetadataCompletionBlock) -> CancellableCall { unused.fetchTransferMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func transfer(info: TransferInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("PermissionScanner attempted a transfer"); return PermissionScannerCall() }
    func prepareTransferSubmission(for info: TransferInfo, preSigningValidation: @escaping () throws -> Void) async throws -> PreparedSora2TransferSubmission { XCTFail("PermissionScanner attempted to sign"); throw CancellationError() }
    func submitPreparedTransfer(_ submission: PreparedSora2TransferSubmission, info: TransferInfo, preTransportValidation: @escaping () throws -> Void) async throws -> Data { XCTFail("PermissionScanner attempted a submission"); throw CancellationError() }
    func fetchContacts(runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall { unused.fetchContacts(runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping WithdrawalMetadataCompletionBlock) -> CancellableCall { unused.fetchWithdrawalMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func withdraw(info: WithdrawInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("PermissionScanner attempted withdrawal"); return PermissionScannerCall() }
}


private final class PermissionScannerImageExtraction: WalletQRExtractionServiceProtocol {
    var images = 0, runMatcher = true
    private var matcher: WalletQRMatcherProtocol?, queue: DispatchQueue?, completion: ((Result<String, Error>) -> Void)?
    func extract(from image: UIImage, using matcher: WalletQRMatcherProtocol, dispatchCompletionIn queue: DispatchQueue?, completionBlock: @escaping (Result<String, Error>) -> Void) {
        images += 1; self.matcher = matcher; self.queue = queue; completion = completionBlock
    }
    func finish(_ result: Result<String, Error>) {
        if case let .success(code) = result, runMatcher { _ = matcher?.match(code: code) }
        let callback = completion; (queue ?? .main).async { callback?(result) }
    }
}

@MainActor final class ScannerPhotoPermissionBoundaryTests: XCTestCase {
    private var fixtures = [ScannerPhotoFixture]()
    private var previous: AccountItem?
    override func setUp() { super.setUp(); previous = SelectedWalletSettings.shared.currentAccount; SelectedWalletSettings.shared.commitInternalValue(nil) }
    override func tearDown() {
        fixtures.forEach { $0.model.prepareDismiss(); $0.model.handleDismiss() }; fixtures = []
        SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown()
    }
    private func make(_ status: PHAuthorizationStatus, generated: Bool = false) -> ScannerPhotoFixture {
        let f = ScannerPhotoFixture(status: status, generated: generated); fixtures.append(f); return f
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 35_000_000) }
    private func activate(_ f: ScannerPhotoFixture) async {
        f.model.prepareAppearance(); f.capture.delegate?.qrCapture(service: f.capture, didSetup: AVCaptureSession()); await settle()
    }
    func testAuthorizedPhotoImportPresentsTheLibraryWithTheScannerDelegate() throws {
        let f = make(.authorized); f.model.activateImport()
        let picker = try XCTUnwrap(f.screen.presented.first as? UIImagePickerController)
        XCTAssertEqual(picker.sourceType, .photoLibrary)
        XCTAssertTrue(picker.delegate === f.model); XCTAssertTrue(f.permissions.callbacks.isEmpty)
    }
    func testLimitedPhotoPermissionCanOpenTheAllowedLibrary() {
        let f = make(.limited); f.model.activateImport()
        XCTAssertEqual(f.screen.presented.count, 1); XCTAssertEqual(f.screen.settingsPrompts, 0)
    }
    func testDeniedPhotoPermissionOffersSettingsWithoutPresentingAPicker() {
        let f = make(.denied); f.model.activateImport()
        XCTAssertEqual(f.screen.settingsPrompts, 1); XCTAssertTrue(f.screen.presented.isEmpty)
        XCTAssertTrue(f.permissions.callbacks.isEmpty)
    }
    func testRestrictedPhotoPermissionDoesNotAskAgainOrOpenTheLibrary() {
        let f = make(.restricted); f.model.activateImport()
        XCTAssertEqual(f.screen.settingsPrompts, 0); XCTAssertTrue(f.screen.presented.isEmpty)
        XCTAssertTrue(f.permissions.callbacks.isEmpty)
    }
    func testUndeterminedPhotoAccessWaitsForUserResponse() {
        let f = make(.notDetermined); f.model.activateImport()
        XCTAssertEqual(f.permissions.callbacks.count, 1); XCTAssertTrue(f.screen.presented.isEmpty)
    }
    func testRepeatedImportDuringPermissionPromptKeepsOneRequest() {
        let f = make(.notDetermined); f.model.activateImport(); f.model.activateImport()
        XCTAssertEqual(f.permissions.callbacks.count, 1)
    }
    func testNewFullPhotoGrantOpensExactlyOnePicker() async {
        let f = make(.notDetermined); f.model.activateImport()
        f.permissions.callbacks[0](.authorized); await settle()
        XCTAssertEqual(f.screen.presented.count, 1); XCTAssertEqual(f.screen.settingsPrompts, 0)
    }
    func testNewLimitedPhotoGrantAlsoOpensTheAllowedLibrary() async {
        let f = make(.notDetermined); f.model.activateImport()
        f.permissions.callbacks[0](.limited); await settle()
        XCTAssertEqual(f.screen.presented.count, 1)
    }
    func testNewPhotoDenialKeepsTheScannerAvailableWithoutSettingsPrompt() async {
        let f = make(.notDetermined); await activate(f); f.model.activateImport()
        f.permissions.callbacks[0](.denied); await settle()
        XCTAssertTrue(f.screen.presented.isEmpty); XCTAssertEqual(f.screen.settingsPrompts, 0)
        guard case .active = f.model.scanState else { return XCTFail("Denied photo access closed the scanner") }
    }
    func testPhotoGrantAfterScannerDismissalCannotPresentTheLibrary() async {
        let f = make(.notDetermined); f.model.activateImport(); f.model.prepareDismiss()
        f.permissions.callbacks[0](.authorized); await settle()
        XCTAssertTrue(f.screen.presented.isEmpty)
    }
    func testDuplicatePhotoGrantCannotPresentASecondPicker() async {
        let f = make(.notDetermined); f.model.activateImport()
        f.permissions.callbacks[0](.authorized); f.permissions.callbacks[0](.authorized); await settle()
        XCTAssertEqual(f.screen.presented.count, 1)
    }
    func testOldPhotoGrantCannotSatisfyANewRequestAfterReopening() async {
        let f = make(.notDetermined); f.model.activateImport(); f.model.prepareDismiss()
        f.model.prepareAppearance(); f.model.activateImport()
        XCTAssertEqual(f.permissions.callbacks.count, 2)
        f.permissions.callbacks[0](.authorized); await settle(); XCTAssertTrue(f.screen.presented.isEmpty)
        f.permissions.callbacks[1](.authorized); await settle(); XCTAssertEqual(f.screen.presented.count, 1)
    }
    func testMissingExtractionServiceNeverReadsOrRequestsPhotoPermission() {
        let f = make(.notDetermined); f.model.qrExtractionService = nil; f.model.activateImport()
        XCTAssertEqual(f.permissions.reads, 0); XCTAssertTrue(f.permissions.callbacks.isEmpty)
    }
    func testLatePhotoExtractionFailureDoesNotAlertAfterDismissal() async {
        let f = make(.authorized); await activate(f)
        let extraction = PermissionScannerImageExtraction(); f.model.qrExtractionService = extraction
        f.model.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: UIImage()])
        f.model.prepareDismiss(); extraction.finish(.failure(WalletQRExtractionServiceError.noFeatures)); await settle()
        XCTAssertTrue(f.screen.alerts.isEmpty); XCTAssertTrue(f.network.queries.isEmpty)
    }
    func testImageExtractionBeforeCameraReadinessStillReportsTheInvalidImage() async {
        let f = make(.authorized)
        let extraction = PermissionScannerImageExtraction(); f.model.qrExtractionService = extraction
        f.model.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: UIImage()])
        extraction.finish(.failure(WalletQRExtractionServiceError.noFeatures)); await settle()
        XCTAssertEqual(f.screen.alerts.count, 1)
    }
    func testSupersededPhotoCannotReplaceTheNewestRecipientLookup() async {
        let f = make(.authorized); await activate(f)
        let old = PermissionScannerImageExtraction(), current = PermissionScannerImageExtraction()
        f.model.qrExtractionService = old
        f.model.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: UIImage()])
        f.model.qrExtractionService = current
        f.model.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: UIImage()])
        current.finish(.success("current-recipient")); await settle()
        old.finish(.success("old-recipient")); await settle()
        XCTAssertEqual(f.network.queries, ["current-recipient"])
        XCTAssertEqual(f.network.calls.first?.cancellations, 0)
    }
    func testDuplicateExtractionCompletionDoesNotRepeatAnError() async {
        let f = make(.authorized); await activate(f)
        let extraction = PermissionScannerImageExtraction(); f.model.qrExtractionService = extraction
        f.model.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: UIImage()])
        extraction.finish(.failure(WalletQRExtractionServiceError.noFeatures)); await settle()
        extraction.finish(.failure(WalletQRExtractionServiceError.noFeatures)); await settle()
        XCTAssertEqual(f.screen.alerts.count, 1)
    }
    func testLateConnectPhotoCannotDismissTheScannerAgain() async throws {
        let f = make(.authorized); await activate(f)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); let previous = scene.windows.first { $0.isKeyWindow }
        window.rootViewController = f.screen; f.screen.loadViewIfNeeded(); window.isHidden = false; f.screen.completeDismissal = false
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        let extraction = PermissionScannerImageExtraction(); f.model.qrExtractionService = extraction
        f.model.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: UIImage()])
        f.model.prepareDismiss(); extraction.finish(.success("iroha://connect?v=1")); await settle()
        XCTAssertEqual(f.screen.dismissals, 0); XCTAssertTrue(f.network.queries.isEmpty)
    }
    func testShowReceiveWithoutASelectedAccountCannotInventARecipient() {
        let f = make(.authorized); f.model.showMyQrCode()
        XCTAssertTrue(f.route.requests.isEmpty); XCTAssertEqual(f.screen.dismissals, 0)
    }
    func testShowReceiveRoutesTheExactSelectedAccountAndRestartsOnReturn() {
        let f = make(.authorized)
        let account = AccountItem(address: "isolated-public-address", cryptoType: .sr25519, networkType: 69,
            username: "Selected fixture", publicKeyData: Data(repeating: 1, count: 32),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        SelectedWalletSettings.shared.commitInternalValue(account)
        f.model.showMyQrCode()
        XCTAssertEqual(f.route.requests.first?.1, account.address)
        XCTAssertEqual(f.route.requests.first?.2, account.username)
        XCTAssertEqual(f.route.requests.first?.0, "", "Malformed fixture addresses must not fabricate account bytes")
        XCTAssertTrue(f.route.controller === f.screen)
        f.route.closed?(); XCTAssertEqual(f.capture.starts, 1)
    }
    func testReceiveAlreadyUnderTheScannerDismissesWithoutBuildingAnotherScreen() {
        let f = make(.authorized, generated: true); f.model.showMyQrCode()
        XCTAssertEqual(f.screen.dismissals, 1); XCTAssertTrue(f.route.requests.isEmpty)
    }
}
@MainActor private final class ScannerPhotoFixture {
    let permissions: ScannerPhotoPermission
    let capture = PermissionScannerCapture(), screen = PermissionScannerView(), network = PermissionScannerNetwork()
    let route = ScannerPhotoRoute(), coder = PermissionScannerCoder(), generated: Bool
    lazy var model: ScanQRViewModel = {
        let factory = WalletNetworkOperationFactoryProtocolMock()
        let m = ScanQRViewModel(networkService: network, localSearchEngine: nil, qrScanServiceFactory: capture,
            qrCoderFactory: coder, wireframe: route, qrEncoder: coder, sharingFactory: PermissionScannerShare(),
            assetManager: nil, assetsProvider: nil, networkFacade: nil, isGeneratedQRCodeScreenShown: generated,
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared,
                networkOperationFactory: factory, identifierFactory: SingleProviderIdentifierFactory()),
            feeProvider: FeeProvider(account: nil), marketCapService: PermissionScannerMarket(), completion: nil,
            photoAccess: ScanQRPhotoAccess(status: { [permissions] in permissions.reads += 1; return permissions.status },
                request: { [permissions] in permissions.callbacks.append($0) }))
        m.view = screen; return m
    }()
    init(status: PHAuthorizationStatus, generated: Bool) { permissions = ScannerPhotoPermission(status); self.generated = generated }
}
private final class ScannerPhotoPermission {
    let status: PHAuthorizationStatus; var reads = 0
    var callbacks = [(PHAuthorizationStatus) -> Void]()
    init(_ status: PHAuthorizationStatus) { self.status = status }
}
private final class ScannerPhotoRoute: ScanQRWireframeProtocol {
    var requests = [(String, String, String)](), controller: UIViewController?, closed: (() -> Void)?
    func showGenerateQR(on controller: UIViewController?, accountId: String, address: String, username: String,
                        qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?, assetsProvider: AssetProviderProtocol?,
                        networkFacade: WalletNetworkOperationFactoryProtocol?, providerFactory: BalanceProviderFactory,
                        feeProvider: FeeProviderProtocol, marketCapService: MarketCapServiceProtocol, closeHandler: (() -> Void)?) {
        requests.append((accountId, address, username)); self.controller = controller; closed = closeHandler
    }
}
