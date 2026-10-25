// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

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

    func testVisibilityMirrorsTheAssetList() {
        let fresh = wallet("A")
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: xor, wallet: fresh))
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: val, wallet: fresh), "Default assets show")
        XCTAssertFalse(PortfolioSnapshotBuilder.isVisible(assetId: other, wallet: fresh))
        let customised = wallet("A", visible: [other], ordered: [xor, val, other])
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: other, wallet: customised))
        XCTAssertFalse(PortfolioSnapshotBuilder.isVisible(assetId: val, wallet: customised))
        XCTAssertTrue(PortfolioSnapshotBuilder.isVisible(assetId: xor, wallet: customised), "XOR always shows")
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
        XCTAssertEqual(snapshot.holdings.first { $0.token.id == other }?.isHidden, true)
        XCTAssertEqual(snapshot.holdings.first { $0.network == .taira }?.amount, 42)
        XCTAssertEqual(snapshot.wallet("A")?.networks, [.sora2, .taira])
        XCTAssertEqual(snapshot.wallet("A")?.addresses[.sora2], "A")
        XCTAssertEqual(snapshot.wallet("A")?.freshness.state, .live)
        XCTAssertEqual(snapshot.wallet("B")?.freshness.state, .partial)
        XCTAssertEqual(snapshot.wallet("B")?.networks, [.sora2], "No Taira account, no Taira network")
        XCTAssertEqual(PortfolioAggregator.summary(snapshot, scope: .allWallets).total, 210)
    }

    func testDebugInputsStayOutOfReleaseBuilds() {
        #if F_RELEASE
        XCTAssertFalse(PortfolioFeature.allowsDebugInjection, "Release builds never take the sample or an injected tilt")
        #else
        XCTAssertTrue(PortfolioFeature.allowsDebugInjection)
        #endif
    }
}
