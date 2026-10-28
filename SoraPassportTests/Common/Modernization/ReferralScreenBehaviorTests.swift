// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraKeystore
import SoraUIKit
import UIKit
import class sorawallet.ReferrerReward
import XCTest
@testable import SoraPassport

@MainActor
final class ReferralScreenBehaviorTests: XCTestCase {
    private func make() -> (FriendsPresenter, FriendsViewController, ReferralInteractorRecorder, ReferralRouteRecorder) {
        let account = AccountItem(address: "fixture-account", cryptoType: .sr25519, networkType: 69,
            username: "Referral test", publicKeyData: Data(repeating: 1, count: 32),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        let asset = AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18,
                              icon: nil, displayName: "SORA", visible: true)
        let presenter = FriendsPresenter(settings: SettingsManager.shared, keychain: Keychain(), selectedAccount: account, feeAsset: asset)
        let interactor = ReferralInteractorRecorder()
        let route = ReferralRouteRecorder()
        let view = FriendsViewController()
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = route
        view.loadViewIfNeeded()
        view.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        return (presenter, view, interactor, route)
    }
    private func settle() async { await Task.yield(); try? await Task.sleep(nanoseconds: 30_000_000) }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }
    private func receive(_ presenter: FriendsPresenter, balance: Decimal = 5, fee: Decimal = 2,
                         rewards: [ReferrerReward] = [], referrer: String = "") {
        presenter.didReceive(rewards: rewards, setReferrerFee: fee, bondFee: 1, unbondFee: 3,
                             referralBalance: balance, referrer: referrer)
    }

    func testReferralScreenBuildsAmountsAndRendersAllSummaryRows() async throws {
        let (presenter, view, interactor, _) = make()
        XCTAssertEqual(interactor.setups, 1)
        receive(presenter, rewards: [ReferrerReward(referral: "Alice", amount: "1250000000000000000"),
                                     ReferrerReward(referral: "Bob", amount: "2500000000000000000")])
        await settle()
        XCTAssertEqual(view.contentViewModels.count, 4)
        XCTAssertTrue(view.containerView.isHidden)
        let invitation = try XCTUnwrap(view.contentViewModels.first as? AvailableInvitationsViewModel)
        XCTAssertEqual(invitation.accountAddress, "fixture-account")
        XCTAssertEqual(invitation.invitationCount, 2)
        XCTAssertEqual(invitation.bondedAmount, 5)
        let total = try XCTUnwrap(view.contentViewModels[2] as? TotalRewardsViewModel)
        XCTAssertEqual(total.invetationCount, 2)
        XCTAssertEqual(total.totalRewardsAmount, Decimal(string: "3.75"))
        let table = try XCTUnwrap(views(UITableView.self, in: view.view).first)
        XCTAssertEqual(view.tableView(table, numberOfRowsInSection: 0), 4)
        for row in 0..<4 {
            let cell = view.tableView(table, cellForRowAt: IndexPath(row: row, section: 0))
            XCTAssertFalse(cell.contentView.subviews.isEmpty)
        }
        presenter.updateReferral(balance: 9)
        await settle()
        XCTAssertEqual((view.contentViewModels.first as? AvailableInvitationsViewModel)?.invitationCount, 4)
    }

    func testReferralSummaryExpansionAndCollapseKeepRowsInSync() async throws {
        let (presenter, view, _, _) = make()
        receive(presenter, rewards: [ReferrerReward(referral: "Alice", amount: "1000000000000000000"),
                                     ReferrerReward(referral: "Bob", amount: "2000000000000000000")])
        await settle()
        presenter.expandButtonTapped()
        XCTAssertEqual(view.contentViewModels.count, 7)
        XCTAssertTrue(view.contentViewModels[3] is RewardSeparatorViewModel)
        XCTAssertEqual((view.contentViewModels[4] as? RewardRawViewModel)?.title, "Alice")
        XCTAssertEqual((view.contentViewModels[5] as? RewardRawViewModel)?.amount, 2)
        let table = try XCTUnwrap(views(UITableView.self, in: view.view).first)
        for row in 0..<7 { _ = view.tableView(table, cellForRowAt: IndexPath(row: row, section: 0)) }
        presenter.expandButtonTapped()
        XCTAssertEqual(view.contentViewModels.count, 4)
        presenter.updateReferral(rewards: [])
        await settle()
        presenter.expandButtonTapped()
        XCTAssertEqual(view.contentViewModels.count, 5)
        presenter.expandButtonTapped()
        XCTAssertEqual(view.contentViewModels.count, 4)
    }

    func testReferralActionsUseCurrentFeesBalanceAndReferrer() async {
        let (presenter, view, _, route) = make()
        receive(presenter)
        await settle()
        presenter.didSelectAction(.startInvite)
        presenter.changeBoundedAmount(to: .unbond)
        XCTAssertEqual(route.amounts.count, 2)
        XCTAssertEqual(route.amounts.map(\.fee), [1, 3])
        XCTAssertEqual(route.amounts.map(\.balance), [5, 5])
        presenter.didSelectAction(.enterLink)
        XCTAssertEqual(route.linkEntries, 1)
        presenter.setupReferrer("Alice")
        await settle()
        presenter.didSelectAction(.enterLink)
        XCTAssertEqual(route.referrers, ["Alice"])
        presenter.shareButtonTapped(with: "fixture referral link")
        XCTAssertEqual(route.shared, ["fixture referral link"])
        presenter.moveForward(controller: view)
        XCTAssertEqual(route.forwarded, ["Alice"])
        presenter.enterLinkButtonTapped()
        XCTAssertEqual(route.linkEntries, 2)
    }

    func testInsufficientBondShowsInvitationEntryInsteadOfSummary() async throws {
        let (presenter, view, _, route) = make()
        receive(presenter, balance: 1, fee: 2)
        await settle()
        XCTAssertFalse(view.containerView.isHidden)
        let buttons = views(SoramitsuButton.self, in: view.containerView)
        XCTAssertEqual(buttons.count, 2)
        buttons[0].sendActions(for: .touchUpInside)
        buttons[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(route.amounts.count, 1)
        XCTAssertEqual(route.linkEntries, 1)
        receive(presenter, balance: 2, fee: 2)
        await settle()
        XCTAssertTrue(view.containerView.isHidden)
        XCTAssertEqual((view.contentViewModels.first as? AvailableInvitationsViewModel)?.invitationCount, 1)
    }

    func testInvitationEntryResetsReferrerButtonWhenReferrerIsRemoved() async throws {
        let (_, view, _, _) = make()
        view.startInvitingScreen(with: "")
        let button = try XCTUnwrap(views(SoramitsuButton.self, in: view.containerView).last)
        let initial = button.sora.attributedText?.attributedString.string
        view.startInvitingScreen(with: "Alice")
        XCTAssertNotEqual(button.sora.attributedText?.attributedString.string, initial)
        view.startInvitingScreen(with: "")
        XCTAssertEqual(button.sora.attributedText?.attributedString.string, initial)
    }

    func testUnavailableInvitationFeeCannotDisplayNaNOrNegativeInvitationCount() async {
        for fee in [Decimal.zero, Decimal(-1), Decimal.nan] {
            let (presenter, view, _, _) = make()
            receive(presenter, balance: 5, fee: fee)
            await settle()
            XCTAssertFalse(view.containerView.isHidden, "Missing/invalid fee must not produce invitation counts")
            XCTAssertTrue(view.contentViewModels.isEmpty)
        }
    }

    func testInvalidRewardDoesNotPoisonValidRewardsInSummary() async throws {
        let (presenter, view, _, _) = make()
        receive(presenter, rewards: [ReferrerReward(referral: "valid", amount: "1000000000000000000"),
                                     ReferrerReward(referral: "invalid", amount: "NaN")])
        await settle()
        let summary = try XCTUnwrap(view.contentViewModels[2] as? TotalRewardsViewModel)
        XCTAssertEqual(summary.totalRewardsAmount, 1)
        presenter.updateReferrer(address: "Current")
        await settle()
        XCTAssertEqual((view.contentViewModels[1] as? ReferrerViewModel)?.address, "Current")
    }
}

private final class ReferralInteractorRecorder: FriendsInteractorInputProtocol {
    var setups = 0
    func setup() { setups += 1 }
}

private final class ReferralRouteRecorder: FriendsWireframeProtocol {
    var linkEntries = 0
    var amounts: [(fee: Decimal, balance: Decimal)] = []
    var referrers: [String] = []
    var shared: [String] = []
    var forwarded: [String] = []
    func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput) { linkEntries += 1 }
    func showInputRewardAmountViewController(from controller: UIViewController, fee: Decimal, bondedAmount: Decimal,
                                             type: InputRewardAmountType, delegate: InputRewardAmountPresenterOutput) {
        amounts.append((fee, bondedAmount))
    }
    func showActivityViewController(from controller: UIViewController, shareText: String) { shared.append(shareText) }
    func showReferrerScreen(from controller: UIViewController, referrer: String) { referrers.append(referrer) }
    func showActivityDetails(from controller: UIViewController?, model: Transaction, completion: (() -> Void)?) { completion?() }
    func setViewControllers(from controller: UIViewController?, currentController: UIViewController?, referrer: String) { forwarded.append(referrer) }
}
