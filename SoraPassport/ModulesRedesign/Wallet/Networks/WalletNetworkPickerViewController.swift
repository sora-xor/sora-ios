// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraKeystore
import UIKit

/// The selected wallet's network accounts that this build and the user's
/// settings show: SORA2 always, SORA Nexus with the Nexus portfolio, Taira
/// also with the Taira switch. The same gates as the Networks screen.
@MainActor
enum WalletNetworkAccounts {
    static func selectedWallet() -> [NetworkAccount] {
        let settings = SettingsManager.shared
        guard
            let walletId = SelectedWalletSettings.shared.currentAccount?.address,
            let snapshot = try? WalletNetworkStore().load(),
            snapshot.wallets.contains(where: { $0.id == walletId })
        else {
            return []
        }
        return snapshot.accounts.filter { account in
            guard account.walletId == walletId else {
                return false
            }
            switch account.networkId {
            case .sora2:
                return true
            case .minamoto:
                return settings.nexusEnabled
            case .taira:
                return settings.nexusEnabled && settings.isTairaEnabled &&
                    NexusNetworkAdmissionPolicy.current.isTairaAdmitted
            }
        }
    }

    /// Whether this wallet can start a send on `networkId` now. SORA2's own
    /// send flow checks the account itself.
    static func canSend(on networkId: NetworkId) -> Bool {
        guard networkId != .sora2 else {
            return true
        }
        let settings = SettingsManager.shared
        let access = NexusPortfolioPresentationPolicy.networkDetailAccess(
            networkId: networkId,
            nexusEnabled: settings.nexusEnabled,
            tairaEnabled: settings.isTairaEnabled,
            tairaAdmitted: NexusNetworkAdmissionPolicy.current.isTairaAdmitted,
            mutationCoordinatorAvailable: NexusTransactionRuntime.shared.coordinator != nil
        )
        return access.mutationSurfaceAvailable && settings.nexusSendsEnabled(for: networkId)
    }

    nonisolated static func shortAddress(_ value: String) -> String {
        guard value.count > 24 else {
            return value
        }
        return "\(value.prefix(10))…\(value.suffix(8))"
    }
}

/// "Main", "Testnet" or "Coming soon" next to a network's name.
final class WalletNetworkTagView: UIView {
    private let label = UILabel()

    init(networkTag: WalletNetworkTag) {
        super.init(frame: .zero)
        let color: UIColor
        switch networkTag {
        case .main:
            color = WalletUX.accent
        case .testnet:
            color = .systemOrange
        case .comingSoon:
            color = WalletUX.secondary
        }
        label.text = networkTag.title
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = color.withAlphaComponent(0.14)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
        isAccessibilityElement = true
        accessibilityLabel = networkTag.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Accessory views are laid out by frame, not by constraints.
    func sizeToContent() {
        frame.size = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    }
}

/// The one question the wallet asks about networks, and only when there is a
/// real choice: which network to receive or send on. The main network is
/// first. Each row shows the network's tag, the XOR balance and the address.
@MainActor
final class WalletNetworkPickerViewController: WalletTableViewController {
    private let action: WalletNetworkAction
    private let choices: [WalletNetworkChoice]
    private let onPick: @MainActor (WalletNetworkChoice) -> Void

    init(
        action: WalletNetworkAction,
        choices: [WalletNetworkChoice],
        onPick: @escaping @MainActor (WalletNetworkChoice) -> Void
    ) {
        self.action = action
        self.choices = choices
        self.onPick = onPick
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    static func present(
        action: WalletNetworkAction,
        choices: [WalletNetworkChoice],
        from source: UIViewController,
        onPick: @escaping @MainActor (WalletNetworkChoice) -> Void
    ) {
        let picker = WalletNetworkPickerViewController(action: action, choices: choices, onPick: onPick)
        let navigation = SoraNavigationController(rootViewController: picker)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        source.present(navigation, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = WalletUX.text(action == .receive ? "Receive on" : "Send on")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: WalletUX.text("Close"),
            style: .plain,
            target: self,
            action: #selector(closePicker)
        )
        tableView.accessibilityIdentifier = action == .receive
            ? "wallet.network-picker.receive"
            : "wallet.network-picker.send"
    }

    @objc private func closePicker() {
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        choices.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch action {
        case .receive:
            return WalletUX.text("Each network has its own address. Share the address of the network the sender uses.")
        case .send:
            return WalletUX.text("The recipient needs an address on the network you choose.")
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let choice = choices[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = choice.network.name
        let amount = choice.network.isLive
            ? choice.balance.map { "\($0) XOR" }
            : WalletUX.text("Address ready")
        content.secondaryText = [amount, WalletNetworkAccounts.shortAddress(choice.account.address), choice.unavailableReason]
            .compactMap { $0 }
            .joined(separator: "\n")
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        if let tag = choice.tag {
            let tagView = WalletNetworkTagView(networkTag: tag)
            tagView.sizeToContent()
            cell.accessoryView = tagView
        }
        cell.selectionStyle = choice.isAvailable ? .default : .none
        cell.accessibilityIdentifier = "wallet.network-choice.\(choice.network.id.rawValue)"
        cell.accessibilityTraits = choice.isAvailable ? .button : [.button, .notEnabled]
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        // The base table styles every row as enabled: a network that cannot be
        // used for this action must read as unavailable.
        guard !choices[indexPath.row].isAvailable else { return }
        if var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.color = WalletUX.secondary
            content.secondaryTextProperties.color = WalletUX.secondary
            cell.contentConfiguration = content
        }
        cell.accessoryView?.alpha = 0.5
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let choice = choices[indexPath.row]
        guard choice.isAvailable else {
            return
        }
        let onPick = onPick
        dismiss(animated: true) {
            Task { @MainActor in onPick(choice) }
        }
    }
}
