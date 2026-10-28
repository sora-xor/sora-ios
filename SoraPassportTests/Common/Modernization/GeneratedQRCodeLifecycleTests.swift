// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class GeneratedQRCodeLifecycleTests: XCTestCase {
    private var previous: AccountItem?
    private var owner: AccountItem!
    private var recipient = ""
    override func setUpWithError() throws {
        try super.setUpWithError(); previous = SelectedWalletSettings.shared.currentAccount
        owner = try account(1, name: "QR owner"); recipient = try account(2, name: "Recipient").address
        SelectedWalletSettings.shared.commitInternalValue(owner)
    }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private func account(_ byte: UInt8, name: String) throws -> AccountItem {
        let key = Data(repeating: byte, count: 32)
        return AccountItem(address: try SS58AddressFactory().address(fromAccountId: key, type: SNAddressType(chain: .sora)), cryptoType: .sr25519, networkType: 69, username: name, publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
    }
    private struct Fixture { let model: GenerateQRViewModel; let service: GeneratedQRService; let route: GeneratedQRRoute; let view: GeneratedQRView; let output: GeneratedQROutput; let fee: GeneratedQRFee; let share: GeneratedQRShare; let balances: GeneratedQRBalances }
    private func make(scannerShown: Bool = false) -> Fixture {
        let service = GeneratedQRService(); let route = GeneratedQRRoute(); let view = GeneratedQRView(); let output = GeneratedQROutput(); let fee = GeneratedQRFee(); let share = GeneratedQRShare(); let network = WalletNetworkOperationFactoryProtocolMock(); network.transferFeeClosure = { try await fee.estimate($0) }
        let balances = GeneratedQRBalances(values: [WalletAssetId.xor.rawValue: 10, WalletAssetId.val.rawValue: 20])
        let model = GenerateQRViewModel(qrService: service, sharingFactory: share, accountId: owner.publicKeyData.toHex(), address: owner.address, username: owner.username,
            fiatService: GeneratedQRFiat(), assetManager: GeneratedQRAssets(), assetsProvider: balances, qrEncoder: GeneratedQRCoder(), networkFacade: network,
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory()),
            feeProvider: FeeProvider(), marketCapService: GeneratedQRMarket(), isScanQRShown: scannerShown)
        model.view = view; model.wireframe = route
        model.setupReceiveView = { output.received.append($0); output.deliveryThreads.append(Thread.isMainThread) }
        model.setupRequestView = { output.requests.append($0) }; model.setupSwicherView = { output.switcher = $0; output.switchUpdates += 1 }; model.updateContent = { output.modes.append($0) }; model.showShareContent = { output.shared.append($0) }
        return Fixture(model: model, service: service, route: route, view: view, output: output, fee: fee, share: share, balances: balances)
    }
    private func pause() async { try? await Task.sleep(nanoseconds: 40_000_000) }
    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }; XCTFail("QR flow did not finish", file: file, line: line)
    }
    private func scan(_ f: Fixture, amount: Decimal? = nil, asset: String? = WalletAssetId.val.rawValue) {
        f.model.scanQRCodeButtonTapped(); f.route.scanCompletion?(ScanQRResult(firstName: recipient, receiverInfo: ReceiveInfo(accountId: "recipient", assetId: asset, amount: amount.map(AmountDecimal.init(value:)), details: nil)))
    }
    func testInitialScreenPublishesBothModesAndTheOwnerRequest() {
        let f = make(); f.model.viewDidLoad(); XCTAssertEqual(f.output.switcher?.buttonViewModels.map(\.isSelected), [true, false]); XCTAssertEqual(f.output.requests.count, 1); XCTAssertEqual(f.output.requests.first?.address, owner.address); XCTAssertEqual(f.output.requests.first?.username, owner.username)
    }
    func testSwitchingModesPublishesOnlyRealSelectionChanges() {
        let f = make(); f.model.viewDidLoad(); f.output.switcher?.buttonViewModels[1].actionBlock?(); XCTAssertEqual(f.output.switcher?.buttonViewModels.map(\.isSelected), [false, true]); XCTAssertEqual(f.output.modes, [.request]); f.output.switcher?.buttonViewModels[1].actionBlock?(); XCTAssertEqual(f.output.switchUpdates, 2)
        f.output.switcher?.buttonViewModels[0].actionBlock?(); XCTAssertEqual(f.output.modes, [.request, .receive]); XCTAssertEqual(f.output.switcher?.buttonViewModels.map(\.isSelected), [true, false])
    }
    func testGenerationEncodesTheOriginalAccountWithoutAnAmount() {
        let f = make(); f.model.viewDidLoad(); XCTAssertEqual(f.service.infos, [ReceiveInfo(accountId: owner.publicKeyData.toHex(), assetId: WalletAssetId.xor.rawValue, amount: nil, details: "")]); XCTAssertGreaterThan(f.service.sizes[0].width, 0); XCTAssertEqual(f.service.sizes[0].width, f.service.sizes[0].height)
    }
    func testReceiveAddressAndNameBelongToTheGeneratedAccount() async {
        let f = make(); f.model.viewDidLoad(); f.service.complete(0); await wait { !f.output.received.isEmpty }; XCTAssertEqual(f.output.received.last?.address, owner.address); XCTAssertEqual(f.output.received.last?.name, owner.username)
    }
    func testChangingSelectedWalletWhileGeneratingCannotRelabelAnOldQR() async throws {
        let f = make(); f.model.viewDidLoad(); SelectedWalletSettings.shared.commitInternalValue(try account(3, name: "Another wallet")); f.service.complete(0); await wait { !f.output.received.isEmpty }
        XCTAssertEqual(f.output.received.last?.address, owner.address); XCTAssertEqual(f.output.received.last?.name, owner.username)
    }
    func testGenerationPublishesTheReceiveModelOnMain() async {
        let f = make(); f.model.viewDidLoad(); let done = expectation(description: "background completion")
        DispatchQueue.global().async { f.service.complete(0); done.fulfill() }; await fulfillment(of: [done]); await wait { !f.output.received.isEmpty }; XCTAssertEqual(f.output.deliveryThreads, [true])
    }
    func testShareUsesTheSameAccountAndImageAsTheDisplayedQR() async {
        let f = make(); f.model.viewDidLoad(); f.service.complete(0); await wait { !f.output.received.isEmpty }; f.output.received.last?.shareHandler?()
        XCTAssertEqual(f.share.infos.first?.accountId, owner.publicKeyData.toHex()); XCTAssertTrue(f.share.images.first === f.output.received.last?.qrImage); XCTAssertEqual(f.output.shared.first?.first as? String, "share-fixture")
    }
    func testOutOfOrderGenerationCannotReplaceTheLatestImage() async {
        let f = make(); f.model.viewDidLoad(); f.model.viewDidLoad(); let latest = UIImage(systemName: "circle")!; let old = UIImage(systemName: "square")!
        f.service.complete(1, image: latest); await wait { !f.output.received.isEmpty }; f.service.complete(0, image: old); await pause(); XCTAssertTrue(f.output.received.last?.qrImage === latest)
    }
    func testStartingAnotherGenerationCancelsThePreviousOperation() {
        let f = make(); f.model.viewDidLoad(); f.model.viewDidLoad(); XCTAssertTrue(f.service.operations[0].isCancelled); XCTAssertFalse(f.service.operations[1].isCancelled)
    }
    func testDiscardedModelCancelsGenerationWithoutPublishing() async {
        var f: Fixture? = make(); let service = f!.service; weak var model = f!.model; let output = f!.output; f!.model.viewDidLoad(); f = nil; await pause(); XCTAssertNil(model); XCTAssertTrue(service.operations[0].isCancelled); service.complete(0); await pause(); XCTAssertTrue(output.received.isEmpty)
    }
    func testRetainingAReceiveRowDoesNotRetainItsScreenModel() async {
        var f: Fixture? = make(); let output = f!.output; weak var model = f!.model; f!.model.viewDidLoad(); f!.service.complete(0); await wait { !output.received.isEmpty }; f = nil; await pause(); XCTAssertNil(model)
    }
    func testGenerationFailureDoesNotPublishOrShareAnImage() async {
        let f = make(); f.model.viewDidLoad(); f.service.completions[0](.failure(GeneratedQRError.expected)); await pause(); XCTAssertTrue(f.output.received.isEmpty); XCTAssertTrue(f.output.shared.isEmpty)
    }
    func testMissingGenerationResultDoesNotPublishAnImage() async {
        let f = make(); f.model.viewDidLoad(); f.service.completions[0](nil); await pause(); XCTAssertTrue(f.output.received.isEmpty)
    }
    func testAlreadyOpenScannerReturnsToItsOwner() {
        let f = make(scannerShown: true); f.model.scanQRCodeButtonTapped(); XCTAssertEqual(f.view.dismissals, 1); XCTAssertEqual(f.route.scans, 0)
    }
    func testScanWithoutAmountOpensAmountEntryForTheRequestedAsset() {
        let f = make(); scan(f); XCTAssertEqual(f.route.sends.count, 1); XCTAssertEqual(f.route.sends.first?.0, WalletAssetId.val.rawValue); XCTAssertEqual(f.route.sends.first?.1, recipient); XCTAssertTrue(f.fee.requests.isEmpty)
    }
    func testScanWithoutAnAssetUsesXor() {
        let f = make(); scan(f, asset: nil); XCTAssertEqual(f.route.sends.first?.0, WalletAssetId.xor.rawValue)
    }
    func testExactScannedAmountEstimatesFeeAndPreservesTransferFields() async {
        let f = make(); scan(f, amount: Decimal(string: "1.234567")!); await wait { !f.route.confirmations.isEmpty }
        XCTAssertEqual(f.route.confirmations.first?.0, WalletAssetId.val.rawValue); XCTAssertEqual(f.route.confirmations.first?.1, recipient); XCTAssertEqual(f.route.confirmations.first?.2, Decimal(string: "1.234567")); XCTAssertEqual(f.route.confirmations.first?.3, 1); XCTAssertEqual(f.fee.requests.count, 1)
    }
    func testInvalidScannedAmountNeverReachesFeeEstimation() async {
        for amount in [Decimal(-1), .zero, .nan, Decimal(string: "0.0000001")!] {
            let f = make(); scan(f, amount: amount); await pause(); XCTAssertTrue(f.fee.requests.isEmpty, "invalid amount \(amount)"); XCTAssertTrue(f.route.confirmations.isEmpty)
        }
    }
    func testUnknownScannedAssetNeverOpensTransferConfirmation() async {
        let f = make(); scan(f, amount: 1, asset: "unknown-asset"); await pause(); XCTAssertTrue(f.fee.requests.isEmpty); XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testFailedFeeCanRetryTheSameRequest() async {
        let f = make(); f.fee.fee = 0; scan(f, amount: 2); await wait { f.route.errors == 1 }; XCTAssertTrue(f.route.confirmations.isEmpty)
        f.fee.fee = 1; f.route.retry?(); await wait { f.route.confirmations.count == 1 }; XCTAssertEqual(f.fee.requests.map { $0.amount.decimalValue }, [2, 2])
    }
    func testWalletChangeDuringFeeReadCannotOpenConfirmation() async throws {
        let f = make(); f.fee.hold = true; scan(f, amount: 2); await wait { f.fee.pending.count == 1 }; SelectedWalletSettings.shared.commitInternalValue(try account(4, name: "Changed")); f.fee.completeAll(); await wait { f.route.errors == 1 }; XCTAssertTrue(f.route.confirmations.isEmpty)
    }
}
private enum GeneratedQRError: Error { case expected }
private final class GeneratedQROutput {
    var received: [ReceiveQRViewModel] = []; var requests: [InputSendInfoViewModel] = []; var switcher: SwitcherViewModel?; var switchUpdates = 0; var modes: [GenerateQRMode] = []; var shared: [[Any]] = []; var deliveryThreads: [Bool] = []
}
private final class GeneratedQRService: WalletQRServiceProtocol {
    var infos: [ReceiveInfo] = []; var sizes: [CGSize] = []; var operations: [Operation] = []; var completions: [(Result<UIImage, Error>?) -> Void] = []
    func generate(from info: ReceiveInfo, qrSize: CGSize, runIn queue: DispatchQueue, completionBlock: @escaping (Result<UIImage, Error>?) -> Void) throws -> Operation {
        infos.append(info); sizes.append(qrSize); completions.append(completionBlock); let op = BlockOperation {}; operations.append(op); return op
    }
    func complete(_ index: Int, image: UIImage = UIImage()) { completions[index](.success(image)) }
}
private final class GeneratedQRShare: AccountShareFactoryProtocol {
    var infos: [ReceiveInfo] = []; var images: [UIImage] = []
    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { infos.append(receiveInfo); images.append(qrImage); return ["share-fixture"] }
}
private final class GeneratedQRView: UIViewController, GenerateQRViewProtocol {
    var controller: UIViewController { self }; var dismissals = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}
private final class GeneratedQRRoute: GenerateQRWireframeProtocol {
    var scanCompletion: ((ScanQRResult) -> Void)?; var scans = 0; var errors = 0; var retry: (() -> Void)?; var sends: [(String?, String)] = []; var confirmations: [(String, String, Decimal, Decimal)] = []
    func showAssetSelection(assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol, assetViewModelFactory: AssetViewModelFactory, assetsProvider: AssetProviderProtocol?, assetIds: [String], marketCapService: MarketCapServiceProtocol, completion: @escaping (String) -> Void) {}
    func showReceive(selectedAsset: AssetInfo, accountId: String, address: String, amount: AmountDecimal?, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, fiatService: FiatServiceProtocol?, assetProvider: AssetProviderProtocol?, assetManager: AssetManagerProtocol?) {}
    func showScanQR(on view: UIViewController, networkFacade: WalletNetworkOperationFactoryProtocol, assetManager: AssetManagerProtocol, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, assetsProvider: AssetProviderProtocol?, providerFactory: BalanceProviderFactory, feeProvider: FeeProviderProtocol, marketCapService: MarketCapServiceProtocol, scanCompletion: @escaping (ScanQRResult) -> Void) { scans += 1; self.scanCompletion = scanCompletion }
    func showConfirmSendingAsset(on controller: UIViewController?, assetId: String, walletService: WalletServiceProtocol, assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol, recipientAddress: String, firstAssetAmount: Decimal, fee: Decimal, assetsProvider: AssetProviderProtocol?) { confirmations.append((assetId, recipientAddress, firstAssetAmount, fee)) }
    func showFeeEstimationError(on controller: UIViewController?, retry: @escaping () -> Void) { errors += 1; self.retry = retry }
    func showSend(on controller: UIViewController?, selectedTokenId: String?, selectedAddress: String, fiatService: FiatServiceProtocol?, assetManager: AssetManagerProtocol?, providerFactory: BalanceProviderFactory, networkFacade: WalletNetworkOperationFactoryProtocol?, assetsProvider: AssetProviderProtocol, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, marketCapService: MarketCapServiceProtocol) { sends.append((selectedTokenId, selectedAddress)) }
}
@MainActor private final class GeneratedQRFee {
    var fee: Decimal = 1; var hold = false; var requests: [TransferInfo] = []; var pending: [CheckedContinuation<Decimal, Error>] = []
    func estimate(_ info: TransferInfo) async throws -> Decimal { requests.append(info); if hold { return try await withCheckedThrowingContinuation { pending.append($0) } }; return fee }
    func completeAll() { let values = pending; pending.removeAll(); values.forEach { $0.resume(returning: fee) } }
}
private actor GeneratedQRFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }
private final class GeneratedQRBalances: AssetProviderProtocol {
    var values: [String: Decimal]; var unavailable: Set<String> = []; var observers = 0
    init(values: [String: Decimal]) { self.values = values }
    func getBalances(with assetIds: [String]) -> [BalanceData] { assetIds.compactMap { id in values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) } } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { observers += 1 }; func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}
private final class GeneratedQRAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true), AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 6, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }; func getAssetList() -> [AssetInfo]? { assets }; func updateAssetList(_ list: [AssetInfo]) {}; func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }; func visibleCount() -> UInt { 2 }; func setup(for accountSettings: SelectedWalletSettings) {}
}
private struct GeneratedQRCoder: WalletQREncoderProtocol { func encode(receiverInfo: ReceiveInfo) throws -> Data { Data() } }
private final class GeneratedQRMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }
