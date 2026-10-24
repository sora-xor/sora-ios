// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

@testable import SoraPassport
import SoraUIKit
import XCTest

/// The Wallet tab with the portfolio: what it replaces and what it keeps.
final class PortfolioWalletHomeTests: XCTestCase {
    @MainActor
    func testHomeKeepsTheSecondaryCardsAndReplacesTheHeaderAndAssets() {
        let home = PortfolioHome(dataSource: PortfolioFakeSource(PortfolioFixtures.snapshot()),
                                 preferences: PortfolioPreferences(defaults: UserDefaults(suiteName: "portfolio.home")!))
        let account = AccountTableViewItem(accountName: "Main")
        let backup = BackupItem()
        let friends = FriendsItem()
        let edit = EditViewItem()
        let composed = home.compose(replacing: [account, backup, friends, edit])
        XCTAssertTrue(composed[0] === home.heroItem)
        XCTAssertTrue(composed[1] === home.lensItem)
        XCTAssertTrue(composed[2] === home.listItem)
        XCTAssertTrue(composed[3] === backup)
        XCTAssertTrue(composed[4] === friends)
        XCTAssertTrue(composed[5] === edit)
        XCTAssertFalse(composed.contains { $0 is AccountTableViewItem })
        // An account that cannot sign keeps its warning under the hero.
        account.capability = .missingKeys
        let warned = home.compose(replacing: [account, edit])
        XCTAssertTrue(warned[1] === home.noticeItem)
        XCTAssertTrue(home.noticeShown)
    }

    @MainActor
    func testOtherNetworkRowsStayReachableUnderTheList() {
        let home = PortfolioHome(dataSource: PortfolioFakeSource(PortfolioFixtures.snapshot()),
                                 preferences: PortfolioPreferences(defaults: UserDefaults(suiteName: "portfolio.home")!))
        let assets = AssetsItem(title: "Assets", assetProvider: PortfolioHomeAssetProvider(), service: nil)
        let account = NetworkAccount(walletId: "A", networkId: .taira, derivationVersion: 1,
                                     publicKey: Data(repeating: 1, count: 32), address: "testu-a")
        var opened: [NetworkAccount] = []
        assets.networkRowHandler = { opened.append($0) }
        assets.networkRows = [NetworkAssetRow(account: account, title: "XOR · Taira", amount: "5,000 XOR",
                                              tag: .testnet, icon: nil, isMain: false)]
        let edit = EditViewItem()
        let composed = home.compose(replacing: [AccountTableViewItem(accountName: "Main"), assets, edit])
        XCTAssertTrue(composed[2] === home.listItem)
        XCTAssertTrue(composed[3] === home.otherNetworksItem, "The network rows sit right under the list")
        XCTAssertFalse(composed.contains { $0 is AssetsItem }, "The hero and the Tokens lens replace the Assets card")
        XCTAssertEqual(home.otherNetworksItem.rows.map(\.title), ["XOR · Taira"])
        home.otherNetworksItem.open(account)
        XCTAssertEqual(opened, [account], "A row opens the network's page through the Wallet tab")
        // The Wallet tab reloads its Assets card when the rows change; that reload reaches the card.
        let targets = home.reloadTargets(for: [assets, edit])
        XCTAssertTrue(targets[0] === home.otherNetworksItem)
        XCTAssertTrue(targets[1] === edit)
    }
}

private final class PortfolioHomeAssetProvider: AssetProviderProtocol {
    func getBalances(with assetIds: [String]) -> [BalanceData] { [] }
    func add(observer: AssetProviderObserverProtocol) {}
    func remove(observer: AssetProviderObserverProtocol) {}
}
