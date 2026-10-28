// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ObjectiveC
import SoraUIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!
    var middleButtonHadler: (() -> Void)?
    private var viewAppeared: Bool = false
    /// The custom bar, kept even when it could not be swapped in (its swap
    /// disc then lives on the system bar and still follows theme changes).
    private var customTabBar: TabBar?

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
    /// storage, as every release since 2.0 has. Verified on the iOS 18.4
    /// (notched bar), 26.5 and 27.0 (Liquid Glass) simulators, and checked
    /// by `SoraNeonDesignTests.testTabBarChromeAndSwapDisc` on whatever
    /// system the tests run on. If a future iOS renames that storage, KVC
    /// would raise an Objective-C exception, so the swap is skipped and the
    /// whole disc (glow, gradient fill, button, tap cover and label) moves
    /// onto the system tab bar.
    private func installCustomTabBar(_ custom: TabBar) {
        customTabBar = custom
        if class_getInstanceVariable(UITabBarController.self, "_tabBar") != nil {
            setValue(custom, forKey: "tabBar")
        }
        guard tabBar !== custom else { return }
        custom.installSwapDisc(in: tabBar)
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
        guard let custom = customTabBar, let items = tabBar.items else { return }
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

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // iOS 16–25: slide the active indicator (no-op on iOS 26+).
        (tabBar as? TabBar)?.updateSelectionIndicator(animated: true)
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
        customTabBar?.middleButtonTitleLabel.sora.text = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: languages)
    }
}
