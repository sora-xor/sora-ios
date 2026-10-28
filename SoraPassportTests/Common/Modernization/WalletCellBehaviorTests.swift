// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class WalletCellBehaviorTests: XCTestCase {
    private func views<T: UIView>(_ type: T.Type, in root: UIView) -> [T] {
        ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { views(type, in: $0) }
    }

    private func text(in root: UIView) -> [String] {
        views(UILabel.self, in: root).filter { !$0.isHidden }.compactMap { $0.text ?? $0.attributedText?.string }
    }

    private func detail(_ title: String, amount: String) -> DetailViewModel {
        DetailViewModel(title: title,
            assetAmountText: SoramitsuTextItem(text: amount, fontData: FontType.textM, textColor: .fgPrimary))
    }

    func testInvitationCellRebindingChangesLinkAmountsAndDelegate() throws {
        let cell = AvailableInvitationsCell(style: .default, reuseIdentifier: nil)
        let first = ReferralCellRecorder()
        let second = ReferralCellRecorder()
        cell.bind(viewModel: AvailableInvitationsViewModel(accountAddress: "first", invitationCount: 1,
                                                          bondedAmount: 2, delegate: first))
        cell.getInvitationButtonTapped()
        cell.bind(viewModel: AvailableInvitationsViewModel(accountAddress: "second", invitationCount: 3,
                                                          bondedAmount: 4, delegate: second))
        XCTAssertTrue(text(in: cell).contains("3"))
        XCTAssertTrue(text(in: cell).contains("4 XOR"))
        XCTAssertTrue(text(in: cell).contains("polkaswap.io/#/referral/second"))
        XCTAssertFalse(text(in: cell).contains("polkaswap.io/#/referral/first"))
        cell.unbondXorButtonTapped()
        XCTAssertEqual(first.bonds.count, 1)
        XCTAssertEqual(second.bonds.count, 1)
        XCTAssertEqual(first.bonds.first, .bond)
        XCTAssertEqual(second.bonds.first, .unbond)
        let link = try XCTUnwrap(views(InvitationLinkView.self, in: cell).first)
        let clipboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = clipboard }
        link.buttonTapped()
        XCTAssertEqual(second.shared, ["polkaswap.io/#/referral/second"])
        XCTAssertEqual(UIPasteboard.general.string, "polkaswap.io/#/referral/second")
        XCTAssertTrue(first.shared.isEmpty)
    }

    func testReferralCellSwitchesBetweenAddressAndEnterLink() throws {
        let cell = ReferrerCell(style: .default, reuseIdentifier: nil)
        let recorder = ReferralCellRecorder()
        cell.bind(viewModel: ReferrerViewModel(address: "", delegate: recorder))
        let button = try XCTUnwrap(views(SoramitsuButton.self, in: cell).first)
        XCTAssertFalse(button.isHidden)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(recorder.links, 1)
        cell.bind(viewModel: ReferrerViewModel(address: "referrer-fixture", delegate: nil))
        XCTAssertTrue(button.isHidden)
        XCTAssertTrue(text(in: cell).contains("referrer-fixture"))
        cell.enterLinkButtonTapped()
        XCTAssertEqual(recorder.links, 1)
        cell.bind(viewModel: ReferrerViewModel(address: "", delegate: recorder))
        XCTAssertFalse(button.isHidden)
        XCTAssertFalse(text(in: cell).contains("referrer-fixture"))
    }

    func testTotalRewardsCellUpdatesTotalsAndExpansionDelegate() throws {
        let cell = TotalRewardsCell(style: .default, reuseIdentifier: nil)
        let recorder = ReferralCellRecorder()
        cell.bind(viewModel: TotalRewardsViewModel(invetationCount: 2, totalRewardsAmount: 0, assetSymbol: "XOR", delegate: recorder))
        XCTAssertTrue(text(in: cell).contains("0 XOR"))
        cell.bind(viewModel: TotalRewardsViewModel(invetationCount: 5, totalRewardsAmount: Decimal(string: "1.25")!, assetSymbol: "VAL", delegate: recorder))
        XCTAssertTrue(text(in: cell).contains("5"))
        XCTAssertTrue(text(in: cell).contains("1.25 VAL"))
        cell.expandButtonTap()
        cell.expandButtonTap()
        XCTAssertEqual(recorder.expansions, 2)
        cell.bind(viewModel: TotalRewardsViewModel(invetationCount: 0, totalRewardsAmount: 0, assetSymbol: "XOR", delegate: nil))
        cell.expandButtonTap()
        XCTAssertEqual(recorder.expansions, 2)
    }

    func testRewardRowsReplaceTitleAndAmountOnReuse() {
        let cell = RewardRawCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 80)
        cell.bind(viewModel: RewardRawViewModel(title: "First referral", amount: 4, assetSymbol: "XOR"))
        cell.layoutIfNeeded()
        XCTAssertTrue(text(in: cell).contains("First referral"))
        XCTAssertTrue(text(in: cell).contains("4 XOR"))
        cell.bind(viewModel: RewardRawViewModel(title: "Second referral", amount: 0, assetSymbol: "VAL"))
        XCTAssertTrue(text(in: cell).contains("Second referral"))
        XCTAssertTrue(text(in: cell).contains("0 VAL"))
        XCTAssertFalse(text(in: cell).contains("First referral"))
        let separator = RewardSeparatorCell(style: .default, reuseIdentifier: nil)
        separator.bind(viewModel: RewardSeparatorViewModel())
        separator.frame = cell.frame
        separator.layoutIfNeeded()
        XCTAssertFalse(separator.contentView.subviews.isEmpty)
    }

    func testActivityHeaderRebindingReplacesPreviousDetails() {
        let cell = HeaderActivityDetailsCell(style: .default, reuseIdentifier: nil)
        let first = HeaderActivityDetailsItem(typeText: "Swap", typeTransactionImage: UIImage(),
            actionTransactionImage: UIImage(), firstAssetImageViewModel: UIImage(), secondAssetImageViewModel: UIImage(),
            firstBalanceText: NSAttributedString(string: "-1 XOR"), secondBalanceText: NSAttributedString(string: "+2 VAL"),
            details: [detail("Network fee", amount: "0.1 XOR"), detail("Block", amount: "100")])
        cell.set(item: first, context: nil)
        XCTAssertEqual(views(DetailView.self, in: cell).count, 2)
        let second = HeaderActivityDetailsItem(typeText: "Send", typeTransactionImage: nil,
            firstAssetImageViewModel: nil, firstBalanceText: NSAttributedString(string: "-3 XOR"),
            details: [detail("Network fee", amount: "0.2 XOR")])
        cell.set(item: second, context: nil)
        XCTAssertEqual(views(DetailView.self, in: cell).count, 1)
        XCTAssertTrue(text(in: cell).contains("0.2 XOR"))
        XCTAssertFalse(text(in: cell).contains("0.1 XOR"))
        XCTAssertFalse(text(in: cell).contains("100"))
        XCTAssertFalse(text(in: cell).contains("+2 VAL"))
        let empty = HeaderActivityDetailsItem(typeText: "Pending", typeTransactionImage: nil,
            firstAssetImageViewModel: nil, firstBalanceText: NSAttributedString(string: "0 XOR"), details: [])
        cell.set(item: empty, context: nil)
        XCTAssertTrue(views(DetailView.self, in: cell).isEmpty)
    }

    func testActivityHeaderInformationUsesOnlyCurrentModels() throws {
        let cell = HeaderActivityDetailsCell(style: .default, reuseIdentifier: nil)
        var requests: [String] = []
        let model = detail("Fee", amount: "0.1 XOR")
        model.infoHandler = { requests.append("fee") }
        let item = HeaderActivityDetailsItem(typeText: "Send", typeTransactionImage: nil,
            firstAssetImageViewModel: nil, firstBalanceText: NSAttributedString(string: "-1 XOR"), details: [model])
        cell.set(item: item, context: nil)
        let row = try XCTUnwrap(views(DetailView.self, in: cell).first)
        XCTAssertFalse(row.infoButton.isHidden)
        row.infoButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(requests, ["fee"])
    }

    func testNodeSelectionUsesLatestModelAndRebindingDoesNotAccumulateConstraints() {
        let nodeView = NodeView(frame: CGRect(x: 0, y: 0, width: 390, height: 80))
        let first = ChainNodeModel(url: URL(string: "wss://first.example")!, name: "First", apikey: nil)
        let second = ChainNodeModel(url: URL(string: "wss://second.example/path")!, name: "Second", apikey: nil)
        var selected: [String] = []
        nodeView.onSelect = { selected.append($0.name) }
        nodeView.userTapped()
        XCTAssertTrue(selected.isEmpty)
        nodeView.updateView(model: NodeViewModel(node: first, isSelected: true, isCustom: false))
        nodeView.layoutIfNeeded()
        let initialCount = nodeView.constraints.filter(\.isActive).count
        for index in 0..<10 {
            nodeView.updateView(model: NodeViewModel(node: second, isSelected: false, isCustom: index.isMultiple(of: 2)))
            nodeView.layoutIfNeeded()
        }
        nodeView.userTapped()
        XCTAssertEqual(selected, ["Second"])
        XCTAssertTrue(text(in: nodeView).contains("wss://second.example/path"))
        XCTAssertFalse(text(in: nodeView).contains("First"))
        XCTAssertLessThanOrEqual(nodeView.constraints.filter(\.isActive).count, initialCount + 1)
    }

    func testPriceCellClearsOldFiatAndChangeWhenNoQuoteExists() {
        let cell = PriceCell(style: .default, reuseIdentifier: nil)
        cell.set(item: PriceItem(icon: nil, tokenName: "SORA", tokenSymbol: "XOR", priceText: "$1",
            deltaPriceText: SoramitsuTextItem(text: "+2%", fontData: FontType.textM, textColor: .statusSuccess)), context: nil)
        XCTAssertTrue(text(in: cell).contains("$1"))
        XCTAssertTrue(text(in: cell).contains("+2%"))
        cell.set(item: PriceItem(icon: nil, tokenName: "Unknown", tokenSymbol: "MEME"), context: nil)
        XCTAssertTrue(text(in: cell).contains("MEME"))
        XCTAssertFalse(text(in: cell).contains("$1"))
        XCTAssertFalse(text(in: cell).contains("+2%"))
    }

    func testDisclaimerCellRebindingUsesNewCloseCallback() throws {
        let cell = SwapDisclaimerCell(style: .default, reuseIdentifier: nil)
        var calls: [String] = []
        let old = SwapDisclaimerItem()
        old.closeButtonHandler = { calls.append("old") }
        cell.set(item: old, context: nil)
        let current = SwapDisclaimerItem()
        current.closeButtonHandler = { calls.append("current") }
        cell.set(item: current, context: nil)
        let buttons = views(SoramitsuButton.self, in: cell)
        XCTAssertFalse(buttons.isEmpty)
        buttons.forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(calls, ["current"])
    }

    func testPolkamarktChartFitsEmptyAndPopulatedDataAndExposesDescription() {
        let chart = PolkamarktLineChartView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        chart.caption = "Market probability"
        chart.context = "Finalized blocks 1 to 3"
        let empty = chart.sizeThatFits(CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude))
        chart.values = [0, 0.5, 1]
        chart.secondaryValues = [1, 0.5, 0]
        chart.markerFraction = 0.5
        let populated = chart.sizeThatFits(CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(populated.height - empty.height, 150)
        XCTAssertEqual(chart.accessibilityLabel, "Market probability. Finalized blocks 1 to 3")
        XCTAssertTrue(chart.accessibilityTraits.contains(.image))
        chart.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: chart.bounds.size).image { context in
            chart.layer.render(in: context.cgContext)
        }
        XCTAssertEqual(image.size, chart.bounds.size)
        chart.values = [-1, 2]
        chart.markerFraction = -5
        chart.setNeedsLayout()
        chart.layoutIfNeeded()
        _ = UIGraphicsImageRenderer(size: chart.bounds.size).image { context in chart.layer.render(in: context.cgContext) }
        XCTAssertEqual(chart.sizeThatFits(CGSize(width: 390, height: 300)).height, populated.height)
    }
}

private final class ReferralCellRecorder: AvailableInvitationsCellDelegate, ReferrerCellDelegate, TotalRewardsCellDelegate {
    var bonds: [InputRewardAmountType] = []
    var shared: [String] = []
    var links = 0
    var expansions = 0
    func changeBoundedAmount(to type: InputRewardAmountType) { bonds.append(type) }
    func shareButtonTapped(with text: String) { shared.append(text) }
    func enterLinkButtonTapped() { links += 1 }
    func expandButtonTapped() { expansions += 1 }
}
