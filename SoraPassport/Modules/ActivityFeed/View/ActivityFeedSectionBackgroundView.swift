import UIKit
import SoraUI

final class ActivityFeedSectionBackgroundView: UICollectionReusableView {
    @IBOutlet var itemSeparatorsView: ActivityFeedItemSeparatorsView!

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)

        guard let decoratorAttributes = layoutAttributes as? ActivityFeedDecoratorAttributes else {
            return
        }

        itemSeparatorsView.separatorVerticalPositions = decoratorAttributes.separatorVerticalPositions
    }
}

@IBDesignable
final class ActivityFeedItemSeparatorsView: UIView {
    var separatorVerticalPositions: [CGFloat] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable
    var separatorColor: UIColor = .gray {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable
    var separatorWidth: CGFloat = 1.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(separatorWidth)

        for position in separatorVerticalPositions {
            context.move(to: CGPoint(x: rect.minX, y: position))
            context.addLine(to: CGPoint(x: rect.maxX, y: position))
            context.drawPath(using: .stroke)
        }
    }
}
