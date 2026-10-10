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
import ObjectiveC
import SoraUIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!
    var middleButtonHadler: (() -> Void)?
    private var viewAppeared: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        let tabBar = TabBar(frame: tabBar.frame)
        // The swap disc draws its own neon fill and glow; the Polkaswap mark
        // is tinted ink (white in light) on it.
        tabBar.middleButton.sora.image = R.image.wallet.polkaswap()?.withRenderingMode(.alwaysTemplate)
        tabBar.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.coverButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.middleButtonTitleLabel.sora.text = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: .currentLocale)
        installCustomTabBar(tabBar)

        installAurora()
        SoramitsuUI.updates.addObserver(self)
        configureTabBar()
    }

    /// Swaps in the notched tab bar with the swap disc. `UITabBarController`
    /// has no public setter, so this uses key-value coding on its `_tabBar`
    /// storage, as every release since 2.0 has. Verified on iOS 26 and 27
    /// (Liquid Glass). If a future iOS renames that storage, KVC would raise
    /// an Objective-C exception, so the swap is skipped and the disc is
    /// added to the system tab bar instead.
    private func installCustomTabBar(_ custom: TabBar) {
        if class_getInstanceVariable(UITabBarController.self, "_tabBar") != nil {
            setValue(custom, forKey: "tabBar")
        }
        guard tabBar !== custom else { return }
        [custom.coverButton, custom.middleButton, custom.middleButtonTitleLabel].forEach {
            $0.removeFromSuperview()
            tabBar.addSubview($0)
        }
        NSLayoutConstraint.activate([
            custom.middleButton.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            custom.middleButton.bottomAnchor.constraint(equalTo: tabBar.safeAreaLayoutGuide.bottomAnchor, constant: -21),
            custom.coverButton.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            custom.coverButton.bottomAnchor.constraint(equalTo: tabBar.safeAreaLayoutGuide.bottomAnchor),
            custom.middleButtonTitleLabel.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            custom.middleButtonTitleLabel.bottomAnchor.constraint(equalTo: tabBar.safeAreaLayoutGuide.bottomAnchor,
                                                                  constant: -1)
        ])
    }

    /// One static aurora behind every tab (spec §4.2.1). Tab roots are clear.
    private func installAurora() {
        let aurora = AuroraView(style: .standard)
        aurora.frame = view.bounds
        aurora.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(aurora, at: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let custom = tabBar as? TabBar, let items = tabBar.items else { return }
        let nativeButtons = tabBar.subviews.compactMap { $0 as? UIControl }
            .filter { $0 !== custom.coverButton && $0 !== custom.middleButton }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard nativeButtons.count == items.count, items.count == 5 else { return }
        var elements: [UIView] = []
        for (index, button) in nativeButtons.enumerated() {
            let accessibleButton: UIControl = index == 2 ? custom.middleButton : button
            accessibleButton.isAccessibilityElement = true
            accessibleButton.accessibilityLabel = index == 2
                ? custom.middleButtonTitleLabel.sora.text : items[index].title
            accessibleButton.accessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
            elements.append(accessibleButton)
        }
        custom.coverButton.isAccessibilityElement = false
        custom.middleButtonTitleLabel.isAccessibilityElement = false
        tabBar.accessibilityElements = elements
    }

    /// Spec §7.11: inactive items `text.secondary`, the active item
    /// `text.primary` (SemiBold). On iOS 26+ the system Liquid Glass
    /// selection is the indicator; nothing paints over the bar.
    private func configureTabBar() {
        let tokens = NeonTokens.current
        let appearance = NeonChrome.tabBarAppearance(tokens: tokens)
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = tokens.textPrimary
        tabBar.unselectedItemTintColor = tokens.textSecondary
        tabBar.items?.forEach {
            $0.setTitleTextAttributes([.foregroundColor: tokens.textSecondary, .font: FontType.textXS.font],
                                      for: .normal)
            $0.setTitleTextAttributes([.foregroundColor: tokens.textPrimary, .font: FontType.textBoldXS.font],
                                      for: .selected)
        }
    }
}

extension MainTabBarViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        configureTabBar()
        AppearanceFactory.applyGlobalAppearance()
        AppearanceFactory.restyleVisibleNavigationBars()
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
