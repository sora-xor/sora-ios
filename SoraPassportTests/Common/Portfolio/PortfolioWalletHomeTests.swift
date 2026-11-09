// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

@testable import SoraPassport
import SoraUIKit
import XCTest
import UIKit

final class PortfolioWalletHomeTests: XCTestCase {
    func testHomeSettingsOfferOnlyTheRemainingOptionalCards() {
        XCTAssertEqual(Cards.allCases.map(\.id), [1, 2, 3],
                       "Persisted card IDs stay stable; the classic home's Assets card can be shown or hidden again")
    }

    func testBackupAccountsKeepTheirOwnCellAfterTheHeaderIsRemoved() {
        let item = BackupedAccountItem(accountAddress: "public fixture",
                                      config: .init(cornerMask: .all, cornerRaduis: .zero, topOffset: 0, bottomOffset: 0))
        XCTAssertTrue(item.cellType === BackupedAccountCell.self)
    }

    @MainActor
    func testWalletSheetKeepsAssetManagementReachable() throws {
        let sheet = PortfolioWalletsSheet(title: "Wallets")
        var opened = false
        sheet.onManageAssets = { opened = true }
        sheet.loadViewIfNeeded()
        let action = try XCTUnwrap(sheet.contentStack.arrangedSubviews.first {
            $0.accessibilityIdentifier == "portfolio.manage-assets"
        } as? UIControl)
        action.sendActions(for: .primaryActionTriggered)
        XCTAssertTrue(opened)
    }

    @MainActor
    private func home() -> PortfolioHome {
        PortfolioHome(dataSource: PortfolioFakeSource(PortfolioFixtures.snapshot()),
                      preferences: PortfolioPreferences(defaults: UserDefaults(suiteName: "portfolio.home")!))
    }

    @MainActor
    func testHomeShowsTheKeyWarningOnlyWhileTheSelectedAccountCannotSign() {
        let home = home()
        // No Tokens / Networks / Wallets switch on the home: the assets follow the hero.
        XCTAssertEqual(home.items.count, 3)
        XCTAssertTrue(home.items[0] === home.heroItem)
        XCTAssertTrue(home.items[1] === home.listItem)
        XCTAssertTrue(home.items[2] === home.otherNetworksItem)
        XCTAssertFalse(home.items.contains { $0 === home.lensItem })
        for state in [WalletAccountCapability.State.missingKeys, .invalidKeys, .watchOnly, .repairPending, .unavailable] {
            home.noticeItem.setCapability(state)
            XCTAssertEqual(home.items.count, 4)
            XCTAssertTrue(home.items[1] === home.noticeItem)
        }
        home.noticeItem.setCapability(.signing)
        XCTAssertFalse(home.items.contains { $0 === home.noticeItem })
    }

    /// A lens stored by an earlier build (Networks, Wallets) cannot strand the home: it has no
    /// switch to leave it, so the home always opens on the token list.
    @MainActor
    func testHomeOpensOnTokensWhateverLensWasStored() {
        let defaults = UserDefaults(suiteName: "portfolio.home.stored-lens")!
        defer { defaults.removePersistentDomain(forName: "portfolio.home.stored-lens") }
        defaults.set(PortfolioLens.networks.rawValue, forKey: PortfolioPreferences.lensKey)
        let home = PortfolioHome(dataSource: PortfolioFakeSource(PortfolioFixtures.snapshot()),
                                 preferences: PortfolioPreferences(defaults: defaults))
        home.viewModel.update()
        XCTAssertEqual(home.viewModel.state.lens, .tokens)
        XCTAssertEqual(home.listItem.model?.lens, .tokens)
    }

    @MainActor
    func testNoticeReportsWhenTheHomeNeedsToInsertOrRemoveIt() {
        let item = PortfolioNoticeItem()
        var visibilityChanges: [Bool] = []
        item.onCapabilityChange = { visibilityChanges.append($0) }
        item.setCapability(.missingKeys)
        item.setCapability(.invalidKeys)
        item.setCapability(.signing)
        XCTAssertEqual(visibilityChanges, [true, false, true])
    }

    @MainActor
    func testOtherNetworkRowsStayReachableUnderTheList() {
        let home = home()
        let account = NetworkAccount(walletId: "A", networkId: .taira, derivationVersion: 1,
                                     publicKey: Data(repeating: 1, count: 32), address: "testu-a")
        var opened: [NetworkAccount] = []
        home.otherNetworksItem.onOpen = { opened.append($0) }
        home.otherNetworksItem.rows = [NetworkAssetRow(account: account, title: "XOR · Taira", amount: "5,000 XOR",
                                                       tag: .testnet, icon: nil)]
        XCTAssertTrue(home.items.last === home.otherNetworksItem)
        XCTAssertEqual(home.otherNetworksItem.rows.map(\.title), ["XOR · Taira"])
        home.otherNetworksItem.open(account)
        XCTAssertEqual(opened, [account])
    }

    // MARK: XOR on other networks, as VoiceOver reads it

    private func networkRow(_ network: NetworkId, amount: String, wallet: String = "A") -> NetworkAssetRow {
        let account = NetworkAccount(walletId: wallet, networkId: network, derivationVersion: 1,
                                     publicKey: Data(repeating: 1, count: 32), address: "\(wallet)-\(network.rawValue)")
        return NetworkAssetRow(account: account, title: "XOR · \(network.rawValue)", amount: amount, tag: .testnet, icon: nil)
    }

    /// The card in a real table in a window, so it is laid out as on screen. `refresh` is the home's own redraw.
    @MainActor
    private func showCard(_ rows: [NetworkAssetRow]) -> (card: PortfolioOtherNetworksItem, table: SoramitsuTableView, window: UIWindow) {
        let card = PortfolioOtherNetworksItem()
        card.rows = rows
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let table = SoramitsuTableView()
        table.sora.estimatedRowHeight = UITableView.automaticDimension // As on the Wallet tab: without it the row has no height.
        table.frame = window.bounds
        window.addSubview(table)
        window.isHidden = false
        table.sora.sections = [SoramitsuTableViewSection(rows: [card])]
        table.layoutIfNeeded()
        return (card, table, window)
    }

    /// The cell's own list of elements, which VoiceOver reads in place of UIKit's copy.
    @MainActor
    private func listedElements(in cell: UITableViewCell?) -> [UIView] {
        (cell?.accessibilityElements as? [UIView]) ?? []
    }

    /// UIKit keeps its own list of a cell's elements and misses rows replaced deep inside the cell: VoiceOver kept reading the
    /// old row, at a frame it never had, while the screen showed the new one. That list exists only while an assistive client
    /// runs, so this pins what keeps it out of the way: the card lists the views on screen itself and keeps them across a redraw.
    @MainActor
    func testVoiceOverGetsTheCardsCurrentRowsWhereTheScreenShowsThemAfterARedraw() throws {
        let nexus = networkRow(.minamoto, amount: "Address ready")
        let shown = showCard([nexus, networkRow(.taira, amount: "")])
        defer { shown.window.isHidden = true }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: shown.card))
        let testnet = WalletNetworkTag.testnet.title
        let before = listedElements(in: cell)
        XCTAssertEqual(before.count, 3, "The title and the two rows")
        XCTAssertEqual(before.last?.accessibilityLabel, "XOR · taira, \(testnet)")

        shown.card.rows = [nexus, networkRow(.taira, amount: "24,997.98 XOR")]
        RedesignWalletViewController.refresh(items: [shown.card], in: shown.table)

        let after = listedElements(in: cell)
        XCTAssertEqual((after.first as? UILabel)?.text, PortfolioStrings.otherNetworksTitle)
        XCTAssertEqual(after.dropFirst().map(\.accessibilityLabel), ["XOR · minamoto, Address ready, \(testnet)",
                                                                     "XOR · taira, 24,997.98 XOR, \(testnet)"])
        XCTAssertEqual(after.dropFirst().map(\.accessibilityIdentifier), ["portfolio.network-row.minamoto", "portfolio.network-row.taira"])
        XCTAssertTrue(zip(before, after).allSatisfy { $0 === $1 }, "VoiceOver stays on a row whose amount changes")
        guard after.count == 3 else { return XCTFail("The title and the two rows") }
        // The elements are the views on screen, so the frames VoiceOver gets are the screen's.
        let card = cell.convert(cell.bounds, to: nil)
        let frames = after.map { $0.convert($0.bounds, to: nil) }
        for (element, frame) in zip(after, frames) {
            XCTAssertTrue(element.window === shown.window, "\(element) is not on screen")
            XCTAssertGreaterThan(frame.height, 0)
            XCTAssertTrue(card.contains(frame), "\(frame) is outside the card \(card)")
        }
        XCTAssertEqual(frames[1].height, PortfolioNetworkAssetRowView.height, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(frames[1].minY, frames[0].maxY, "Read top to bottom")
        XCTAssertGreaterThanOrEqual(frames[2].minY, frames[1].maxY, "One under the other")
    }

    @MainActor
    func testVoiceOverListFollowsRowsThatComeGoAndChangeOrder() {
        let nexus = networkRow(.minamoto, amount: "Address ready"), taira = networkRow(.taira, amount: "5 XOR")
        let nexusId = "portfolio.network-row.minamoto", tairaId = "portfolio.network-row.taira"
        let shown = showCard([nexus])
        defer { shown.window.isHidden = true }
        func listed() -> [UIView] { listedElements(in: shown.table.cellForItem(item: shown.card)) }
        XCTAssertEqual(listed().dropFirst().map(\.accessibilityIdentifier), [nexusId])

        for (rows, expected) in [([nexus, taira], [nexusId, tairaId]), ([taira, nexus], [tairaId, nexusId]), ([taira], [tairaId])] {
            shown.card.rows = rows
            RedesignWalletViewController.refresh(items: [shown.card], in: shown.table)
            let elements = listed()
            XCTAssertEqual(elements.dropFirst().map(\.accessibilityIdentifier), expected)
            XCTAssertTrue(elements.allSatisfy { $0.window === shown.window }, "Nothing that left the card stays listed")
            let tops = elements.map { $0.convert($0.bounds, to: nil).minY }
            XCTAssertEqual(tops, tops.sorted(), "Read top to bottom")
        }
        shown.card.isShown = false
        RedesignWalletViewController.refresh(items: [shown.card], in: shown.table)
        XCTAssertTrue(listed().isEmpty, "Stepped aside: nothing to read")
        shown.card.isShown = true
        RedesignWalletViewController.refresh(items: [shown.card], in: shown.table)
        XCTAssertEqual(listed().dropFirst().map(\.accessibilityIdentifier), [tairaId])
    }

    /// A row keeps its view, so it must open what it shows now: the selected wallet can change under it.
    @MainActor
    func testRedrawnRowOpensTheAccountItShows() throws {
        let shown = showCard([networkRow(.taira, amount: "1 XOR", wallet: "A")])
        defer { shown.window.isHidden = true }
        var opened: [String] = []
        shown.card.onOpen = { opened.append($0.walletId) }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: shown.card))
        let row = try XCTUnwrap(listedElements(in: cell).last as? UIControl)
        row.sendActions(for: .touchUpInside)
        shown.card.rows = [networkRow(.taira, amount: "2 XOR", wallet: "B")]
        RedesignWalletViewController.refresh(items: [shown.card], in: shown.table)
        XCTAssertTrue(listedElements(in: cell).last === row)
        row.sendActions(for: .touchUpInside)
        XCTAssertEqual(opened, ["A", "B"])
    }
}
