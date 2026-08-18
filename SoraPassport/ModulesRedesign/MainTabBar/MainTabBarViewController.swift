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
