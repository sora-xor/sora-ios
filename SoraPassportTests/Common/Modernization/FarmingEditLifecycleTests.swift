// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import Combine
import RobinHood
import SSFUtils
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class FarmingEditLifecycleTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()
    private let xor = WalletAssetId.xor.rawValue; private let val = WalletAssetId.val.rawValue
    private var language = "en"
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { subscriptions.removeAll(); LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func user(pooled: Decimal = 20) -> UserFarm { UserFarm(id: "farm", baseAssetId: xor, poolAssetId: val, rewardAssetId: WalletAssetId.pswap.rawValue, isFarm: true, pooledTokens: pooled, rewards: 777) }
    private func pool(balance: Decimal = 100, pooled: Decimal = 20) -> PoolInfo { PoolInfo(baseAssetId: xor, targetAssetId: val, poolId: "pool", accountId: "fixture", accountPoolBalance: balance, farms: [user(pooled: pooled)]) }
    private struct Fixture { let service: EditFarmItemService; let fee: FarmingEditFee; let input: PassthroughSubject<FarmShareSelection, Never> }
    private func make(balance: Decimal = 100, pooled: Decimal = 20, walletBalance: Decimal = 10, depositFee: Decimal = 1, withdrawalFee: Decimal = 2, percentage: Decimal = 5) -> Fixture {
        let fee = FarmingEditFee(deposit: depositFee, withdrawal: withdrawalFee); let input = PassthroughSubject<FarmShareSelection, Never>()
        let service = EditFarmItemService(poolInfo: pool(balance: balance, pooled: pooled), userFarm: user(pooled: pooled), feeProvider: fee, currentSelection: FarmShareSelection(percent: 20)!, feePercentage: percentage, userBalance: walletBalance)
        service.transform(input: input.eraseToAnyPublisher()).sink { _ in }.store(in: &subscriptions)
        return Fixture(service: service, fee: fee, input: input)
    }
    private func pause() async { try? await Task.sleep(nanoseconds: 50_000_000) }
    private func ready(_ f: Fixture) async { f.service.setup(); for _ in 0..<100 { if !f.service.networkFeeText.isEmpty { return }; try? await Task.sleep(nanoseconds: 10_000_000) }; XCTFail("Fee estimation did not finish") }
    private func select(_ f: Fixture, _ percent: Decimal) { f.input.send(FarmShareSelection(percent: percent)!) }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] { ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) } }
    private func item(_ service: EditFarmItemService?, percent: Decimal = 20, fee: Decimal = 5) -> EditFarmItem { EditFarmItem(sharePercentage: percent, stakedSelection: FarmShareSelection(percent: percent)!, stakeFeeAmount: fee, service: service) }
    func testFarmSelectionCannotConfirmBeforeBothFeesAreKnown() { let f = make(); select(f, 50); XCTAssertFalse(f.service.confirmButtonEnabled); XCTAssertEqual(f.service.amount, 30) }
    func testDepositUsesTheExactDeltaAndDepositFee() async { let f = make(); select(f, 50); await ready(f); XCTAssertEqual(f.service.amount, 30); XCTAssertEqual(f.service.farmTransaction.transactionType, .demeterDeposit); XCTAssertEqual(f.service.networkFeeAmount, 1); XCTAssertEqual(f.service.feeText, "5%"); XCTAssertTrue(f.service.confirmButtonEnabled) }
    func testWithdrawalUsesItsOwnNetworkFeeAndNoDepositCharge() async { let f = make(); select(f, 10); await ready(f); XCTAssertEqual(f.service.amount, 10); XCTAssertEqual(f.service.farmTransaction.transactionType, .demeterWithdraw); XCTAssertEqual(f.service.networkFeeAmount, 2); XCTAssertEqual(f.service.feeText, "0%"); XCTAssertEqual(f.service.willBePercentageText, "10%"); XCTAssertTrue(f.service.confirmButtonEnabled) }
    func testReturningToTheCurrentShareDisablesConfirmation() async { let f = make(); await ready(f); select(f, 50); XCTAssertTrue(f.service.confirmButtonEnabled); select(f, 20); XCTAssertEqual(f.service.amount, 0); XCTAssertFalse(f.service.confirmButtonEnabled) }
    func testMaximumSelectionHidesTheMaxActionAndPreservesAllShares() async { let f = make(); await ready(f); f.input.send(.maximum); XCTAssertTrue(f.service.isMaxButtonHidden); XCTAssertEqual(f.service.amount, 80); XCTAssertEqual(f.service.percentageText, "100%"); select(f, 99); XCTAssertFalse(f.service.isMaxButtonHidden) }
    func testZeroNetworkFeeCannotAuthorizeAChange() async { let f = make(depositFee: 0); await ready(f); select(f, 50); XCTAssertFalse(f.service.confirmButtonEnabled) }
    func testWalletWithExactlyTheNetworkFeeCanWithdrawPoolTokens() async { let f = make(walletBalance: 2); await ready(f); select(f, 10); XCTAssertTrue(f.service.confirmButtonEnabled) }
    func testInvalidFeeAndPoolInputsNeverEnableConfirmation() async {
        for f in [make(depositFee: -1), make(depositFee: .nan), make(percentage: -1), make(percentage: 101), make(balance: 0), make(balance: 10, pooled: 20)] { await ready(f); select(f, 50); XCTAssertFalse(f.service.confirmButtonEnabled) }
    }
    func testDepositFeeDisplaysTheResultingShareRoundedDown() async { let f = make(); await ready(f); select(f, 50); XCTAssertEqual(f.service.willBePercentageText, "49.23%") }
    func testReplacingTheSelectionInputDisconnectsThePreviousStream() async { let f = make(); await ready(f); let replacement = PassthroughSubject<FarmShareSelection, Never>(); f.service.transform(input: replacement.eraseToAnyPublisher()).sink { _ in }.store(in: &subscriptions); replacement.send(.maximum); f.input.send(.zero); XCTAssertEqual(f.service.amount, 80); XCTAssertEqual(f.service.percentageText, "100%") }
    func testFeeCompletionPublishesOnTheMainThread() async { let f = make(); var threads: [Bool] = []; f.service.$networkFeeText.dropFirst().sink { _ in threads.append(Thread.isMainThread) }.store(in: &subscriptions); await ready(f); XCTAssertFalse(threads.isEmpty); XCTAssertTrue(threads.allSatisfy { $0 }) }
    func testFarmCellShowsCurrentShareAndExactFee() async throws { let f = make(); await ready(f); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); cell.set(item: item(f.service)); await pause(); let details = descendants(DetailView.self, in: cell); XCTAssertEqual(details.count, 4); XCTAssertEqual(details[0].valueLabel.text, "20%"); XCTAssertEqual(details[3].valueLabel.text, "2 XOR"); XCTAssertEqual(try XCTUnwrap(descendants(UISlider.self, in: cell).first).value, 0.2, accuracy: 0.0001) }
    func testFarmCellSliderPublishesAnExactSelection() async throws { let f = make(); await ready(f); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); cell.set(item: item(f.service)); let slider = try XCTUnwrap(descendants(UISlider.self, in: cell).first); slider.value = 0.3333; slider.sendActions(for: .valueChanged); await pause(); XCTAssertEqual(f.service.amount, Decimal(string: "13.33")); XCTAssertEqual(f.service.percentageText, "33.33%") }
    func testFarmCellMaximumButtonUpdatesTheCurrentService() async throws { let f = make(); await ready(f); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); cell.set(item: item(f.service)); let slider = try XCTUnwrap(descendants(FarmSliderView.self, in: cell).first); slider.maxButton.sendActions(for: .touchUpInside); await pause(); XCTAssertEqual(f.service.amount, 80); XCTAssertEqual(slider.slider.value, 1); XCTAssertTrue(slider.maxButton.isHidden) }
    func testRebindingFarmCellDisconnectsTheOldServiceOutput() async throws { let old = make(); let current = make(); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); cell.set(item: item(old.service)); cell.set(item: item(current.service)); current.service.networkFeeText = "CURRENT"; await pause(); old.service.networkFeeText = "OLD"; await pause(); XCTAssertEqual(descendants(DetailView.self, in: cell).last?.valueLabel.text, "CURRENT") }
    func testRebindingFarmCellDisconnectsTheOldSelectionInput() throws { let old = make(); let current = make(); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); cell.set(item: item(old.service)); cell.set(item: item(current.service)); let slider = try XCTUnwrap(descendants(FarmSliderView.self, in: cell).first); slider.maxButton.sendActions(for: .touchUpInside); XCTAssertEqual(old.service.amount, 0); XCTAssertEqual(current.service.amount, 80) }
    func testFarmCellCannotConfirmAServiceThatIsNotReady() throws { let f = make(); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); let row = item(f.service); var calls = 0; row.onConfirm = { calls += 1 }; cell.set(item: row); try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).last).sendActions(for: .touchUpInside); XCTAssertEqual(calls, 0) }
    func testFarmCellUsesOnlyCurrentInfoAndConfirmHandlers() async throws { let f = make(); await ready(f); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); let old = item(f.service); let current = item(f.service); var oldCalls = 0; var feeCalls = 0; var networkCalls = 0; var confirms = 0; old.onConfirm = { oldCalls += 1 }; old.feeInfoHandler = { oldCalls += 1 }; old.networkFeeHandler = { oldCalls += 1 }; current.onConfirm = { confirms += 1 }; current.feeInfoHandler = { feeCalls += 1 }; current.networkFeeHandler = { networkCalls += 1 }; cell.set(item: old); cell.set(item: current); let sliders = try XCTUnwrap(descendants(FarmSliderView.self, in: cell).first); sliders.maxButton.sendActions(for: .touchUpInside); await pause(); let details = descendants(DetailView.self, in: cell); details[2].infoButton.sendActions(for: .touchUpInside); details[3].infoButton.sendActions(for: .touchUpInside); try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).last).sendActions(for: .touchUpInside); XCTAssertEqual(oldCalls, 0); XCTAssertEqual(feeCalls, 1); XCTAssertEqual(networkCalls, 1); XCTAssertEqual(confirms, 1) }
    func testFarmCellReuseDoesNotRetainThePreviousItemOrRenderOldUpdates() async { let f = make(); let cell = EditFarmCell(style: .default, reuseIdentifier: nil); weak var retained: EditFarmItem?; do { let row = item(f.service); retained = row; cell.set(item: row) }; cell.prepareForReuse(); await pause(); XCTAssertNil(retained); f.service.networkFeeText = "LATE"; await pause(); XCTAssertNotEqual(descendants(DetailView.self, in: cell).last?.valueLabel.text, "LATE") }
    func testFarmItemIdentityIncludesCurrentPresentationAndService() { let first = make(); let second = make(); XCTAssertNotEqual(item(first.service, fee: 1), item(first.service, fee: 2)); XCTAssertNotEqual(item(first.service), item(second.service)); XCTAssertEqual(item(first.service), item(first.service)) }
}
private final class FarmingEditFee: FeeProviderProtocol {
    let deposit: Decimal; let withdrawal: Decimal
    init(deposit: Decimal, withdrawal: Decimal) { self.deposit = deposit; self.withdrawal = withdrawal }
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { completion(deposit) }
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) { completion(deposit) }
    func getFee(for call: any RuntimeCallable) async -> Decimal { call is RuntimeCall<DemeterFarmingDepositLiquidityCall> ? deposit : withdrawal }
    func getFee(for type: TransactionType) async -> Decimal { deposit }
}
