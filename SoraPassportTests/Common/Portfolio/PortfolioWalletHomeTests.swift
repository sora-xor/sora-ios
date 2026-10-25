// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

@testable import SoraPassport
import SoraUIKit
import XCTest
import UIKit

final class PortfolioWalletHomeTests: XCTestCase {
    func testHomeSettingsOfferOnlyTheRemainingOptionalCards() {
        XCTAssertEqual(Cards.allCases.map(\.id), [1, 3], "Persisted card IDs stay stable; the permanent portfolio has no visibility toggle")
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
        XCTAssertEqual(home.items.count, 4)
        XCTAssertTrue(home.items[0] === home.heroItem)
        XCTAssertTrue(home.items[1] === home.lensItem)
        XCTAssertTrue(home.items[2] === home.listItem)
        for state in [WalletAccountCapability.State.missingKeys, .invalidKeys, .watchOnly, .repairPending, .unavailable] {
            home.noticeItem.setCapability(state)
            XCTAssertEqual(home.items.count, 5)
            XCTAssertTrue(home.items[1] === home.noticeItem)
        }
        home.noticeItem.setCapability(.signing)
        XCTAssertFalse(home.items.contains { $0 === home.noticeItem })
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
        XCTAssertTrue(home.items[3] === home.otherNetworksItem)
        XCTAssertEqual(home.otherNetworksItem.rows.map(\.title), ["XOR · Taira"])
        home.otherNetworksItem.open(account)
        XCTAssertEqual(opened, [account])
    }
}
