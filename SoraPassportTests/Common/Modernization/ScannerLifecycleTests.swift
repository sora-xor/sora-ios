// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import AVFoundation
import RobinHood
import SoraFoundation
import SoraKeystore
import SoraUIKit
import SoraUI
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ScannerLifecycleTests: XCTestCase {
    private var previous: AccountItem?
    private var model: ScanQRViewModel!
    private var network: ScannerNetwork!
    private var capture: ScannerCapture!
    private var screen: ScannerView!
    private var results: [ScanQRResult] = []
    override func setUp() {
        super.setUp(); previous = SelectedWalletSettings.shared.currentAccount
        SelectedWalletSettings.shared.commitInternalValue(nil)
        create()
    }
    override func tearDown() {
        model.prepareDismiss(); model.handleDismiss(); model = nil; screen = nil
        SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown()
    }
    private func create(local: InvoiceLocalSearchEngineProtocol? = nil) {
        network = ScannerNetwork(); capture = ScannerCapture(); screen = ScannerView()
        let factory = WalletNetworkOperationFactoryProtocolMock()
        let coder = ScannerCoder()
        model = ScanQRViewModel(networkService: network, localSearchEngine: local,
            qrScanServiceFactory: capture, qrCoderFactory: coder, qrEncoder: coder,
            sharingFactory: ScannerShare(), assetManager: nil, assetsProvider: nil, networkFacade: nil,
            isGeneratedQRCodeScreenShown: true,
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared,
                networkOperationFactory: factory, identifierFactory: SingleProviderIdentifierFactory()),
            feeProvider: FeeProvider(account: nil), marketCapService: ScannerMarket(),
            completion: { [weak self] in self?.results.append($0) })
        model.view = screen
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    private func activate() async {
        model.prepareAppearance(); capture.delegate?.qrCapture(service: capture, didSetup: AVCaptureSession()); await settle()
    }
    private func scan(_ account: String) async {
        XCTAssertTrue(capture.matcher?.match(code: account) == true)
        capture.delegate?.qrCapture(service: capture, didMatch: account); await settle()
    }
    private func found(_ account: String) -> SearchData { SearchData(accountId: account, firstName: account, lastName: "") }
    func testScannerScreenForwardsAppearanceAndDisappearanceInOrder() {
        let events = ScannerScreenEvents()
        let controller = ScanQRViewController(viewModel: events)
        controller.loadViewIfNeeded()
        controller.beginAppearanceTransition(true, animated: false); controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false); controller.endAppearanceTransition()
        XCTAssertEqual(events.calls, ["prepareAppearance", "handleAppearance", "prepareDismiss", "handleDismiss"])
    }
    func testScannerScreenImportActionAndPreviewUseTheProvidedModelAndSession() throws {
        let events = ScannerScreenEvents()
        let controller = ScanQRViewController(viewModel: events)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()
        func descendants<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
            ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
        }
        try XCTUnwrap(descendants(SoramitsuButton.self, controller.view).first).sendActions(for: .touchUpInside)
        XCTAssertEqual(events.calls, ["import"])
        let session = AVCaptureSession()
        controller.didReceive(session: session)
        let frame = try XCTUnwrap(descendants(CameraFrameView.self, controller.view).first)
        let preview = try XCTUnwrap(frame.frameLayer as? AVCaptureVideoPreviewLayer)
        XCTAssertTrue(preview.session === session)
        XCTAssertEqual(preview.videoGravity, .resizeAspectFill)
    }
    func testCaptureLifecycleStartsStopsAndDeliversOnlyTheInitialSession() async {
        await activate()
        XCTAssertEqual(capture.starts, 1); XCTAssertEqual(screen.sessions, 1)
        capture.delegate?.qrCapture(service: capture, didSetup: AVCaptureSession()); await settle()
        XCTAssertEqual(screen.sessions, 1)
        model.prepareDismiss(); model.handleDismiss()
        XCTAssertEqual(capture.stops, 1)
        guard case .inactive = model.scanState else { return XCTFail("Dismissed scanner remained active") }
        model.handleAppearance()
        guard case .active = model.scanState else { return XCTFail("Scanner did not resume") }
    }
    func testDismissBeforeCaptureSetupIgnoresTheLateSession() async {
        model.prepareAppearance(); model.prepareDismiss(); model.handleDismiss()
        capture.delegate?.qrCapture(service: capture, didSetup: AVCaptureSession()); await settle()
        XCTAssertEqual(screen.sessions, 0)
        guard case .inactive = model.scanState else { return XCTFail("Late camera setup reactivated a dismissed screen") }
    }
    func testReopeningAfterEarlyDismissAcceptsANewCaptureSession() async {
        model.prepareAppearance(); model.prepareDismiss(); model.handleDismiss()
        await activate()
        XCTAssertEqual(screen.sessions, 1)
        guard case .active = model.scanState else { return XCTFail("Reopened scanner did not activate") }
    }
    func testCompletedLookupCannotDeliverTwiceOrStartAnotherScanDuringDismissal() async {
        await activate(); await scan("first")
        network.completions[0](.success([found("first")]))
        await settle()
        network.completions[0](.success([found("first")]))
        await scan("second")
        XCTAssertEqual(results.map(\.firstName), ["first"])
        XCTAssertEqual(network.queries, ["first"])
        XCTAssertEqual(screen.dismissals, 1)
    }
    func testDuplicateScanDoesNotStartASecondLookup() async {
        await activate(); await scan("first"); await scan("first")
        XCTAssertEqual(network.queries, ["first"])
        XCTAssertEqual(network.calls.first?.cancellations, 0)
    }
    func testNewScanCancelsThePreviousLookup() async {
        await activate(); await scan("first"); await scan("second")
        XCTAssertEqual(network.queries, ["first", "second"])
        XCTAssertEqual(network.calls.first?.cancellations, 1)
        guard case let .processing(receiver, _) = model.scanState else { return XCTFail("New scan did not start") }
        XCTAssertEqual(receiver.accountId, "second")
    }
    func testSupersededLookupCannotCompleteWithTheNewScansReceiver() async {
        await activate(); await scan("first"); await scan("second")
        network.completions[0](.success([found("first")]))
        await settle()
        XCTAssertTrue(results.isEmpty)
        guard case .processing = model.scanState else { return XCTFail("Old result terminated the new lookup") }
        network.completions[1](.success([found("second")]))
        await settle()
        XCTAssertEqual(results.map(\.firstName), ["second"])
        XCTAssertEqual(results.first?.receiverInfo?.accountId, "second")
    }
    func testSupersededFailureCannotInterruptTheNewLookup() async {
        await activate(); await scan("first"); await scan("second")
        network.completions[0](.failure(NSError(domain: "fixture", code: 1)))
        await settle()
        XCTAssertTrue(screen.alerts.isEmpty)
        guard case .processing = model.scanState else { return XCTFail("Old failure terminated the new lookup") }
    }
    func testDismissCancelsLookupAndIgnoresLateCompletion() async {
        await activate(); await scan("first")
        model.prepareDismiss()
        XCTAssertEqual(network.calls.first?.cancellations, 1)
        network.completions[0](.success([found("first")]))
        await settle()
        XCTAssertTrue(results.isEmpty); XCTAssertEqual(screen.dismissals, 0)
    }
    func testMissingSearchResultEndsProcessingAndAllowsRetry() async {
        await activate(); await scan("first")
        network.completions[0](nil)
        await settle()
        guard case .active = model.scanState else { return XCTFail("Nil completion left scanner stuck processing") }
        XCTAssertEqual(screen.alerts.count, 1)
        await scan("first")
        XCTAssertEqual(network.queries.count, 2)
    }
    func testNotFoundEndsProcessingAndShowsAnError() async {
        await activate(); await scan("first")
        network.completions[0](.success([]))
        await settle()
        XCTAssertEqual(screen.alerts.count, 1); XCTAssertTrue(results.isEmpty)
        guard case .active = model.scanState else { return XCTFail("Empty result left scanner processing") }
    }
    func testSearchFailureEndsProcessingAndAllowsRetry() async {
        await activate(); await scan("first")
        network.completions[0](.failure(NSError(domain: "fixture", code: 1)))
        await settle()
        XCTAssertEqual(screen.alerts.count, 1)
        await scan("first"); XCTAssertEqual(network.queries.count, 2)
    }
    func testLocalRecipientCompletesWithoutNetworkLookup() async {
        create(local: ScannerLocal())
        await activate(); await scan("local")
        XCTAssertTrue(network.queries.isEmpty)
        XCTAssertEqual(results.map(\.firstName), ["Local recipient"])
        XCTAssertEqual(results.first?.receiverInfo?.accountId, "local")
    }
    func testCameraPermissionPromptIsShownOnlyOnce() async {
        capture.delegate?.qrCapture(service: capture, didReceive: WalletQRCaptureServiceError.deviceAccessDeniedPreviously)
        capture.delegate?.qrCapture(service: capture, didReceive: WalletQRCaptureServiceError.deviceAccessDeniedPreviously)
        await settle()
        XCTAssertEqual(screen.settingsPrompts, 1)
    }
    func testLateInvalidCodeAfterDismissalDoesNotPresentAnAlert() async {
        await activate(); model.prepareDismiss()
        capture.delegate?.qrCapture(service: capture, didFailMatching: "not-a-code")
        await settle()
        XCTAssertTrue(screen.alerts.isEmpty)
    }
    func testLateConnectCodeAfterDismissalCannotStartNavigation() async throws {
        await activate()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.rootViewController = screen
        screen.loadViewIfNeeded(); window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        screen.completeDismissal = false
        model.prepareDismiss()
        capture.delegate?.qrCapture(service: capture, didMatch: "iroha://connect")
        capture.delegate?.qrCapture(service: capture, didFailMatching: "iroha://connect")
        await settle()
        XCTAssertEqual(screen.dismissals, 0)
        XCTAssertTrue(screen.alerts.isEmpty)
    }
    func testUnrecognizedCodeReportsFailureWithoutLookingUpAnAccount() async {
        await activate()
        capture.delegate?.qrCapture(service: capture, didFailMatching: "not-a-code"); await settle()
        XCTAssertEqual(screen.alerts.count, 1); XCTAssertTrue(network.queries.isEmpty)
    }
}
private final class ScannerView: UIViewController, ScanQRViewProtocol {
    var controller: UIViewController { self }
    var completeDismissal = true
    var sessions = 0; var alerts: [String] = []; var settingsPrompts = 0; var dismissals = 0
    func didReceive(session: AVCaptureSession) { sessions += 1 }
    func presentAlert(title: String) { alerts.append(title) }
    func askOpenApplicationSettings(with message: String, title: String?, from view: ControllerBackedProtocol?, locale: Locale?) { settingsPrompts += 1 }
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; if completeDismissal { completion?() } }
}
private final class ScannerCapture: WalletQRCaptureServiceFactoryProtocol, WalletQRCaptureServiceProtocol {
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
private final class ScannerCoder: WalletQRCoderFactoryProtocol, WalletQRDecoderProtocol, WalletQREncoderProtocol {
    func createEncoder() -> WalletQREncoderProtocol { self }
    func createDecoder() -> WalletQRDecoderProtocol { self }
    func encode(receiverInfo: ReceiveInfo) throws -> Data { Data(receiverInfo.accountId.utf8) }
    func decode(data: Data) throws -> ReceiveInfo { ReceiveInfo(accountId: String(decoding: data, as: UTF8.self), assetId: nil, amount: nil, details: nil) }
}
private struct ScannerLocal: InvoiceLocalSearchEngineProtocol {
    func searchByAccountId(_ accountId: String) -> SearchData? { SearchData(accountId: accountId, firstName: "Local recipient", lastName: "") }
}
private struct ScannerShare: AccountShareFactoryProtocol {
    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { [] }
}
private final class ScannerMarket: MarketCapServiceProtocol {
    func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class ScannerCall: CancellableCall { var cancellations = 0; func cancel() { cancellations += 1 } }
private final class ScannerNetwork: WalletServiceProtocol {
    var queries: [String] = []; var completions: [SearchCompletionBlock] = []; var calls: [ScannerCall] = []
    private let unused = WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock())
    func search(for searchString: String, runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall {
        queries.append(searchString); completions.append(completionBlock); let call = ScannerCall(); calls.append(call); return call
    }
    func fetchBalance(for assets: [String], runCompletionIn queue: DispatchQueue, completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall { unused.fetchBalance(for: assets, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransactionHistory(for filter: WalletHistoryRequest, pagination: Pagination, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall { unused.fetchTransactionHistory(for: filter, pagination: pagination, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransferMetadata(for info: TransferMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransferMetadataCompletionBlock) -> CancellableCall { unused.fetchTransferMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func transfer(info: TransferInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("Scanner attempted a transfer"); return ScannerCall() }
    func prepareTransferSubmission(for info: TransferInfo, preSigningValidation: @escaping () throws -> Void) async throws -> PreparedSora2TransferSubmission { XCTFail("Scanner attempted to sign"); throw CancellationError() }
    func submitPreparedTransfer(_ submission: PreparedSora2TransferSubmission, info: TransferInfo, preTransportValidation: @escaping () throws -> Void) async throws -> Data { XCTFail("Scanner attempted a submission"); throw CancellationError() }
    func fetchContacts(runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall { unused.fetchContacts(runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping WithdrawalMetadataCompletionBlock) -> CancellableCall { unused.fetchWithdrawalMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func withdraw(info: WithdrawInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("Scanner attempted withdrawal"); return ScannerCall() }
}

private final class ScannerScreenEvents: ScanQRViewModelProtocol {
    var calls: [String] = []
    func prepareAppearance() { calls.append("prepareAppearance") }
    func handleAppearance() { calls.append("handleAppearance") }
    func prepareDismiss() { calls.append("prepareDismiss") }
    func handleDismiss() { calls.append("handleDismiss") }
    func activateImport() { calls.append("import") }
}
