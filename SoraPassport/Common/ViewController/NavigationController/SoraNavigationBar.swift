/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

struct SoraNavigationBarStyle {
    static let background: UIImage? = {
        return UIImage.background(from: UIColor.navigationBarColor)
    }()

    static let darkShadow: UIImage? = {
        return UIImage.background(from: UIColor.darkNavigationShadowColor)
    }()

    static let lightShadow: UIImage? = {
        return UIImage.background(from: UIColor.lightNavigationShadowColor)
    }()

    static let noShadow: UIImage? = {
        return UIImage.background(from: UIColor.navigationBarColor)
    }()


    static let tintColor: UIColor? = {
        return R.color.baseContentPrimary()!
    }()

    static let titleAttributes: [NSAttributedString.Key: Any]? = {
        var titleTextAttributes = [NSAttributedString.Key: Any]()
        titleTextAttributes[.foregroundColor] = UIColor.navigationBarTitleColor
        titleTextAttributes[.font] = UIFont.navigationTitleFont

        return titleTextAttributes
    }()
}

protocol SoraCompactNavigationBarFloating: CompactNavigationBarFloating {}

extension SoraCompactNavigationBarFloating {
    var compactBarTitleAttributes: [NSAttributedString.Key: Any]? {
        return SoraNavigationBarStyle.titleAttributes
    }

    var compactBarBackground: UIImage? {
        return SoraNavigationBarStyle.background
    }

    var compactBarShadow: UIImage? {
        if let designableBar = self as? DesignableNavigationBarProtocol {
            switch designableBar.separatorStyle {
            case .dark:
                return SoraNavigationBarStyle.darkShadow
            case .light:
                return SoraNavigationBarStyle.lightShadow
            case .empty:
                return UIImage()
            }
        }

        return SoraNavigationBarStyle.darkShadow
    }
}
