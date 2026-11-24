// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import UIKit

/// The selected account's key warning (watch-only, missing or invalid keys, a pending repair), on
/// the portfolio home under the hero, with Restore keys where a restore can help.
final class PortfolioNoticeItem: NSObject {
    /// The account the Wallet tab shows.
    var account: AccountItem?
    private(set) var capability: WalletAccountCapability.State = .checking
    var onRestore: (() -> Void)?
    /// After a capability change; true when the notice comes or goes rather than changes its text.
    var onCapabilityChange: ((Bool) -> Void)?
    private var probeGeneration = UUID()

    var isShown: Bool { Self.needsNotice(capability) }

    static func needsNotice(_ state: WalletAccountCapability.State) -> Bool {
        switch state {
        case .signing, .checking: return false
        case .watchOnly, .missingKeys, .invalidKeys, .repairPending, .unavailable: return true
        }
    }

    /// Checks the account's signing keys again (`WalletAccountCapability.probe`, read-only).
    /// Only the latest check counts.
    func refreshCapability() {
        guard let account else { return }
        let generation = UUID()
        probeGeneration = generation
        WalletAccountCapability.probe(account: account) { [weak self] state in
            guard let self, self.probeGeneration == generation else { return }
            self.setCapability(state)
        }
    }

    func setCapability(_ state: WalletAccountCapability.State) {
        let wasShown = isShown
        capability = state
        onCapabilityChange?(wasShown != isShown)
    }
}

extension PortfolioNoticeItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioNoticeCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        UITableView.automaticDimension
    }
}

final class PortfolioNoticeCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioNoticeItem?
    private let card = GlassView()
    private let badge = UILabel.portfolio(FontType.textBoldS, .subheadline, lines: 0, maximum: 26)
    private let reason = UILabel.portfolio(FontType.paragraphS, .subheadline, lines: 0, maximum: 28)
    private lazy var restore = PortfolioPrimaryButton(title: WalletUX.text("Restore keys for this account")) {
        [weak self] in self?.item?.onRestore?()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        card.shape = .rounded(20)
        card.border = .none
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        let stack = UIStackView(arrangedSubviews: [badge, reason, restore])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(14, after: reason)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16)
        ])
        badge.accessibilityIdentifier = "wallet-selected-account-capability-badge"
        reason.accessibilityIdentifier = "wallet-selected-account-read-only-reason"
        restore.accessibilityIdentifier = "wallet-selected-account-restore-keys"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioNoticeItem else { return }
        self.item = item
        reload()
    }

    private func reload() {
        guard let state = item?.capability else { return }
        let tokens = PortfolioTheme.tokens
        card.apply()
        // A warning's sheet is of its own colour.
        card.plate.faceColor = tokens.warningContainer
        badge.text = state.badge
        badge.textColor = tokens.warning
        reason.text = state.reason
        reason.textColor = tokens.textPrimary
        restore.isHidden = !state.canRestore
    }
}

/// iOS releases behind on security updates while web-ad exploit kits built to steal wallets target
/// out-of-date iOS: Coruna (13.0–17.2.1), DarkSword (18.4–18.7) and the kits MoldyRoost picks for
/// every release up to 26 (Confiant, 2026-11-20). The bar is the newest security release of each
/// branch on 2026-11-23 (Apple, support.apple.com/en-us/100100). iOS 17 has no current release:
/// its phones can move to 18 or later. No kit is known for 27.
enum IOSPatchLevel {
    static let fixedRelease: [Int: (minor: Int, patch: Int)] = [
        16: (7, 16),
        18: (7, 12),
        26: (7, 3)
    ]

    static func needsUpdate(_ version: OperatingSystemVersion) -> Bool {
        if version.majorVersion == 17 { return true }
        guard let fixed = fixedRelease[version.majorVersion] else {
            return version.majorVersion < 16
        }
        return (version.minorVersion, version.patchVersion) < (fixed.minor, fixed.patch)
    }
}

/// "Update iOS" on the portfolio home while the phone runs a release in `IOSPatchLevel`.
/// "Not now" hides it for a week on that release. It is shown only after `refresh()`.
final class PortfolioSystemUpdateItem: NSObject {
    static let hiddenReleaseKey = "portfolio.ios-update.hidden-release.v1"
    static let hiddenUntilKey = "portfolio.ios-update.hidden-until.v1"
    private let defaults: UserDefaults
    private let version: () -> OperatingSystemVersion
    private let now: () -> Date
    private(set) var isShown = false
    /// The notice came or went.
    var onChange: (() -> Void)?
    private var activeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard,
         version: @escaping () -> OperatingSystemVersion = { ProcessInfo.processInfo.operatingSystemVersion },
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.version = version
        self.now = now
    }

    private var release: String {
        let version = version()
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    deinit { activeObserver.map(NotificationCenter.default.removeObserver) }

    /// Also checks again each time the app comes back, so "Not now" ends after its week and an
    /// update is noticed; that starts with the first check.
    func refresh() {
        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.refresh() }
        }
        let hidden = defaults.string(forKey: Self.hiddenReleaseKey) == release
            && now().timeIntervalSince1970 < defaults.double(forKey: Self.hiddenUntilKey)
        let shown = IOSPatchLevel.needsUpdate(version()) && !hidden
        guard shown != isShown else { return }
        isShown = shown
        onChange?()
    }

    func hideForAWeek() {
        defaults.set(release, forKey: Self.hiddenReleaseKey)
        defaults.set(now().addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970, forKey: Self.hiddenUntilKey)
        refresh()
    }
}

extension PortfolioSystemUpdateItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioSystemUpdateCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        UITableView.automaticDimension
    }
}

final class PortfolioSystemUpdateCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioSystemUpdateItem?
    private let card = GlassView()
    private let badge = UILabel.portfolio(FontType.textBoldS, .subheadline, lines: 0, maximum: 26)
    private let reason = UILabel.portfolio(FontType.paragraphS, .subheadline, lines: 0, maximum: 28)
    private lazy var notNow = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
        self?.item?.hideForAWeek()
    })

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        card.shape = .rounded(20)
        card.border = .none
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        notNow.contentHorizontalAlignment = .leading
        notNow.titleLabel?.font = PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 26)
        notNow.titleLabel?.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [badge, reason, notNow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -12)
        ])
        badge.accessibilityIdentifier = "wallet-ios-update-badge"
        reason.accessibilityIdentifier = "wallet-ios-update-reason"
        notNow.accessibilityIdentifier = "wallet-ios-update-not-now"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioSystemUpdateItem else { return }
        self.item = item
        let tokens = PortfolioTheme.tokens
        card.apply()
        card.plate.faceColor = tokens.warningContainer
        badge.text = WalletUX.text("Update iOS")
        badge.textColor = tokens.warning
        reason.text = WalletUX.text("This iOS is missing security updates, and web attacks that steal wallets target out-of-date iOS. Update in Settings › General › Software Update.")
        reason.textColor = tokens.textPrimary
        notNow.setTitle(WalletUX.text("Not now"), for: .normal)
        notNow.setTitleColor(tokens.link, for: .normal)
    }
}
