// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraKeystore
import SoraUIKit
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
/// One network of the picker, as the home's Assets card shows a token.
struct WalletNetworkChoiceRow: Equatable {
    let choice: WalletNetworkChoice
    let title: String
    let subtitle: String
    let tag: WalletNetworkTag?
    var isAvailable: Bool { choice.isAvailable }
    var identifier: String { "wallet.network-choice.\(choice.network.id.rawValue)" }

    init(_ choice: WalletNetworkChoice) {
        self.choice = choice
        title = choice.network.name
        let amount = choice.network.isLive
            ? choice.balance.map { "\($0) XOR" }
            : WalletUX.text("Address ready")
        subtitle = [amount, WalletNetworkAccounts.shortAddress(choice.account.address), choice.unavailableReason]
            .compactMap { $0 }
            .joined(separator: "\n")
        tag = choice.tag
    }
}

final class WalletNetworkChoicesItem: NSObject {
    let rows: [WalletNetworkChoiceRow]
    let footer: String
    let icon: UIImage?
    var onPick: ((WalletNetworkChoiceRow) -> Void)?

    init(rows: [WalletNetworkChoiceRow], footer: String, icon: UIImage?) {
        self.rows = rows
        self.footer = footer
        self.icon = icon
    }
}

extension WalletNetworkChoicesItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { WalletNetworkChoicesCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
}

/// A card of SORA2 asset rows, one per network.
final class WalletNetworkChoicesCell: SoramitsuTableViewCell {
    private var item: WalletNetworkChoicesItem?

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()

    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 16
        return view
    }()

    let footerLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(containerView)
        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension WalletNetworkChoicesCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? WalletNetworkChoicesItem else {
            assertionFailure("Incorect type of item")
            return
        }
        self.item = item
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for row in item.rows {
            let view = MainScreenAssetView()
            if let icon = item.icon {
                view.assetImageView.sora.picture = .logo(image: icon)
            }
            view.assetImageView.sora.loadingPlaceholder.type = .none
            view.titleLabel.sora.text = row.title
            view.titleLabel.sora.loadingPlaceholder.type = .none
            view.subtitleLabel.sora.text = row.subtitle.isEmpty ? " " : row.subtitle
            // The subtitle can end in a sentence ("Sending on … starts when the network launches").
            view.subtitleLabel.sora.lineBreakMode = .byWordWrapping
            view.subtitleLabel.sora.loadingPlaceholder.type = .none
            view.amountUpLabel.sora.text = row.tag?.title ?? ""
            switch row.tag {
            case .testnet: view.amountUpLabel.sora.textColor = .custom(uiColor: .systemOrange)
            case .comingSoon: view.amountUpLabel.sora.textColor = .fgSecondary
            case .main: view.amountUpLabel.sora.textColor = .accentPrimary
            case nil: break
            }
            view.amountUpLabel.sora.font = FontType.textBoldXS
            view.amountUpLabel.sora.loadingPlaceholder.type = .none
            view.amountDownLabel.sora.text = ""
            view.amountDownLabel.sora.loadingPlaceholder.type = .none
            view.accessibilityIdentifier = row.identifier
            view.accessibilityTraits = row.isAvailable ? .button : [.button, .notEnabled]
            view.isEnabled = row.isAvailable
            view.alpha = row.isAvailable ? 1 : 0.5
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.item?.onPick?(row)
            }
            stackView.addArrangedSubview(view)
        }
        footerLabel.sora.text = item.footer
        stackView.addArrangedSubview(footerLabel)
    }
}

/// "Send on" / "Receive on": the wallet's networks as SORA2 lists choices,
/// rows of the home's asset card over the blurred home.
@MainActor
final class WalletNetworkPickerViewController: SoramitsuViewController {
    private let action: WalletNetworkAction
    private let choices: [WalletNetworkChoice]
    private let onPick: @MainActor (WalletNetworkChoice) -> Void
    private(set) var item: WalletNetworkChoicesItem?

    private(set) lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    init(
        action: WalletNetworkAction,
        choices: [WalletNetworkChoice],
        onPick: @escaping @MainActor (WalletNetworkChoice) -> Void
    ) {
        self.action = action
        self.choices = choices
        self.onPick = onPick
        super.init()
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
        let navigation = UINavigationController(rootViewController: picker)
        navigation.addCustomTransitioning()
        NexusSora2Presentation.present(picker, from: source, navigation: navigation)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = WalletUX.text(action == .receive ? "Receive on" : "Send on")
        navigationItem.title = title
        addCloseButton()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tableView.accessibilityIdentifier = action == .receive
            ? "wallet.network-picker.receive"
            : "wallet.network-picker.send"
        let footer: String
        switch action {
        case .receive:
            footer = WalletUX.text("Each network has its own address. Share the address of the network the sender uses.")
        case .send:
            footer = WalletUX.text("The recipient needs an address on the network you choose.")
        }
        let item = WalletNetworkChoicesItem(
            rows: choices.map(WalletNetworkChoiceRow.init),
            footer: footer,
            icon: NexusSora2Presentation.xorImage(NexusSora2Presentation.xorAsset))
        item.onPick = { [weak self] row in self?.pick(row.choice) }
        self.item = item
        tableView.sora.sections = [SoramitsuTableViewSection(rows: [item])]
    }

    func pick(_ choice: WalletNetworkChoice) {
        guard choice.isAvailable else {
            return
        }
        let onPick = onPick
        dismiss(animated: true) {
            Task { @MainActor in onPick(choice) }
        }
    }
}
