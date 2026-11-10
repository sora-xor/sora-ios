// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

@testable import SoraPassport
import XCTest

/// The live source's snapshot: other wallets read by address, hidden rules per wallet, Nexus XOR.
final class PortfolioSnapshotBuilderTests: XCTestCase {
    private let xor = PortfolioSnapshotBuilder.xorId
    private let val = WalletAssetId.val.rawValue
    private let other = "0x00aabbccddeeff00112233445566778899aabbccddeeff001122334455667788"

    private var assets: [PortfolioAssetSource] {
        [PortfolioAssetSource(id: xor, symbol: "XOR", name: "SORA", icon: nil, precision: 18),
         PortfolioAssetSource(id: val, symbol: "VAL", name: "SORA Validator Token", icon: nil, precision: 18),
         PortfolioAssetSource(id: other, symbol: "OTH", name: "Other", icon: nil, precision: 18)]
    }

    private func wallet(_ id: String, selected: Bool = false, visible: [String]? = nil, ordered: [String]? = nil,
                        taira: String? = nil) -> PortfolioWalletSource {
        PortfolioWalletSource(id: id, name: id, order: 0, isSelected: selected, visibleAssetIds: visible,
                              orderedAssetIds: ordered, addresses: taira.map { [.taira: $0] } ?? [:])
    }

    func testEverythingHeldIsListedUnlessADefaultTokenWasTurnedOff() {
        let fresh = wallet("A")
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: xor, wallet: fresh))
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: val, wallet: fresh), "Default assets show")
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: other, wallet: fresh), "So does any other token held")
        let customised = wallet("A", visible: [other], ordered: [xor, val, other])
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: other, wallet: customised))
        XCTAssertFalse(PortfolioSnapshotBuilder.isVisible(assetId: val, wallet: customised), "The user turned it off")
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: xor, wallet: customised), "XOR always shows")
        // AssetManager saves other tokens as not visible until they are turned on, chosen or not.
        let saved = wallet("A", visible: [xor, val], ordered: [xor, val, other])
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: other, wallet: saved))
    }

    func testBuildsHoldingsFromReadsWithTotalsTransferableAndNexusXor() {
        let now = Date(timeIntervalSince1970: 10_000)
        let reads: [String: PortfolioWalletReadState] = [
            "A": PortfolioWalletReadState(sora2: [xor: PortfolioRawBalance(free: 100, reserved: 5, frozen: 10),
                                                  val: .zero, other: PortfolioRawBalance(free: 7, reserved: 0, frozen: 0)],
                                          nexus: [.taira: 42], lastRead: now.addingTimeInterval(-30), lastAttempt: now,
                                          failed: []),
            "B": PortfolioWalletReadState(sora2: nil, lastRead: nil, lastAttempt: now, failed: [.sora2])
        ]
        let snapshot = PortfolioSnapshotBuilder.build(
            wallets: [wallet("A", selected: true, taira: "taira-a"), wallet("B")], assets: assets, reads: reads,
            prices: PortfolioPriceSource(usd: [xor: 2], change: [xor: 1]), networks: [.sora2, .taira],
            liveNetworks: [.sora2, .taira], swapsAvailable: true, disclaimerAccepted: false, now: now)

        let xorA = snapshot.holdings.first { $0.walletId == "A" && $0.network == .sora2 && $0.token.id == xor }
        XCTAssertEqual(xorA?.amount, 105, "Total is free plus reserved")
        XCTAssertEqual(xorA?.transferable, 90, "Transferable is free minus frozen")
        XCTAssertEqual(xorA?.locked, 15)
        XCTAssertEqual(xorA?.token.priceUSD, 2)
        XCTAssertNil(snapshot.holdings.first { $0.token.id == val }, "Zero balances are not holdings")
        XCTAssertEqual(snapshot.holdings.first { $0.token.id == other }?.isHidden, false, "Everything held is listed")
        XCTAssertEqual(snapshot.holdings.first { $0.network == .taira }?.amount, 42)
        XCTAssertEqual(snapshot.wallet("A")?.networks, [.sora2, .taira])
        XCTAssertEqual(snapshot.wallet("A")?.addresses[.sora2], "A")
        XCTAssertEqual(snapshot.wallet("A")?.freshness.state, .live)
        XCTAssertEqual(snapshot.wallet("B")?.freshness.state, .partial)
        XCTAssertEqual(snapshot.wallet("B")?.networks, [.sora2], "No Taira account, no Taira network")
        XCTAssertEqual(PortfolioAggregator.summary(snapshot, scope: .allWallets).total, 210)
    }

    func testOldPricesKeepTheirValueButLoseTheir24HourChange() {
        let now = Date(timeIntervalSince1970: 10_000)
        func build(_ prices: PortfolioPriceSource) -> PortfolioSnapshot {
            let reads = ["A": PortfolioWalletReadState(sora2: [xor: PortfolioRawBalance(free: 1, reserved: 0, frozen: 0)], lastRead: now)]
            return PortfolioSnapshotBuilder.build(wallets: [wallet("A", selected: true)], assets: assets, reads: reads,
                                                  prices: prices, networks: [.sora2], liveNetworks: [.sora2],
                                                  swapsAvailable: true, disclaimerAccepted: false, now: now)
        }

        let recent = build(PortfolioPriceSource(usd: [xor: 2], change: [xor: 1], readAt: now.addingTimeInterval(-60)))
        XCTAssertEqual(recent.holdings.first?.token.change24h, 1)
        XCTAssertNil(recent.pricesAsOf)

        // Saved by an earlier launch, or not read since: nothing has said so yet, but they are old.
        let lastRead = now.addingTimeInterval(-PortfolioSnapshotBuilder.pricesOldAfter - 1)
        let saved = build(PortfolioPriceSource(usd: [xor: 2], change: [xor: 1], readAt: lastRead))
        XCTAssertEqual(saved.holdings.first?.token.priceUSD, 2)
        XCTAssertNil(saved.holdings.first?.token.change24h)
        XCTAssertEqual(saved.pricesAsOf, lastRead)

        let marked = now.addingTimeInterval(-120)
        let catalog = build(PortfolioPriceSource(usd: [xor: 2], change: [xor: 1], asOf: marked, readAt: marked))
        XCTAssertNil(catalog.holdings.first?.token.change24h, "The price catalog already says they are old")
        XCTAssertEqual(catalog.pricesAsOf, marked)
    }

    func testDebugInputsStayOutOfReleaseBuilds() {
        // F_RELEASE is set on the app target only, so this bundle goes by its own DEBUG flag.
        #if DEBUG
        XCTAssertTrue(PortfolioFeature.allowsDebugInjection)
        #else
        XCTAssertFalse(PortfolioFeature.allowsDebugInjection, "Release builds never take the sample or an injected tilt")
        #endif
    }
}
