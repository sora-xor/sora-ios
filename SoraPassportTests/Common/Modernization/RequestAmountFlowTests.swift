// SPDX-License-Identifier: Apache-2.0
import Combine
import Foundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class RequestAmountFlowTests: XCTestCase {
    private func make() -> RequestFlowFixture { RequestFlowFixture() }
    private func settle() async { await Task.yield(); try? await Task.sleep(nanoseconds: 20_000_000) }
    private func buttons(_ root: UIView) -> [SoramitsuButton] { (root as? SoramitsuButton).map { [$0] } ?? root.subviews.flatMap(buttons) }
    func testDefaultRequestUsesXorAndTheSelectedPublicRecipient() {
        let f = make(); f.model.viewDidLoad(); f.model.inputedAmount = 2; f.send(.createQr)
        XCTAssertEqual(f.route.receives.count, 1); XCTAssertEqual(f.route.receives.first?.0, WalletAssetId.xor.rawValue); XCTAssertEqual(f.route.receives.first?.1, "public-recipient"); XCTAssertEqual(f.route.receives.first?.2, 2)
    }
    func testSelectedAssetAndExactAmountReachTheGeneratedRequest() {
        let f = make(); f.model.asset = f.assets.assets[1]; f.model.inputedAmount = Decimal(string: "1.234567")!; f.send(.createQr)
        XCTAssertEqual(f.route.receives.first?.0, WalletAssetId.val.rawValue); XCTAssertEqual(f.route.receives.first?.2, Decimal(string: "1.234567"))
    }
    func testInvalidAmountsCannotGeneratePaymentRequests() {
        let f = make(); f.model.asset = f.assets.assets[1]
        for amount in [Decimal.zero, -1, .nan, Decimal(string: "0.0000001")!] { f.model.inputedAmount = amount; f.send(.createQr) }
        XCTAssertTrue(f.route.receives.isEmpty)
    }
    func testEmptyRecipientCannotGenerateAPaymentRequest() {
        let f = make(); f.model.asset = f.assets.assets[0]; f.model.inputedAmount = 2; f.model.address = ""; f.send(.createQr)
        XCTAssertTrue(f.route.receives.isEmpty)
    }
    func testNoSelectedAssetCannotGenerateAPaymentRequest() {
        let f = make(); f.model.inputedAmount = 2; f.send(.createQr); XCTAssertTrue(f.route.receives.isEmpty)
    }
    func testAssetChooserReceivesTheVisibleCatalogAndAppliesItsSelection() {
        let f = make(); f.send(.choiseAsset); XCTAssertEqual(f.route.selections, [f.assets.assets.map(\.assetId)])
        f.route.selection?(WalletAssetId.val.rawValue); XCTAssertEqual(f.model.assetSymbol, "VAL")
    }
    func testChangingAssetCannotRetainAnotherTokensBalance() {
        let f = make(); f.model.asset = f.assets.assets[0]; XCTAssertEqual(f.model.assetBalance.balance.decimalValue, 12)
        f.model.asset = f.assets.assets[1]; XCTAssertEqual(f.model.assetBalance.identifier, WalletAssetId.val.rawValue); XCTAssertEqual(f.model.assetBalance.balance.decimalValue, 0)
    }
    func testMissingBalanceRefreshCannotLeaveAStaleSpendableValue() {
        let f = make(); f.model.asset = f.assets.assets[0]; f.balances.values = [:]; f.model.processBalance(data: [])
        XCTAssertEqual(f.model.assetBalance.balance.decimalValue, 0)
    }
    func testUnavailableBalanceDisplaysANoticeInsteadOfTheStaleValue() {
        let f = make(); f.model.asset = f.assets.assets[0]
        f.balances.unavailable = [WalletAssetId.xor.rawValue]; f.model.processBalance(data: [])
        XCTAssertEqual(f.model.balanceFiatText, WalletUX.balanceUnavailableText)
    }
    func testUnavailableBalanceDoesNotPreventReceivingAnExactAmount() {
        let f = make(); f.balances.unavailable = [WalletAssetId.xor.rawValue]; f.model.asset = f.assets.assets[0]
        f.model.inputedAmount = 2; f.send(.createQr); XCTAssertEqual(f.route.receives.count, 1)
    }
    func testBalanceRefreshContinuesToUseTheSelectedAsset() {
        let f = make(); f.balances.values[WalletAssetId.val.rawValue] = 3; f.model.asset = f.assets.assets[1]
        f.balances.values[WalletAssetId.val.rawValue] = 7; f.model.processBalance(data: [])
        XCTAssertEqual(f.model.assetBalance.identifier, WalletAssetId.val.rawValue); XCTAssertEqual(f.model.assetBalance.balance.decimalValue, 7)
    }
    func testBindingAReplacementModelIgnoresOldUsernameUpdates() async {
        let a = make(), b = make(); let view = InputSendInfoView(); view.viewModel = a.model; view.viewModel = b.model
        b.model.username = "Current"; await settle(); a.model.username = "Obsolete"; await settle()
        XCTAssertEqual(view.recipientView.contactView.usernameTitle.sora.text, "Current")
    }
    func testBindingAReplacementModelIgnoresOldAssetUpdates() async {
        let a = make(), b = make(); let view = InputSendInfoView(); view.viewModel = a.model; view.viewModel = b.model
        b.model.assetSymbol = "VAL"; await settle(); a.model.assetSymbol = "XOR"; await settle()
        XCTAssertEqual(view.assetView.sora.assetSymbol, "VAL")
    }
    func testRepeatedModelBindingDoesNotDuplicateCreateActions() async throws {
        let f = make(); f.model.asset = f.assets.assets[0]; f.model.inputedAmount = 2
        let view = InputSendInfoView(); view.viewModel = f.model; view.viewModel = f.model; await settle()
        let button = try XCTUnwrap(buttons(view).last); button.sendActions(for: .touchUpInside)
        // Fixture's explicit publisher has no event here; only one view button event is emitted.
        XCTAssertEqual(f.route.receives.count, 1)
    }
    func testReplacementModelOwnsTheNextCreateAction() async throws {
        let a = make(), b = make(); a.model.asset = a.assets.assets[0]; b.model.asset = b.assets.assets[0]; a.model.inputedAmount = 1; b.model.inputedAmount = 2
        let view = InputSendInfoView(); view.viewModel = a.model; view.viewModel = b.model; await settle()
        try XCTUnwrap(buttons(view).last).sendActions(for: .touchUpInside)
        XCTAssertTrue(a.route.receives.isEmpty); XCTAssertEqual(b.route.receives.count, 1)
    }
    func testTextFieldAcceptsAnExactDecimalSeparator() {
        let f = make(); let view = InputSendInfoView(); view.viewModel = f.model
        view.assetView.textField.text = "1,25"; view.assetView.textField.sendActions(for: .editingChanged); XCTAssertEqual(f.model.inputedAmount, Decimal(string: "1.25"))
    }
    func testPastedTrailingGarbageDoesNotBecomeAValidRequestAmount() {
        let f = make(); let view = InputSendInfoView(); view.viewModel = f.model
        view.assetView.textField.text = "12oops"; view.assetView.textField.sendActions(for: .editingChanged); XCTAssertEqual(f.model.inputedAmount, 0)
    }
    func testPastedRepeatedSeparatorsDoNotSilentlyChangeTheAmount() {
        let f = make(); let view = InputSendInfoView(); view.viewModel = f.model
        view.assetView.textField.text = "1.2.3"; view.assetView.textField.sendActions(for: .editingChanged); XCTAssertEqual(f.model.inputedAmount, 0)
    }
    func testEmptyInputClearsThePreviouslyEnteredAmount() {
        let f = make(); let view = InputSendInfoView(); view.viewModel = f.model; f.model.inputedAmount = 12
        view.assetView.textField.text = ""; view.assetView.textField.sendActions(for: .editingChanged); XCTAssertEqual(f.model.inputedAmount, 0)
    }
}
@MainActor private final class RequestFlowFixture {
    let assets = RequestFlowAssets(), balances = RequestFlowBalances(values: [WalletAssetId.xor.rawValue: 12]), fiat = RequestFlowFiat(), route = RequestFlowRoute(), input = PassthroughSubject<InputSendInfoViewModel.Input, Never>()
    let model: InputSendInfoViewModel
    var output: AnyCancellable?
    init() {
        model = InputSendInfoViewModel(address: "public-recipient", accountId: "public-account", username: "Fixture", fiatService: fiat, assetManager: assets, assetsProvider: balances, wireframe: route, qrEncoder: RequestFlowCoder(), sharingFactory: RequestFlowShare(), marketCapService: RequestFlowMarket())
        output = model.transform(input: input.eraseToAnyPublisher()).sink { _ in }
    }
    func send(_ event: InputSendInfoViewModel.Input) { input.send(event) }
}
private final class RequestFlowShare: AccountShareFactoryProtocol {
    var infos: [ReceiveInfo] = []; var images: [UIImage] = []
    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { infos.append(receiveInfo); images.append(qrImage); return ["share-fixture"] }
}
private final class RequestFlowView: UIViewController, GenerateQRViewProtocol {
    var controller: UIViewController { self }; var dismissals = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}
private final class RequestFlowRoute: GenerateQRWireframeProtocol {
    var receives = [(String, String, Decimal?)](), selections = [[String]](), selection: ((String) -> Void)?
    var scanCompletion: ((ScanQRResult) -> Void)?; var scans = 0; var errors = 0; var retry: (() -> Void)?; var sends: [(String?, String)] = []; var confirmations: [(String, String, Decimal, Decimal)] = []
    func showAssetSelection(assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol, assetViewModelFactory: AssetViewModelFactory, assetsProvider: AssetProviderProtocol?, assetIds: [String], marketCapService: MarketCapServiceProtocol, completion: @escaping (String) -> Void) { selections.append(assetIds); selection = completion }
    func showReceive(selectedAsset: AssetInfo, accountId: String, address: String, amount: AmountDecimal?, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, fiatService: FiatServiceProtocol?, assetProvider: AssetProviderProtocol?, assetManager: AssetManagerProtocol?) { receives.append((selectedAsset.assetId, address, amount?.decimalValue)) }
    func showScanQR(on view: UIViewController, networkFacade: WalletNetworkOperationFactoryProtocol, assetManager: AssetManagerProtocol, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, assetsProvider: AssetProviderProtocol?, providerFactory: BalanceProviderFactory, feeProvider: FeeProviderProtocol, marketCapService: MarketCapServiceProtocol, scanCompletion: @escaping (ScanQRResult) -> Void) { scans += 1; self.scanCompletion = scanCompletion }
    func showConfirmSendingAsset(on controller: UIViewController?, assetId: String, walletService: WalletServiceProtocol, assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol, recipientAddress: String, firstAssetAmount: Decimal, fee: Decimal, assetsProvider: AssetProviderProtocol?) { confirmations.append((assetId, recipientAddress, firstAssetAmount, fee)) }
    func showFeeEstimationError(on controller: UIViewController?, retry: @escaping () -> Void) { errors += 1; self.retry = retry }
    func showSend(on controller: UIViewController?, selectedTokenId: String?, selectedAddress: String, fiatService: FiatServiceProtocol?, assetManager: AssetManagerProtocol?, providerFactory: BalanceProviderFactory, networkFacade: WalletNetworkOperationFactoryProtocol?, assetsProvider: AssetProviderProtocol, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, marketCapService: MarketCapServiceProtocol) { sends.append((selectedTokenId, selectedAddress)) }
}
private actor RequestFlowFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }
private final class RequestFlowBalances: AssetProviderProtocol {
    var values: [String: Decimal]; var unavailable: Set<String> = []; var observers = 0
    init(values: [String: Decimal]) { self.values = values }
    func getBalances(with assetIds: [String]) -> [BalanceData] { assetIds.compactMap { id in values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) } } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { observers += 1 }; func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}
private final class RequestFlowAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true), AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 6, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }; func getAssetList() -> [AssetInfo]? { assets }; func updateAssetList(_ list: [AssetInfo]) {}; func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }; func visibleCount() -> UInt { 2 }; func setup(for accountSettings: SelectedWalletSettings) {}
}
private struct RequestFlowCoder: WalletQREncoderProtocol { func encode(receiverInfo: ReceiveInfo) throws -> Data { Data() } }
private final class RequestFlowMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }
