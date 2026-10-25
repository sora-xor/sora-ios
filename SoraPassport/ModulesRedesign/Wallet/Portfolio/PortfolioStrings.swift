// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// User-facing text of the portfolio. Keys are the English text (`en.lproj/Localizable.strings`);
/// other languages fall back to English, as the app's other new surfaces do (`WalletUX.text`).
enum PortfolioStrings {
    static func text(_ key: String) -> String { WalletUX.text(key) }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: WalletUX.text(key), arguments: arguments)
    }

    static func count(_ count: Int, one: String, other: String) -> String {
        format(count == 1 ? one : other, count)
    }

    /// Eyebrows and state chips are uppercase at the call site, so translations stay natural.
    static func upper(_ value: String) -> String {
        value.uppercased(with: PortfolioFormat.locale)
    }

    // MARK: Hero

    static var portfolio: String { text("Portfolio") }
    static var allWallets: String { text("All wallets") }
    static var wallets: String { text("Wallets") }
    static var totalBalance: String { upper(text("Total balance")) }
    static var live: String { upper(text("Live")) }
    static var saved: String { upper(text("Saved")) }
    static var partial: String { upper(text("Partial")) }
    static var offline: String { upper(text("Offline")) }
    static var walletReady: String { text("Your wallet is ready.") }
    static var walletReadyDetail: String { text("Receive tokens on SORA2 to see them here.") }
    static var howWeCount: String { text("How we count your balance") }
    static var other: String { text("Other") }
    static var hours24: String { text("24h") }

    static func notIncluded(hidden: Int, unpriced: Int, testnet: Int) -> String? {
        var parts: [String] = []
        if hidden > 0 { parts.append(format("%d hidden", hidden)) }
        if unpriced > 0 { parts.append(format("%d unpriced", unpriced)) }
        if testnet > 0 { parts.append(format("%d testnet", testnet)) }
        guard !parts.isEmpty else { return nil }
        return format("%@ not included", parts.joined(separator: ", "))
    }

    // MARK: Lenses and rows

    static var tokens: String { text("Tokens") }
    static var networks: String { text("Networks") }

    static func lensTitle(_ lens: PortfolioLens) -> String {
        switch lens {
        case .tokens: return tokens
        case .networks: return networks
        case .wallets: return wallets
        }
    }

    static func networksCount(_ count: Int) -> String { self.count(count, one: "%d network", other: "%d networks") }
    static func walletsCount(_ count: Int) -> String { self.count(count, one: "%d wallet", other: "%d wallets") }
    static func holdingsCount(_ count: Int) -> String { self.count(count, one: "%d holding", other: "%d holdings") }
    static func tokensCount(_ count: Int) -> String { self.count(count, one: "%d token", other: "%d tokens") }
    static func openAlone(_ wallet: String) -> String { format("Open %@ alone", wallet) }
    static func openNetwork(_ network: String) -> String { format("Open %@", network) }
    static var noPrice: String { text("No price") }
    static var noBalanceYet: String { text("No balance yet") }
    static var readingBalances: String { text("Reading balances…") }

    /// "SORA2", "SORA Nexus" or "Taira", as every network list in the app names them (never translated).
    static func networkName(_ network: PortfolioNetwork) -> String {
        WalletNetworkDirectory.current.info(network.networkId).name
    }

    /// "Address ready": a network that is not live yet only has an address to copy.
    static var addressReady: String { text("Address ready") }
    static var otherNetworksTitle: String { text("XOR on other networks") }

    // MARK: Readiness

    static var swapReady: String { text("Swap-ready") }
    static var swapOnPolkaswap: String { text("Swap on Polkaswap") }
    static var openPolkaswap: String { text("Open Polkaswap") }
    static var polkaswapRunsOnSora2: String { text("Polkaswap swaps run on SORA2.") }
    static func noRoute(from network: String) -> String { format("There is no route from %@ in this version.", network) }
    static var receiveOnSora2: String { text("Receive on SORA2") }
    static var testnetNoValue: String { text("Testnet assets have no monetary value.") }
    static var readyOnSora2: String { text("On SORA2. You can swap it on Polkaswap now.") }
    static var notListed: String { text("This token is not listed on Polkaswap.") }

    // MARK: Where it lives

    static var whereItLives: String { text("Where it lives") }
    static var transferable: String { text("Transferable") }
    static var locked: String { text("Locked") }
    static var totalCounted: String { text("Total counted") }
    static func shareOfScope(_ share: String, allWallets: Bool) -> String {
        allWallets ? format("%@ of all wallets", share) : format("%@ of this wallet", share)
    }

    // MARK: Actions

    static var send: String { text("Send") }
    static var receive: String { text("Receive") }
    static var move: String { text("Move") }
    static var swap: String { text("Swap") }
    static func moveToken(_ symbol: String) -> String { format("Move %@", symbol) }
    static func swapToken(_ symbol: String) -> String { format("Swap %@", symbol) }
    static var reviewInSend: String { text("Review in Send") }
    static func switchAndReview(_ wallet: String) -> String { format("Switch to %@ and review", wallet) }
    static func switchNote(_ wallet: String) -> String { format("This is in %@. We switch to it first.", wallet) }
    static var from: String { upper(text("From")) }
    static var to: String { upper(text("To")) }
    static var youPay: String { upper(text("You pay")) }
    static var youGet: String { upper(text("You get")) }
    static var amount: String { text("Amount") }
    static var max: String { text("Max") }
    static var priceFeeImpact: String { text("Polkaswap shows price, fee and impact before you sign.") }
    static var moveExplainer: String {
        text("Moves between your own wallets use Send. You review the fee and sign there.")
    }
    static func whichWallet(for action: String) -> String { format("%@ from which wallet?", action) }

    // MARK: Unavailable reasons

    static var reasonNoOtherWallet: String { text("You have no other wallet on this network.") }
    static var reasonNothingTransferable: String { text("Nothing here can move right now.") }
    static func reasonNotLive(_ network: String) -> String { format("%@ is not live yet.", network) }
    static func reasonNetworkUnavailable(_ network: String) -> String {
        format("%@ is not available for this wallet right now.", network)
    }
    static var reasonNotTradable: String { notListed }
    static var reasonSwapsOnSora2: String { polkaswapRunsOnSora2 }
}
