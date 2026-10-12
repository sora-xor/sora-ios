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
