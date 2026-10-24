// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

#if !F_RELEASE
import Foundation

/// Debug-only sample portfolio: three wallets on SORA2, Minamoto and Taira with priced and
/// unpriced assets, so a fresh simulator can show the dashboard without real funds. Every number
/// and name is invented. Not compiled into App Store builds (`F_RELEASE`).
enum PortfolioSampleData {
    enum Variant: String {
        case full
        case empty
        case partial
        case offline
        /// The first read still running.
        case loading
    }

    /// Valid SORA2 address format (identicons need one), derived from the public keys 0x11..11,
    /// 0x22..22 and 0x33..33. Nobody holds their keys: hand-offs that would send to them stay off
    /// in sample mode (`PortfolioCoordinator`).
    static let mainId = "cnRsfMpGQ24tCKDLBbwde6NrS9ttrXN3hjX3zMHnVDeQokoBA"
    static let savingsId = "cnSG3F5hh3Z5JzV2Qzn6Ez71CL8NUTi68wr9zrjdNedrJht1C"
    static let tradingId = "cnSeR8M8z53GRfkiePcYqsq9xWMr6Q48aABG1NBUG5dHof6xY"

    struct Asset {
        let id: String
        let symbol: String
        let name: String
        let price: Decimal?
        let change: Decimal?
        let swappable: Bool
    }

    static let xor = Asset(id: "0x0200000000000000000000000000000000000000000000000000000000000000",
                           symbol: "XOR", name: "SORA", price: Decimal(string: "0.0042"),
                           change: Decimal(string: "3.4"), swappable: true)
    static let val = Asset(id: "0x0200040000000000000000000000000000000000000000000000000000000000",
                           symbol: "VAL", name: "SORA Validator Token", price: Decimal(string: "0.0215"),
                           change: Decimal(string: "2.2"), swappable: true)
    static let pswap = Asset(id: "0x0200050000000000000000000000000000000000000000000000000000000000",
                             symbol: "PSWAP", name: "Polkaswap", price: Decimal(string: "0.00052"),
                             change: Decimal(string: "-1.4"), swappable: true)
    static let xstusd = Asset(id: "0x0200080000000000000000000000000000000000000000000000000000000000",
                              symbol: "XSTUSD", name: "SORA Synthetic USD", price: Decimal(string: "1.0"),
                              change: Decimal(0), swappable: true)
    static let eth = Asset(id: "0x0200070000000000000000000000000000000000000000000000000000000000",
                           symbol: "ETH", name: "Ether", price: Decimal(string: "2410"),
                           change: Decimal(string: "2.7"), swappable: true)
    static let dai = Asset(id: "0x0200060000000000000000000000000000000000000000000000000000000000",
                           symbol: "DAI", name: "Dai", price: Decimal(string: "1.0"),
                           change: Decimal(string: "0.1"), swappable: true)
    static let kusd = Asset(id: "0x02000c0000000000000000000000000000000000000000000000000000000000",
                            symbol: "KUSD", name: "Kensetsu Dollar", price: Decimal(string: "0.98"),
                            change: Decimal(0), swappable: true)
    static let ceres = Asset(id: "0x008bcfd2387d3fc453333557eecb0efe59fcba128769b2feefdd306e98e66440",
                             symbol: "CERES", name: "Ceres", price: Decimal(string: "0.52"),
                             change: Decimal(string: "-0.8"), swappable: true)
    /// An airdropped token without a price and without a Polkaswap listing.
    static let meme = Asset(id: "0x00e7fa3a1e6d8c1f5e9b3c8f3b6a3a3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f70",
                            symbol: "MEME", name: "Airdropped token", price: nil, change: nil, swappable: false)

    /// - Parameter icon: the asset list icon for an asset id (the bundled whitelist in the app).
    static func snapshot(_ variant: Variant = .full, now: Date = Date(),
                         icon: (String) -> String? = { _ in nil }) -> PortfolioSnapshot {
        func token(_ asset: Asset) -> PortfolioToken {
            PortfolioToken(id: asset.id, symbol: asset.symbol, name: asset.name, icon: icon(asset.id),
                           priceUSD: asset.price, change24h: asset.change, isSwappable: asset.swappable)
        }
        func holding(_ wallet: String, _ network: PortfolioNetwork, _ asset: Asset, _ amount: String,
                     locked: String = "0", hidden: Bool = false) -> PortfolioHolding {
            let total = Decimal(string: amount) ?? 0
            let lockedAmount = Decimal(string: locked) ?? 0
            return PortfolioHolding(walletId: wallet, network: network, token: token(asset), amount: total,
                                    transferable: max(0, total - lockedAmount), isHidden: hidden)
        }

        let networks: [PortfolioNetwork] = [.sora2, .minamoto, .taira]
        let freshness: (PortfolioFreshness, PortfolioFreshness, PortfolioFreshness)
        switch variant {
        case .full, .empty, .loading:
            freshness = (.live(now.addingTimeInterval(-31)), .live(now.addingTimeInterval(-12)),
                         .live(now.addingTimeInterval(-18)))
        case .partial:
            freshness = (.live(now.addingTimeInterval(-31)), .partial(now.addingTimeInterval(-40), unreachable: [.sora2]),
                         .saved(now.addingTimeInterval(-7_200)))
        case .offline:
            freshness = (.offline, .offline, .offline)
        }

        func address(_ wallet: String, _ network: PortfolioNetwork) -> String {
            switch network {
            case .sora2: return wallet
            case .minamoto: return "sorau" + String(wallet.suffix(20)).lowercased()
            case .taira: return "testu" + String(wallet.suffix(20)).lowercased()
            }
        }
        func addresses(_ wallet: String, _ list: [PortfolioNetwork]) -> [PortfolioNetwork: String] {
            Dictionary(uniqueKeysWithValues: list.map { ($0, address(wallet, $0)) })
        }

        let wallets = [
            PortfolioWallet(id: mainId, name: "Main", isSelected: true, order: 0, networks: networks,
                            addresses: addresses(mainId, networks), freshness: freshness.0),
            PortfolioWallet(id: savingsId, name: "Savings", isSelected: false, order: 1,
                            networks: [.sora2, .minamoto], addresses: addresses(savingsId, [.sora2, .minamoto]),
                            freshness: freshness.1),
            PortfolioWallet(id: tradingId, name: "Trading", isSelected: false, order: 2,
                            networks: [.sora2, .taira], addresses: addresses(tradingId, [.sora2, .taira]),
                            freshness: freshness.2)
        ]

        let holdings: [PortfolioHolding]
        if variant == .empty || variant == .loading {
            holdings = []
        } else {
            holdings = [
                holding(mainId, .sora2, xor, "520000", locked: "8000"),
                holding(mainId, .sora2, val, "41000"),
                holding(mainId, .sora2, pswap, "1200000"),
                holding(mainId, .sora2, xstusd, "1250"),
                holding(mainId, .sora2, eth, "0.42"),
                holding(mainId, .sora2, dai, "300"),
                holding(mainId, .sora2, kusd, "50", hidden: true),
                holding(mainId, .sora2, meme, "1000000"),
                holding(mainId, .minamoto, xor, "30000"),
                holding(mainId, .taira, xor, "12500"),
                holding(savingsId, .sora2, xor, "1800000", locked: "250000"),
                holding(savingsId, .sora2, xstusd, "2000"),
                holding(savingsId, .sora2, eth, "0.3"),
                holding(savingsId, .sora2, val, "10000"),
                holding(savingsId, .minamoto, xor, "250000"),
                holding(tradingId, .sora2, pswap, "3000000"),
                holding(tradingId, .sora2, val, "60000"),
                holding(tradingId, .sora2, xor, "150000"),
                holding(tradingId, .sora2, ceres, "40"),
                holding(tradingId, .taira, xor, "4000")
            ]
        }

        return PortfolioSnapshot(wallets: wallets, holdings: holdings, networks: networks,
                                 swapsAvailable: true, swapDisclaimerAccepted: true,
                                 liveNetworks: [.sora2, .minamoto, .taira], isLoading: variant == .loading)
    }
}
#endif
