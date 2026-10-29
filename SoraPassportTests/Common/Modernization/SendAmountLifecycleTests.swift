// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import RobinHood
import IrohaCrypto
import SSFUtils
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class SendAmountLifecycleTests: XCTestCase {
    private let xor = WalletAssetId.xor.rawValue; private let val = WalletAssetId.val.rawValue
    private var previous: AccountItem?; private var sender = ""; private var recipient = ""
    override func setUpWithError() throws {
        try super.setUpWithError(); previous = SelectedWalletSettings.shared.currentAccount
        sender = try SS58AddressFactory().address(fromAccountId: Data(repeating: 1, count: 32), type: SNAddressType(chain: .sora))
        recipient = try SS58AddressFactory().address(fromAccountId: Data(repeating: 2, count: 32), type: SNAddressType(chain: .sora))
        SelectedWalletSettings.shared.commitInternalValue(AccountItem(address: sender, cryptoType: .sr25519, networkType: 69, username: "Fixture", publicKeyData: Data(repeating: 1, count: 32), settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true))
    }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private struct Fixture { let model: InputAssetAmountViewModel; let view: SendAmountView; let balances: SendAmountBalances; let fiat: SendAmountFiat; let route: SendAmountRoutes; let fee: SendAmountFee }
    private func make(asset: String? = nil, values: [String: Decimal]? = nil) -> Fixture {
        let provider = SendAmountBalances(values: values ?? [xor: 10, val: 10]); let fiat = SendAmountFiat(); let routes = SendAmountRoutes(); let network = WalletNetworkOperationFactoryProtocolMock(); let fee = SendAmountFee()
        network.transferFeeClosure = { try await fee.estimate($0) }
        let model = InputAssetAmountViewModel(selectedTokenId: asset ?? xor, selectedAddress: recipient, fiatService: fiat, assetManager: SendAmountAssets(),
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory()),
            networkFacade: network, wireframe: routes, assetsProvider: provider, qrEncoder: SendAmountCoder(), sharingFactory: SendAmountShare(), marketCapService: SendAmountMarket())
        let view = SendAmountView(); model.view = view; model.viewDidLoad(); return Fixture(model: model, view: view, balances: provider, fiat: fiat, route: routes, fee: fee)
    }
    private func pause() async { try? await Task.sleep(nanoseconds: 35_000_000) }
    private func wait(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 { if predicate() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }; XCTFail("Amount flow did not finish", file: file, line: line)
    }
    func testAmountScreenStartsWithCurrentAssetRecipientAndNoReview() async {
        let f = make(); await pause(); XCTAssertEqual(f.view.symbol, "XOR"); XCTAssertEqual(f.view.recipient, recipient); XCTAssertEqual(f.view.amount, "0"); XCTAssertFalse(f.view.enabled); XCTAssertEqual(f.balances.observers, 1)
    }
    func testPositiveAmountWithinBothBalancesEnablesReview() async {
        let f = make(asset: val); f.model.inputedFirstAmount = 2; await pause(); XCTAssertTrue(f.view.enabled); XCTAssertTrue(f.model.checkBalances()); XCTAssertTrue(f.model.checkXorBalance())
    }
    func testNegativeNaNAndSubatomicAmountsCannotEnableReview() async {
        let f = make(asset: val)
        for amount in [Decimal(-1), .nan, Decimal(string: "0.0000001")!] { f.model.inputedFirstAmount = amount; await pause(); XCTAssertFalse(f.view.enabled, "Invalid amount \(amount)") }
    }
    func testBalanceDecreaseImmediatelyRevokesAnExistingAmount() async {
        let f = make(); f.model.inputedFirstAmount = 5; XCTAssertTrue(f.view.enabled); f.balances.values[xor] = 1; f.model.processBalance(data: []); await pause(); XCTAssertFalse(f.view.enabled); XCTAssertFalse(f.model.checkBalances())
    }
    func testBalanceIncreaseReenablesAPreviouslyUnaffordableAmount() async {
        let f = make(); f.model.inputedFirstAmount = 20; XCTAssertFalse(f.view.enabled); f.balances.values[xor] = 30; f.model.processBalance(data: []); await pause(); XCTAssertTrue(f.view.enabled)
    }
    func testMissingLatestBalanceCannotLeaveAnOldSpendableValue() async {
        let f = make(); f.model.inputedFirstAmount = 5; f.balances.values.removeValue(forKey: xor); f.model.processBalance(data: []); await pause()
        XCTAssertFalse(f.view.enabled); XCTAssertTrue(f.model.firstAssetBalanceUnavailable); XCTAssertEqual(f.view.balance, WalletUX.balanceUnavailableText)
    }
    func testSwitchingToAnUnreadAssetCannotReuseThePreviousAssetBalance() async {
        let f = make(values: [xor: 10]); f.model.firstAssetId = val; f.model.inputedFirstAmount = 1; await pause(); XCTAssertFalse(f.view.enabled); XCTAssertTrue(f.model.firstAssetBalanceUnavailable)
    }
    func testUnavailableFeeBalanceRevokesReviewButDoesNotInventAnInsufficientAssetBalance() async {
        let f = make(asset: val); f.model.inputedFirstAmount = 1; f.balances.unavailable = [xor]; f.model.processBalance(data: []); await pause()
        XCTAssertFalse(f.view.enabled); XCTAssertTrue(f.model.checkBalances())
    }
    func testUnavailableAmountCannotBeReplacedByAPreset() async {
        let f = make(); f.balances.values.removeValue(forKey: xor); f.balances.unavailable = [xor]; f.model.processBalance(data: []); await pause(); f.model.didSelect(variant: 1); XCTAssertEqual(f.model.inputedFirstAmount, 0)
    }
    func testFractionalAndMaximumPresetsUseTheSelectedBalance() {
        let f = make(asset: val); f.model.didSelect(variant: Decimal(string: "0.25")!); XCTAssertEqual(f.model.inputedFirstAmount, Decimal(string: "2.5")); f.model.didSelect(variant: 1); XCTAssertEqual(f.model.inputedFirstAmount, 10)
    }
    func testInvalidPresetCannotReplaceTheEnteredAmount() {
        let f = make(); f.model.inputedFirstAmount = 2
        for variant in [Decimal.zero, -1, 2, .nan] { f.model.didSelect(variant: variant); XCTAssertEqual(f.model.inputedFirstAmount, 2) }
    }
    func testExactFeeReviewPassesTheReviewedRecipientAmountAndAsset() async {
        let f = make(asset: val); f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped(); await wait { f.route.confirmations.count == 1 }
        XCTAssertEqual(f.route.confirmations.first?.0, val); XCTAssertEqual(f.route.confirmations.first?.1, recipient); XCTAssertEqual(f.route.confirmations.first?.2, 2); XCTAssertEqual(f.route.confirmations.first?.3, 1)
        XCTAssertEqual(f.fee.requests.count, 1); XCTAssertEqual(f.fee.requests.first?.amount.decimalValue, 2)
    }
    func testMaximumXorReviewReestimatesTheFeeForTheAdjustedAmount() async {
        let f = make(); f.model.didSelect(variant: 1); f.model.reviewButtonTapped(); await wait { f.route.confirmations.count == 1 }
        XCTAssertEqual(f.fee.requests.map { $0.amount.decimalValue }, [10, 9]); XCTAssertEqual(f.route.confirmations.first?.2, 9); XCTAssertEqual(f.model.inputedFirstAmount, 9); XCTAssertEqual(f.view.amount, "9")
    }
    func testNonFeeAssetPresetIsNotLimitedByTheXorFeeMagnitude() async {
        let f = make(values: [xor: 10, val: Decimal(string: "0.5")!]); f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped(); await wait { f.route.confirmations.count == 1 }
        f.model.firstAssetId = val; f.model.didSelect(variant: 1); XCTAssertEqual(f.model.inputedFirstAmount, Decimal(string: "0.5"))
    }
    func testEditingTheAmountWhileFeeIsPendingInvalidatesTheOldReview() async {
        let f = make(); f.fee.hold = true; f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped(); await wait { f.fee.pending.count == 1 }
        f.model.inputedFirstAmount = 3; f.fee.completeAll(); await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testRepeatedReviewActionCannotLaunchTwoConcurrentFeeRequests() async {
        let f = make(); f.fee.hold = true; f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped(); f.model.reviewButtonTapped(); await pause()
        XCTAssertEqual(f.fee.requests.count, 1); f.fee.completeAll(); await pause(); XCTAssertLessThanOrEqual(f.route.confirmations.count, 1)
    }
    func testReviewRereadsBalanceThatChangedWithoutAnObserverCallback() async {
        let f = make(); f.model.inputedFirstAmount = 2; f.balances.values.removeValue(forKey: xor); f.model.reviewButtonTapped(); await pause()
        XCTAssertTrue(f.route.confirmations.isEmpty); XCTAssertTrue(f.fee.requests.isEmpty); XCTAssertFalse(f.view.enabled)
    }
    func testRejectedFeeDoesNotOpenConfirmation() async {
        let f = make(); f.fee.fee = 0; f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped(); await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testChangingTheAssetResetsTheAmountAndShowsItsNewBalance() async {
        let f = make(values: [xor: 10, val: 20]); f.model.inputedFirstAmount = 2; f.model.firstAssetId = val; await pause()
        XCTAssertEqual(f.model.inputedFirstAmount, 0); XCTAssertEqual(f.view.symbol, "VAL"); XCTAssertEqual(f.view.balance, "20"); XCTAssertFalse(f.view.enabled)
    }
    func testDiscardingTheAmountModelRemovesItsBalanceObserver() async {
        let balances: SendAmountBalances; weak var released: InputAssetAmountViewModel?
        do { let f = make(); balances = f.balances; released = f.model; await pause() }; await pause(); XCTAssertNil(released); XCTAssertEqual(balances.observers, 0)
    }
}
@MainActor private final class SendAmountFee {
    var sequence = [Decimal]()
    var fee: Decimal = 1; var hold = false; var requests: [TransferInfo] = []; var pending: [CheckedContinuation<Decimal, Error>] = []
    func estimate(_ info: TransferInfo) async throws -> Decimal { requests.append(info); if hold { return try await withCheckedThrowingContinuation { pending.append($0) } }; return sequence.isEmpty ? fee : sequence.removeFirst() }
    func completeAll() { let values = pending; pending.removeAll(); values.forEach { $0.resume(returning: fee) } }
}
private final class SendAmountView: UIViewController, InputAssetAmountViewProtocol {
    var controller: UIViewController { self }; var enabled = false; var balance = ""; var amount = ""; var symbol = ""; var recipient = ""; var alerts: [UIViewController] = []; var focuses = 0
    func updateFirstAsset(balance: String) { self.balance = balance }; func updateFirstAsset(symbol: String, image: UIImage?) { self.symbol = symbol }; func updateFirstAsset(fiatText: String) {}
    func updateRecipientView(with address: String) { recipient = address }; func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {}
    func set(firstAmountText: String) { amount = firstAmountText }; func setupButton(isEnabled: Bool) { enabled = isEnabled }; func focusFirstField() { focuses += 1 }; func updateWarinignView(model: WarningViewModel) {}
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) { alerts.append(viewControllerToPresent); completion?() }
}
private final class SendAmountRoutes: InputAssetAmountWireframeProtocol {
    var confirmations: [(String, String, Decimal, Decimal)] = []
    var assetChoices = [String](), addressAsset: String?
    var chooseAsset: ((String) -> Void)?, chooseAddress: ((ScanQRResult) -> Void)?
    func showChoiceBaseAsset(on controller: UIViewController?, assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol, assetViewModelFactory: AssetViewModelFactory, assetsProvider: AssetProviderProtocol?, assetIds: [String], marketCapService: MarketCapServiceProtocol, completion: @escaping (String) -> Void) { assetChoices = assetIds; chooseAsset = completion }
    func showSelectAddress(on controller: UIViewController?, assetId: String, dataProvider: SingleValueProvider<[SearchData]>, walletService: WalletServiceProtocol, networkFacade: WalletNetworkOperationFactoryProtocol, assetManager: AssetManagerProtocol, qrEncoder: WalletQREncoderProtocol, sharingFactory: AccountShareFactoryProtocol, assetsProvider: AssetProviderProtocol?, providerFactory: BalanceProviderFactory, feeProvider: FeeProviderProtocol, marketCapService: MarketCapServiceProtocol, completion: ((ScanQRResult) -> Void)?) { addressAsset = assetId; chooseAddress = completion }
    func showConfirmSendingAsset(on controller: UINavigationController?, assetId: String, walletService: WalletServiceProtocol, assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol, recipientAddress: String, firstAssetAmount: Decimal, fee: Decimal, assetsProvider: AssetProviderProtocol?) { confirmations.append((assetId, recipientAddress, firstAssetAmount, fee)) }
}
private actor SendAmountFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }
private final class SendAmountBalances: AssetProviderProtocol {
    var values: [String: Decimal]; var unavailable: Set<String> = []; var observers = 0
    init(values: [String: Decimal]) { self.values = values }
    func getBalances(with assetIds: [String]) -> [BalanceData] { assetIds.compactMap { id in values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) } } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { observers += 1 }; func remove(observer: AssetProviderObserverProtocol) { observers -= 1 }
}
private final class SendAmountAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true), AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 6, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }; func getAssetList() -> [AssetInfo]? { assets }; func updateAssetList(_ list: [AssetInfo]) {}; func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }; func visibleCount() -> UInt { 2 }; func setup(for accountSettings: SelectedWalletSettings) {}
}
private struct SendAmountCoder: WalletQREncoderProtocol { func encode(receiverInfo: ReceiveInfo) throws -> Data { Data() } }
private struct SendAmountShare: AccountShareFactoryProtocol { func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { [] } }
private final class SendAmountMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }

extension SendAmountLifecycleTests {
    func testAssetPickerReceivesAvailableAssetsAndUpdatesTheSelectedToken() async {
        let f = make(); f.model.inputedFirstAmount = 4; f.model.choiceBaseAssetButtonTapped()
        XCTAssertEqual(f.route.assetChoices, [xor, val]); f.route.chooseAsset?(val); await pause()
        XCTAssertEqual(f.model.firstAssetId, val); XCTAssertEqual(f.view.symbol, "VAL"); XCTAssertEqual(f.model.inputedFirstAmount, 0)
    }
    func testMissingFiatServiceDoesNotOpenAnIncompleteAssetPicker() {
        let f = make(); f.model.fiatService = nil; f.model.choiceBaseAssetButtonTapped()
        XCTAssertNil(f.route.chooseAsset); XCTAssertTrue(f.route.assetChoices.isEmpty)
    }
    func testAddressPickerUsesTheCurrentAssetAndReturnsTheExactSelectedRecipient() {
        let f = make(asset: val); f.model.selectAddress()
        XCTAssertEqual(f.route.addressAsset, val); f.route.chooseAddress?(.init(firstName: sender, receiverInfo: nil))
        XCTAssertEqual(f.model.selectedAddress, sender); XCTAssertEqual(f.view.recipient, sender); XCTAssertEqual(f.view.focuses, 1)
    }
    func testInvoiceSelectionAlsoChangesTheRequestedAsset() async {
        let f = make(); f.model.selectAddress()
        f.route.chooseAddress?(.init(firstName: recipient, receiverInfo: .init(accountId: recipient, assetId: val, amount: nil, details: nil)))
        await pause(); XCTAssertEqual(f.model.firstAssetId, val); XCTAssertEqual(f.view.symbol, "VAL"); XCTAssertEqual(f.view.focuses, 1)
    }
    func testClearingRecipientImmediatelyDisablesReview() {
        let f = make(); f.model.inputedFirstAmount = 2; XCTAssertTrue(f.view.enabled)
        f.model.selectedAddress = nil; XCTAssertEqual(f.view.recipient, ""); XCTAssertFalse(f.view.enabled)
        f.model.reviewButtonTapped(); XCTAssertTrue(f.fee.requests.isEmpty)
    }
    func testUnknownTokenCannotReuseAnotherTokensMetadataForReview() async {
        let f = make(); f.model.firstAssetId = "unknown-token"; f.model.inputedFirstAmount = 2
        f.model.reviewButtonTapped(); await pause(); XCTAssertFalse(f.view.enabled); XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testAccountDisappearingBeforeTheReviewTaskStartsCannotRequestAFee() async {
        let f = make(); f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped()
        SelectedWalletSettings.shared.commitInternalValue(nil)
        await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.fee.requests.isEmpty); XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testRecipientChangeDuringFeeCalculationCannotOpenAnOldReview() async {
        let f = make(); f.fee.hold = true; f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped()
        await wait { f.fee.pending.count == 1 }; f.model.selectedAddress = sender; f.fee.completeAll()
        await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testSelectedWalletChangeDuringFeeCalculationCannotOpenAnOldReview() async {
        let f = make(); f.fee.hold = true; f.model.inputedFirstAmount = 2; f.model.reviewButtonTapped()
        await wait { f.fee.pending.count == 1 }; SelectedWalletSettings.shared.commitInternalValue(nil); f.fee.completeAll()
        await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
    }
    func testMaximumSendRecomputesItsAmountWhenTheAdjustedFeeChanges() async {
        let f = make(); f.fee.sequence = [1, 2, 2]; f.model.didSelect(variant: 1); f.model.reviewButtonTapped()
        await wait { !f.route.confirmations.isEmpty }
        XCTAssertEqual(f.fee.requests.map { $0.amount.decimalValue }, [10, 9, 8])
        XCTAssertEqual(f.route.confirmations.first?.2, 8); XCTAssertEqual(f.route.confirmations.first?.3, 2)
    }
    func testMaximumSendRejectsAZeroFeeForTheAdjustedAmount() async {
        let f = make(); f.fee.sequence = [1, 0]; f.model.didSelect(variant: 1); f.model.reviewButtonTapped()
        await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
        XCTAssertEqual(f.fee.requests.map { $0.amount.decimalValue }, [10, 9])
    }
    func testMaximumSendDoesNotApproveAnUnstableFeeAfterItsBoundedRetries() async {
        let f = make(); f.fee.sequence = [1, 2, 3, 4]; f.model.didSelect(variant: 1); f.model.reviewButtonTapped()
        await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
        XCTAssertEqual(f.fee.requests.count, 4)
    }
    func testFeeLargerThanAvailableXorCannotApproveANonFeeAssetSend() async {
        let f = make(asset: val, values: [xor: Decimal(string: "0.5")!, val: 10]); f.model.inputedFirstAmount = 2
        f.model.reviewButtonTapped(); await wait { !f.view.alerts.isEmpty }; XCTAssertTrue(f.route.confirmations.isEmpty)
    }
}
