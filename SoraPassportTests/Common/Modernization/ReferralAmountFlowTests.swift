// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ReferralAmountFlowTests: XCTestCase {
    private func fixture(_ type: InputRewardAmountType = .bond, fee: Decimal = 2, bonded: Decimal = 10) -> (InputRewardAmountPresenter, ReferralAmountView, ReferralAmountInteractor) {
        let source = ReferralAmountInteractor(); let asset = AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true)
        let model = InputRewardAmountPresenter(fee: fee, previousBondedAmount: bonded, type: type, interactor: source, feeAsset: asset)
        let view = ReferralAmountView(); model.view = view; return (model, view, source)
    }
    private func pause() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] { ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) } }
    func testReferralScreenRequestsBalanceAndNamesItsOperation() {
        for type in [InputRewardAmountType.bond, .unbond] { let (model, view, source) = fixture(type); model.willMove(); XCTAssertEqual(source.reads, 1); XCTAssertEqual(view.title, type.screenTitle) }
    }
    func testReferralBalanceRefreshReplacesItsSingleInputRow() async {
        let (model, view, _) = fixture(); model.received(20); await pause(); model.received(30); await pause()
        XCTAssertEqual(view.rows.count, 1); XCTAssertEqual((view.rows.first as? InvitationsViewModel)?.balance, "30 XOR")
    }
    func testBondRequiresBothTheChosenAmountAndTransactionFee() async {
        let (model, _, source) = fixture(); model.received(6); await pause()
        XCTAssertTrue(model.isPlusEnabled(1)); XCTAssertFalse(model.isPlusEnabled(2))
        model.userChanged(2); XCTAssertEqual(model.viewModel?.isEnabled, true); model.buttonTapped(); XCTAssertEqual(source.amounts, [4])
        model.userChanged(3); XCTAssertEqual(model.viewModel?.isEnabled, false)
    }
    func testUnbondCannotExceedPreviouslyReservedBalance() async {
        let (model, _, source) = fixture(.unbond, bonded: 6); model.received(2); await pause()
        XCTAssertTrue(model.isPlusEnabled(2)); XCTAssertFalse(model.isPlusEnabled(3)); model.userChanged(3); model.buttonTapped(); XCTAssertEqual(source.amounts, [6])
        model.userChanged(4); XCTAssertEqual(model.viewModel?.isEnabled, false)
    }
    func testInvalidOrEmptySelectionCannotSubmitThroughAnObsoleteAction() async {
        let (model, _, source) = fixture(); model.received(20); await pause()
        for count in [Decimal(0), -1, 100] { model.userChanged(count); model.buttonTapped() }
        XCTAssertTrue(source.amounts.isEmpty)
    }
    func testReferralSubmissionBeforeBalanceReadIsRejected() {
        let (model, _, source) = fixture(.unbond); model.buttonTapped(); XCTAssertTrue(source.amounts.isEmpty)
    }
    func testFractionalInvitationCountIsNotAnActionableSelection() async {
        let (model, _, source) = fixture(); model.received(20); await pause(); model.userChanged(Decimal(string: "1.5")!); model.buttonTapped()
        XCTAssertEqual(model.viewModel?.isEnabled, false); XCTAssertTrue(source.amounts.isEmpty)
    }
    func testInvalidFeeCannotEnablePlusOrSubmission() async {
        for fee in [Decimal.zero, -1, .nan] {
            let (model, _, source) = fixture(fee: fee); model.received(20); await pause()
            XCTAssertFalse(model.isPlusEnabled(0)); model.userChanged(1); XCTAssertEqual(model.viewModel?.isEnabled, false); model.buttonTapped(); XCTAssertTrue(source.amounts.isEmpty)
        }
    }
    func testBalanceRefreshRevokesPreviouslyEnabledSelection() async {
        let (model, _, source) = fixture(); model.received(20); await pause(); model.userChanged(2); XCTAssertEqual(model.viewModel?.isEnabled, true)
        model.received(1); await pause(); model.buttonTapped(); XCTAssertTrue(source.amounts.isEmpty)
    }
    func testSuccessfulBondAndUnbondPublishExactResultingBalanceAndDetails() async {
        for (type, expected) in [(InputRewardAmountType.bond, Decimal(14)), (.unbond, Decimal(6))] {
            let (model, view, _) = fixture(type); let output = ReferralAmountOutput(); model.output = output; model.received(20); await pause(); model.userChanged(2); model.buttonTapped()
            model.referralBalanceOperationReceived(with: .success("hash")); await pause()
            XCTAssertEqual(output.balances, [expected]); XCTAssertEqual(output.amounts, [4]); XCTAssertEqual(output.fees, [2]); output.completion?(); XCTAssertEqual(view.pops, 1)
        }
    }
    func testFailedReferralDoesNotPublishASuccessBalance() async {
        let (model, _, _) = fixture(); let output = ReferralAmountOutput(); model.output = output; model.received(20); await pause(); model.userChanged(2); model.buttonTapped()
        model.referralBalanceOperationReceived(with: .failure(URLError(.notConnectedToInternet))); await pause()
        XCTAssertTrue(output.balances.isEmpty); XCTAssertEqual(output.amounts, [4]); XCTAssertTrue(output.failed)
    }
    func testReferralRepeatedActionCannotSubmitTwiceWhilePending() async {
        let (model, _, source) = fixture(); model.received(20); await pause(); model.userChanged(2)
        model.buttonTapped(); model.buttonTapped(); model.userChanged(3); model.buttonTapped()
        XCTAssertEqual(source.amounts, [4]); XCTAssertEqual(model.viewModel?.isEnabled, false)
    }
    func testReferralCompletionUsesTheAmountSubmittedBeforeFurtherEdits() async {
        let (model, _, _) = fixture(); let output = ReferralAmountOutput(); model.output = output; model.received(20); await pause()
        model.userChanged(2); model.buttonTapped(); model.userChanged(3); model.referralBalanceOperationReceived(with: .success("hash")); await pause()
        XCTAssertEqual(output.amounts, [4]); XCTAssertEqual(output.balances, [14])
    }
    func testReferralFailedSubmissionCanRetryItsCurrentValidatedAmount() async {
        let (model, _, source) = fixture(); model.received(20); await pause(); model.userChanged(2); model.buttonTapped()
        model.referralBalanceOperationReceived(with: .failure(URLError(.notConnectedToInternet))); await pause(); model.buttonTapped()
        XCTAssertEqual(source.amounts, [4, 4])
    }
    func testReferralBalancePublicationUsesTheMainThread() async {
        let (model, view, _) = fixture(); let update = expectation(description: "main row")
        view.onSetup = { XCTAssertTrue(Thread.isMainThread); update.fulfill() }
        DispatchQueue.global().async { model.received(20) }; await fulfillment(of: [update], timeout: 2)
    }
    func testReferralRowsDoNotRetainTheirDismissedPresenter() async {
        weak var released: InputRewardAmountPresenter?
        do { let (model, _, _) = fixture(); released = model; model.received(20); await pause() }
        await pause(); XCTAssertNil(released)
    }
    private func row(_ delegate: ReferralAmountDelegate, fee: Decimal = 2, bonded: Decimal = 6, enabled: Bool = true, symbol: String = "XOR") -> InvitationsViewModel {
        InvitationsViewModel(title: "Invite", description: "Description", fee: fee, feeSymbol: symbol, balance: "20 \(symbol)", bondedAmount: bonded, buttonTitle: "Confirm", isEnabled: enabled, delegate: delegate)
    }
    func testReferralInputBindingShowsTheCurrentFeeAndReservedAmount() throws {
        let cell = InvitationsCell(style: .default, reuseIdentifier: nil); let delegate = ReferralAmountDelegate(); let model = row(delegate); cell.bind(viewModel: model)
        let amount = try XCTUnwrap(views(AmountView.self, in: cell).first)
        XCTAssertEqual(amount.textField.text, "3"); XCTAssertEqual(amount.underMinusLabel.text, "6 XOR"); XCTAssertTrue(amount.underPlusLabel.text?.contains("20 XOR") == true)
    }
    func testReferralCellRebindingDoesNotNotifyTheOldDelegate() throws {
        let cell = InvitationsCell(style: .default, reuseIdentifier: nil); let old = ReferralAmountDelegate(); let current = ReferralAmountDelegate()
        let first = row(old, bonded: 2); let second = row(current, bonded: 8)
        cell.bind(viewModel: first); old.changed.removeAll(); cell.bind(viewModel: second)
        XCTAssertTrue(old.changed.isEmpty)
        try XCTUnwrap(views(AmountView.self, in: cell).first).plusButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(current.changed.last, 5)
    }
    func testReferralCellRebindingDisconnectsThePreviousButtonPublisher() async throws {
        let cell = InvitationsCell(style: .default, reuseIdentifier: nil); let delegate = ReferralAmountDelegate(); let old = row(delegate); let current = row(delegate, enabled: false)
        cell.bind(viewModel: old); await pause(); cell.bind(viewModel: current); await pause(); old.isEnabled = true; await pause()
        XCTAssertFalse(try XCTUnwrap(views(SoramitsuButton.self, in: cell).first).isEnabled)
    }
    func testReferralCellUsesTheCurrentSymbolAfterCountChanges() throws {
        let cell = InvitationsCell(style: .default, reuseIdentifier: nil); let delegate = ReferralAmountDelegate(); let model = row(delegate, symbol: "TEST"); cell.bind(viewModel: model)
        let amount = try XCTUnwrap(views(AmountView.self, in: cell).first); amount.plusButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(amount.underMinusLabel.text, "8 TEST")
    }
    func testReferralCellRejectsPartialNumbersAndFractionalCounts() throws {
        let cell = InvitationsCell(style: .default, reuseIdentifier: nil); let delegate = ReferralAmountDelegate(); let model = row(delegate); cell.bind(viewModel: model)
        let amount = try XCTUnwrap(views(AmountView.self, in: cell).first)
        for input in ["2junk", "2.5", "-1", "1e2"] { amount.textField.text = input; amount.textField.sendActions(for: .editingChanged); XCTAssertEqual(delegate.changed.last, 0, input) }
    }
    func testReferralCellPlusMinusAndFeeActionsRespectDelegateGuards() throws {
        let cell = InvitationsCell(style: .default, reuseIdentifier: nil); let delegate = ReferralAmountDelegate(); let model = row(delegate, bonded: 0); cell.bind(viewModel: model)
        let amount = try XCTUnwrap(views(AmountView.self, in: cell).first); delegate.changed.removeAll()
        delegate.allowed = false; amount.plusButton.sendActions(for: .touchUpInside); amount.minusButton.sendActions(for: .touchUpInside); XCTAssertTrue(delegate.changed.isEmpty)
        delegate.allowed = true; amount.plusButton.sendActions(for: .touchUpInside); amount.minusButton.sendActions(for: .touchUpInside); XCTAssertEqual(delegate.changed, [1, 0])
        try XCTUnwrap(views(FeeView.self, in: cell).first).infoButton.sendActions(for: .touchUpInside); XCTAssertEqual(delegate.infos, 1)
        try XCTUnwrap(views(SoramitsuButton.self, in: cell).first).sendActions(for: .touchUpInside); XCTAssertEqual(delegate.submits, 1)
    }
    func testReferralScreenRendersModelsAndUpdatesKeyboardInsets() throws {
        let output = ReferralAmountScreenOutput(); let screen = InputRewardAmountViewController(presenter: output); screen.loadViewIfNeeded(); XCTAssertEqual(output.moves, 1)
        let delegate = ReferralAmountDelegate(); let model = row(delegate); screen.setupTitle(with: "Referral"); screen.setup(with: [model]); XCTAssertEqual(screen.title, "Referral")
        let table = try XCTUnwrap(views(UITableView.self, in: screen.view).first); XCTAssertEqual(screen.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertTrue(screen.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) is InvitationsCell)
        let userInfo = [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 500, width: 390, height: 300))]
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: userInfo); XCTAssertEqual(table.contentInset.bottom, 300)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: userInfo); XCTAssertEqual(table.contentInset.bottom, 0)
        screen.setup(with: []); XCTAssertEqual(screen.tableView(table, numberOfRowsInSection: 0), 0)
    }
}
private final class ReferralAmountView: InputRewardAmountViewInput {
    let controller = UIViewController(); var isSetup: Bool { true }; var title = ""; var rows: [CellViewModel] = []; var pops = 0; var onSetup: (() -> Void)?
    func setupTitle(with text: String) { title = text }; func setup(with models: [CellViewModel]) { rows = models; onSetup?() }
    func reloadCell(at indexPath: IndexPath, models: [CellViewModel]) { rows = models }; func dismiss(with completion: @escaping () -> Void) { completion() }; func pop() { pops += 1 }
}
private final class ReferralAmountInteractor: InputRewardAmountInteractorInputProtocol { var reads = 0; var amounts: [Decimal] = []; func getBalance() { reads += 1 }; func sendReferralBalanceRequest(with type: InputRewardAmountType, decimalBalance: Decimal) { amounts.append(decimalBalance) } }
private final class ReferralAmountOutput: InputRewardAmountPresenterOutput {
    var balances: [Decimal] = []; var amounts: [Decimal] = []; var fees: [Decimal] = []; var completion: (() -> Void)?; var failed = false
    func updateReferral(balance: Decimal) { balances.append(balance) }; func showAlert(withSuccess isSuccess: Bool) {}
    func showTransactionDetails(from controller: UIViewController?, result: Result<String, Error>, fee: Decimal, amount: Decimal, type: ReferralBondTransaction.ReferralTransactionType, completion: (() -> Void)?) {
        amounts.append(amount); fees.append(fee); self.completion = completion; if case .failure = result { failed = true }
    }
}
private final class ReferralAmountDelegate: InvitationsCellDelegate {
    var allowed = true; var changed: [Decimal] = []; var infos = 0; var submits = 0
    func isMinusEnabled(_ currentInvitationCount: Decimal) -> Bool { allowed }; func isPlusEnabled(_ currentInvitationCount: Decimal) -> Bool { allowed }
    func userChanged(_ currentInvitationCount: Decimal) { changed.append(currentInvitationCount) }; func networkFeeInfoButtonTapped() { infos += 1 }; func buttonTapped() { submits += 1 }
}
private final class ReferralAmountScreenOutput: InputRewardAmountViewOutput { var moves = 0; func willMove() { moves += 1 } }
