import UIKit
import SoraUI

class AnimatableCollectionView: UICollectionViewCell {
    lazy var highlitedOnAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOn
    lazy var highlitedOffAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOff

    override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }

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
    }
}
