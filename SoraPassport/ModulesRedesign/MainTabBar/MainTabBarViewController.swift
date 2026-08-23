// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
import SoraUIKit
import SoraFoundation
import SoraKeystore

extension Notification.Name {
    static let retainedWalletSigningRestored = Notification.Name(
        "co.jp.soramitsu.sora.retained-wallet-signing-restored"
    )
}

/// Uses SORA's font and palette tokens while retaining UIKit Dynamic Type.
/// `SoramitsuLabel` renders its typography through a fixed attributed string,
/// so new accessibility-critical surfaces use this adapter instead.
@MainActor
final class SoraAdaptiveLabel: UILabel, SoramitsuObserver {
    var soraFont: FontData {
        didSet { updateFont() }
    }

    var soraTextColor: SoramitsuColor {
        didSet { updateColor() }
    }

    private let textStyle: UIFont.TextStyle

    init(
        font: FontData,
        textStyle: UIFont.TextStyle,
        color: SoramitsuColor
    ) {
        soraFont = font
        self.textStyle = textStyle
        soraTextColor = color
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        adjustsFontForContentSizeCategory = true
        updateFont()
        updateColor()
        SoramitsuUI.updates.addObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            updateFont()
        }
    }

    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) {
            updateColor()
        }
    }

    private func updateFont() {
        font = UIFontMetrics(forTextStyle: textStyle).scaledFont(
            for: soraFont.font
        )
    }

    private func updateColor() {
        textColor = SoramitsuUI.shared.theme.palette.color(soraTextColor)
    }
}

enum WalletHomeNetwork: String, CaseIterable, Equatable {
    case sora2
    case sora3
}

enum WalletHomeNetworkSelectionPolicy {
    static func availableNetworks(
        sora3Available: Bool
    ) -> [WalletHomeNetwork] {
        sora3Available ? [.sora2, .sora3] : [.sora2]
    }

    static func resolvedSelection(
        stored: WalletHomeNetwork,
        sora3Available: Bool
    ) -> WalletHomeNetwork {
        availableNetworks(sora3Available: sora3Available).contains(stored)
            ? stored
            : .sora2
    }
}

enum WalletHomeNetworkPreference {
    private static let key = "walletHomeNetwork"

    static func stored(
        settings: SettingsManagerProtocol = SettingsManager.shared
    ) -> WalletHomeNetwork {
        guard
            let rawValue = settings.string(for: key),
            let network = WalletHomeNetwork(rawValue: rawValue)
        else {
            return .sora2
        }
        return network
    }

    static func store(
        _ network: WalletHomeNetwork,
        settings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        settings.set(value: network.rawValue, for: key)
    }
}

/// The second wallet-home slot is intentionally modeled as the SORA3 family,
/// not as a permanent Taira preference. Internal tester builds map it to Taira
/// today; a future release can point the same slot at SORA3 mainnet without
/// migrating the user's home-screen choice.
enum WalletHomeSora3Target: Equatable {
    case tairaTestnet

    static var current: WalletHomeSora3Target? {
#if SORA_INTERNAL_TAIRA_TESTFLIGHT
        let policy = NexusNetworkAdmissionPolicy.current
        guard
            policy.tairaDeployment == nil,
            policy.internalTairaTestFlight != nil,
            NexusNetworkConfiguration.taira != nil
        else {
            return nil
        }
        return .tairaTestnet
#else
        return nil
#endif
    }
}

@MainActor
final class WalletNetworkTabControl: UIControl {
    private let backgroundView = SoramitsuView()
    private let titleLabel = SoraAdaptiveLabel(
        font: FontType.textBoldS,
        textStyle: .subheadline,
        color: .accentSecondary
    )
    private let environmentLabel = SoraAdaptiveLabel(
        font: FontType.textXS,
        textStyle: .caption1,
        color: .fgSecondary
    )

    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            updateInteractionAppearance(animated: true)
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateInteractionAppearance(animated: false)
        }
    }

    private func updateInteractionAppearance(animated: Bool) {
        let targetAlpha: CGFloat
        if !isEnabled {
            targetAlpha = 0.44
        } else {
            targetAlpha = isHighlighted ? 0.72 : 1
        }
        if !animated || UIAccessibility.isReduceMotionEnabled {
            backgroundView.sora.alpha = targetAlpha
        } else {
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: {
                    self.backgroundView.sora.alpha = targetAlpha
                }
            )
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        title: String,
        environment: String,
        accessibilityHint: String
    ) {
        titleLabel.text = title
        environmentLabel.text = environment
        accessibilityLabel = [title, environment]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        self.accessibilityHint = accessibilityHint
    }

    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        isExclusiveTouch = true

        backgroundView.sora.cornerRadius = .medium
        backgroundView.sora.clipsToBounds = true
        backgroundView.isUserInteractionEnabled = false

        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        environmentLabel.textAlignment = .center
        environmentLabel.lineBreakMode = .byTruncatingTail

        let labels = UIStackView(
            arrangedSubviews: [titleLabel, environmentLabel]
        )
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.axis = .vertical
        labels.alignment = .fill
        labels.spacing = 2
        labels.isUserInteractionEnabled = false

        addSubview(backgroundView)
        backgroundView.addSubview(labels)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            labels.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor,
                constant: 12
            ),
            labels.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor,
                constant: -12
            ),
            labels.topAnchor.constraint(
                equalTo: backgroundView.topAnchor,
                constant: 8
            ),
            labels.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor,
                constant: -8
            ),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    private func updateAppearance() {
        // This mirrors the established Explore segmented control: selected
        // tabs use accentSecondary and inactive tabs use bgSurface.
        backgroundView.sora.backgroundColor = isSelected
            ? .accentSecondary
            : .bgSurface
        backgroundView.sora.borderWidth = isSelected ? 0 : 1
        backgroundView.sora.borderColor = isSelected ? nil : .fgOutline
        titleLabel.soraTextColor = isSelected
            ? .bgSurface
            : .accentSecondary
        environmentLabel.soraTextColor = isSelected
            ? .bgSurface
            : .fgSecondary

        var traits: UIAccessibilityTraits = .button
        if isSelected {
            traits.insert(.selected)
        }
        accessibilityTraits = traits
    }
}

@MainActor
final class WalletNetworkSwitchViewController: UIViewController {
    private let sora2Controller: UIViewController
    private let makeSora3Controller: @MainActor () -> UIViewController
    private let selectionChanged: (WalletHomeNetwork) -> Void
    private let rootView = SoramitsuView()
    private let contentView = UIView()
    private let selector = UIStackView()
    private let sora2Button = WalletNetworkTabControl()
    private let sora3Button = WalletNetworkTabControl()
    private var sora3Controller: UIViewController?
    private var displayedController: UIViewController?
    private var isTransitioning = false
    private(set) var selectedNetwork: WalletHomeNetwork

    var activeNavigationController: UINavigationController? {
        if let navigationController = displayedController as? UINavigationController {
            return navigationController
        }
        return displayedController?.navigationController
    }

    init(
        sora2Controller: UIViewController,
        initialSelection: WalletHomeNetwork,
        makeSora3Controller: @escaping @MainActor () -> UIViewController,
        selectionChanged: @escaping (WalletHomeNetwork) -> Void
    ) {
        self.sora2Controller = sora2Controller
        self.selectedNetwork = initialSelection
        self.makeSora3Controller = makeSora3Controller
        self.selectionChanged = selectionChanged
        super.init(nibName: nil, bundle: nil)
        tabBarItem = sora2Controller.tabBarItem
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        rootView.sora.backgroundColor = .bgPage
        // A view-controller root is sized by UIKit's container. SoraUIKit views
        // default to constraint-managed sizing, so opt back into the framework's
        // root-view contract before UITabBarController installs this controller.
        rootView.sora.useAutoresizingMask = true
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        applyLocalization()
        _ = select(selectedNetwork, animated: false)

        LocalizationManager.shared.addObserver(with: self) {
            [weak self] _, _ in
            self?.applyLocalization()
        }
    }

    @discardableResult
    func select(
        _ network: WalletHomeNetwork,
        animated: Bool = true
    ) -> Bool {
        guard !isTransitioning else {
            return false
        }

        let controller: UIViewController
        switch network {
        case .sora2:
            controller = sora2Controller
        case .sora3:
            if let sora3Controller {
                controller = sora3Controller
            } else {
                let created = makeSora3Controller()
                sora3Controller = created
                controller = created
            }
        }

        selectedNetwork = network
        selectionChanged(network)
        updateSelectionAppearance()
        if animated {
            let selectedControl = network == .sora2
                ? sora2Button
                : sora3Button
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: selectedControl
            )
        }
        guard displayedController !== controller else {
            return true
        }

        let previous = displayedController
        let shouldForwardAppearance = viewIfLoaded?.window != nil
        previous?.willMove(toParent: nil)
        addChild(controller)
        if shouldForwardAppearance {
            previous?.beginAppearanceTransition(false, animated: animated)
            controller.beginAppearanceTransition(true, animated: animated)
        }
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            controller.view.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            controller.view.topAnchor.constraint(
                equalTo: contentView.topAnchor
            ),
            controller.view.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            )
        ])
        displayedController = controller

        let shouldDiscardSora3 = network == .sora2 && previous === sora3Controller
        let completeTransition = { [weak self, weak previous, weak controller] in
            previous?.view.removeFromSuperview()
            previous?.removeFromParent()
            controller?.didMove(toParent: self)
            if shouldForwardAppearance {
                previous?.endAppearanceTransition()
                controller?.endAppearanceTransition()
            }
            if shouldDiscardSora3 {
                self?.sora3Controller = nil
            }
            self?.isTransitioning = false
            self?.setSelectionEnabled(true)
        }

        guard animated,
              !UIAccessibility.isReduceMotionEnabled,
              previous != nil else {
            completeTransition()
            return true
        }

        isTransitioning = true
        setSelectionEnabled(false)
        controller.view.alpha = 0
        UIView.animate(
            withDuration: 0.18,
            animations: {
                controller.view.alpha = 1
                previous?.view.alpha = 0
            },
            completion: { _ in
                previous?.view.alpha = 1
                completeTransition()
            }
        )
        return true
    }

    private func configureLayout() {
        selector.translatesAutoresizingMaskIntoConstraints = false
        selector.axis = .horizontal
        selector.distribution = .fillEqually
        selector.spacing = 8
        selector.accessibilityIdentifier = "wallet.network.selector"

        sora2Button.accessibilityIdentifier = "wallet.network.sora2"
        sora3Button.accessibilityIdentifier = "wallet.network.sora3"
        sora2Button.addTarget(
            self,
            action: #selector(selectSora2),
            for: .touchUpInside
        )
        sora3Button.addTarget(
            self,
            action: #selector(selectSora3),
            for: .touchUpInside
        )

        selector.addArrangedSubview(sora2Button)
        selector.addArrangedSubview(sora3Button)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        view.addSubview(selector)
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            selector.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            selector.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            selector.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(
                equalTo: selector.bottomAnchor,
                constant: 12
            ),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyLocalization() {
        let sora2Text = networkTabText(
            tairaLocalizedText(
                "wallet_network_sora2_mainnet",
                fallback: "SORA2\nMAINNET"
            )
        )
        let sora3Text = networkTabText(
            tairaLocalizedText(
                "wallet_network_sora3_taira_testnet",
                fallback: "SORA3\nTAIRA TESTNET"
            )
        )
        let hint = tairaLocalizedText(
            "wallet_network_switch_hint",
            fallback: "Switch the wallet between SORA2 mainnet and the SORA3 Taira testnet."
        )
        sora2Button.configure(
            title: sora2Text.title,
            environment: sora2Text.environment,
            accessibilityHint: hint
        )
        sora3Button.configure(
            title: sora3Text.title,
            environment: sora3Text.environment,
            accessibilityHint: hint
        )
        updateSelectionAppearance()
    }

    private func networkTabText(
        _ localizedText: String
    ) -> (title: String, environment: String) {
        let components = localizedText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        guard let title = components.first else {
            return (localizedText, "")
        }
        return (title, components.dropFirst().joined(separator: " "))
    }

    private func updateSelectionAppearance() {
        update(button: sora2Button, selected: selectedNetwork == .sora2)
        update(button: sora3Button, selected: selectedNetwork == .sora3)
    }

    private func update(
        button: WalletNetworkTabControl,
        selected: Bool
    ) {
        button.isSelected = selected
    }

    private func setSelectionEnabled(_ enabled: Bool) {
        sora2Button.isEnabled = enabled
        sora3Button.isEnabled = enabled
    }

    @objc private func selectSora2() {
        _ = select(.sora2)
    }

    @objc private func selectSora3() {
        _ = select(.sora3)
    }
}

extension WalletNetworkSwitchViewController: ScrollsToTop {
    func scrollToTop() {
        (displayedController as? ScrollsToTop)?.scrollToTop()
    }
}

extension UIViewController {
    var embeddedWalletNavigationController: UINavigationController? {
        if let navigationController = self as? UINavigationController {
            return navigationController
        }
        if let networkSwitch = self as? WalletNetworkSwitchViewController {
            return networkSwitch.activeNavigationController
        }
        return navigationController
    }
}

final class MainTabBarViewController: UITabBarController {
    var presenter: MainTabBarPresenterProtocol!
    var middleButtonHadler: (() -> Void)?
    private(set) var isRecoveryReadOnly = false
    var recoveryRestoreHandler: (() -> Void)?
    private var viewAppeared: Bool = false
    private(set) var recoveryInteractionShield: UIView?
    private var recoveryRestoredObserver: NSObjectProtocol?
    var recoveryRequiredProvider: (() -> Bool)?

    deinit {
        if let recoveryRestoredObserver {
            NotificationCenter.default.removeObserver(recoveryRestoredObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        recoveryRestoredObserver = NotificationCenter.default.addObserver(
            forName: .retainedWalletSigningRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.recoveryIsStillRequired() else {
                return
            }
            self.disableRecoveryReadOnlyMode()
        }

        self.delegate = self

        let tabBar = TabBar(frame: tabBar.frame)
        tabBar.middleButton.sora.backgroundColor = .custom(uiColor: .white)
        tabBar.middleButton.sora.image = R.image.wallet.polkaswap()
        tabBar.middleButton.sora.shadow = .default
        tabBar.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.coverButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.middleButtonTitleLabel.sora.text = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: .currentLocale)
        setValue(tabBar, forKey: "tabBar")
        
        SoramitsuUI.updates.addObserver(self)
        configureTabBar()

        if isRecoveryReadOnly, recoveryIsStillRequired() {
            configureRecoveryReadOnlyMode()
        } else {
            isRecoveryReadOnly = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }
    }

    override func setViewControllers(
        _ viewControllers: [UIViewController]?,
        animated: Bool
    ) {
        super.setViewControllers(viewControllers, animated: animated)

        if isViewLoaded {
            configureTabBar()
        }
        guard recoveryInteractionShield != nil else {
            return
        }
        if let recoveryInteractionShield {
            view.bringSubviewToFront(recoveryInteractionShield)
        }
    }

    func enableRecoveryReadOnlyMode() {
        isRecoveryReadOnly = true

        // Creation can race a successful background recovery after the factory sampled
        // recovery state. Never recreate a shield from that stale decision.
        guard recoveryIsStillRequired() else {
            disableRecoveryReadOnlyMode()
            return
        }

        if isViewLoaded, recoveryInteractionShield == nil {
            configureRecoveryReadOnlyMode()
        }
    }

    func disableRecoveryReadOnlyMode() {
        isRecoveryReadOnly = false
        recoveryInteractionShield?.removeFromSuperview()
        recoveryInteractionShield = nil
    }

    private func recoveryIsStillRequired() -> Bool {
        if let recoveryRequiredProvider {
            return recoveryRequiredProvider()
        }

        guard let account = SelectedWalletSettings.shared.currentAccount else {
            return isRecoveryReadOnly
        }

        return SelectedWalletSettings.requiresRecoveryReadOnlyMode(
            settings: SettingsManager.shared,
            keystore: Keychain(),
            account: account
        )
    }

    private func configureTabBar() {
        let palette = SoramitsuUI.shared.theme.palette
        
        let normalAttributes = [NSAttributedString.Key.foregroundColor: palette.color(.fgSecondary),
                                NSAttributedString.Key.font: FontType.textBoldXS.font]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: palette.color(.accentPrimary),
                                  NSAttributedString.Key.font: FontType.textBoldXS.font]
        
        tabBar.tintColor = palette.color(.accentPrimary)
        tabBar.unselectedItemTintColor = palette.color(.fgSecondary)
        tabBar.items?.forEach {
            $0.setTitleTextAttributes(normalAttributes, for: .normal)
            $0.setTitleTextAttributes(selectedAttributes, for: .selected)
        }
    }

    private func configureRecoveryReadOnlyMode() {
        let banner = SoramitsuView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.sora.backgroundColor = .statusWarningContainer
        banner.sora.borderColor = .statusWarning
        banner.sora.borderWidth = 1
        banner.sora.cornerRadius = .large
        banner.accessibilityIdentifier = "walletRecovery.banner"

        let titleLabel = SoraAdaptiveLabel(
            font: FontType.textBoldS,
            textStyle: .headline,
            color: .custom(uiColor: Colors.brown90)
        )
        titleLabel.text = recoveryText(
            "wallet.recovery.banner.title",
            fallback: "Signing unavailable"
        )
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .left

        let messageLabel = SoraAdaptiveLabel(
            font: FontType.paragraphXS,
            textStyle: .footnote,
            color: .custom(uiColor: Colors.brown70)
        )
        messageLabel.text = recoveryText(
            "wallet.recovery.banner",
            fallback: "Wallet access needs restoring. You can still view balances and receive funds, but signing is unavailable."
        )
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left

        let restoreButton = SoramitsuButton(
            size: .large,
            type: .filled(.primary)
        )
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.sora.cornerRadius = .circle
        let restoreTitle = recoveryText(
            "wallet.recovery.banner.action",
            fallback: "Restore access"
        )
        restoreButton.sora.title = restoreTitle
        restoreButton.isAccessibilityElement = true
        restoreButton.accessibilityLabel = restoreTitle
        restoreButton.accessibilityHint = recoveryText(
            "wallet.recovery.banner.action.hint",
            fallback: "Choose how to restore the signing key for this wallet"
        )
        restoreButton.accessibilityIdentifier = "walletRecovery.banner.restore"
        restoreButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.restoreWallet()
        }

        banner.addSubview(titleLabel)
        banner.addSubview(messageLabel)
        banner.addSubview(restoreButton)
        view.addSubview(banner)
        recoveryInteractionShield = banner

        // Keep recovery UI as an overlay. On iOS 26, reserving this height through
        // UITabBarController child safe-area insets can collapse the child width.
        let bannerBottomAnchor = (tabBar as? TabBar)?.middleButton.topAnchor
            ?? tabBar.topAnchor
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            banner.bottomAnchor.constraint(equalTo: bannerBottomAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 14),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            restoreButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            restoreButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            restoreButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            restoreButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -14)
        ])

        view.layoutIfNeeded()

        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    @objc private func restoreWallet() {
        recoveryRestoreHandler?()
    }
}

extension MainTabBarViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        configureTabBar()
        AppearanceFactory.applyGlobalAppearance()
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        if let scrollableController = viewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }

        return true
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        self.setViewControllers(newViewControllers, animated: false)
        if let recoveryInteractionShield {
            self.view.bringSubviewToFront(recoveryInteractionShield)
        }
    }
}

extension MainTabBarViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        (tabBar as? TabBar)?.middleButtonTitleLabel.sora.text = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: languages)
    }
}
