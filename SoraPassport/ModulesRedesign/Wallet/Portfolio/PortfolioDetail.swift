// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// "Where it lives": one token across wallets and networks.
struct PortfolioDetailModel: Equatable {
    struct Satellite: Equatable {
        let network: PortfolioNetwork
        let amount: String
        /// Relative size by amount, 0...1.
        let weight: Double
        /// Solid pink link to Polkaswap when the holding there is Swap-ready, dotted otherwise.
        let isSwapReady: Bool
        let isTestnet: Bool
        /// The network's largest holding: tapping the satellite selects it.
        let holdingId: String
    }

    struct Holding: Equatable {
        let id: String
        let network: PortfolioNetwork
        let walletName: String
        let walletSlot: PortfolioSlot?
        let amount: String
        let value: String
        let tag: PortfolioTag?
        let isSelected: Bool
        let accessibilityLabel: String
    }

    struct Action: Equatable {
        let kind: PortfolioActionPlan.Action
        let title: String
        let isEnabled: Bool
        let reason: String?
    }

    struct Route: Equatable {
        enum Style: Equatable {
            case ready
            case notListed
            case noRoute
            case test
        }

        let network: PortfolioNetwork
        let style: Style
        let text: String
    }

    struct Panel: Equatable {
        let holdingId: String
        let transferable: String
        let locked: String
        let total: String
        /// Transferable part of the bar, 0...1.
        let transferableFraction: Double
        let route: Route
        let primary: Action
        let secondary: [Action]
        /// "This is in Savings. We switch to it first." for a wallet that is not selected.
        let switchNote: String?
    }

    struct Check: Equatable {
        let text: String
        let isMet: Bool
    }

    struct PolkaswapCard: Equatable {
        /// The SORA2 holding the card is about: the selected one when it is on SORA2, else the largest.
        let holdingId: String?
        let checks: [Check]
        let action: Action
    }

    let tokenId: String
    let symbol: String
    let name: String
    let icon: PortfolioIcon
    let amount: String
    let value: String
    let change: String?
    let direction: PortfolioChangeDirection
    let share: String
    let counts: String
    let satellites: [Satellite]
    let holdings: [Holding]
    let panel: Panel?
    let polkaswap: PolkaswapCard
}

enum PortfolioDetailPresenter {
    static func model(tokenId: String, selectedHoldingId: String?, snapshot: PortfolioSnapshot,
                      scope: PortfolioScope, walletSlots: [String: PortfolioSlot]) -> PortfolioDetailModel? {
        let holdings = PortfolioAggregator.holdings(ofToken: tokenId, in: snapshot, scope: scope)
        guard let first = holdings.first else { return nil }
        let token = holdings.first { $0.network == .sora2 }?.token ?? first.token
        let group = PortfolioAggregator.groups(snapshot, scope: scope, lens: .tokens).first { $0.key == tokenId }
        let selectedId = holdings.contains { $0.id == selectedHoldingId } ? selectedHoldingId : first.id

        let networks = PortfolioNetwork.ordered(Array(Set(holdings.map(\.network))), directory: snapshot.directory)
        let maxAmount = networks.map { network in
            holdings.filter { $0.network == network }.reduce(Decimal(0)) { $0 + $1.amount }
        }.max() ?? 1
        let satellites = networks.map { network -> PortfolioDetailModel.Satellite in
            let members = holdings.filter { $0.network == network }
            let amount = members.reduce(Decimal(0)) { $0 + $1.amount }
            let ready = members.contains {
                PortfolioReadiness.evaluate($0, swapsAvailable: snapshot.swapsAvailable) == .ready
            }
            let weight = maxAmount > 0 ? NSDecimalNumber(decimal: amount / maxAmount).doubleValue : 0
            return .init(network: network, amount: PortfolioFormat.amount(amount), weight: weight,
                         isSwapReady: ready, isTestnet: network.isTestnet, holdingId: members[0].id)
        }

        let rows = holdings.map { holding -> PortfolioDetailModel.Holding in
            let wallet = snapshot.wallet(holding.walletId)?.name ?? ""
            let amount = PortfolioFormat.amount(holding.amount, symbol: holding.token.symbol)
            let value = PortfolioPresenter.holdingValueText(holding)
            let network = PortfolioStrings.networkName(holding.network)
            return .init(id: holding.id, network: holding.network, walletName: wallet,
                         walletSlot: walletSlots[holding.walletId], amount: amount, value: value,
                         tag: PortfolioPresenter.tag(for: holding, snapshot: snapshot),
                         isSelected: holding.id == selectedId,
                         accessibilityLabel: "\(network), \(wallet), \(amount), \(value)")
        }

        let panel = holdings.first { $0.id == selectedId }.map { panel(for: $0, snapshot: snapshot) }
        let amount = group?.tokenAmount ?? first.amount
        let value = PortfolioPresenter.valueText(of: holdings)
        let share = PortfolioStrings.shareOfScope(PortfolioFormat.share(group?.share ?? 0),
                                                  allWallets: scope == .allWallets)
        let counts = PortfolioStrings.upper(PortfolioStrings.holdingsCount(holdings.count)) + " · " +
            PortfolioStrings.upper(PortfolioStrings.networksCount(networks.count))

        return PortfolioDetailModel(tokenId: tokenId, symbol: token.symbol, name: token.name,
                                    icon: .token(id: token.id, symbol: token.symbol, icon: token.icon),
                                    amount: PortfolioFormat.amount(amount, symbol: token.symbol),
                                    value: value, change: PortfolioPresenter.changeText(token.change24h),
                                    direction: PortfolioPresenter.direction(of: token.change24h),
                                    share: share, counts: counts, satellites: satellites, holdings: rows,
                                    panel: panel,
                                    polkaswap: polkaswapCard(holdings: holdings, selectedId: selectedId, snapshot: snapshot))
    }

    static func panel(for holding: PortfolioHolding, snapshot: PortfolioSnapshot) -> PortfolioDetailModel.Panel {
        let readiness = PortfolioReadiness.evaluate(holding, swapsAvailable: snapshot.swapsAvailable)
        let network = PortfolioStrings.networkName(holding.network)
        let otherWallets = snapshot.wallets.filter { $0.id != holding.walletId && $0.networks.contains(holding.network) }
        let plan = PortfolioActionPlan.plan(for: holding, readiness: readiness,
                                            otherWalletsOnNetwork: otherWallets.count,
                                            networkIsLive: snapshot.liveNetworks.contains(holding.network))
        let route: PortfolioDetailModel.Route
        switch readiness {
        case .ready:
            route = .init(network: holding.network, style: .ready, text: PortfolioStrings.readyOnSora2)
        case .notTradable:
            route = .init(network: holding.network, style: .notListed, text: PortfolioStrings.notListed)
        case let .noRoute(source):
            route = .init(network: source, style: .noRoute,
                          text: PortfolioStrings.polkaswapRunsOnSora2 + " " +
                              PortfolioStrings.noRoute(from: PortfolioStrings.networkName(source)))
        case .test:
            route = .init(network: holding.network, style: .test, text: PortfolioStrings.testnetNoValue)
        }
        let symbol = holding.token.symbol
        let total = holding.amount
        let fraction = total > 0 ? NSDecimalNumber(decimal: holding.transferable / total).doubleValue : 0
        let wallet = snapshot.wallet(holding.walletId)
        let switchNote = wallet?.isSelected == false ? PortfolioStrings.switchNote(wallet?.name ?? "") : nil
        return .init(holdingId: holding.id,
                     transferable: PortfolioFormat.amount(holding.transferable, symbol: symbol),
                     locked: PortfolioFormat.amount(holding.locked, symbol: symbol),
                     total: PortfolioFormat.amount(total, symbol: symbol),
                     transferableFraction: min(1, max(0, fraction)),
                     route: route,
                     primary: action(plan.primary, network: network, symbol: symbol),
                     secondary: plan.secondary.map { action($0, network: network, symbol: symbol) },
                     switchNote: switchNote)
    }

    static func action(_ entry: PortfolioActionPlan.Entry, network: String, symbol: String) -> PortfolioDetailModel.Action {
        let title: String
        switch entry.action {
        case .swap: title = PortfolioStrings.swapOnPolkaswap
        case .send: title = PortfolioStrings.send
        case .move: title = PortfolioStrings.move
        case .receiveOnSora2: title = PortfolioStrings.receiveOnSora2
        }
        return .init(kind: entry.action, title: title, isEnabled: entry.unavailableReason == nil,
                     reason: entry.unavailableReason.map { reason(for: $0) })
    }

    static func reason(for reason: PortfolioActionPlan.UnavailableReason) -> String {
        switch reason {
        case .swapsRunOnSora2: return PortfolioStrings.reasonSwapsOnSora2
        case .notTradable: return PortfolioStrings.reasonNotTradable
        case .noOtherWallet: return PortfolioStrings.reasonNoOtherWallet
        case let .networkNotLive(network): return PortfolioStrings.reasonNotLive(PortfolioStrings.networkName(network))
        case .nothingTransferable: return PortfolioStrings.reasonNothingTransferable
        }
    }

    static func polkaswapCard(holdings: [PortfolioHolding], selectedId: String?,
                              snapshot: PortfolioSnapshot) -> PortfolioDetailModel.PolkaswapCard {
        let sora2 = holdings.first { $0.id == selectedId && $0.network == .sora2 } ?? holdings.first { $0.network == .sora2 }
        let walletName = sora2.flatMap { snapshot.wallet($0.walletId)?.name } ??
            snapshot.selectedWallet?.name ?? ""
        let checks: [PortfolioDetailModel.Check] = [
            .init(text: PortfolioStrings.format("SORA2 account in %@", walletName), isMet: true),
            .init(text: PortfolioStrings.text("Polkaswap is available in this version"), isMet: snapshot.swapsAvailable),
            .init(text: snapshot.swapDisclaimerAccepted
                    ? PortfolioStrings.text("Polkaswap disclaimer accepted")
                    : PortfolioStrings.text("You see the Polkaswap disclaimer before your first swap"),
                  isMet: snapshot.swapDisclaimerAccepted)
        ]
        let ready = sora2.map { PortfolioReadiness.evaluate($0, swapsAvailable: snapshot.swapsAvailable) == .ready } ?? false
        let action = PortfolioDetailModel.Action(
            kind: ready ? .swap : .receiveOnSora2,
            title: ready ? PortfolioStrings.openPolkaswap : PortfolioStrings.receiveOnSora2,
            isEnabled: true,
            reason: ready ? nil : (sora2 == nil ? PortfolioStrings.polkaswapRunsOnSora2 : PortfolioStrings.notListed)
        )
        return .init(holdingId: sora2?.id, checks: checks, action: action)
    }
}
