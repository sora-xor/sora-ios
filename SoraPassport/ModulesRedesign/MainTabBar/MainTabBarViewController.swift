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
final class WalletNetworkSwitchViewController: UIViewController {
    private let sora2Controller: UIViewController
    private let makeSora3Controller: @MainActor () -> UIViewController
    private let selectionChanged: (WalletHomeNetwork) -> Void
    private let contentView = UIView()
    private let selectorBackground = UIView()
    private let sora2Button = UIButton(type: .system)
    private let sora3Button = UIButton(type: .system)
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

        let completeTransition = { [weak self, weak previous, weak controller] in
            previous?.view.removeFromSuperview()
            previous?.removeFromParent()
            controller?.didMove(toParent: self)
            if shouldForwardAppearance {
                previous?.endAppearanceTransition()
                controller?.endAppearanceTransition()
            }
            self?.isTransitioning = false
            self?.setSelectionEnabled(true)
        }

        guard animated, previous != nil else {
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
        view.backgroundColor = .systemBackground

        selectorBackground.translatesAutoresizingMaskIntoConstraints = false
        selectorBackground.backgroundColor = .secondarySystemBackground
        selectorBackground.layer.cornerRadius = 16
        selectorBackground.layer.cornerCurve = .continuous
        selectorBackground.accessibilityIdentifier =
            "wallet.network.selector"

        [sora2Button, sora3Button].forEach { button in
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.font = UIFont.preferredFont(
                forTextStyle: .headline
            )
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.layer.cornerRadius = 12
            button.layer.cornerCurve = .continuous
            button.contentEdgeInsets = UIEdgeInsets(
                top: 10,
                left: 8,
                bottom: 10,
                right: 8
            )
        }
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

        let selector = UIStackView(
            arrangedSubviews: [sora2Button, sora3Button]
        )
        selector.translatesAutoresizingMaskIntoConstraints = false
        selector.axis = .horizontal
        selector.distribution = .fillEqually
        selector.spacing = 8
        selectorBackground.addSubview(selector)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectorBackground)
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            selectorBackground.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            selectorBackground.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            selectorBackground.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            selector.leadingAnchor.constraint(
                equalTo: selectorBackground.leadingAnchor,
                constant: 6
            ),
            selector.trailingAnchor.constraint(
                equalTo: selectorBackground.trailingAnchor,
                constant: -6
            ),
            selector.topAnchor.constraint(
                equalTo: selectorBackground.topAnchor,
                constant: 6
            ),
            selector.bottomAnchor.constraint(
                equalTo: selectorBackground.bottomAnchor,
                constant: -6
            ),
            sora2Button.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 62
            ),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(
                equalTo: selectorBackground.bottomAnchor,
                constant: 8
            ),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyLocalization() {
        sora2Button.setTitle(
            tairaLocalizedText(
                "wallet_network_sora2_mainnet",
                fallback: "SORA2\nMAINNET"
            ),
            for: .normal
        )
        sora3Button.setTitle(
            tairaLocalizedText(
                "wallet_network_sora3_taira_testnet",
                fallback: "SORA3\nTAIRA TESTNET"
            ),
            for: .normal
        )
        let hint = tairaLocalizedText(
            "wallet_network_switch_hint",
            fallback: "Switch the wallet between SORA2 mainnet and the SORA3 Taira testnet."
        )
        sora2Button.accessibilityHint = hint
        sora3Button.accessibilityHint = hint
        updateSelectionAppearance()
    }

    private func updateSelectionAppearance() {
        update(button: sora2Button, selected: selectedNetwork == .sora2)
        update(button: sora3Button, selected: selectedNetwork == .sora3)
    }

    private func update(button: UIButton, selected: Bool) {
        button.isSelected = selected
        button.backgroundColor = selected ? .systemRed : .clear
        button.setTitleColor(selected ? .white : .label, for: .normal)
        var traits: UIAccessibilityTraits = .button
        if selected {
            traits.insert(.selected)
        }
        button.accessibilityTraits = traits
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
    private var recoveryBannerTopConstraint: NSLayoutConstraint?
    private var recoveryOriginalAdditionalSafeAreaTop: CGFloat?

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

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateRecoveryBannerLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateRecoveryBannerLayout()
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
        if let originalAdditionalSafeAreaTop = recoveryOriginalAdditionalSafeAreaTop {
            additionalSafeAreaInsets.top = originalAdditionalSafeAreaTop
        }
        recoveryOriginalAdditionalSafeAreaTop = nil
        recoveryBannerTopConstraint = nil
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
        let banner = UIView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.96)
        banner.layer.cornerRadius = 12
        banner.accessibilityIdentifier = "walletRecovery.banner"

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = recoveryText(
            "wallet.recovery.banner",
            fallback: "Wallet access needs restoring. You can still view balances and receive funds, but signing is unavailable."
        )
        label.textColor = .black
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center

        let restoreButton = UIButton(type: .system)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.setTitle(
            R.string.localizable.recoveryTitle(preferredLanguages: .currentLocale),
            for: .normal
        )
        restoreButton.setTitleColor(.black, for: .normal)
        restoreButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        restoreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        restoreButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        restoreButton.layer.cornerRadius = 8
        restoreButton.accessibilityHint = recoveryText(
            "wallet.recovery.banner.action.hint",
            fallback: "Choose how to restore the signing key for this wallet"
        )
        restoreButton.accessibilityIdentifier = "walletRecovery.banner.restore"
        restoreButton.addTarget(self, action: #selector(restoreWallet), for: .touchUpInside)

        banner.addSubview(label)
        banner.addSubview(restoreButton)
        view.addSubview(banner)
        recoveryInteractionShield = banner

        let originalAdditionalSafeAreaTop = additionalSafeAreaInsets.top
        recoveryOriginalAdditionalSafeAreaTop = originalAdditionalSafeAreaTop
        let systemTopInset = max(0, view.safeAreaInsets.top - originalAdditionalSafeAreaTop)
        let topConstraint = banner.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: systemTopInset + originalAdditionalSafeAreaTop + 8
        )
        recoveryBannerTopConstraint = topConstraint

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topConstraint,
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            restoreButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            restoreButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            restoreButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            restoreButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            restoreButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10)
        ])

        view.layoutIfNeeded()
        updateRecoveryBannerLayout()

        UIAccessibility.post(notification: .screenChanged, argument: label)
    }

    private func updateRecoveryBannerLayout() {
        guard let banner = recoveryInteractionShield,
              let originalAdditionalSafeAreaTop = recoveryOriginalAdditionalSafeAreaTop else {
            return
        }

        let systemTopInset = max(
            0,
            view.safeAreaInsets.top - additionalSafeAreaInsets.top
        )
        recoveryBannerTopConstraint?.constant = systemTopInset + originalAdditionalSafeAreaTop + 8

        let fittingWidth = max(0, view.bounds.width - 32)
        guard fittingWidth > 0 else { return }

        let bannerHeight = banner.systemLayoutSizeFitting(
            CGSize(width: fittingWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let reservedTop = originalAdditionalSafeAreaTop + bannerHeight + 16
        if abs(additionalSafeAreaInsets.top - reservedTop) > 0.5 {
            additionalSafeAreaInsets.top = reservedTop
        }
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
