import UIKit

protocol LayoutFlexible {
    var itemWidth: CGFloat { get }
    var contentInsets: UIEdgeInsets { get }
}

extension LayoutFlexible {
    var drawingBoundingSize: CGSize {
        return CGSize(width: itemWidth - contentInsets.left - contentInsets.right,
                      height: CGFloat.greatestFiniteMagnitude)
    }
}
