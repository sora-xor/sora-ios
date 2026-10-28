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

import Foundation
import UIKit

import SoraUIKit

struct AppearanceFactory {
    static func applyGlobalAppearance() {
        configureGlobalNavigationBar()
        configureSearchBar()
        configureTabBarItem()
    }

    /// Appearance proxies only reach bars created later: re-style bars that
    /// are already on screen after a theme change.
    static func restyle(_ navigationBar: UINavigationBar) {
        let tokens = NeonTokens.current
        let (standard, scrollEdge) = NeonChrome.navigationBarAppearances(tokens: tokens)
        let backImage = R.image.wallet.backArrow()
        standard.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        scrollEdge.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        navigationBar.standardAppearance = standard
        navigationBar.scrollEdgeAppearance = scrollEdge
        navigationBar.compactAppearance = scrollEdge
        navigationBar.tintColor = tokens.cyan
    }

    /// Re-styles every navigation bar currently in the app's windows,
    /// including presented flows, after a theme change.
    static func restyleVisibleNavigationBars() {
        var visited = Set<ObjectIdentifier>()
        func visit(_ controller: UIViewController?) {
            guard let controller, visited.insert(ObjectIdentifier(controller)).inserted else { return }
            if let navigation = controller as? UINavigationController {
                restyle(navigation.navigationBar)
            }
            controller.children.forEach(visit)
            visit(controller.presentedViewController)
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { visit($0.rootViewController) }
    }

    private static func configureSearchBar() {
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([
            .foregroundColor: NeonTokens.current.cyan],
                                             for: .normal)
    }

    /// SORA Neon chrome (spec §4.3.3, §4.3.4). On iOS 26+ the bars keep the
    /// system Liquid Glass; only fonts, colours and the tint are set.
    private static func configureGlobalNavigationBar() {
        let tokens = NeonTokens.current
        let (standard, scrollEdge) = NeonChrome.navigationBarAppearances(tokens: tokens)

        let backImage = R.image.wallet.backArrow()
        standard.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        scrollEdge.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        UINavigationBar.appearance().compactAppearance = scrollEdge
        UINavigationBar.appearance().tintColor = tokens.cyan

        UINavigationBar.appearance().backIndicatorImage = backImage
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = backImage
        // Back-button titles stay hidden through the bar appearances above.
        // The old global `UIBarButtonItem` clear title also hid every text
        // bar button in the app.
    }
    
    private static func configureTabBarItem() {
        UITabBarItem.appearance().setTitleTextAttributes([.font: FontType.textXS.font], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: FontType.textBoldXS.font], for: .selected)
    }
}
