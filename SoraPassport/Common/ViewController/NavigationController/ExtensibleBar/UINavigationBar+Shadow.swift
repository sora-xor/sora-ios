/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

public extension UINavigationBar {

    var shadowIsHidden: Bool {
        get {
            if #available(iOS 13.0, *) {
                return standardAppearance.shadowColor == nil
            } else {
                return shadowImage != nil
            }
        }

        set {
            let newShadowImage = newValue ? UIImage() : nil
            let newShadowColor = newValue ? nil : UIColor.gray

            if #available(iOS 13.0, *) {
                scrollEdgeAppearance?.shadowColor = newShadowColor
                compactAppearance?.shadowColor = newShadowColor
                standardAppearance.shadowColor = newShadowColor
            } else {
                shadowImage = newShadowImage
            }
        }
    }
}
