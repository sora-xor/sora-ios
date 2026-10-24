// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// The app's existing Send, Receive, Swap and network screens, for the selected wallet.
@MainActor
protocol PortfolioHandoffRouting: AnyObject {
    /// The Wallet tab's Send: the network choice when there is one, then that network's Send.
    func showSend(from controller: UIViewController)
    /// SORA2's Send with the token, the recipient and the amount filled in.
    func showSora2Send(from controller: UIViewController, assetId: String?, recipient: String?,
                       amount: PortfolioAmountChoice?)
    /// The Wallet tab's Receive: the network choice when there is one.
    func showReceive(from controller: UIViewController)
    func showSora2Receive(from controller: UIViewController)
    func showSwap(from controller: UIViewController, fromAssetId: String, toAssetId: String)
    /// The selected wallet's page on a network other than SORA2; false when it cannot open
    /// (no account there, or the network is off in this build or the settings).
    func showNetwork(_ network: PortfolioNetwork, send: Bool, from controller: UIViewController) -> Bool
    /// The app's account list (add, import, rename, select).
    func showManageWallets(from controller: UIViewController)
}

/// Switches the selected wallet the way the account picker does.
@MainActor
protocol PortfolioAccountSwitching: AnyObject {
    var selectedWalletId: String? { get }
    func switchTo(walletId: String, completion: @escaping (Bool) -> Void)
}

/// Presents the dashboard's sheets and screens and runs the hand-offs.
@MainActor
final class PortfolioCoordinator {
    weak var host: UIViewController?
    let viewModel: PortfolioViewModel
    private let router: PortfolioHandoffRouting
    private let switcher: PortfolioAccountSwitching
    private let inbox: PortfolioHandoffInbox
    private let asset: (String) -> (symbol: String, icon: String?)?
    private weak var detail: PortfolioDetailViewController?

    static let swapTargets = [
        "0x0200000000000000000000000000000000000000000000000000000000000000", // XOR
        "0x0200040000000000000000000000000000000000000000000000000000000000", // VAL
        "0x0200050000000000000000000000000000000000000000000000000000000000", // PSWAP
        "0x0200080000000000000000000000000000000000000000000000000000000000"  // XSTUSD
    ]

    init(viewModel: PortfolioViewModel, router: PortfolioHandoffRouting, switcher: PortfolioAccountSwitching,
         inbox: PortfolioHandoffInbox = .shared,
         asset: @escaping (String) -> (symbol: String, icon: String?)?) {
        self.viewModel = viewModel
        self.router = router
        self.switcher = switcher
        self.inbox = inbox
        self.asset = asset
        viewModel.onRoute = { [weak self] route in self?.handle(route) }
    }

    /// The numbers changed: an open Where it lives follows them.
    func renderDidChange() {
        detail?.reload()
    }

    private var presenter: UIViewController? {
        guard let host else { return nil }
        var top: UIViewController = host.navigationController ?? host
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    func handle(_ route: PortfolioRoute) {
        switch route {
        case .walletsSheet: showWallets()
        case let .tokenDetail(tokenId, holdingId): showDetail(tokenId: tokenId, holdingId: holdingId)
        case .howWeCount: showHowWeCount()
        case let .partial(networks): showFreshness(networks)
        case let .quickAction(action): quickAction(action)
        }
    }

    // MARK: Wallets

    func showWallets() {
        guard let presenter else { return }
        let snapshot = viewModel.snapshot
        let now = Date()
        let all = PortfolioAggregator.summary(snapshot, scope: .allWallets)
        var entries: [PortfolioWalletsSheet.Entry] = [
            .init(scope: .allWallets, icon: .allWallets, title: PortfolioStrings.allWallets,
                  subtitle: PortfolioStrings.format("%d wallets together", snapshot.wallets.count),
                  value: PortfolioFormat.fiat(all.total),
                  detail: all.changePercent.map { PortfolioFormat.signedPercent($0) + " " + PortfolioStrings.hours24 } ?? "")
        ]
        for wallet in snapshot.wallets.sorted(by: { $0.order < $1.order }) {
            let summary = PortfolioAggregator.summary(snapshot, scope: .wallet(wallet.id))
            let freshness = PortfolioPresenter.chip(wallet.freshness, now: now).text
            entries.append(.init(scope: .wallet(wallet.id), icon: .wallet(id: wallet.id, name: wallet.name),
                                 title: wallet.name,
                                 subtitle: PortfolioStrings.networksCount(wallet.networks.count) + " · " + freshness,
                                 value: PortfolioFormat.fiat(summary.total),
                                 detail: summary.changePercent.map {
                                     PortfolioFormat.signedPercent($0) + " " + PortfolioStrings.hours24
                                 } ?? ""))
        }
        let sheet = PortfolioWalletsSheet(title: PortfolioStrings.wallets)
        sheet.entries = entries
        sheet.selected = viewModel.state.scope
        sheet.onSelect = { [weak self, weak sheet] scope in
            self?.viewModel.selectScope(scope)
            sheet?.dismiss(animated: true)
        }
        sheet.onRefresh = { [weak self, weak sheet] in
            self?.viewModel.refreshAll()
            sheet?.dismiss(animated: true)
        }
        sheet.onManage = { [weak self, weak sheet] in
            sheet?.dismiss(animated: true) {
                guard let self, let presenter = self.presenter else { return }
                self.router.showManageWallets(from: presenter)
            }
        }
        sheet.present(from: presenter)
    }

    /// "Open Taira" under an expanded network row: the selected wallet's page on that network, as
    /// the Wallet tab's network rows open it.
    func openNetwork(_ network: PortfolioNetwork) {
        guard let presenter else { return }
        if viewModel.isSample {
            showMessage(PortfolioStrings.text("Sample data: network pages show the real selected wallet."))
            return
        }
        if !router.showNetwork(network, send: false, from: presenter) {
            showMessage(PortfolioStrings.reasonNetworkUnavailable(PortfolioStrings.networkName(network)))
        }
    }

    // MARK: Where it lives

    func showDetail(tokenId: String, holdingId: String?) {
        guard let navigation = host?.navigationController else { return }
        let detail = PortfolioDetailViewController(tokenId: tokenId, holdingId: holdingId) { [weak self] token, holding in
            self?.viewModel.detailModel(tokenId: token, holdingId: holding)
        }
        detail.onAction = { [weak self] action, holdingId in self?.detailAction(action, holdingId: holdingId) }
        detail.onPolkaswap = { [weak self] holdingId in
            guard let self else { return }
            if let holdingId { self.showSwap(holdingId: holdingId) }
        }
        self.detail = detail
        navigation.pushViewController(detail, animated: true)
    }

    func detailAction(_ action: PortfolioActionPlan.Action, holdingId: String) {
        guard let holding = viewModel.holding(holdingId) else { return }
        switch action {
        case .swap: showSwap(holdingId: holdingId)
        case .move: showMove(holdingId: holdingId)
        case .send:
            switch holding.network {
            case .sora2:
                perform(.send(assetId: holding.token.id, recipient: nil, amount: nil), walletId: holding.walletId)
            case .minamoto, .taira:
                perform(.network(holding.network, send: true), walletId: holding.walletId)
            }
        case .receiveOnSora2:
            perform(.receiveOnSora2, walletId: holding.walletId)
        }
    }

    // MARK: Info

    func showHowWeCount() {
        guard let presenter else { return }
        let summary = PortfolioAggregator.summary(viewModel.snapshot, scope: viewModel.state.scope)
        let sheet = PortfolioInfoSheet(title: PortfolioStrings.howWeCount)
        sheet.paragraphs = [
            PortfolioStrings.text("The total counts the visible, priced tokens on mainnet networks. Each token is its total balance times that token's own price."),
            PortfolioStrings.text("All wallets adds each wallet's own total. The rows always add up to the total.")
        ]
        var bullets: [String] = []
        if summary.hiddenCount > 0 {
            bullets.append(PortfolioStrings.format("%d hidden: tokens you hid in a wallet's asset list.", summary.hiddenCount))
        }
        if summary.unpricedCount > 0 {
            bullets.append(PortfolioStrings.format("%d unpriced: there is no price for them, so they cannot be counted.",
                                                   summary.unpricedCount))
        }
        if summary.testnetCount > 0 {
            bullets.append(PortfolioStrings.format("%d testnet: Taira test tokens have no monetary value.",
                                                   summary.testnetCount))
        }
        sheet.bullets = bullets
        sheet.present(from: presenter)
    }

    func showFreshness(_ networks: [PortfolioNetwork]) {
        guard let presenter else { return }
        let sheet = PortfolioInfoSheet(title: PortfolioStrings.text("Balances"))
        if networks.isEmpty {
            sheet.paragraphs = [PortfolioStrings.text("Some wallets could not be refreshed. Their numbers are the last ones read, and each wallet shows how old they are.")]
        } else {
            let names = networks.map(PortfolioStrings.networkName).joined(separator: ", ")
            // A wallet read before keeps its last numbers in the total; one never read has none yet.
            let summary = PortfolioAggregator.summary(viewModel.snapshot, scope: viewModel.state.scope)
            sheet.paragraphs = [summary.freshness.updatedAt == nil
                ? PortfolioStrings.format("%@ could not be reached. Its value is not in the total until it is read again.", names)
                : PortfolioStrings.format("%@ could not be reached on the last try. Its numbers are the last ones read.", names)]
        }
        sheet.buttonTitle = PortfolioStrings.text("Try again")
        sheet.onButton = { [weak self, weak sheet] in
            self?.viewModel.refreshAll()
            sheet?.dismiss(animated: true)
        }
        sheet.present(from: presenter)
    }

    // MARK: Quick actions

    func quickAction(_ action: PortfolioQuickAction) {
        switch action {
        case .send, .receive:
            let wallets = viewModel.walletsForPicker
            if wallets.count == 1, let wallet = wallets.first {
                perform(action == .send ? .send(assetId: nil, recipient: nil, amount: nil) : .receive, walletId: wallet.id)
                return
            }
            showWalletPicker(for: action, wallets: wallets)
        case .move:
            pickHolding(viewModel.movableHoldings, title: PortfolioStrings.move) { [weak self] id in self?.showMove(holdingId: id) }
        case .swap:
            pickHolding(viewModel.swappableHoldings, title: PortfolioStrings.swap) { [weak self] id in self?.showSwap(holdingId: id) }
        }
    }

    private func showWalletPicker(for action: PortfolioQuickAction, wallets: [PortfolioWallet]) {
        guard let presenter else { return }
        let title = action == .send ? PortfolioStrings.send : PortfolioStrings.receive
        let sheet = PortfolioPickerSheet(title: PortfolioStrings.whichWallet(for: title))
        let snapshot = viewModel.snapshot
        sheet.options = wallets.map { wallet in
            let total = PortfolioAggregator.walletTotal(wallet.id, in: snapshot)
            return .init(id: wallet.id, icon: .wallet(id: wallet.id, name: wallet.name), title: wallet.name,
                         subtitle: PortfolioFormat.shortAddress(wallet.id), value: PortfolioFormat.fiat(total), detail: nil)
        }
        sheet.onPick = { [weak self, weak sheet] walletId in
            sheet?.dismiss(animated: true) {
                self?.perform(action == .send ? .send(assetId: nil, recipient: nil, amount: nil) : .receive,
                              walletId: walletId)
            }
        }
        sheet.present(from: presenter)
    }

    private func pickHolding(_ holdings: [PortfolioHolding], title: String, open: @escaping (String) -> Void) {
        guard let presenter else { return }
        if holdings.count == 1, let holding = holdings.first {
            open(holding.id)
            return
        }
        let snapshot = viewModel.snapshot
        let sheet = PortfolioPickerSheet(title: title)
        if holdings.isEmpty {
            sheet.note = PortfolioStrings.text("Nothing here can do that right now.")
        }
        sheet.options = holdings.prefix(12).map { holding in
            let wallet = snapshot.wallet(holding.walletId)?.name ?? ""
            return .init(id: holding.id,
                         icon: .token(id: holding.token.id, symbol: holding.token.symbol, icon: holding.token.icon),
                         title: holding.token.symbol,
                         subtitle: PortfolioStrings.networkName(holding.network) + " · " + wallet,
                         value: PortfolioPresenter.holdingValueText(holding),
                         detail: PortfolioFormat.amount(holding.transferable, symbol: holding.token.symbol))
        }
        sheet.onPick = { [weak sheet] id in
            sheet?.dismiss(animated: true) { open(id) }
        }
        sheet.present(from: presenter)
    }

    // MARK: Move and Swap

    func showMove(holdingId: String) {
        guard let presenter, let holding = viewModel.holding(holdingId) else { return }
        let snapshot = viewModel.snapshot
        let source = snapshot.wallet(holding.walletId)
        let sheet = PortfolioMoveSheet(title: PortfolioStrings.moveToken(holding.token.symbol))
        sheet.holding = holding
        sheet.sourceWalletName = source?.name ?? ""
        sheet.sourceIsSelected = holding.walletId == effectiveSelectedWalletId
        sheet.destinations = snapshot.wallets
            .filter { $0.id != holding.walletId && $0.networks.contains(holding.network) }
            .sorted { $0.order < $1.order }
            .compactMap { wallet in
                guard let address = wallet.addresses[holding.network] else { return nil }
                return .init(walletId: wallet.id, name: wallet.name, address: address)
            }
        if !snapshot.liveNetworks.contains(holding.network) {
            sheet.availability = .unavailable(PortfolioStrings.reasonNotLive(PortfolioStrings.networkName(holding.network)))
        } else if sheet.destinations.isEmpty {
            sheet.availability = .unavailable(PortfolioStrings.reasonNoOtherWallet)
        } else {
            sheet.availability = holding.network == .sora2 ? .send : .nexusSend
        }
        sheet.onCopyAddress = { address in UIPasteboard.general.string = address }
        sheet.onReview = { [weak self, weak sheet] destination, amount in
            sheet?.dismiss(animated: true) {
                guard let self else { return }
                // The sheet already said "Switch to … and review" for another wallet.
                if holding.network == .sora2 {
                    self.perform(.send(assetId: holding.token.id, recipient: destination.address, amount: amount),
                                 walletId: holding.walletId, confirmed: true)
                } else {
                    self.perform(.network(holding.network, send: true), walletId: holding.walletId, confirmed: true)
                }
            }
        }
        sheet.present(from: presenter)
    }

    func showSwap(holdingId: String) {
        guard let presenter, let holding = viewModel.holding(holdingId) else { return }
        let snapshot = viewModel.snapshot
        let walletName = snapshot.wallet(holding.walletId)?.name ?? ""
        let sheet = PortfolioSwapSheet(title: PortfolioStrings.swapToken(holding.token.symbol))
        sheet.holding = holding
        sheet.walletName = walletName
        sheet.isSelectedWallet = holding.walletId == effectiveSelectedWalletId
        sheet.targets = Self.swapTargets.filter { $0 != holding.token.id }.compactMap { id in
            if let token = snapshot.holdings.first(where: { $0.token.id == id })?.token {
                return .init(id: id, symbol: token.symbol, icon: token.icon)
            }
            return asset(id).map { .init(id: id, symbol: $0.symbol, icon: $0.icon) }
        }
        sheet.checks = PortfolioDetailPresenter.polkaswapCard(holdings: [holding], selectedId: holding.id,
                                                              snapshot: snapshot).checks
        sheet.onOpen = { [weak self, weak sheet] target in
            sheet?.dismiss(animated: true) {
                self?.perform(.swap(from: holding.token.id, to: target.id), walletId: holding.walletId, confirmed: true)
            }
        }
        sheet.onReceiveOnSora2 = { [weak self, weak sheet] in
            sheet?.dismiss(animated: true) { self?.perform(.receiveOnSora2, walletId: holding.walletId) }
        }
        sheet.present(from: presenter)
    }

    // MARK: Hand-off

    /// The wallet the portfolio treats as selected: the real one, or the sample's own.
    private var effectiveSelectedWalletId: String? {
        viewModel.isSample ? viewModel.snapshot.selectedWallet?.id : switcher.selectedWalletId
    }

    /// Runs a hand-off for a wallet. Another wallet is switched to first, after the user has seen
    /// "This is in {wallet}. We switch to it first." (`confirmed` when a sheet already said so).
    func perform(_ handoff: PortfolioHandoff, walletId: String, confirmed: Bool = false) {
        if viewModel.isSample {
            performSample(handoff, walletId: walletId)
            return
        }
        if walletId == switcher.selectedWalletId {
            run(handoff)
            return
        }
        if confirmed {
            switchAndRun(handoff, walletId: walletId)
            return
        }
        guard let presenter, let wallet = viewModel.snapshot.wallet(walletId) else { return }
        let sheet = PortfolioSwitchSheet(title: PortfolioStrings.text("Switch wallet"))
        sheet.walletName = wallet.name
        sheet.walletIcon = .wallet(id: wallet.id, name: wallet.name)
        sheet.onConfirm = { [weak self, weak sheet] in
            sheet?.dismiss(animated: true) { self?.switchAndRun(handoff, walletId: walletId) }
        }
        sheet.present(from: presenter)
    }

    private func switchAndRun(_ handoff: PortfolioHandoff, walletId: String) {
        inbox.put(handoff, walletId: walletId)
        switcher.switchTo(walletId: walletId) { [weak self] success in
            guard !success else { return }
            self?.inbox.clear()
            self?.showMessage(PortfolioStrings.text("The wallet could not be switched. Nothing was changed."))
        }
    }

    /// Runs a hand-off waiting for this wallet after an account switch.
    func consumePendingHandoff() {
        guard let handoff = inbox.take(selectedWalletId: switcher.selectedWalletId) else { return }
        run(handoff)
    }

    private func run(_ handoff: PortfolioHandoff) {
        guard let presenter else { return }
        switch handoff {
        case let .send(assetId, recipient, amount):
            if handoff.isPlainSend {
                router.showSend(from: presenter)
            } else {
                router.showSora2Send(from: presenter, assetId: assetId, recipient: recipient, amount: amount)
            }
        case .receive:
            router.showReceive(from: presenter)
        case .receiveOnSora2:
            router.showSora2Receive(from: presenter)
        case let .swap(from, to):
            router.showSwap(from: presenter, fromAssetId: from, toAssetId: to)
        case let .network(network, send):
            if !router.showNetwork(network, send: send, from: presenter) {
                showMessage(PortfolioStrings.reasonNetworkUnavailable(PortfolioStrings.networkName(network)))
            }
        }
    }

    /// Sample wallets are not real: nothing may send to them and they cannot be selected. Swap and
    /// Receive still open the real screens of the real selected wallet, so they can be checked.
    private func performSample(_ handoff: PortfolioHandoff, walletId: String) {
        let isSampleSelected = walletId == viewModel.snapshot.selectedWallet?.id
        switch handoff {
        case .swap, .receive, .receiveOnSora2:
            if isSampleSelected {
                run(handoff)
            } else {
                showMessage(PortfolioStrings.text("Sample wallets cannot be selected. Nothing was changed."))
            }
        case .send, .network:
            showMessage(PortfolioStrings.text("Sample data: Send stays closed so nothing goes to a sample address."))
        }
    }

    private func showMessage(_ message: String) {
        guard let presenter else { return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: PortfolioStrings.text("OK"), style: .default))
        presenter.present(alert, animated: true)
    }
}
