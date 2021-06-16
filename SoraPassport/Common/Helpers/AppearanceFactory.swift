/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraUI
import CommonWallet

struct AppearanceFactory {
    static func applyGlobalAppearance() {
        configureGlobalNavigationBar()
        configureButtons()
    }

    private static func configureButtons() {
        SoraButton.appearance().titleFont = .styled(for: .button)
        SoraButton.appearance().cornerRadius = 12.0
        SoraButton.appearance().shadowOpacity = 0

        GrayCopyButton.appearance().titleFont = .styled(for: .paragraph2)
        GrayCopyButton.appearance().cornerRadius = 24.0
        GrayCopyButton.appearance().shadowOpacity = 0

    }

    // TODO: SN-264. UINavigationBar configuration to decorator ??
    private static func configureGlobalNavigationBar() {

        let color = R.color.baseContentPrimary()!
        let image = R.image.arrowLeft()
        let largeFont = UIFont.styled(for: .display1)
        let normalFont = UIFont.styled(for: .paragraph1)

        if #available(iOS 13, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()

            // large title color
            appearance.largeTitleTextAttributes = [.foregroundColor: color, .font: largeFont]

            // title color
            appearance.titleTextAttributes = [.foregroundColor: color, .font: normalFont]

            // bar button styling
            let barButtonItemApperance = UIBarButtonItemAppearance()
            barButtonItemApperance.normal.titleTextAttributes = [.foregroundColor: color]
            appearance.backButtonAppearance = barButtonItemApperance

            // back button image
            appearance.setBackIndicatorImage(image, transitionMaskImage: image)

            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        } else {
            // back button image
            let barAppearance = UINavigationBar.appearance(
                whenContainedInInstancesOf: [SoraNavigationController.self]
            )

            barAppearance.backIndicatorImage = image
            barAppearance.backIndicatorTransitionMaskImage = image

            let barButtonAppearance = UIBarButtonItem.appearance(
                whenContainedInInstancesOf: [SoraNavigationController.self]
            )

            barButtonAppearance.setBackButtonTitlePositionAdjustment(
                UIOffset(horizontal: 0, vertical: -1), for: .default
            )
        }

        // large title color
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: color, .font: largeFont]

        UINavigationBar.appearance(whenContainedInInstancesOf: [SoraNavigationController.self]).prefersLargeTitles = true
        // title color
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: color, .font: normalFont]

        // the back icon / buttons color
        UINavigationBar.appearance().tintColor = color

        // background color
        UINavigationBar.appearance().barTintColor = .white
        UINavigationBar.appearance().backgroundColor = .white
        UINavigationBar.appearance().shadowImage = UIImage()
    }
}
