/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

class AnimatableCollectionView: UICollectionViewCell {
    lazy var highlitedOnAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOn
    lazy var highlitedOffAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOff

    override var isHighlighted: Bool {
        set {
            let oldValue = super.isHighlighted
            super.isHighlighted = newValue

            if !oldValue, newValue {
                layer.removeAllAnimations()
                highlitedOnAnimation.animate(view: self, completionBlock: nil)
            }

            if oldValue, !newValue {
                layer.removeAllAnimations()
                highlitedOffAnimation.animate(view: self, completionBlock: nil)
            }
        }

        get {
            return super.isHighlighted
        }
    }
}
