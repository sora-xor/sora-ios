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

    // MARK: Assets, as VoiceOver reads it

    /// The Assets card in a real table in a window, laid out as on the home. A read that lands sets a new model.
    @MainActor
    private func showList(_ home: PortfolioHome) -> (table: SoramitsuTableView, window: UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let table = SoramitsuTableView()
        table.sora.estimatedRowHeight = UITableView.automaticDimension
        table.frame = window.bounds
        window.addSubview(table)
        window.isHidden = false
        table.sora.sections = [SoramitsuTableViewSection(rows: [home.listItem])]
        table.layoutIfNeeded()
        // The Wallet host uses this callback to resize the card when its rows or holdings change.
        home.listItem.onHeightChange = { [weak table] in
            UIView.performWithoutAnimation {
                table?.beginUpdates()
                table?.endUpdates()
            }
        }
        return (table, window)
    }

    /// What VoiceOver speaks for each element. A label has no `accessibilityLabel` of its own while VoiceOver is off.
    private func spoken(_ elements: [UIView]) -> [String] {
        elements.map { ($0 as? UILabel)?.text ?? $0.accessibilityLabel ?? "" }
    }

    private func withNewAmount(_ row: PortfolioRow) -> PortfolioRow {
        PortfolioRow(key: row.key, kind: row.kind, icon: row.icon, title: row.title, change: row.change, direction: row.direction,
                     subtitle: row.subtitle, walletDots: row.walletDots, value: row.value + " +1", detail: row.detail, tag: row.tag,
                     isExpandable: row.isExpandable, isExpanded: row.isExpanded, children: row.children, link: row.link,
                     accessibilityLabel: row.accessibilityLabel + " +1")
    }

    /// Each element is a view on screen inside the card, under the one before it: the frames VoiceOver gets are the screen's.
    @MainActor
    private func assertOnScreenInReadingOrder(_ elements: [UIView], in cell: UITableViewCell, window: UIWindow,
                                              file: StaticString = #filePath, line: UInt = #line) {
        let card = cell.convert(cell.bounds, to: nil).insetBy(dx: -0.5, dy: -0.5)
        var bottom = card.minY
        for element in elements {
            let frame = element.convert(element.bounds, to: nil)
            XCTAssertTrue(element.window === window, "\(element) is not on screen", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, file: file, line: line)
            XCTAssertTrue(card.contains(frame), "\(frame) is outside the card \(card)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minY, bottom - 0.5, "Read top to bottom", file: file, line: line)
            bottom = frame.maxY
        }
    }

    /// UIKit's own list of a cell's elements missed rows rebuilt deep inside the Assets card: VoiceOver skipped them, or read a
    /// removed row's old balance. The card now lists its views itself and keeps them while their tokens stay.
    @MainActor
    func testVoiceOverKeepsTheAssetRowsItFoundAndReadsTheirNewAmounts() throws {
        let home = home()
        home.viewModel.update()
        let model = try XCTUnwrap(home.listItem.model)
        XCTAssertFalse(model.rows.isEmpty)
        let shown = showList(home)
        defer { shown.window.isHidden = true }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: home.listItem))
        let before = listedElements(in: cell)
        XCTAssertEqual(spoken(before), [PortfolioStrings.assets] + model.rows.map(\.accessibilityLabel))

        home.listItem.model = PortfolioListModel(lenses: model.lenses, lens: model.lens, rows: model.rows.map(withNewAmount),
                                                 emptyText: nil)
        shown.table.layoutIfNeeded()

        let after = listedElements(in: cell)
        XCTAssertEqual(spoken(after), [PortfolioStrings.assets] + model.rows.map { $0.accessibilityLabel + " +1" })
        XCTAssertEqual(after.count, before.count)
        XCTAssertTrue(zip(before, after).allSatisfy { $0 === $1 }, "VoiceOver stays on a row whose amount changes")
        assertOnScreenInReadingOrder(after, in: cell, window: shown.window)
    }

    /// On a new wallet the card first says it is reading. VoiceOver kept that text and never reached the rows that replaced it.
    @MainActor
    func testTheAssetRowsReplaceTheReadingTextInWhatVoiceOverReads() throws {
        let home = home()
        home.viewModel.update()
        let model = try XCTUnwrap(home.listItem.model)
        home.listItem.model = PortfolioListModel(lenses: model.lenses, lens: model.lens, rows: [], emptyText: "Reading balances…")
        let shown = showList(home)
        defer { shown.window.isHidden = true }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: home.listItem))
        XCTAssertEqual(spoken(listedElements(in: cell)), [PortfolioStrings.assets, "Reading balances…"])

        home.listItem.model = model
        shown.table.layoutIfNeeded()

        let after = listedElements(in: cell)
        XCTAssertEqual(spoken(after), [PortfolioStrings.assets] + model.rows.map(\.accessibilityLabel))
        assertOnScreenInReadingOrder(after, in: cell, window: shown.window)
    }

    /// Opening a row keeps VoiceOver on it, its holdings come straight after it, and they leave the list when it closes.
    @MainActor
    func testOpeningAnAssetRowKeepsVoiceOverOnItAndListsItsHoldingsNext() throws {
        let home = home()
        home.viewModel.update()
        let model = try XCTUnwrap(home.listItem.model)
        let index = try XCTUnwrap(model.rows.firstIndex(where: \.isExpandable))
        let shown = showList(home)
        defer { shown.window.isHidden = true }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: home.listItem))
        func element(_ position: Int) throws -> UIView {
            let elements = listedElements(in: cell)
            return try XCTUnwrap(elements.indices.contains(position) ? elements[position] : nil, "Nothing listed at \(position)")
        }
        let row = try element(index + 1)
        XCTAssertEqual(row.accessibilityValue, PortfolioStrings.text("Collapsed"))

        home.viewModel.toggleRow(model.rows[index].key)
        shown.table.layoutIfNeeded()

        let opened = try XCTUnwrap(home.listItem.model?.rows[index])
        XCTAssertFalse(opened.children.isEmpty)
        XCTAssertTrue(try element(index + 1) === row, "VoiceOver stays on the row it opened")
        XCTAssertEqual(row.accessibilityValue, PortfolioStrings.text("Expanded"))
        let holdings = Array(listedElements(in: cell).dropFirst(index + 2).prefix(opened.children.count))
        XCTAssertEqual(spoken(holdings), opened.children.map(\.accessibilityLabel))
        assertOnScreenInReadingOrder(listedElements(in: cell), in: cell, window: shown.window)

        home.viewModel.toggleRow(model.rows[index].key)
        shown.table.layoutIfNeeded()
        XCTAssertTrue(try element(index + 1) === row)
        XCTAssertEqual(listedElements(in: cell).count, model.rows.count + 1, "The holdings left the list with the well")
    }

    @MainActor
    func testAssetRowsKeepIdentityWhenReorderedAndUseTheirLatestCallbacks() throws {
        let home = home()
        home.viewModel.update()
        let model = try XCTUnwrap(home.listItem.model)
        XCTAssertGreaterThanOrEqual(model.rows.count, 2)
        guard model.rows.count >= 2 else { return }
        let initial = Array(model.rows.prefix(2))
        func setRows(_ rows: [PortfolioRow]) {
            home.listItem.model = PortfolioListModel(lenses: model.lenses, lens: model.lens, rows: rows, emptyText: nil)
        }
        setRows(initial)
        let shown = showList(home)
        defer { shown.window.isHidden = true }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: home.listItem))
        let before = listedElements(in: cell)
        guard before.count == 3 else { return XCTFail("Expected the heading and two asset rows") }
        let first = try XCTUnwrap(before[1] as? UIControl)
        let second = try XCTUnwrap(before[2] as? UIControl)
        var opened: [PortfolioRow] = []
        home.listItem.onRow = { opened.append($0) }
        first.sendActions(for: .touchUpInside)

        let updated = initial.map(withNewAmount)
        setRows(Array(updated.reversed()))
        shown.table.layoutIfNeeded()
        let reordered = listedElements(in: cell)
        guard reordered.count == 3 else { return XCTFail("Expected the reordered asset rows") }
        XCTAssertTrue(reordered[1] === second)
        XCTAssertTrue(reordered[2] === first)
        XCTAssertEqual(spoken(reordered), [PortfolioStrings.assets] + updated.reversed().map(\.accessibilityLabel))
        first.sendActions(for: .touchUpInside)
        XCTAssertEqual(opened, [initial[0], updated[0]], "A retained view must open the latest row model")
        assertOnScreenInReadingOrder(reordered, in: cell, window: shown.window)

        setRows([updated[0]])
        shown.table.layoutIfNeeded()
        let remaining = listedElements(in: cell)
        guard remaining.count == 2 else { return XCTFail("Expected only the retained asset row") }
        XCTAssertTrue(remaining[1] === first)
        XCTAssertNil(second.window, "A removed row must leave the visual and accessibility trees")
        assertOnScreenInReadingOrder(remaining, in: cell, window: shown.window)
    }

    @MainActor
    func testExpandedHoldingsRefreshTheirTargetsAndRemoveTheOldLink() throws {
        let home = home()
        home.viewModel.update()
        let initialModel = try XCTUnwrap(home.listItem.model)
        let expandable = try XCTUnwrap(initialModel.rows.first(where: \.isExpandable))
        home.viewModel.toggleRow(expandable.key)
        let model = try XCTUnwrap(home.listItem.model)
        let expanded = try XCTUnwrap(model.rows.first(where: { $0.key == expandable.key }))
        XCTAssertGreaterThanOrEqual(expanded.children.count, 2)
        guard expanded.children.count >= 2 else { return }
        let children = Array(expanded.children.prefix(2))
        func parent(_ children: [PortfolioChildRow], value: String, link: String?) -> PortfolioRow {
            PortfolioRow(key: expanded.key, kind: expanded.kind, icon: expanded.icon, title: expanded.title,
                         change: expanded.change, direction: expanded.direction, subtitle: expanded.subtitle,
                         walletDots: expanded.walletDots, value: value, detail: expanded.detail, tag: expanded.tag,
                         isExpandable: true, isExpanded: true, children: children, link: link,
                         accessibilityLabel: expanded.accessibilityLabel)
        }
        func setRow(_ row: PortfolioRow) {
            home.listItem.model = PortfolioListModel(lenses: model.lenses, lens: model.lens, rows: [row], emptyText: nil)
        }
        setRow(parent(children, value: "old value", link: "Open wallet"))
        let shown = showList(home)
        defer { shown.window.isHidden = true }
        let cell = try XCTUnwrap(shown.table.cellForItem(item: home.listItem))
        let before = listedElements(in: cell)
        guard before.count == 5 else { return XCTFail("Expected the heading, parent, two holdings and link") }
        let first = try XCTUnwrap(before[2] as? UIControl)
        let second = try XCTUnwrap(before[3] as? UIControl)
        let link = try XCTUnwrap(before[4] as? UIButton)
        var opened: [PortfolioChildRow] = []
        var linkedValues: [String] = []
        home.listItem.onChild = { opened.append($0) }
        home.listItem.onLink = { linkedValues.append($0.value) }
        first.sendActions(for: .touchUpInside)
        link.sendActions(for: .touchUpInside)

        let updated = children.map { child in
            PortfolioChildRow(key: child.key, icon: child.icon, title: child.title, subtitle: child.subtitle,
                              walletSlot: child.walletSlot, value: child.value + " +1", detail: child.detail,
                              tag: child.tag, target: .token("updated-" + child.key),
                              accessibilityLabel: child.accessibilityLabel + " +1")
        }
        setRow(parent(Array(updated.reversed()), value: "new value", link: "Open updated wallet"))
        shown.table.layoutIfNeeded()
        let reordered = listedElements(in: cell)
        guard reordered.count == 5 else { return XCTFail("Expected the reordered holdings and link") }
        XCTAssertTrue(reordered[2] === second)
        XCTAssertTrue(reordered[3] === first)
        XCTAssertTrue(reordered[4] === link)
        XCTAssertEqual(spoken(Array(reordered[2...3])), updated.reversed().map(\.accessibilityLabel))
        first.sendActions(for: .touchUpInside)
        link.sendActions(for: .touchUpInside)
        XCTAssertEqual(opened, [children[0], updated[0]])
        XCTAssertEqual(linkedValues, ["old value", "new value"])
        assertOnScreenInReadingOrder(reordered, in: cell, window: shown.window)

        setRow(parent([updated[0]], value: "new value", link: nil))
        shown.table.layoutIfNeeded()
        let remaining = listedElements(in: cell)
        guard remaining.count == 3 else { return XCTFail("Expected only the parent and retained holding") }
        XCTAssertTrue(remaining[2] === first)
        XCTAssertNil(second.window)
        XCTAssertNil(link.window)
        assertOnScreenInReadingOrder(remaining, in: cell, window: shown.window)
    }
}
