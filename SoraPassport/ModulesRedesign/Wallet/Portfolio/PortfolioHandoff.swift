// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// The amount the Move sheet hands to Send.
enum PortfolioAmountChoice: Equatable {
    case exact(Decimal)
    case max
}

/// A hand-off into a flow the app already has. The dashboard never builds or signs a transaction.
enum PortfolioHandoff: Equatable {
    /// The selected wallet's Send. With a token, recipient or amount: SORA2's Send prefilled.
    /// Without: the Wallet tab's own Send, which asks for the network when there is a choice.
    case send(assetId: String?, recipient: String?, amount: PortfolioAmountChoice?)
    /// The Wallet tab's own Receive, which asks for the network when there is a choice.
    case receive
    /// Receive on SORA2, without a network choice ("Receive on SORA2").
    case receiveOnSora2
    case swap(from: String, to: String)
    /// The selected wallet's page on a network other than SORA2 (balance, address, activity), with
    /// its Send started when `send`.
    case network(PortfolioNetwork, send: Bool)

    /// Send without anything to prefill: the network choice belongs to the Wallet tab.
    var isPlainSend: Bool {
        if case .send(nil, nil, nil) = self { return true }
        return false
    }
}

/// A hand-off waiting for an account switch: the rebuilt Wallet tab picks it up once the wallet it
/// belongs to is the selected one. It expires after a minute and is never carried to another wallet.
final class PortfolioHandoffInbox {
    static let shared = PortfolioHandoffInbox()
    static let lifetime: TimeInterval = 60

    private var pending: (walletId: String, handoff: PortfolioHandoff, date: Date, id: UUID)?

    @discardableResult
    func put(_ handoff: PortfolioHandoff, walletId: String, now: Date = Date()) -> UUID {
        let id = UUID()
        pending = (walletId, handoff, now, id)
        return id
    }

    @discardableResult
    func clear(ifCurrent id: UUID) -> Bool {
        guard pending?.id == id else { return false }
        pending = nil
        return true
    }

    func clear() {
        pending = nil
    }

    func take(selectedWalletId: String?, now: Date = Date()) -> PortfolioHandoff? {
        guard let pending else { return nil }
        guard now.timeIntervalSince(pending.date) <= Self.lifetime else {
            self.pending = nil
            return nil
        }
        guard let selectedWalletId, selectedWalletId == pending.walletId else { return nil }
        self.pending = nil
        return pending.handoff
    }
}
