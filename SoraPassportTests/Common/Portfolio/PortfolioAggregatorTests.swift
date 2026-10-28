// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

@testable import SoraPassport
import XCTest

/// Fixtures for the portfolio data layer.
enum PortfolioFixtures {
    static let xor = token("0x0200000000000000000000000000000000000000000000000000000000000000", "XOR", "0.004", "3.4")
    static let val = token("0x0200040000000000000000000000000000000000000000000000000000000000", "VAL", "0.02", "-2")
    static let pswap = token("0x0200050000000000000000000000000000000000000000000000000000000000", "PSWAP", "0.0005", nil)
    static let eth = token("0x0200070000000000000000000000000000000000000000000000000000000000", "ETH", "2000", "1")
    static let meme = token("0x00aa", "MEME", nil, nil, swappable: false)

    static func token(_ id: String, _ symbol: String, _ price: String?, _ change: String?,
                      swappable: Bool = true) -> PortfolioToken {
        PortfolioToken(id: id, symbol: symbol, name: symbol, icon: nil, priceUSD: price.flatMap { Decimal(string: $0) },
                       change24h: change.flatMap { Decimal(string: $0) }, isSwappable: swappable)
    }

    static func holding(_ wallet: String, _ network: PortfolioNetwork, _ token: PortfolioToken, _ amount: String,
                        transferable: String? = nil, hidden: Bool = false) -> PortfolioHolding {
        let total = Decimal(string: amount) ?? 0
        return PortfolioHolding(walletId: wallet, network: network, token: token, amount: total,
                                transferable: transferable.flatMap { Decimal(string: $0) } ?? total, isHidden: hidden)
    }

    static func wallet(_ id: String, _ name: String, order: Int, selected: Bool = false,
                       networks: [PortfolioNetwork] = [.sora2],
                       freshness: PortfolioFreshness = .live(Date(timeIntervalSince1970: 1_000))) -> PortfolioWallet {
        PortfolioWallet(id: id, name: name, isSelected: selected, order: order, networks: networks,
                        addresses: Dictionary(uniqueKeysWithValues: networks.map { ($0, "\(id)-\($0.rawValue)") }),
                        freshness: freshness)
    }

    /// Two wallets: A holds XOR on SORA2 and Taira, VAL hidden, MEME unpriced; B holds XOR and ETH.
    static func snapshot(freshnessB: PortfolioFreshness = .live(Date(timeIntervalSince1970: 1_000))) -> PortfolioSnapshot {
        PortfolioSnapshot(
            wallets: [wallet("A", "Alpha", order: 0, selected: true, networks: [.sora2, .taira]),
                      wallet("B", "Beta", order: 1, freshness: freshnessB)],
            holdings: [
                holding("A", .sora2, xor, "100000", transferable: "90000"),  // $400
                holding("A", .taira, xor, "5000"),                            // testnet
                holding("A", .sora2, val, "1000", hidden: true),              // hidden
                holding("A", .sora2, meme, "77"),                             // unpriced
                holding("B", .sora2, xor, "50000"),                           // $200
                holding("B", .sora2, eth, "0.5"),                             // $1,000
                holding("B", .sora2, pswap, "0")                              // zero: ignored
            ],
            networks: [.sora2, .minamoto, .taira], swapsAvailable: true, swapDisclaimerAccepted: true,
            liveNetworks: [.sora2, .taira])
    }
}

final class PortfolioAggregatorTests: XCTestCase {
    private let snapshot = PortfolioFixtures.snapshot()

    func testTotalCountsVisiblePricedMainnetHoldingsOnly() {
        let summary = PortfolioAggregator.summary(snapshot, scope: .allWallets)
        XCTAssertEqual(summary.total, 1_600)
        XCTAssertEqual(summary.hiddenCount, 1)
        XCTAssertEqual(summary.unpricedCount, 1)
        XCTAssertEqual(summary.testnetCount, 1)
        XCTAssertTrue(summary.hasExclusions)
    }

    func testExclusionPrecedenceNamesEachHoldingOnce() {
        let hiddenTestnet = PortfolioFixtures.holding("A", .taira, PortfolioFixtures.xor, "1", hidden: true)
        XCTAssertEqual(PortfolioAggregator.exclusion(for: hiddenTestnet), .hidden)
        let testnet = PortfolioFixtures.holding("A", .taira, PortfolioFixtures.meme, "1")
        XCTAssertEqual(PortfolioAggregator.exclusion(for: testnet), .testnet)
        XCTAssertEqual(PortfolioAggregator.value(of: testnet), 0)
    }

    func testAllWalletsTotalIsTheSumOfEachWalletsOwnTotal() {
        let a = PortfolioAggregator.summary(snapshot, scope: .wallet("A")).total
        let b = PortfolioAggregator.summary(snapshot, scope: .wallet("B")).total
        XCTAssertEqual(a, 400)
        XCTAssertEqual(b, 1_200)
        XCTAssertEqual(PortfolioAggregator.summary(snapshot, scope: .allWallets).total, a + b)
    }

    func testRowsAddUpToTheHeaderInEveryLens() {
        for scope in [PortfolioScope.allWallets, .wallet("A"), .wallet("B")] {
            let total = PortfolioAggregator.summary(snapshot, scope: scope).total
            for lens in PortfolioLens.allCases where scope == .allWallets || lens != .wallets {
                let sum = PortfolioAggregator.groups(snapshot, scope: scope, lens: lens).reduce(Decimal(0)) { $0 + $1.value }
                XCTAssertEqual(sum, total, "\(scope) \(lens)")
            }
        }
    }

    func testTokenLensGroupsNativeXorAcrossNetworksAndHidesHiddenAssets() {
        let groups = PortfolioAggregator.groups(snapshot, scope: .allWallets, lens: .tokens)
        XCTAssertEqual(groups.first?.key, PortfolioFixtures.eth.id)
        guard let xor = groups.first(where: { $0.key == PortfolioFixtures.xor.id }) else {
            return XCTFail("XOR group missing")
        }
        XCTAssertEqual(xor.holdings.count, 3)
        XCTAssertEqual(xor.networks, [.sora2, .taira])
        XCTAssertEqual(xor.walletIds.sorted(), ["A", "B"])
        // Mainnet amounts add up; the testnet amount is not mixed in.
        XCTAssertEqual(xor.tokenAmount, 150_000)
        XCTAssertEqual(xor.holdings.last?.network, .taira)
        XCTAssertFalse(groups.contains { $0.key == PortfolioFixtures.val.id })
        XCTAssertFalse(groups.contains { $0.key == PortfolioFixtures.pswap.id })
        // Unpriced tokens stay in the list, after the counted ones.
        XCTAssertEqual(groups.last?.key, PortfolioFixtures.meme.id)
    }

    func testNetworkAndWalletLenses() {
        let networks = PortfolioAggregator.groups(snapshot, scope: .allWallets, lens: .networks)
        XCTAssertEqual(networks.map(\.key), ["sora2", "taira"])
        XCTAssertEqual(networks.first?.share, 1)
        let wallets = PortfolioAggregator.groups(snapshot, scope: .allWallets, lens: .wallets)
        XCTAssertEqual(wallets.map(\.key), ["B", "A"])
        XCTAssertEqual(wallets.map(\.share), [Decimal(string: "0.75"), Decimal(string: "0.25")])
    }

    func testChangeOver24HoursUsesEachAssetsOwnPriceChange() {
        let summary = PortfolioAggregator.summary(snapshot, scope: .wallet("B"))
        // XOR +3.4 % on $200 and ETH +1 % on $1,000.
        let expected = Decimal(200) - Decimal(200) / Decimal(string: "1.034")! + Decimal(1_000) - Decimal(1_000) / Decimal(string: "1.01")!
        XCTAssertEqual(NSDecimalNumber(decimal: summary.change24h).doubleValue, NSDecimalNumber(decimal: expected).doubleValue,
                       accuracy: 1e-9)
        XCTAssertNotNil(summary.changePercent)
    }

    func testEmptyScopeHasNoChangePercent() {
        let empty = PortfolioSnapshot(wallets: [PortfolioFixtures.wallet("A", "Alpha", order: 0, selected: true)],
                                      holdings: [], networks: [.sora2], swapsAvailable: true,
                                      swapDisclaimerAccepted: false, liveNetworks: [.sora2])
        let summary = PortfolioAggregator.summary(empty, scope: .allWallets)
        XCTAssertEqual(summary.total, 0)
        XCTAssertNil(summary.changePercent)
        XCTAssertFalse(summary.hasExclusions)
    }

    func testFreshnessIsTheWorstWallets() {
        let saved = PortfolioFixtures.snapshot(freshnessB: .saved(Date(timeIntervalSince1970: 500)))
        XCTAssertEqual(PortfolioAggregator.summary(saved, scope: .allWallets).freshness.state, .saved)
        XCTAssertEqual(PortfolioAggregator.summary(saved, scope: .wallet("A")).freshness.state, .live)
        let partial = PortfolioFixtures.snapshot(freshnessB: .partial(nil, unreachable: [.sora2]))
        XCTAssertEqual(PortfolioAggregator.summary(partial, scope: .allWallets).freshness.unreachable, [.sora2])
    }
}

final class PortfolioAllocationTests: XCTestCase {
    func testLargestRemainderAlwaysAddsUpToOneHundred() {
        XCTAssertEqual(PortfolioAllocation.apportion([5, 3, 2]), [50, 30, 20])
        XCTAssertEqual(PortfolioAllocation.apportion([1, 1, 1]), [34, 33, 33])
        for values in [[1_000, 1, 1], [3, 3, 3, 1], [0.4, 0.4, 0.2], [7, 13, 29, 51, 1, 1]] as [[Decimal]] {
            XCTAssertEqual(PortfolioAllocation.apportion(values).reduce(0, +), 100, "\(values)")
        }
        XCTAssertEqual(PortfolioAllocation.apportion([0, 0]), [0, 0])
        XCTAssertEqual(PortfolioAllocation.apportion([]), [])
    }

    func testFanKeepsFiveSlotsAndFoldsTheRestIntoOtherLast() {
        let values: [(key: String, value: Decimal)] = (1...8).map { ("k\($0)", Decimal(100 - $0 * 10)) }
        let fan = PortfolioAllocation.fan(values: values, previousSlots: [:])
        XCTAssertEqual(fan.segments.count, 6)
        XCTAssertEqual(fan.segments.last?.key, PortfolioAllocation.otherKey)
        XCTAssertEqual(fan.segments.last?.slot, .other)
        XCTAssertEqual(fan.segments.last?.members, ["k6", "k7", "k8"])
        XCTAssertEqual(fan.segments.map(\.rays).reduce(0, +), 100)
        XCTAssertEqual(Set(fan.segments.dropLast().map(\.slot)), Set((0..<5).map(PortfolioSlot.slot)))
    }

    func testSeedMatchesAcrossDevicesAndColourFollowsTheEntity() {
        let seed = PortfolioAllocation.tokenSeed
        let xor = PortfolioFixtures.xor.id, val = PortfolioFixtures.val.id, eth = PortfolioFixtures.eth.id
        let first = PortfolioAllocation.fan(values: [(eth, 50), (xor, 30), (val, 20)], previousSlots: seed)
        XCTAssertEqual(first.segments.map(\.slot), [.slot(4), .slot(0), .slot(1)])
        // XOR overtakes ETH: the ranks change, the colours do not.
        let second = PortfolioAllocation.fan(values: [(xor, 60), (eth, 30), (val, 10)], previousSlots: first.slots)
        XCTAssertEqual(second.segments.map(\.slot), [.slot(0), .slot(4), .slot(1)])
    }

    func testNewcomerPrefersAFreeSlotThenEvictsAReservation() {
        let previous = ["a": 0, "b": 1, "c": 2, "d": 3, "e": 4]
        let slots = PortfolioAllocation.assignSlots(topKeys: ["a", "b", "x", "d", "y"], previous: previous)
        XCTAssertEqual(slots["a"], 0)
        XCTAssertEqual(slots["b"], 1)
        XCTAssertEqual(slots["d"], 3)
        XCTAssertEqual(Set([slots["x"], slots["y"]].compactMap { $0 }), [2, 4])
        XCTAssertNil(slots["c"])
        XCTAssertNil(slots["e"])
        let kept = PortfolioAllocation.assignSlots(topKeys: ["a"], previous: previous)
        XCTAssertEqual(kept, previous, "Entities outside the top keep their slot until it is needed")
    }

    func testPercentText() {
        XCTAssertEqual(PortfolioAllocation.percentText(rays: 19, share: Decimal(string: "0.19")!), "19%")
        XCTAssertEqual(PortfolioAllocation.percentText(rays: 0, share: Decimal(string: "0.001")!), "<1%")
    }
}

final class PortfolioPolicyTests: XCTestCase {
    func testReadiness() {
        let swapsOn = true
        XCTAssertEqual(PortfolioReadiness.evaluate(PortfolioFixtures.holding("A", .sora2, PortfolioFixtures.xor, "1"),
                                                   swapsAvailable: swapsOn), .ready)
        XCTAssertEqual(PortfolioReadiness.evaluate(PortfolioFixtures.holding("A", .sora2, PortfolioFixtures.xor, "1"),
                                                   swapsAvailable: false), .notTradable)
        XCTAssertEqual(PortfolioReadiness.evaluate(PortfolioFixtures.holding("A", .sora2, PortfolioFixtures.meme, "1"),
                                                   swapsAvailable: swapsOn), .notTradable)
        XCTAssertEqual(PortfolioReadiness.evaluate(PortfolioFixtures.holding("A", .minamoto, PortfolioFixtures.xor, "1"),
                                                   swapsAvailable: swapsOn), .noRoute(.minamoto))
        XCTAssertEqual(PortfolioReadiness.evaluate(PortfolioFixtures.holding("A", .taira, PortfolioFixtures.xor, "1"),
                                                   swapsAvailable: swapsOn), .test)
        XCTAssertTrue(PortfolioReadiness.ready.showsChip)
        XCTAssertTrue(PortfolioReadiness.test.showsChip)
        XCTAssertFalse(PortfolioReadiness.noRoute(.minamoto).showsChip)
    }

    func testActionPlanLeadsWithSwapOnlyWhenReadyAndExplainsTheRest() {
        let ready = PortfolioFixtures.holding("A", .sora2, PortfolioFixtures.xor, "10")
        let plan = PortfolioActionPlan.plan(for: ready, readiness: .ready, otherWalletsOnNetwork: 0, networkIsLive: true)
        XCTAssertEqual(plan.primary.action, .swap)
        XCTAssertEqual(plan.secondary.map(\.action), [.send, .move])
        XCTAssertEqual(plan.secondary.last?.unavailableReason, .noOtherWallet)

        let nexus = PortfolioFixtures.holding("A", .minamoto, PortfolioFixtures.xor, "10")
        let notLive = PortfolioActionPlan.plan(for: nexus, readiness: .noRoute(.minamoto), otherWalletsOnNetwork: 1,
                                               networkIsLive: false)
        XCTAssertEqual(notLive.primary.action, .send)
        XCTAssertEqual(notLive.primary.unavailableReason, .networkNotLive(.minamoto))
        XCTAssertEqual(notLive.secondary.first?.action, .receiveOnSora2)

        let locked = PortfolioFixtures.holding("A", .sora2, PortfolioFixtures.meme, "10", transferable: "0")
        let lockedPlan = PortfolioActionPlan.plan(for: locked, readiness: .notTradable, otherWalletsOnNetwork: 2,
                                                  networkIsLive: true)
        XCTAssertEqual(lockedPlan.primary.unavailableReason, .nothingTransferable)
        XCTAssertEqual(lockedPlan.secondary.last?.unavailableReason, .notTradable)
    }

    func testFreshnessPolicy() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(PortfolioFreshnessPolicy.freshness(lastRead: now.addingTimeInterval(-30), failedNetworks: [], now: now).state, .live)
        XCTAssertEqual(PortfolioFreshnessPolicy.freshness(lastRead: now.addingTimeInterval(-7_200), failedNetworks: [], now: now).state, .saved)
        XCTAssertEqual(PortfolioFreshnessPolicy.freshness(lastRead: now.addingTimeInterval(-30), failedNetworks: [.sora2], now: now).state, .partial)
        // A testnet that cannot be reached never makes the counted total partial.
        XCTAssertEqual(PortfolioFreshnessPolicy.freshness(lastRead: now.addingTimeInterval(-30), failedNetworks: [.taira], now: now).state, .live)
        XCTAssertEqual(PortfolioFreshnessPolicy.freshness(lastRead: nil, failedNetworks: [], now: now).state, .offline)

        let combined = PortfolioFreshnessPolicy.combined([.live(now.addingTimeInterval(-12)), .live(now.addingTimeInterval(-31))])
        XCTAssertEqual(combined.state, .live)
        XCTAssertEqual(PortfolioFreshnessPolicy.ageText(since: combined.updatedAt, now: now), "31s")
        XCTAssertEqual(PortfolioFreshnessPolicy.combined([.live(now), .saved(now), .offline]).state, .offline)
        XCTAssertEqual(PortfolioFreshnessPolicy.ageText(since: now.addingTimeInterval(-7_300), now: now), "2h")
        XCTAssertEqual(PortfolioFreshnessPolicy.ageText(since: now.addingTimeInterval(-700), now: now), "11m")
    }

    func testNonSelectedWalletsRefreshAtMostOnceAMinute() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertTrue(PortfolioFreshnessPolicy.isDue(lastAttempt: nil, now: now))
        XCTAssertFalse(PortfolioFreshnessPolicy.isDue(lastAttempt: now.addingTimeInterval(-59), now: now))
        XCTAssertTrue(PortfolioFreshnessPolicy.isDue(lastAttempt: now.addingTimeInterval(-60), now: now))
    }
}
