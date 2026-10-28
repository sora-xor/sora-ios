// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class TransferConfirmationBehaviorTests: XCTestCase {
    private var previousLanguage = "en"
    override func setUp() {
        super.setUp()
        previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
    }
    override func tearDown() {
        LocalizationManager.shared.selectedLocalization = previousLanguage
        super.tearDown()
    }
    private struct Fixture {
        let model: ConfirmSendingViewModel
        let balances: ConfirmationBalances
        let fiat: ConfirmationFiat
        let route: ConfirmationRoute
    }
    private func make(asset: String = WalletAssetId.xor.rawValue, amount: Decimal = 5, fee: Decimal = 1,
                      balances: [String: Decimal], load: Bool = true) -> Fixture {
        let manager = ConfirmationAssets()
        let balances = ConfirmationBalances(values: balances)
        let fiat = ConfirmationFiat()
        let route = ConfirmationRoute()
        let model = ConfirmSendingViewModel(wireframe: route, fiatService: fiat, assetManager: manager,
            detailsFactory: DetailViewModelFactory(assetManager: manager), assetId: asset,
            recipientAddress: "fixture-recipient", firstAssetAmount: amount, transactionType: .outgoing, fee: fee,
            walletService: WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock()), assetsProvider: balances)
        if load { model.viewDidLoad() }
        return Fixture(model: model, balances: balances, fiat: fiat, route: route)
    }
    private func button(_ model: ConfirmSendingViewModel) throws -> SoramitsuButtonItem {
        try XCTUnwrap(model.items.compactMap { $0 as? SoramitsuButtonItem }.first)
    }
    private func notice(_ model: ConfirmSendingViewModel) -> String? {
        model.items.compactMap { $0 as? WalletInlineNoticeItem }.first?.message
    }
    func testAsynchronousPriceUpdatesPublishConfirmationOnTheMainThread() async {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 6], load: false)
        let updated = expectation(description: "Initial rows and asynchronous price update")
        updated.expectedFulfillmentCount = 2
        fixture.model.setupItems = { items in
            XCTAssertTrue(Thread.isMainThread, "Price completion mutated UI state off the main thread")
            XCTAssertEqual(items.count, 7)
            updated.fulfill()
        }
        fixture.model.viewDidLoad()
        await fulfillment(of: [updated], timeout: 2)
    }
    func testBackgroundBalanceNotificationPublishesRowsOnTheMainThread() async {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 6], load: false)
        let updated = expectation(description: "Balance and price updates")
        updated.expectedFulfillmentCount = 2
        fixture.model.setupItems = { _ in XCTAssertTrue(Thread.isMainThread); updated.fulfill() }
        DispatchQueue.global().async { fixture.model.processBalance(data: []) }
        await fulfillment(of: [updated], timeout: 2)
    }
    func testExactXORBalanceIncludesItsNetworkFee() throws {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 6])
        XCTAssertTrue(try button(fixture.model).isEnable)
        XCTAssertNil(notice(fixture.model))
        XCTAssertEqual(fixture.model.items.count, 7)
        XCTAssertEqual(fixture.balances.additions, 1)
        XCTAssertNotNil(fixture.model.title)
        XCTAssertNil(fixture.model.imageName)
    }
    func testXORShortfallIncludesAmountAndFee() throws {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 4])
        XCTAssertFalse(try button(fixture.model).isEnable)
        XCTAssertTrue(notice(fixture.model)?.contains("2 more XOR") == true)
        fixture.model.submit()
        XCTAssertEqual(fixture.route.shown, 0)
    }
    func testXORBalanceEnoughForAmountStillRequiresFee() throws {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 5])
        XCTAssertFalse(try button(fixture.model).isEnable)
        XCTAssertTrue(notice(fixture.model)?.contains("1 more XOR") == true)
    }
    func testNonFeeTokenUsesItsOwnAmountAndSeparateXORBalance() throws {
        let fixture = make(asset: WalletAssetId.val.rawValue,
                           balances: [WalletAssetId.val.rawValue: 5, WalletAssetId.xor.rawValue: 1])
        XCTAssertTrue(try button(fixture.model).isEnable)
        XCTAssertNil(notice(fixture.model))
    }
    func testNonFeeTokenShortfallNamesTheMissingToken() throws {
        let fixture = make(asset: WalletAssetId.val.rawValue,
                           balances: [WalletAssetId.val.rawValue: 3, WalletAssetId.xor.rawValue: 10])
        XCTAssertFalse(try button(fixture.model).isEnable)
        XCTAssertTrue(notice(fixture.model)?.contains("2 more VAL") == true)
    }
    func testNonFeeTokenFeeShortfallNamesXOR() throws {
        let fixture = make(asset: WalletAssetId.val.rawValue, fee: 3,
                           balances: [WalletAssetId.val.rawValue: 10, WalletAssetId.xor.rawValue: 1])
        XCTAssertFalse(try button(fixture.model).isEnable)
        XCTAssertTrue(notice(fixture.model)?.contains("2 more XOR") == true)
    }
    func testMissingFeeBalanceCannotEnableConfirmation() throws {
        let fixture = make(asset: WalletAssetId.val.rawValue, balances: [WalletAssetId.val.rawValue: 10])
        XCTAssertFalse(try button(fixture.model).isEnable)
        fixture.model.submit()
        XCTAssertEqual(fixture.route.shown, 0)
    }
    func testLosingAssetBalanceInvalidatesThePreviouslyAffordableScreen() throws {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 10])
        XCTAssertTrue(try button(fixture.model).isEnable)
        fixture.balances.values = [:]
        fixture.model.processBalance(data: [])
        XCTAssertFalse(try button(fixture.model).isEnable)
        XCTAssertNotNil(notice(fixture.model))
        XCTAssertEqual(fixture.model.items.compactMap { $0 as? SendAssetItem }.first?.balance, WalletUX.balanceUnavailableText)
    }
    func testBalanceUpdatesRecoverFromFeeShortfall() throws {
        let fixture = make(asset: WalletAssetId.val.rawValue,
                           balances: [WalletAssetId.val.rawValue: 5, WalletAssetId.xor.rawValue: 0])
        XCTAssertFalse(try button(fixture.model).isEnable)
        fixture.balances.values[WalletAssetId.xor.rawValue] = 1
        fixture.model.processBalance(data: [])
        XCTAssertTrue(try button(fixture.model).isEnable)
        XCTAssertNil(notice(fixture.model))
    }
    func testSubmitRechecksBalancesEvenBeforeAnObserverUpdate() throws {
        let fixture = make(balances: [WalletAssetId.xor.rawValue: 10])
        XCTAssertTrue(try button(fixture.model).isEnable)
        fixture.balances.values = [:]
        fixture.model.submit()
        XCTAssertFalse(try button(fixture.model).isEnable)
        XCTAssertEqual(fixture.route.shown, 0)
    }
    func testInvalidAssetBalancesCannotEnableConfirmation() throws {
        for balance in [Decimal(-1), Decimal.nan] {
            let fixture = make(balances: [WalletAssetId.xor.rawValue: balance])
            XCTAssertFalse(try button(fixture.model).isEnable)
            XCTAssertNotNil(notice(fixture.model))
        }
    }
    func testInvalidFeeBalancesCannotEnableConfirmation() throws {
        for balance in [Decimal(-1), Decimal.nan] {
            let fixture = make(asset: WalletAssetId.val.rawValue,
                               balances: [WalletAssetId.val.rawValue: 10, WalletAssetId.xor.rawValue: balance])
            XCTAssertFalse(try button(fixture.model).isEnable)
            XCTAssertNotNil(notice(fixture.model))
        }
    }
    func testMissingAssetMetadataCannotEnableConfirmation() throws {
        let fixture = make(asset: "unknown", balances: ["unknown": 10, WalletAssetId.xor.rawValue: 1])
        XCTAssertFalse(try button(fixture.model).isEnable)
        fixture.model.submit()
        XCTAssertEqual(fixture.route.shown, 0)
    }
    func testInvalidAmountsNeverEnableConfirmation() throws {
        for amount in [Decimal.zero, Decimal(-1), Decimal.nan] {
            let fixture = make(amount: amount, balances: [WalletAssetId.xor.rawValue: 10])
            XCTAssertFalse(try button(fixture.model).isEnable)
            fixture.model.submit()
            XCTAssertEqual(fixture.route.shown, 0)
        }
    }
    func testMissingOrInvalidFeeNeverEnablesConfirmation() throws {
        for fee in [Decimal.zero, Decimal(-1), Decimal.nan] {
            let fixture = make(fee: fee, balances: [WalletAssetId.xor.rawValue: 10])
            XCTAssertFalse(try button(fixture.model).isEnable)
            fixture.model.submit()
            XCTAssertEqual(fixture.route.shown, 0)
        }
    }
}

private actor ConfirmationFiat: FiatServiceProtocol {
    func getFiat() async -> [PIExactFiatData] { [] }
}
private final class ConfirmationBalances: AssetProviderProtocol {
    var values: [String: Decimal]
    var additions = 0
    init(values: [String: Decimal]) { self.values = values }
    func getBalances(with assetIds: [String]) -> [BalanceData] {
        assetIds.compactMap { id in values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) } }
    }
    func add(observer: AssetProviderObserverProtocol) { additions += 1 }
    func remove(observer: AssetProviderObserverProtocol) { additions -= 1 }
}
private final class ConfirmationAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    private var assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
                          AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "Validator", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) { assets = list }
    func saveAssetList(_ list: [AssetInfo]) { assets = list }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class ConfirmationRoute: ConfirmWireframeProtocol {
    var shown = 0
    var hidden = 0
    func showActivityIndicator() { shown += 1 }
    func hideActivityIndicator() { hidden += 1 }
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?) { completion?() }
}
