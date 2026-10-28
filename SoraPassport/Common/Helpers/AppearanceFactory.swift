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
import SoraUI

import SoraUIKit

struct AppearanceFactory {
    static func applyGlobalAppearance() {
        configureGlobalNavigationBar()
        configureButtons()
        configureSearchBar()
        configureTabBarItem()
    }

    private static func configureButtons() {
        SoraButton.appearance().titleFont = .styled(for: .button)
        SoraButton.appearance().cornerRadius = 12.0
        SoraButton.appearance().shadowOpacity = 0

        GrayCopyButton.appearance().titleFont = .styled(for: .paragraph2)
        GrayCopyButton.appearance().cornerRadius = 24.0
        GrayCopyButton.appearance().shadowOpacity = 0
    }

    private static func configureSearchBar() {
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([
            .foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary)],
                                             for: .normal)
    }

    private static func configureGlobalNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgPrimary) as Any]
        appearance.largeTitleTextAttributes = [.foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgPrimary) as Any]
        appearance.backgroundEffect = UIBlurEffect(style: SoramitsuUI.shared.theme == .light ? .light : .dark)
        
        let scrollingAppearance = UINavigationBarAppearance()
        scrollingAppearance.configureWithTransparentBackground()
        scrollingAppearance.backgroundColor = .clear
        scrollingAppearance.titleTextAttributes = [.foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgPrimary) as Any]
        scrollingAppearance.largeTitleTextAttributes = [.foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgPrimary) as Any]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollingAppearance
        UINavigationBar.appearance().compactAppearance = scrollingAppearance
        UINavigationBar.appearance().tintColor = SoramitsuUI.shared.theme.palette.color(.accentPrimary)
        
        let backImage = R.image.wallet.backArrow()
        
        UINavigationBar.appearance().backIndicatorImage = backImage
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = backImage
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .normal)
    }
    
    private static func configureTabBarItem() {
        UITabBarItem.appearance().setTitleTextAttributes(FontType.textBoldXS.attributes, for: .normal)
    }
}
