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
        viewControllers?.forEach {
            if $0.isViewLoaded {
                $0.view.accessibilityElementsHidden = false
            }
        }
        tabBar.accessibilityElementsHidden = false
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
        selectedIndex = MainTabBarViewFactory.walletIndex

        let interactionShield = UIView()
        interactionShield.translatesAutoresizingMaskIntoConstraints = false
        interactionShield.backgroundColor = .clear
        interactionShield.isAccessibilityElement = false
        interactionShield.accessibilityViewIsModal = true

        let banner = UIView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.96)
        banner.layer.cornerRadius = 12

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Wallet recovery preview — read only. Restore your wallet backup to send funds."
        label.textColor = .black
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center

        let restoreButton = UIButton(type: .system)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.setTitle(
            R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale),
            for: .normal
        )
        restoreButton.setTitleColor(.black, for: .normal)
        restoreButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        restoreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        restoreButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        restoreButton.layer.cornerRadius = 8
        restoreButton.accessibilityHint = "Restore the signing key for this wallet"
        restoreButton.addTarget(self, action: #selector(restoreWallet), for: .touchUpInside)

        banner.addSubview(label)
        banner.addSubview(restoreButton)
        interactionShield.addSubview(banner)
        view.addSubview(interactionShield)
        recoveryInteractionShield = interactionShield
        viewControllers?.forEach {
            if $0.isViewLoaded {
                $0.view.accessibilityElementsHidden = true
            }
        }
        tabBar.accessibilityElementsHidden = true

        NSLayoutConstraint.activate([
            interactionShield.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            interactionShield.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            interactionShield.topAnchor.constraint(equalTo: view.topAnchor),
            interactionShield.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            banner.leadingAnchor.constraint(equalTo: interactionShield.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: interactionShield.trailingAnchor, constant: -16),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            restoreButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            restoreButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            restoreButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            restoreButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            restoreButton.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10)
        ])
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
